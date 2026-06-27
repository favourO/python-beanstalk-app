from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.core.config import get_settings
from phora.core.security import create_token
from phora.db.session import get_session_factory
from phora.models import PricingEligibilityReviewLog, Subscription, User
from phora.services.stripe_billing import StripeBillingService


def _client(tmp_path, monkeypatch, name: str) -> TestClient:
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / name}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")
    monkeypatch.setenv("AFRICA_FREE_LAUNCH_ENABLED", "true")
    monkeypatch.setenv("LOCAL_CURRENCY_PRICING_ENABLED", "true")
    monkeypatch.setenv("DEFAULT_PRICING_COUNTRY", "GB")
    monkeypatch.setenv("DEFAULT_CURRENCY", "GBP")
    get_settings.cache_clear()
    return TestClient(create_app())


def _user(user_id: str = "01TESTLOCALPRICING000000000") -> str:
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email=f"{user_id.lower()}@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.commit()
    return f"Bearer {create_token(user_id, 'access', 30)}"


def test_country_affordability_pricing_uses_configured_fixed_stripe_prices(tmp_path, monkeypatch):
    client = _client(tmp_path, monkeypatch, "local-pricing-countries.db")

    cases = [
        ("GB", "GBP", "TIER_1_PREMIUM", "£3.99", "price_1TfEErGRl5Hb5DeyCEawachj"),
        ("US", "USD", "TIER_1_PREMIUM", "$2.99", "price_1TaYWVGRl5Hb5Deyl6kkG0zi"),
        ("CZ", "CZK", "TIER_3_VALUE", "Kc49", "price_1TaYXcGRl5Hb5Deytk7gUTwL"),
        ("DE", "EUR", "TIER_2_STANDARD", "€2.49", "price_1TaYXHGRl5Hb5Deylzups3z7"),
        ("IN", "INR", "TIER_4_GROWTH", "₹99", "price_1TaYXwGRl5Hb5DeymNEHmaaA"),
    ]
    for country, currency, tier, display, price_id in cases:
        response = client.get("/api/v1/billing/plan-offers", params={"country": country})
        assert response.status_code == 200
        body = response.json()
        assert body["requiresPayment"] is True
        assert body["isFreeRegion"] is False
        assert body["pricingTier"] == tier
        assert body["pricingStrategy"] == "AFFORDABILITY_BASED"
        assert body["currency"] == currency
        assert body["monthly"]["displayAmount"] == display
        assert body["monthly"]["stripePriceId"] == price_id


def test_african_user_gets_free_launch_and_no_stripe_checkout(tmp_path, monkeypatch):
    client = _client(tmp_path, monkeypatch, "africa-free-launch.db")
    auth = _user("01TESTAFRICAFREE0000000000")

    response = client.post(
        "/api/v1/billing/pricing-eligibility",
        headers={"Authorization": auth},
        json={"country": "NG", "phone_number": "+2348012345678"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["isFreeRegion"] is True
    assert body["requiresPayment"] is False
    assert body["planType"] == "AFRICA_FREE_LAUNCH"
    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == "01TESTAFRICAFREE0000000000").one()
        assert subscription.provider == "africa_free_launch"
        assert subscription.amount == 0.0


def test_unsupported_country_falls_back_to_default_price(tmp_path, monkeypatch):
    client = _client(tmp_path, monkeypatch, "fallback-default-pricing.db")

    response = client.get("/api/v1/billing/plan-offers", params={"country": "AQ"})

    assert response.status_code == 200
    body = response.json()
    assert body["normalized_country"] == "GB"
    assert body["currency"] == "GBP"
    assert body["fallbackApplied"] is True
    assert body["monthly"]["stripePriceId"] == "price_1TaYVaGRl5Hb5DeyQDl1oONm"


def test_feature_flag_disabled_uses_default_paid_pricing(tmp_path, monkeypatch):
    client = _client(tmp_path, monkeypatch, "local-pricing-disabled.db")
    monkeypatch.setenv("LOCAL_CURRENCY_PRICING_ENABLED", "false")
    get_settings.cache_clear()

    response = client.get("/api/v1/billing/plan-offers", params={"country": "CZ"})

    assert response.status_code == 200
    body = response.json()
    assert body["normalized_country"] == "GB"
    assert body["currency"] == "GBP"
    assert body["fallbackReason"] == "local_currency_pricing_disabled"


def test_mismatched_country_signals_are_logged(tmp_path, monkeypatch):
    client = _client(tmp_path, monkeypatch, "mismatched-country-signals.db")
    auth = _user("01TESTMISMATCH000000000000")

    response = client.post(
        "/api/v1/billing/pricing-eligibility",
        headers={"Authorization": auth},
        json={"country": "NG", "billing_country": "GB", "phone_number": "+2348012345678"},
    )

    assert response.status_code == 200
    assert response.json()["reviewFlagged"] is True
    assert response.json()["requiresPayment"] is True
    with get_session_factory()() as db:
        log = db.query(PricingEligibilityReviewLog).one()
        assert log.reason == "country_signal_mismatch"


def test_billing_country_wins_over_device_location_for_paid_pricing(tmp_path, monkeypatch):
    client = _client(tmp_path, monkeypatch, "billing-country-priority.db")

    response = client.get(
        "/api/v1/billing/plan-offers",
        params={
            "country": "United Kingdom",
            "billing_country": "United Kingdom",
            "device_location_country": "US",
            "device_locale_country": "US",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["normalized_country"] == "GB"
    assert body["currency"] == "GBP"
    assert body["yearly"]["displayAmount"] == "£35"


def test_request_country_wins_over_device_location_for_older_clients(tmp_path, monkeypatch):
    client = _client(tmp_path, monkeypatch, "request-country-priority.db")

    response = client.get(
        "/api/v1/billing/plan-offers",
        params={
            "country": "United Kingdom",
            "device_location_country": "US",
            "device_locale_country": "US",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["normalized_country"] == "GB"
    assert body["currency"] == "GBP"


def test_stripe_checkout_uses_resolved_country_price_id(tmp_path, monkeypatch):
    client = _client(tmp_path, monkeypatch, "stripe-checkout-resolved-price.db")
    auth = _user("01TESTSTRIPEPRICE0000000000")
    captured: dict[str, str] = {}

    def fake_stripe_post(self, path, *, data, stripe_version=None):
        captured.update(data)
        return {"id": "cs_test_123", "url": "https://checkout.stripe.com/test"}

    monkeypatch.setattr(StripeBillingService, "_stripe_post", fake_stripe_post)

    response = client.post(
        "/api/v1/billing/stripe/checkout-sessions",
        headers={"Authorization": auth},
        json={
            "country": "CZ",
            "plan_id": "premium_plus",
            "interval": "month",
            "success_url": "https://example.com/success",
            "cancel_url": "https://example.com/cancel",
        },
    )

    assert response.status_code == 200
    assert captured["line_items[0][price]"] == "price_1TaYXcGRl5Hb5Deytk7gUTwL"
    assert captured["metadata[pricing_tier]"] == "TIER_3_VALUE"
    assert response.json()["provider_price_id"] == "price_1TaYXcGRl5Hb5Deytk7gUTwL"


def test_removed_flutterwave_subscription_does_not_surface_legacy_ngn_price(tmp_path, monkeypatch):
    client = _client(tmp_path, monkeypatch, "removed-flutterwave-subscription.db")
    user_id = "01TESTREMOVEDFLW0000000000"
    auth = _user(user_id)
    with get_session_factory()() as db:
        db.add(
            Subscription(
                user_id=user_id,
                tier="premium_plus",
                status="active",
                provider="flutterwave",
                currency="NGN",
                amount=27000.0,
                billing_interval="year",
                provider_price_id="legacy_flutterwave_price",
            )
        )
        db.commit()

    response = client.get(
        "/api/v1/billing/subscription",
        headers={"Authorization": auth},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["is_active"] is False
    assert body["show_subscription_screen"] is True
    assert body["currency"] is None
    assert body["amount"] is None
