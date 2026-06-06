import base64
import hashlib
import hmac
import json
from datetime import UTC, datetime

from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.core.config import Settings
from phora.core.security import create_token
from phora.db.session import get_session_factory
from phora.models import Invoice, PricingEligibilityReviewLog, Subscription, User, WearableOrder
from phora.services import billing_catalog
from phora.services.email import EmailService


def test_plan_offers_uses_stripe_for_united_kingdom(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-uk.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    app = create_app()
    client = TestClient(app)

    response = client.get("/api/v1/billing/plan-offers", params={"country": "United Kingdom"})

    assert response.status_code == 200
    body = response.json()
    assert body["supported"] is True
    assert body["primary_provider"] == "stripe"
    assert body["provider_configured"] is True
    assert body["checkout_endpoint"] == "/api/v1/billing/stripe/payment-sheet"
    assert body["checkout_public_key"] == "pk_test_123"
    assert body["currency"] == "GBP"
    assert len(body["plans"]) == 2
    assert body["plans"][1]["id"] == "premium_plus"
    assert body["plans"][1]["name"] == "Premium"
    assert body["plans"][1]["display_price"] == "£3.99"
    assert body["plans"][1]["billing_period"] == "month"
    assert body["plans"][1]["provider_product_id"] == "prod_UHWvb0SEUJR4Hk"
    assert body["plans"][1]["provider_price_id"] == "price_1TTR20GRl5Hb5Deyw0zaAes6"
    assert body["plans"][1]["price_options"] == [
        {
            "interval": "month",
            "provider_price_id": "price_1TTR20GRl5Hb5Deyw0zaAes6",
            "price_minor": 399,
            "display_price": "£3.99",
        },
        {
            "interval": "year",
            "provider_price_id": "price_1TTR20GRl5Hb5DeyR2UCLkOX",
            "price_minor": 3500,
            "display_price": "£35",
        },
    ]
    assert body["plans"][1]["badge"] == "POPULAR"


def test_plan_offers_use_live_stripe_catalog_when_live_keys_are_configured(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-live-catalog.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_ENVIRONMENT", "stage")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_live_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_live_123")
    monkeypatch.setenv("PHORA_STRIPE_PREMIUM_GBP_MONTH_PRICE_ID", "price_live_gbp_month_399")
    monkeypatch.setenv("PHORA_STRIPE_PREMIUM_GBP_YEAR_PRICE_ID", "price_live_gbp_year_3500")

    app = create_app()
    client = TestClient(app)

    response = client.get("/api/v1/billing/plan-offers", params={"country": "United Kingdom"})

    assert response.status_code == 200
    body = response.json()
    assert body["primary_provider"] == "stripe"
    assert body["plans"][1]["provider_product_id"] == "prod_UHVBHeX529Udc0"
    assert body["plans"][1]["provider_price_id"] == "price_live_gbp_month_399"
    assert body["plans"][1]["price_options"][1]["provider_price_id"] == "price_live_gbp_year_3500"


def test_plan_offers_uses_flutterwave_for_nigeria(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-ng.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_PUBLIC_KEY", "FLWPUBK_TEST-123")

    app = create_app()
    client = TestClient(app)

    response = client.get("/api/v1/billing/plan-offers", params={"country": "Nigeria"})

    assert response.status_code == 200
    body = response.json()
    assert body["supported"] is True
    assert body["primary_provider"] == "flutterwave"
    assert body["provider_configured"] is True
    assert body["checkout_endpoint"] == "/api/v1/billing/flutterwave/checkout-sessions"
    assert body["checkout_public_key"] == "FLWPUBK_TEST-123"
    assert body["currency"] == "NGN"
    assert len(body["plans"]) == 2
    assert body["plans"][1]["display_price"] == "₦3,000"
    assert body["plans"][1]["price_options"][1]["display_price"] == "₦27,000"


def test_plan_offers_uses_lower_flutterwave_regional_prices_outside_nigeria(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-gh.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get("/api/v1/billing/plan-offers", params={"country": "Ghana"})

    assert response.status_code == 200
    body = response.json()
    assert body["supported"] is True
    assert body["primary_provider"] == "flutterwave"
    assert body["currency"] == "GHS"
    assert body["plans"][1]["display_price"] == "GH₵29"
    assert body["plans"][1]["price_options"][1]["display_price"] == "GH₵261"


def test_plan_offers_uses_usd_for_united_states(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-us.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get("/api/v1/billing/plan-offers", params={"country": "United States"})

    assert response.status_code == 200
    body = response.json()
    assert body["supported"] is True
    assert body["primary_provider"] == "stripe"
    assert body["currency"] == "USD"
    assert len(body["plans"]) == 2
    assert body["plans"][1]["display_price"] == "$4.99"
    assert body["plans"][1]["provider_product_id"] == "prod_UHVBHeX529Udc0"
    assert body["plans"][1]["provider_price_id"] == "price_1TIwFOGRl5Hb5DeyGaYnuDP0"
    assert body["plans"][1]["price_options"] == [
        {
            "interval": "month",
            "provider_price_id": "price_1TIwFOGRl5Hb5DeyGaYnuDP0",
            "price_minor": 499,
            "display_price": "$4.99",
        },
        {
            "interval": "year",
            "provider_price_id": "price_1TIwFnGRl5Hb5Dey3nJzr4Dx",
            "price_minor": 4000,
            "display_price": "$40",
        },
    ]


def test_plan_offers_uses_czk_for_czech_republic_in_test_catalog(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-cz.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    app = create_app()
    client = TestClient(app)

    response = client.get("/api/v1/billing/plan-offers", params={"country": "Czech Republic"})

    assert response.status_code == 200
    body = response.json()
    assert body["primary_provider"] == "stripe"
    assert body["provider_configured"] is True
    assert body["currency"] == "CZK"
    assert body["plans"][1]["provider_product_id"] == "prod_UHWvb0SEUJR4Hk"
    assert body["plans"][1]["provider_price_id"] == "price_1TKz69GRl5Hb5DeyCXknTQ8p"
    assert body["plans"][1]["price_options"] == [
        {
            "interval": "month",
            "provider_price_id": "price_1TKz69GRl5Hb5DeyCXknTQ8p",
            "price_minor": 11477,
            "display_price": "Kc114.77",
        },
        {
            "interval": "year",
            "provider_price_id": "price_1TKz69GRl5Hb5DeyFWY3R8qU",
            "price_minor": 92000,
            "display_price": "Kc920",
        },
    ]


def test_plan_offers_uses_matching_eur_test_prices(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-eur.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    app = create_app()
    client = TestClient(app)

    response = client.get("/api/v1/billing/plan-offers", params={"country": "Germany"})

    assert response.status_code == 200
    body = response.json()
    assert body["currency"] == "EUR"
    assert body["plans"][1]["price_options"] == [
        {
            "interval": "month",
            "provider_price_id": "price_1TYsDpGRl5Hb5DeyORFNMRbA",
            "price_minor": 459,
            "display_price": "EUR4.59",
        },
        {
            "interval": "year",
            "provider_price_id": "price_1TYsDpGRl5Hb5DeygaJVLN6N",
            "price_minor": 3680,
            "display_price": "EUR36.80",
        },
    ]


def test_test_stripe_catalog_covers_all_stripe_country_currencies():
    stripe_currencies = {currency for _, currency in billing_catalog._STRIPE_COUNTRIES.values()}
    test_currencies = {currency for currency, _, _ in billing_catalog._STRIPE_PRICE_IDS_TEST}

    assert test_currencies == stripe_currencies
    for currency in stripe_currencies:
        assert (currency, "premium_plus", "month") in billing_catalog._STRIPE_PRICE_IDS_TEST
        assert (currency, "premium_plus", "year") in billing_catalog._STRIPE_PRICE_IDS_TEST


def test_live_stripe_catalog_covers_all_stripe_country_currencies():
    stripe_currencies = {currency for _, currency in billing_catalog._STRIPE_COUNTRIES.values()}
    live_currencies = {currency for currency, _, _ in billing_catalog._STRIPE_PRICE_IDS_LIVE}

    assert live_currencies == stripe_currencies
    for currency in stripe_currencies:
        assert (currency, "premium_plus", "month") in billing_catalog._STRIPE_PRICE_IDS_LIVE
        assert (currency, "premium_plus", "year") in billing_catalog._STRIPE_PRICE_IDS_LIVE


def test_plan_offers_falls_back_for_unsupported_country(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-fallback.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get("/api/v1/billing/plan-offers", params={"country": "Antarctica"})

    assert response.status_code == 200
    body = response.json()
    assert body["supported"] is False
    assert body["primary_provider"] is None
    assert body["provider_configured"] is True
    assert body["checkout_endpoint"] is None
    assert body["checkout_public_key"] is None
    assert body["currency"] == "USD"
    assert "not yet localized" in body["subheadline"].lower()


def test_create_stripe_checkout_session_returns_checkout_url(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-checkout.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "billing@example.com",
            "password": "password123",
            "first_name": "Billing",
            "last_name": "User",
            "country": "United Kingdom",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "billing@example.com", "code": sent_codes["billing@example.com"]},
    )
    assert verify.status_code == 200
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    def fake_stripe_post(self, path: str, *, data: dict[str, str]) -> dict[str, str]:
        assert path == "/v1/checkout/sessions"
        assert data["line_items[0][price]"] == "price_1TTR20GRl5Hb5Deyw0zaAes6"
        assert data["metadata[plan_id]"] == "premium_plus"
        assert data["subscription_data[metadata][interval]"] == "month"
        assert (
            data["success_url"]
            == "http://testserver/api/v1/billing/stripe/return/success"
            "?target=vyla%3A%2F%2Fbilling%2Fsuccess%3Fsession_id%3D%7BCHECKOUT_SESSION_ID%7D"
            "&session_id=%7BCHECKOUT_SESSION_ID%7D"
        )
        assert (
            data["cancel_url"]
            == "http://testserver/api/v1/billing/stripe/return/cancel?target=vyla%3A%2F%2Fbilling%2Fcancel"
        )
        return {"id": "cs_test_123", "url": "https://checkout.stripe.com/c/pay/cs_test_123"}

    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_post", fake_stripe_post)

    response = client.post(
        "/api/v1/billing/stripe/checkout-sessions",
        headers=headers,
        json={
            "country": "United Kingdom",
            "plan_id": "premium_plus",
            "interval": "month",
            "success_url": "vyla://billing/success?session_id={CHECKOUT_SESSION_ID}",
            "cancel_url": "vyla://billing/cancel",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "stripe"
    assert body["checkout_session_id"] == "cs_test_123"
    assert body["checkout_url"] == "https://checkout.stripe.com/c/pay/cs_test_123"
    assert body["publishable_key"] == "pk_test_123"
    assert body["provider_product_id"] == "prod_UHWvb0SEUJR4Hk"
    assert body["provider_price_id"] == "price_1TTR20GRl5Hb5Deyw0zaAes6"


def test_create_stripe_payment_sheet_returns_native_payment_details(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-payment-sheet.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "payment-sheet@example.com",
            "password": "password123",
            "first_name": "Payment",
            "last_name": "Sheet",
            "country": "United Kingdom",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "payment-sheet@example.com", "code": sent_codes["payment-sheet@example.com"]},
    )
    assert verify.status_code == 200
    user_id = verify.json()["user"]["id"]
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    calls: list[tuple[str, dict[str, object], str | None]] = []

    def fake_stripe_post(
        self,
        path: str,
        *,
        data: dict[str, object],
        stripe_version: str | None = None,
    ) -> dict[str, object]:
        calls.append((path, data, stripe_version))
        if path == "/v1/customers":
            assert data["email"] == "payment-sheet@example.com"
            assert data["metadata[user_id]"] == user_id
            return {"id": "cus_payment_sheet"}
        if path == "/v1/subscriptions":
            assert data["customer"] == "cus_payment_sheet"
            assert data["items[0][price]"] == "price_1TTR20GRl5Hb5Deyw0zaAes6"
            assert data["payment_behavior"] == "default_incomplete"
            assert data["payment_settings[save_default_payment_method]"] == "on_subscription"
            assert data["metadata[plan_id]"] == "premium_plus"
            assert data["metadata[interval]"] == "month"
            return {
                "id": "sub_payment_sheet",
                "status": "incomplete",
                "current_period_end": int(datetime(2026, 6, 1, tzinfo=UTC).timestamp()),
                "latest_invoice": {
                    "payment_intent": {
                        "id": "pi_payment_sheet",
                        "client_secret": "pi_payment_sheet_secret_123",
                    },
                },
            }
        if path == "/v1/ephemeral_keys":
            assert stripe_version == "2026-02-25.clover"
            assert data["customer"] == "cus_payment_sheet"
            return {"id": "ephkey_payment_sheet", "secret": "ek_test_secret_123"}
        raise AssertionError(f"Unexpected Stripe path: {path}")

    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_post", fake_stripe_post)

    response = client.post(
        "/api/v1/billing/stripe/payment-sheet",
        headers=headers,
        json={
            "country": "United Kingdom",
            "plan_id": "premium_plus",
            "interval": "month",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "stripe"
    assert body["payment_intent_client_secret"] == "pi_payment_sheet_secret_123"
    assert body["customer_id"] == "cus_payment_sheet"
    assert body["customer_ephemeral_key_secret"] == "ek_test_secret_123"
    assert body["publishable_key"] == "pk_test_123"
    assert body["provider_subscription_id"] == "sub_payment_sheet"
    assert body["provider_product_id"] == "prod_UHWvb0SEUJR4Hk"
    assert body["provider_price_id"] == "price_1TTR20GRl5Hb5Deyw0zaAes6"
    assert body["amount_minor"] == 399
    assert body["display_price"] == "£3.99"
    assert [call[0] for call in calls] == [
        "/v1/customers",
        "/v1/subscriptions",
        "/v1/ephemeral_keys",
    ]

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == user_id).one()
        assert subscription.provider == "stripe"
        assert subscription.provider_customer_id == "cus_payment_sheet"
        assert subscription.provider_subscription_id == "sub_payment_sheet"
        assert subscription.provider_price_id == "price_1TTR20GRl5Hb5Deyw0zaAes6"
        assert subscription.tier == "premium_plus"
        assert subscription.status == "incomplete"
        assert subscription.amount == 3.99
        assert subscription.billing_interval == "month"


def test_african_user_gets_free_launch_access_without_stripe(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-africa-free.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("AFRICA_FREE_LAUNCH_ENABLED", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    app = create_app()
    client = TestClient(app)
    user_id = "01AFRICAFREELAUNCHUSER000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="africa-free@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.commit()

    def fail_stripe_post(*args, **kwargs):
        raise AssertionError("Stripe must not be called for Africa free launch users")

    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_post", fail_stripe_post)
    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}

    response = client.post(
        "/api/v1/billing/stripe/payment-sheet",
        headers=headers,
        json={
            "country": "Ghana",
            "plan_id": "premium_plus",
            "interval": "month",
            "app_store_country": "GH",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["isFreeRegion"] is True
    assert body["requiresPayment"] is False
    assert body["pricingRule"] == "africa_free_launch_promotion"
    assert body["freeLaunchPlanId"] == "africa_free_launch_premium_plus"

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == user_id).one()
        assert subscription.provider == "africa_free_launch"
        assert subscription.tier == "premium_plus"
        assert subscription.status == "active"
        assert subscription.amount == 0.0


def test_non_african_user_continues_to_stripe(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-non-africa-stripe.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("AFRICA_FREE_LAUNCH_ENABLED", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    app = create_app()
    client = TestClient(app)
    user_id = "01NONAFRICASTRIPEUSER000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="non-africa@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.commit()

    calls: list[str] = []

    def fake_stripe_post(self, path: str, *, data: dict[str, object], stripe_version: str | None = None) -> dict[str, object]:
        calls.append(path)
        if path == "/v1/customers":
            return {"id": "cus_non_africa"}
        if path == "/v1/subscriptions":
            return {
                "id": "sub_non_africa",
                "status": "incomplete",
                "current_period_end": int(datetime(2026, 6, 1, tzinfo=UTC).timestamp()),
                "latest_invoice": {"payment_intent": {"client_secret": "pi_non_africa_secret"}},
            }
        if path == "/v1/ephemeral_keys":
            return {"secret": "ek_non_africa_secret"}
        raise AssertionError(f"Unexpected Stripe path: {path}")

    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_post", fake_stripe_post)
    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}

    response = client.post(
        "/api/v1/billing/stripe/payment-sheet",
        headers=headers,
        json={"country": "United Kingdom", "plan_id": "premium_plus", "interval": "month"},
    )

    assert response.status_code == 200
    assert response.json()["provider"] == "stripe"
    assert calls == ["/v1/customers", "/v1/subscriptions", "/v1/ephemeral_keys"]


def test_mismatched_pricing_signals_are_logged(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-signal-mismatch.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("AFRICA_FREE_LAUNCH_ENABLED", "true")

    app = create_app()
    client = TestClient(app)
    user_id = "01SIGNALMISMATCHUSER000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="signal-mismatch@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.commit()

    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}
    response = client.post(
        "/api/v1/billing/pricing-eligibility",
        headers=headers,
        json={"country": "Ghana", "billing_country": "United States"},
    )

    assert response.status_code == 200
    assert response.json()["isFreeRegion"] is False
    assert response.json()["requiresPayment"] is True
    assert response.json()["reviewFlagged"] is True

    with get_session_factory()() as db:
        log = db.query(PricingEligibilityReviewLog).one()
        assert log.reason == "country_signal_mismatch"
        countries = {item["country"] for item in log.signals["countries"]}
        assert {"GH", "US"}.issubset(countries)


def test_device_location_country_can_qualify_africa_free_launch(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-device-location.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("AFRICA_FREE_LAUNCH_ENABLED", "true")

    app = create_app()
    client = TestClient(app)
    user_id = "01DEVICELOCATIONUSER000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="device-location@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/billing/pricing-eligibility",
        headers={"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"},
        json={"country": "Ghana", "device_location_country": "GH"},
    )

    assert response.status_code == 200
    assert response.json()["isFreeRegion"] is True
    assert response.json()["requiresPayment"] is False


def test_africa_free_launch_flag_disabled_uses_normal_pricing(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-africa-disabled.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("AFRICA_FREE_LAUNCH_ENABLED", "false")

    app = create_app()
    client = TestClient(app)
    user_id = "01AFRICADISABLEDUSER000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="africa-disabled@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.commit()

    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}
    response = client.post(
        "/api/v1/billing/pricing-eligibility",
        headers=headers,
        json={"country": "Nigeria", "app_store_country": "NG"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["isFreeRegion"] is False
    assert body["requiresPayment"] is True
    assert body["pricingRule"] == "standard_paid_pricing"
    assert body["reason"] == "feature_flag_disabled"

    with get_session_factory()() as db:
        assert db.query(Subscription).filter(Subscription.user_id == user_id).count() == 0


def test_sync_stripe_payment_sheet_subscription_marks_subscription_active(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-payment-sheet-sync.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    app = create_app()
    client = TestClient(app)
    user_id = "01PAYMENTSHEETSYNCUSER000000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="payment-sheet-sync@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.add(
            Subscription(
                user_id=user_id,
                provider="stripe",
                provider_customer_id="cus_payment_sheet_sync",
                provider_subscription_id="sub_payment_sheet_sync",
                provider_price_id="price_1TTR20GRl5Hb5Deyw0zaAes6",
                tier="premium_plus",
                status="incomplete",
                billing_interval="month",
            )
        )
        db.commit()

    token = create_token(user_id, "access", 30)
    headers = {"Authorization": f"Bearer {token}"}

    def fake_stripe_get(self, path: str, *, params: dict[str, object] | None = None) -> dict[str, object]:
        assert path == "/v1/subscriptions/sub_payment_sheet_sync"
        assert params == {"expand[]": "latest_invoice.payment_intent"}
        return {
            "id": "sub_payment_sheet_sync",
            "customer": "cus_payment_sheet_sync",
            "status": "active",
            "currency": "gbp",
            "current_period_end": int(datetime(2026, 6, 1, tzinfo=UTC).timestamp()),
            "metadata": {
                "user_id": user_id,
                "plan_id": "premium_plus",
                "interval": "month",
            },
            "items": {
                "data": [
                    {
                        "price": {
                            "id": "price_1TTR20GRl5Hb5Deyw0zaAes6",
                            "currency": "gbp",
                            "unit_amount": 399,
                            "recurring": {"interval": "month"},
                        }
                    }
                ]
            },
            "latest_invoice": {
                "payment_intent": {
                    "id": "pi_payment_sheet_sync",
                    "status": "succeeded",
                }
            },
        }

    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_get", fake_stripe_get)

    response = client.post(
        "/api/v1/billing/stripe/payment-sheet/sync",
        headers=headers,
        json={"provider_subscription_id": "sub_payment_sheet_sync"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "stripe"
    assert body["tier"] == "premium_plus"
    assert body["status"] == "active"
    assert body["is_active"] is True
    assert body["redirect_to_home"] is True
    assert body["provider_price_id"] == "price_1TTR20GRl5Hb5Deyw0zaAes6"

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == user_id).one()
        assert subscription.status == "active"
        assert subscription.currency == "GBP"
        assert subscription.amount == 3.99
        assert subscription.current_period_end.replace(tzinfo=UTC) == datetime(2026, 6, 1, tzinfo=UTC)


def test_stripe_checkout_return_success_redirects_back_to_app(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-return-success.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get(
        "/api/v1/billing/stripe/return/success",
        params={
            "target": "vyla://billing/success?foo=bar",
            "session_id": "cs_test_123",
        },
        follow_redirects=False,
    )

    assert response.status_code == 307
    assert response.headers["location"] == "vyla://billing/success?foo=bar&session_id=cs_test_123"


def test_stripe_checkout_return_success_replaces_placeholder_session_id(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-return-placeholder.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get(
        "/api/v1/billing/stripe/return/success",
        params={
            "target": "vyla://billing/success?session_id={CHECKOUT_SESSION_ID}",
            "session_id": "cs_test_123",
        },
        follow_redirects=False,
    )

    assert response.status_code == 307
    assert response.headers["location"] == "vyla://billing/success?session_id=cs_test_123"


def test_stripe_checkout_return_cancel_redirects_back_to_app(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-return-cancel.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get(
        "/api/v1/billing/stripe/return/cancel",
        params={"target": "vyla://billing/cancel"},
        follow_redirects=False,
    )

    assert response.status_code == 307
    assert response.headers["location"] == "vyla://billing/cancel"


def test_create_flutterwave_checkout_session_returns_checkout_url(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-checkout.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_PUBLIC_KEY", "FLWPUBK_TEST-123")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "flutterwave@example.com",
            "password": "password123",
            "first_name": "Flutterwave",
            "last_name": "User",
            "country": "Nigeria",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "flutterwave@example.com", "code": sent_codes["flutterwave@example.com"]},
    )
    assert verify.status_code == 200
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    selection = client.post(
        "/api/v1/billing/subscription-selection",
        headers=headers,
        json={"tier": "premium_plus", "interval": "month", "country": "Nigeria"},
    )
    assert selection.status_code == 200

    def fake_ensure_payment_plan(self, *, country: str, currency: str, interval: str, amount: float) -> int:
        assert country == "Nigeria"
        assert currency == "NGN"
        assert interval == "month"
        assert amount == 3000.0
        return 3807

    def fake_flutterwave_post(self, path: str, *, json: dict[str, str]) -> dict[str, object]:
        assert path == "/v3/payments"
        assert json["currency"] == "NGN"
        assert json["amount"] == "3000.0"
        assert (
            json["redirect_url"]
            == "http://testserver/api/v1/billing/flutterwave/return?target=vyla%3A%2F%2Fbilling%2Fflutterwave-callback"
        )
        assert json["payment_plan"] == 3807
        assert json["payment_options"] == "card"
        assert json["customer"]["email"] == "flutterwave@example.com"
        assert json["meta"]["plan_id"] == "premium_plus"
        return {
            "status": "success",
            "message": "Hosted Link",
            "data": {
                "link": "https://checkout.flutterwave.com/v3/hosted/pay/test-link",
            },
        }

    monkeypatch.setattr(
        "phora.services.flutterwave_billing.FlutterwaveBillingService._ensure_payment_plan",
        fake_ensure_payment_plan,
    )
    monkeypatch.setattr("phora.services.flutterwave_billing.FlutterwaveBillingService._flutterwave_post", fake_flutterwave_post)

    response = client.post(
        "/api/v1/billing/flutterwave/checkout-sessions",
        headers=headers,
        json={
            "country": "Nigeria",
            "plan_id": "premium_plus",
            "interval": "month",
            "redirect_url": "vyla://billing/flutterwave-callback",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "flutterwave"
    assert body["checkout_url"] == "https://checkout.flutterwave.com/v3/hosted/pay/test-link"
    assert body["public_key"] == "FLWPUBK_TEST-123"
    assert body["plan_id"] == "premium_plus"
    assert body["interval"] == "month"
    assert body["currency"] == "NGN"
    assert body["amount_minor"] == 300000
    assert body["display_price"] == "₦3,000"
    assert body["customer_email"] == "flutterwave@example.com"
    assert body["tx_ref"].startswith("phora-")

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == verify.json()["user"]["id"]).one()
        assert subscription.provider == "flutterwave"
        assert subscription.status == "pending_checkout"
        assert subscription.provider_subscription_id == body["tx_ref"]
        assert subscription.provider_price_id == "3807"


def test_flutterwave_checkout_return_redirects_back_to_app(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-return.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get(
        "/api/v1/billing/flutterwave/return",
        params={"target": "vyla://billing/flutterwave-callback?status=successful&tx_ref=abc123"},
        follow_redirects=False,
    )

    assert response.status_code == 307
    assert response.headers["location"] == "vyla://billing/flutterwave-callback?status=successful&tx_ref=abc123"


def test_flutterwave_checkout_return_confirms_successful_transaction(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-return-confirm.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        from phora.models import User

        user = User(
            id="01TESTUSERFLWRETURN0000000",
            email="flutterwave-return@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="flutterwave",
                provider_subscription_id="phora-return-ref",
                provider_customer_id="flutterwave-return@example.com",
                provider_price_id="991",
                tier="premium_plus",
                status="pending_checkout",
                billing_interval="month",
            )
        )
        db.commit()

    def fake_verify_transaction(self, transaction_id: str | int) -> dict[str, object]:
        assert str(transaction_id) == "77788"
        return {
            "status": "success",
            "data": {
                "id": 77788,
                "tx_ref": "phora-return-ref",
                "flw_ref": "flw_ref_return",
                "amount": 12.0,
                "charged_amount": 12.0,
                "currency": "XOF",
                "status": "successful",
                "plan": 991,
                "customer": {
                    "email": "ravesb_demo_flutterwave-return@example.com",
                },
                "meta": {
                    "user_id": "01TESTUSERFLWRETURN0000000",
                    "plan_id": "premium_plus",
                    "interval": "month",
                    "country": "Ivory Coast",
                },
            },
        }

    monkeypatch.setattr(
        "phora.services.flutterwave_billing.FlutterwaveBillingService._verify_transaction",
        fake_verify_transaction,
    )

    response = client.get(
        "/api/v1/billing/flutterwave/return",
        params={
            "target": "vyla://billing/flutterwave-callback",
            "status": "successful",
            "tx_ref": "phora-return-ref",
            "transaction_id": "77788",
        },
        follow_redirects=False,
    )

    assert response.status_code == 307
    assert response.headers["location"] == "vyla://billing/flutterwave-callback"

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.provider_subscription_id == "phora-return-ref").one()
        assert subscription.status == "active"
        assert subscription.current_period_end is not None


def test_create_flutterwave_checkout_session_requires_flutterwave_country(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-country.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "wrong-country@example.com",
            "password": "password123",
            "first_name": "Wrong",
            "last_name": "Country",
            "country": "United Kingdom",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "wrong-country@example.com", "code": sent_codes["wrong-country@example.com"]},
    )
    assert verify.status_code == 200

    response = client.post(
        "/api/v1/billing/flutterwave/checkout-sessions",
        headers={"Authorization": f"Bearer {verify.json()['access_token']}"},
        json={
            "country": "United Kingdom",
            "plan_id": "premium_plus",
            "interval": "month",
            "redirect_url": "vyla://billing/flutterwave-callback",
        },
    )

    assert response.status_code == 400
    detail = response.json()["detail"].lower()
    assert (
        "not configured" in detail
        or "not available" in detail
        or "no stripe price is configured" in detail
    )


def test_create_flutterwave_checkout_session_hides_expired_key_provider_error(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-expired-key.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_PUBLIC_KEY", "FLWPUBK_TEST-123")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "flutterwave-expired@example.com",
            "password": "password123",
            "first_name": "Flutterwave",
            "last_name": "Expired",
            "country": "Nigeria",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "flutterwave-expired@example.com", "code": sent_codes["flutterwave-expired@example.com"]},
    )
    assert verify.status_code == 200

    selection = client.post(
        "/api/v1/billing/subscription-selection",
        headers={"Authorization": f"Bearer {verify.json()['access_token']}"},
        json={"tier": "premium_plus", "interval": "month", "country": "Nigeria"},
    )
    assert selection.status_code == 200

    def fail_create_checkout_session(self, *, user_id: str, country: str, plan_id: str, interval: str, redirect_url: str | None = None) -> dict[str, object]:
        raise FlutterwaveBillingError("Flutterwave checkout failed: Key has expired")

    monkeypatch.setattr(
        "phora.services.flutterwave_billing.FlutterwaveBillingService.create_checkout_session",
        fail_create_checkout_session,
    )

    response = client.post(
        "/api/v1/billing/flutterwave/checkout-sessions",
        headers={"Authorization": f"Bearer {verify.json()['access_token']}"},
        json={
            "country": "Nigeria",
            "plan_id": "premium_plus",
            "interval": "month",
            "redirect_url": "vyla://billing/flutterwave-callback",
        },
    )

    assert response.status_code == 503
    assert response.json() == {"detail": "Payment is temporarily unavailable in this region."}


def test_flutterwave_ensure_payment_plan_reuses_existing_active_plan(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-plan-existing.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    _ = app

    def fake_get(self, path: str, *, params: dict[str, object]) -> dict[str, object]:
        assert path == "/v3/payment-plans"
        assert params["page"] == 1
        return {
            "status": "success",
            "data": [
                {
                    "id": 3807,
                    "name": "Vyla Premium Nigeria NGN month",
                    "currency": "NGN",
                    "interval": "monthly",
                    "amount": 3000,
                    "status": "active",
                }
            ],
        }

    def fail_post(self, path: str, *, json: dict[str, object]) -> dict[str, object]:
        raise AssertionError("should not create a new payment plan when an active one already exists")

    monkeypatch.setattr("phora.services.flutterwave_billing.FlutterwaveBillingService._flutterwave_get", fake_get)
    monkeypatch.setattr("phora.services.flutterwave_billing.FlutterwaveBillingService._flutterwave_post", fail_post)

    with get_session_factory()() as db:
        service = FlutterwaveBillingService(db, Settings(flutterwave_secret_key="FLWSECK_TEST-123"))
        plan_id = service._ensure_payment_plan(country="Nigeria", currency="NGN", interval="month", amount=3000.0)

    assert plan_id == 3807


def test_flutterwave_ensure_payment_plan_creates_new_plan_when_missing(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-plan-create.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    _ = app

    calls = {"pages": [], "created": None}

    def fake_get(self, path: str, *, params: dict[str, object]) -> dict[str, object]:
        assert path == "/v3/payment-plans"
        calls["pages"].append(params["page"])
        if params["page"] == 1:
            return {"status": "success", "data": [{"id": 1, "name": "other", "currency": "NGN", "interval": "monthly", "amount": 2000, "status": "active"}]}
        return {"status": "success", "data": []}

    def fake_post(self, path: str, *, json: dict[str, object]) -> dict[str, object]:
        assert path == "/v3/payment-plans"
        calls["created"] = json
        return {"status": "success", "data": {"id": 4812}}

    monkeypatch.setattr("phora.services.flutterwave_billing.FlutterwaveBillingService._flutterwave_get", fake_get)
    monkeypatch.setattr("phora.services.flutterwave_billing.FlutterwaveBillingService._flutterwave_post", fake_post)

    with get_session_factory()() as db:
        service = FlutterwaveBillingService(db, Settings(flutterwave_secret_key="FLWSECK_TEST-123"))
        plan_id = service._ensure_payment_plan(country="Ghana", currency="GHS", interval="year", amount=270.0)

    assert plan_id == 4812
    assert calls["pages"] == [1, 2]
    assert calls["created"] == {
        "name": "Vyla Premium Ghana GHS year",
        "interval": "yearly",
        "currency": "GHS",
        "amount": 270.0,
    }


def test_flutterwave_ensure_payment_plan_rejects_unsupported_interval(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-plan-interval.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    _ = app

    with get_session_factory()() as db:
        service = FlutterwaveBillingService(db, Settings(flutterwave_secret_key="FLWSECK_TEST-123"))
        try:
            service._ensure_payment_plan(country="Nigeria", currency="NGN", interval="week", amount=3000.0)
        except Exception as exc:
            assert "Unsupported Flutterwave billing interval" in str(exc)
        else:
            raise AssertionError("expected unsupported interval to raise")


def test_stripe_webhook_persists_subscription_and_invoice(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-webhook.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_WEBHOOK_SECRET", "whsec_test_123")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        from phora.models import User

        user = User(
            id="01TESTUSER0000000000000000",
            email="stripe-user@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.commit()

    subscription_event = {
        "id": "evt_sub_updated",
        "type": "customer.subscription.updated",
        "data": {
            "object": {
                "id": "sub_123",
                "customer": "cus_123",
                "status": "active",
                "currency": "gbp",
                "current_period_end": int(datetime(2026, 5, 5, tzinfo=UTC).timestamp()),
                "metadata": {
                    "user_id": "01TESTUSER0000000000000000",
                    "plan_id": "premium_plus",
                    "interval": "month",
                },
                "items": {
                    "data": [
                        {
                            "price": {
                                "id": "price_1TIwFQGRl5Hb5DeygcA8938Y",
                                "currency": "gbp",
                                "unit_amount": 399,
                                "recurring": {"interval": "month"},
                            }
                        }
                    ]
                },
            }
        },
    }
    _post_signed_webhook(client, "whsec_test_123", subscription_event)

    invoice_event = {
        "id": "evt_invoice_paid",
        "type": "invoice.paid",
        "data": {
            "object": {
                "id": "in_123",
                "subscription": "sub_123",
                "customer": "cus_123",
                "payment_intent": "pi_123",
                "total": 399,
                "currency": "gbp",
                "status": "paid",
            }
        },
    }
    response = _post_signed_webhook(client, "whsec_test_123", invoice_event)
    assert response.status_code == 200

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.provider_subscription_id == "sub_123").one()
        assert subscription.user_id == "01TESTUSER0000000000000000"
        assert subscription.provider_customer_id == "cus_123"
        assert subscription.provider_price_id == "price_1TIwFQGRl5Hb5DeygcA8938Y"
        assert subscription.tier == "premium_plus"
        assert subscription.status == "active"
        assert subscription.amount == 3.99
        assert subscription.currency == "GBP"
        assert subscription.billing_interval == "month"

        invoice = db.query(Invoice).filter(Invoice.provider_invoice_id == "in_123").one()
        assert invoice.subscription_id == subscription.id
        assert invoice.provider_customer_id == "cus_123"
        assert invoice.provider_payment_intent_id == "pi_123"
        assert invoice.total == 3.99
        assert invoice.currency == "GBP"
        assert invoice.status == "paid"

    access_token = create_token("01TESTUSER0000000000000000", "access", 30)
    status_response = client.get(
        "/api/v1/billing/subscription",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert status_response.status_code == 200
    assert status_response.json() == {
        "provider": "stripe",
        "tier": "premium_plus",
        "status": "active",
        "selection_made": True,
        "plan_saved": True,
        "is_active": True,
        "redirect_to_home": True,
        "show_subscription_screen": False,
        "provider_configured": False,
        "checkout_endpoint": "/api/v1/billing/stripe/payment-sheet",
        "checkout_public_key": None,
        "currency": "GBP",
        "amount": 3.99,
        "billing_interval": "month",
        "provider_price_id": "price_1TIwFQGRl5Hb5DeygcA8938Y",
        "current_period_end": "2026-05-05T00:00:00",
        "cancel_at_period_end": False,
        "pending_billing_interval": None,
        "pending_provider_price_id": None,
        "pending_amount": None,
        "pending_currency": None,
        "pending_change_effective_at": None,
    }


def test_stripe_invoice_paid_creates_new_subscription_from_modern_invoice_payload(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-webhook-modern-invoice.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_WEBHOOK_SECRET", "whsec_test_123")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(
            id="01TESTUSERMODERNINVOICE",
            email="modern-invoice@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        old_subscription = Subscription(
            user_id=user.id,
            tier="premium_plus",
            status="incomplete",
            provider="stripe",
            provider_subscription_id="sub_old",
            provider_customer_id="cus_old",
            provider_price_id="price_old",
        )
        db.add_all([user, old_subscription])
        db.commit()

    invoice_event = {
        "id": "evt_modern_invoice_paid",
        "type": "invoice.paid",
        "data": {
            "object": {
                "id": "in_modern",
                "customer": "cus_new",
                "payment_intent": "pi_new",
                "total": 1104,
                "currency": "eur",
                "status": "paid",
                "parent": {
                    "subscription_details": {
                        "subscription": "sub_new",
                        "metadata": {
                            "user_id": "01TESTUSERMODERNINVOICE",
                            "plan_id": "premium_plus",
                            "interval": "month",
                        },
                    }
                },
                "subscription_details": {
                    "metadata": {
                        "user_id": "01TESTUSERMODERNINVOICE",
                        "plan_id": "premium_plus",
                        "interval": "month",
                    }
                },
                "lines": {
                    "data": [
                        {
                            "subscription": "sub_new",
                            "period": {
                                "end": int(datetime(2026, 5, 15, tzinfo=UTC).timestamp()),
                            },
                            "price": {
                                "id": "price_1TIxtDGRl5Hb5DeygKFNxDKV",
                                "currency": "eur",
                                "unit_amount": 1104,
                                "recurring": {"interval": "month"},
                            },
                            "metadata": {
                                "user_id": "01TESTUSERMODERNINVOICE",
                                "plan_id": "premium_plus",
                                "interval": "month",
                            },
                        }
                    ]
                },
            }
        },
    }

    response = _post_signed_webhook(client, "whsec_test_123", invoice_event)
    assert response.status_code == 200

    with get_session_factory()() as db:
        old_subscription = db.query(Subscription).filter(Subscription.provider_subscription_id == "sub_old").one()
        assert old_subscription.provider_customer_id == "cus_old"
        assert old_subscription.status == "incomplete"

        new_subscription = db.query(Subscription).filter(Subscription.provider_subscription_id == "sub_new").one()
        assert new_subscription.user_id == "01TESTUSERMODERNINVOICE"
        assert new_subscription.provider_customer_id == "cus_new"
        assert new_subscription.provider_price_id == "price_1TIxtDGRl5Hb5DeygKFNxDKV"
        assert new_subscription.tier == "premium_plus"
        assert new_subscription.status == "active"
        assert new_subscription.amount == 11.04
        assert new_subscription.currency == "EUR"
        assert new_subscription.billing_interval == "month"
        assert new_subscription.current_period_end.replace(tzinfo=UTC) == datetime(2026, 5, 15, tzinfo=UTC)

        invoice = db.query(Invoice).filter(Invoice.provider_invoice_id == "in_modern").one()
        assert invoice.subscription_id == new_subscription.id
        assert invoice.provider_customer_id == "cus_new"
        assert invoice.status == "paid"


def test_stripe_webhook_rejects_invalid_signature(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-webhook-invalid.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_WEBHOOK_SECRET", "whsec_test_123")

    app = create_app()
    client = TestClient(app)

    payload = json.dumps({"id": "evt_bad", "type": "invoice.paid", "data": {"object": {}}}).encode("utf-8")
    timestamp = str(int(datetime.now(UTC).timestamp()))
    response = client.post(
        "/api/v1/billing/stripe/webhook",
        content=payload,
        headers={"Stripe-Signature": f"t={timestamp},v1=bad-signature"},
    )

    assert response.status_code == 400
    assert "signature" in response.json()["detail"].lower()


def test_stripe_webhook_accepts_any_configured_secret(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-webhook-multi-secret.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_WEBHOOK_SECRET", "whsec_old_123, whsec_live_456")

    app = create_app()
    client = TestClient(app)

    payload = {
        "id": "evt_multi_secret",
        "type": "invoice.paid",
        "data": {"object": {"id": "in_multi_secret", "currency": "eur", "status": "paid", "total": 459}},
    }

    response = _post_signed_webhook(client, "whsec_live_456", payload)

    assert response.status_code == 200


def test_stripe_invoice_payment_failed_keeps_subscription_on_paywall(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-webhook-failed.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_WEBHOOK_SECRET", "whsec_test_123")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        from phora.models import User

        user = User(
            id="01TESTUSERFAIL000000000000",
            email="failed-stripe@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="stripe",
                provider_subscription_id="sub_fail_123",
                tier="premium_plus",
                status="incomplete",
                billing_interval="month",
                provider_price_id="price_fail_123",
            )
        )
        db.commit()

    invoice_event = {
        "id": "evt_invoice_failed",
        "type": "invoice.payment_failed",
        "data": {
            "object": {
                "id": "in_fail_123",
                "subscription": "sub_fail_123",
                "customer": "cus_fail_123",
                "payment_intent": "pi_fail_123",
                "total": 459,
                "currency": "eur",
                "status": "open",
            }
        },
    }
    response = _post_signed_webhook(client, "whsec_test_123", invoice_event)
    assert response.status_code == 200

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.provider_subscription_id == "sub_fail_123").one()
        assert subscription.status == "payment_failed"

        invoice = db.query(Invoice).filter(Invoice.provider_invoice_id == "in_fail_123").one()
        assert invoice.subscription_id == subscription.id
        assert invoice.provider_customer_id == "cus_fail_123"
        assert invoice.provider_payment_intent_id == "pi_fail_123"
        assert invoice.total == 4.59
        assert invoice.currency == "EUR"
        assert invoice.status == "open"

    access_token = create_token("01TESTUSERFAIL000000000000", "access", 30)
    status_response = client.get(
        "/api/v1/billing/subscription",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert status_response.status_code == 200
    assert status_response.json()["status"] == "payment_failed"
    assert status_response.json()["is_active"] is False
    assert status_response.json()["redirect_to_home"] is False
    assert status_response.json()["show_subscription_screen"] is True


def test_flutterwave_webhook_persists_subscription_and_invoice(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-webhook.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH", "flw-whsec-123")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        from phora.models import User

        user = User(
            id="01TESTUSERFLW00000000000000",
            email="flutterwave-webhook@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="flutterwave",
                provider_subscription_id="phora-ref-123",
                provider_customer_id="flutterwave-webhook@example.com",
                provider_price_id="991",
                tier="premium_plus",
                status="pending_checkout",
                billing_interval="year",
            )
        )
        db.commit()

    def fake_verify_transaction(self, transaction_id: str | int) -> dict[str, object]:
        assert str(transaction_id) == "98765"
        return {
            "status": "success",
            "data": {
                "id": 98765,
                "tx_ref": "phora-ref-123",
                "flw_ref": "flw_ref_123",
                "amount": 270.0,
                "charged_amount": 270.0,
                "currency": "GHS",
                "status": "successful",
                "payment_plan": 991,
                "customer": {
                    "email": "flutterwave-webhook@example.com",
                },
                "meta": {
                    "user_id": "01TESTUSERFLW00000000000000",
                    "plan_id": "premium_plus",
                    "interval": "year",
                    "country": "Ghana",
                },
            },
        }

    monkeypatch.setattr(
        "phora.services.flutterwave_billing.FlutterwaveBillingService._verify_transaction",
        fake_verify_transaction,
    )

    event = {
        "event": "charge.completed",
        "data": {
            "id": 98765,
            "tx_ref": "phora-ref-123",
        },
    }
    payload = json.dumps(event).encode("utf-8")
    signature = hmac.new(b"flw-whsec-123", payload, hashlib.sha256).hexdigest()

    response = client.post(
        "/api/v1/billing/flutterwave/webhook",
        content=payload,
        headers={"flutterwave-signature": signature},
    )

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.provider_subscription_id == "phora-ref-123").one()
        assert subscription.user_id == "01TESTUSERFLW00000000000000"
        assert subscription.provider == "flutterwave"
        assert subscription.provider_customer_id == "flutterwave-webhook@example.com"
        assert subscription.provider_price_id == "991"
        assert subscription.tier == "premium_plus"
        assert subscription.status == "active"
        assert subscription.amount == 270.0
        assert subscription.currency == "GHS"
        assert subscription.billing_interval == "year"
        assert subscription.current_period_end is not None

        invoice = db.query(Invoice).filter(Invoice.provider_invoice_id == "98765").one()
        assert invoice.subscription_id == subscription.id
        assert invoice.provider_customer_id == "flutterwave-webhook@example.com"
        assert invoice.provider_payment_intent_id == "flw_ref_123"
        assert invoice.total == 270.0
        assert invoice.currency == "GHS"
        assert invoice.status == "active"

    access_token = create_token("01TESTUSERFLW00000000000000", "access", 30)
    status_response = client.get(
        "/api/v1/billing/subscription",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert status_response.status_code == 200
    assert status_response.json()["provider"] == "flutterwave"
    assert status_response.json()["status"] == "active"
    assert status_response.json()["is_active"] is True
    assert status_response.json()["show_subscription_screen"] is False


def test_flutterwave_failed_charge_keeps_subscription_on_paywall(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-failed.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH", "flw-whsec-123")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        from phora.models import User

        user = User(
            id="01TESTUSERFLWFAIL0000000000",
            email="flutterwave-failed@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="flutterwave",
                provider_subscription_id="phora-fail-ref",
                provider_customer_id="flutterwave-failed@example.com",
                provider_price_id="501",
                tier="premium_plus",
                status="pending_checkout",
                billing_interval="month",
            )
        )
        db.commit()

    def fake_verify_transaction(self, transaction_id: str | int) -> dict[str, object]:
        assert str(transaction_id) == "54321"
        return {
            "status": "success",
            "data": {
                "id": 54321,
                "tx_ref": "phora-fail-ref",
                "flw_ref": "flw_ref_failed",
                "amount": 3000.0,
                "charged_amount": 3000.0,
                "currency": "NGN",
                "status": "failed",
                "payment_plan": 501,
                "customer": {
                    "email": "flutterwave-failed@example.com",
                },
                "meta": {
                    "user_id": "01TESTUSERFLWFAIL0000000000",
                    "plan_id": "premium_plus",
                    "interval": "month",
                    "country": "Nigeria",
                },
            },
        }

    monkeypatch.setattr(
        "phora.services.flutterwave_billing.FlutterwaveBillingService._verify_transaction",
        fake_verify_transaction,
    )

    event = {
        "event": "charge.failed",
        "data": {
            "id": 54321,
            "tx_ref": "phora-fail-ref",
        },
    }
    payload = json.dumps(event).encode("utf-8")
    signature = hmac.new(b"flw-whsec-123", payload, hashlib.sha256).hexdigest()

    response = client.post(
        "/api/v1/billing/flutterwave/webhook",
        content=payload,
        headers={"flutterwave-signature": signature},
    )

    assert response.status_code == 200

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.provider_subscription_id == "phora-fail-ref").one()
        assert subscription.status == "failed"
        assert subscription.current_period_end is None

        invoice = db.query(Invoice).filter(Invoice.provider_invoice_id == "54321").one()
        assert invoice.status == "failed"

    access_token = create_token("01TESTUSERFLWFAIL0000000000", "access", 30)
    status_response = client.get(
        "/api/v1/billing/subscription",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert status_response.status_code == 200
    assert status_response.json()["status"] == "failed"
    assert status_response.json()["redirect_to_home"] is False
    assert status_response.json()["show_subscription_screen"] is True


def test_flutterwave_renewal_webhook_matches_existing_subscription_by_customer_and_plan(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-renewal.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH", "flw-whsec-123")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        from phora.models import User

        user = User(
            id="01TESTUSERFLWRENEW000000000",
            email="renewal@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="flutterwave",
                provider_subscription_id="phora-initial-ref",
                provider_customer_id="renewal@example.com",
                provider_price_id="3807",
                tier="premium_plus",
                status="active",
                billing_interval="month",
                currency="NGN",
                amount=3000.0,
            )
        )
        db.commit()

    def fake_verify_transaction(self, transaction_id: str | int) -> dict[str, object]:
        assert str(transaction_id) == "12345"
        return {
            "status": "success",
            "data": {
                "id": 12345,
                "flw_ref": "flw_ref_renewal",
                "amount": 3000.0,
                "charged_amount": 3000.0,
                "currency": "NGN",
                "status": "successful",
                "payment_plan": 3807,
                "customer": {
                    "email": "renewal@example.com",
                },
                "meta": {
                    "plan_id": "premium_plus",
                    "interval": "month",
                    "country": "Nigeria",
                },
            },
        }

    monkeypatch.setattr(
        "phora.services.flutterwave_billing.FlutterwaveBillingService._verify_transaction",
        fake_verify_transaction,
    )

    event = {
        "event": "charge.completed",
        "data": {
            "id": 12345,
            "payment_plan": 3807,
            "customer": {
                "email": "renewal@example.com",
            },
        },
    }
    payload = json.dumps(event).encode("utf-8")
    signature = hmac.new(b"flw-whsec-123", payload, hashlib.sha256).hexdigest()

    response = client.post(
        "/api/v1/billing/flutterwave/webhook",
        content=payload,
        headers={"flutterwave-signature": signature},
    )

    assert response.status_code == 200

    with get_session_factory()() as db:
        subscriptions = db.query(Subscription).filter(Subscription.user_id == "01TESTUSERFLWRENEW000000000").all()
        assert len(subscriptions) == 1
        subscription = subscriptions[0]
        assert subscription.provider_subscription_id == "phora-initial-ref"
        assert subscription.provider_customer_id == "renewal@example.com"
        assert subscription.provider_price_id == "3807"
        assert subscription.status == "active"

        invoice = db.query(Invoice).filter(Invoice.provider_invoice_id == "12345").one()
        assert invoice.subscription_id == subscription.id
        assert invoice.status == "active"


def test_flutterwave_subscription_cancelled_webhook_marks_subscription_canceled(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-cancel.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH", "flw-whsec-123")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        from phora.models import User

        user = User(
            id="01TESTUSERFLWCANCEL00000000",
            email="cancel@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="flutterwave",
                provider_subscription_id="phora-cancel-ref",
                provider_customer_id="cancel@example.com",
                provider_price_id="8801",
                tier="premium_plus",
                status="active",
                billing_interval="month",
                currency="NGN",
                amount=3000.0,
                current_period_end=datetime(2026, 6, 1, tzinfo=UTC),
            )
        )
        db.commit()

    event = {
        "event": "subscription.cancelled",
        "data": {
            "amount": 3000.0,
            "currency": "NGN",
            "customer": {
                "email": "cancel@example.com",
            },
            "plan": {
                "id": 8801,
                "interval": "monthly",
            },
        },
    }
    payload = json.dumps(event).encode("utf-8")
    signature = hmac.new(b"flw-whsec-123", payload, hashlib.sha256).hexdigest()

    response = client.post(
        "/api/v1/billing/flutterwave/webhook",
        content=payload,
        headers={"flutterwave-signature": signature},
    )

    assert response.status_code == 200

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == "01TESTUSERFLWCANCEL00000000").one()
        assert subscription.status == "canceled"
        assert subscription.provider_price_id == "8801"
        assert subscription.billing_interval == "month"
        assert subscription.current_period_end is None

    access_token = create_token("01TESTUSERFLWCANCEL00000000", "access", 30)
    status_response = client.get(
        "/api/v1/billing/subscription",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert status_response.status_code == 200
    assert status_response.json()["status"] == "canceled"
    assert status_response.json()["redirect_to_home"] is False
    assert status_response.json()["show_subscription_screen"] is True


def test_flutterwave_webhook_rejects_invalid_signature(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-webhook-invalid.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH", "flw-whsec-123")

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/v1/billing/flutterwave/webhook",
        content=json.dumps({"event": "charge.completed", "data": {"id": 1}}).encode("utf-8"),
        headers={"flutterwave-signature": "bad-signature"},
    )

    assert response.status_code == 400
    assert "signature" in response.json()["detail"].lower()

    with get_session_factory()() as db:
        row = db.query(FlutterwaveWebhookErrorLog).one()
        assert row.error_message == "Invalid Flutterwave webhook signature."
        assert row.signature_present is True
        assert row.legacy_hash_present is False
        assert row.event_type == "charge.completed"
        assert row.transaction_id == "1"


def test_flutterwave_webhook_accepts_base64_signature(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-webhook-base64.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_WEBHOOK_SECRET_HASH", "flw-whsec-123")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        from phora.models import User

        user = User(
            id="01TESTUSERFLWBASE640000000",
            email="flutterwave-base64@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="flutterwave",
                provider_subscription_id="phora-base64-ref",
                provider_customer_id="flutterwave-base64@example.com",
                provider_price_id="991",
                tier="premium_plus",
                status="pending_checkout",
                billing_interval="month",
            )
        )
        db.commit()

    def fake_verify_transaction(self, transaction_id: str | int) -> dict[str, object]:
        assert str(transaction_id) == "77777"
        return {
            "status": "success",
            "data": {
                "id": 77777,
                "tx_ref": "phora-base64-ref",
                "flw_ref": "flw_ref_base64",
                "amount": 20.0,
                "charged_amount": 20.0,
                "currency": "XOF",
                "status": "successful",
                "payment_plan": 991,
                "customer": {
                    "email": "flutterwave-base64@example.com",
                },
                "meta": {
                    "user_id": "01TESTUSERFLWBASE640000000",
                    "plan_id": "premium_plus",
                    "interval": "month",
                    "country": "Ivory Coast",
                },
            },
        }

    monkeypatch.setattr(
        "phora.services.flutterwave_billing.FlutterwaveBillingService._verify_transaction",
        fake_verify_transaction,
    )

    event = {
        "event": "charge.completed",
        "data": {
            "id": 77777,
            "tx_ref": "phora-base64-ref",
        },
    }
    payload = json.dumps(event).encode("utf-8")
    signature = base64.b64encode(
        hmac.new(b"flw-whsec-123", payload, hashlib.sha256).digest()
    ).decode("utf-8")

    response = client.post(
        "/api/v1/billing/flutterwave/webhook",
        content=payload,
        headers={"flutterwave-signature": signature},
    )

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_admin_can_list_flutterwave_webhook_errors(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-webhook-errors-admin.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        db.add(
            User(
                id="01TESTADMINFLWERRORS0000000",
                email="admin@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
                is_admin=True,
            )
        )
        db.add(
            FlutterwaveWebhookErrorLog(
                event_type="charge.completed",
                transaction_id="12345",
                tx_ref="tx-ref-123",
                provider_customer_id="customer@example.com",
                provider_plan_id="8801",
                user_id="01TESTUSERFLW00000000000000",
                error_message="Invalid Flutterwave webhook signature.",
                signature_present=True,
                legacy_hash_present=False,
                payload_summary={"event": "charge.completed"},
            )
        )
        db.commit()

    response = client.get(
        "/api/v1/admin/billing/flutterwave/webhook-errors",
        headers={"Authorization": f"Bearer {create_token('01TESTADMINFLWERRORS0000000', 'access', 30)}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["limit"] == 50
    assert len(body["items"]) == 1
    assert body["items"][0]["transaction_id"] == "12345"
    assert body["items"][0]["error_message"] == "Invalid Flutterwave webhook signature."


def test_non_admin_cannot_list_flutterwave_webhook_errors(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-webhook-errors-non-admin.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        db.add(
            User(
                id="01TESTNONADMINFLWERRORS00000",
                email="user@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
                is_admin=False,
            )
        )
        db.commit()

    response = client.get(
        "/api/v1/admin/billing/flutterwave/webhook-errors",
        headers={"Authorization": f"Bearer {create_token('01TESTNONADMINFLWERRORS00000', 'access', 30)}"},
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Admin access required"


def test_subscription_selection_can_save_free_choice(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-selection-free.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "free@example.com",
            "password": "password123",
            "first_name": "Free",
            "last_name": "User",
            "country": "United Kingdom",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "free@example.com", "code": sent_codes["free@example.com"]},
    )
    assert verify.status_code == 200
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    response = client.post(
        "/api/v1/billing/subscription-selection",
        headers=headers,
        json={"tier": "free"},
    )
    assert response.status_code == 200
    assert response.json() == {
        "provider": None,
        "tier": "free",
        "status": "active",
        "selection_made": True,
        "plan_saved": True,
        "is_active": True,
        "redirect_to_home": True,
        "show_subscription_screen": False,
        "provider_configured": True,
        "checkout_endpoint": None,
        "checkout_public_key": None,
        "currency": None,
        "amount": 0.0,
        "billing_interval": None,
        "provider_price_id": None,
        "current_period_end": None,
        "cancel_at_period_end": False,
        "pending_billing_interval": None,
        "pending_provider_price_id": None,
        "pending_amount": None,
        "pending_currency": None,
        "pending_change_effective_at": None,
    }


def test_subscription_selection_does_not_overwrite_existing_active_paid_subscription_with_free(
    tmp_path, monkeypatch
):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-selection-free-guard.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_PUBLIC_KEY", "FLWPUBK_TEST-123")

    app = create_app()
    client = TestClient(app)

    user_id = "01TESTUSERFREEGUARD000000000"

    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="free-guard@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.add(
            Subscription(
                user_id=user_id,
                tier="premium_plus",
                status="active",
                provider="flutterwave",
                currency="XOF",
                amount=12.0,
                billing_interval="month",
                provider_price_id="plan_month_xof",
                provider_customer_id="customer_123",
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/billing/subscription-selection",
        headers={"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"},
        json={"tier": "free"},
    )

    assert response.status_code == 200
    assert response.json()["tier"] == "premium_plus"
    assert response.json()["status"] == "active"
    assert response.json()["provider"] == "flutterwave"
    assert response.json()["show_subscription_screen"] is False
    assert response.json()["redirect_to_home"] is True

    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == user_id).one()
        assert subscription.tier == "premium_plus"
        assert subscription.status == "active"
        assert subscription.provider == "flutterwave"
        assert subscription.provider_customer_id == "customer_123"


def test_subscription_selection_requires_country_and_interval_for_premium_plus(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-selection-premium.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_PUBLIC_KEY", "FLWPUBK_TEST-123")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "premium@example.com",
            "password": "password123",
            "first_name": "Premium",
            "last_name": "User",
            "country": "Nigeria",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "premium@example.com", "code": sent_codes["premium@example.com"]},
    )
    assert verify.status_code == 200
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    bad = client.post(
        "/api/v1/billing/subscription-selection",
        headers=headers,
        json={"tier": "premium_plus"},
    )
    assert bad.status_code == 400

    response = client.post(
        "/api/v1/billing/subscription-selection",
        headers=headers,
        json={"tier": "premium_plus", "interval": "year", "country": "Nigeria"},
    )
    assert response.status_code == 200
    assert response.json()["provider"] == "flutterwave"
    assert response.json()["provider_configured"] is True
    assert response.json()["checkout_endpoint"] == "/api/v1/billing/flutterwave/checkout-sessions"
    assert response.json()["checkout_public_key"] == "FLWPUBK_TEST-123"
    assert response.json()["tier"] == "premium_plus"
    assert response.json()["status"] == "selected"
    assert response.json()["selection_made"] is True
    assert response.json()["redirect_to_home"] is False
    assert response.json()["show_subscription_screen"] is True
    assert response.json()["billing_interval"] == "year"
    assert response.json()["amount"] == 27000.0


def test_subscription_selection_exposes_stripe_checkout_metadata(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-selection-stripe.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "stripe-premium@example.com",
            "password": "password123",
            "first_name": "Stripe",
            "last_name": "Premium",
            "country": "Germany",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "stripe-premium@example.com", "code": sent_codes["stripe-premium@example.com"]},
    )
    assert verify.status_code == 200

    response = client.post(
        "/api/v1/billing/subscription-selection",
        headers={"Authorization": f"Bearer {verify.json()['access_token']}"},
        json={"tier": "premium_plus", "interval": "month", "country": "Germany"},
    )
    assert response.status_code == 200
    assert response.json()["provider"] == "stripe"
    assert response.json()["provider_configured"] is True
    assert response.json()["checkout_endpoint"] == "/api/v1/billing/stripe/payment-sheet"
    assert response.json()["checkout_public_key"] == "pk_test_123"
    assert response.json()["redirect_to_home"] is False
    assert response.json()["show_subscription_screen"] is True


def test_subscription_selection_accepts_live_stripe_price_for_germany(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-selection-germany-live.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setenv("PHORA_ENVIRONMENT", "stage")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_live_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_live_123")
    monkeypatch.setenv("PHORA_STRIPE_PRICE_DE_MONTH", "price_live_de_month_placeholder")
    monkeypatch.setenv("PHORA_STRIPE_PRICE_DE_YEAR", "price_live_de_year_placeholder")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "stripe-germany@example.com",
            "password": "password123",
            "first_name": "Stripe",
            "last_name": "Germany",
            "country": "Germany",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "stripe-germany@example.com", "code": sent_codes["stripe-germany@example.com"]},
    )
    assert verify.status_code == 200

    response = client.post(
        "/api/v1/billing/subscription-selection",
        headers={"Authorization": f"Bearer {verify.json()['access_token']}"},
        json={"tier": "premium_plus", "interval": "month", "country": "Germany"},
    )
    assert response.status_code == 200
    assert response.json()["provider"] == "stripe"
    assert response.json()["provider_configured"] is True
    assert response.json()["checkout_endpoint"] == "/api/v1/billing/stripe/payment-sheet"


def test_cancel_subscription_rejects_missing_paid_subscription(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-cancel-none.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    from phora.db.session import get_session_factory
    from phora.models import User

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        db.add(
            User(
                id="01TESTUSERCANCELNONE0000000",
                email="cancel-none@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/billing/subscription/cancel",
        headers={"Authorization": f"Bearer {create_token('01TESTUSERCANCELNONE0000000', 'access', 30)}"},
        json={"immediate": True},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "No paid subscription to cancel."


def test_cancel_stripe_subscription_calls_provider_and_updates_state(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-cancel-stripe.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    from phora.db.session import get_session_factory
    from phora.models import User

    updated_calls: list[tuple[str, dict[str, str]]] = []

    def fake_stripe_post(self, path: str, *, data: dict[str, str]) -> dict[str, object]:
        updated_calls.append((path, data))
        return {
            "id": "sub_123",
            "status": "active",
            "cancel_at_period_end": True,
            "current_period_end": int(datetime(2026, 6, 1, tzinfo=UTC).timestamp()),
        }

    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_post", fake_stripe_post)

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(
            id="01TESTUSERCANCELSTRIPE0000",
            email="cancel-stripe@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="stripe",
                provider_subscription_id="sub_123",
                provider_customer_id="cus_123",
                provider_price_id="price_123",
                tier="premium_plus",
                status="active",
                billing_interval="month",
                currency="EUR",
                amount=4.59,
                current_period_end=datetime(2026, 6, 1, tzinfo=UTC),
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/billing/subscription/cancel",
        headers={"Authorization": f"Bearer {create_token('01TESTUSERCANCELSTRIPE0000', 'access', 30)}"},
        json={"immediate": False},
    )

    assert response.status_code == 200
    assert updated_calls == [
        ("/v1/subscriptions/sub_123", {"cancel_at_period_end": "true"})
    ]
    assert response.json()["status"] == "active"
    assert response.json()["is_active"] is True
    assert response.json()["redirect_to_home"] is True
    assert response.json()["show_subscription_screen"] is False
    assert response.json()["cancel_at_period_end"] is True
    assert response.json()["current_period_end"] in {
        "2026-06-01T00:00:00+00:00",
        "2026-06-01T00:00:00",
    }


def test_change_stripe_subscription_interval_schedules_monthly_without_immediate_invoice(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-switch-monthly.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    from phora.db.session import get_session_factory
    from phora.models import User

    calls: list[tuple[str, dict[str, object] | None]] = []

    def fake_stripe_get(self, path: str, *, params: dict[str, object] | None = None) -> dict[str, object]:
        calls.append((path, params))
        if path == "/v1/subscriptions/sub_switch":
            return {
                "id": "sub_switch",
                "current_period_start": int(datetime(2025, 6, 1, tzinfo=UTC).timestamp()),
                "current_period_end": int(datetime(2026, 6, 1, tzinfo=UTC).timestamp()),
                "items": {
                    "data": [
                        {
                            "id": "si_switch",
                            "quantity": 1,
                            "price": {"id": "price_year"},
                        }
                    ]
                },
            }
        raise AssertionError(f"unexpected Stripe GET {path}")

    def fake_stripe_post(self, path: str, *, data: dict[str, str]) -> dict[str, object]:
        calls.append((path, data))
        if path == "/v1/subscription_schedules":
            assert data == {"from_subscription": "sub_switch"}
            return {
                "id": "sched_switch",
                "current_phase": {
                    "start_date": int(datetime(2025, 6, 1, tzinfo=UTC).timestamp()),
                    "end_date": int(datetime(2026, 6, 1, tzinfo=UTC).timestamp()),
                },
            }
        if path == "/v1/subscription_schedules/sched_switch":
            assert data["proration_behavior"] == "none"
            assert data["end_behavior"] == "release"
            assert data["phases[0][items][0][price]"] == "price_year"
            assert data["phases[0][end_date]"] == str(int(datetime(2026, 6, 1, tzinfo=UTC).timestamp()))
            assert data["phases[1][items][0][price]"] == "price_1TTR20GRl5Hb5Deyw0zaAes6"
            assert data["phases[1][metadata][interval]"] == "month"
            return {"id": "sched_switch"}
        raise AssertionError(f"unexpected Stripe POST {path}")

    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_get", fake_stripe_get)
    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_post", fake_stripe_post)

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(
            id="01TESTUSERSWITCHMONTHLY",
            email="switch-monthly@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="stripe",
                provider_subscription_id="sub_switch",
                provider_customer_id="cus_switch",
                provider_price_id="price_year",
                tier="premium_plus",
                status="active",
                billing_interval="year",
                currency="GBP",
                amount=35.0,
                current_period_end=datetime(2026, 6, 1, tzinfo=UTC),
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/billing/subscription/change-interval",
        headers={"Authorization": f"Bearer {create_token('01TESTUSERSWITCHMONTHLY', 'access', 30)}"},
        json={"country": "United Kingdom", "interval": "month"},
    )

    assert response.status_code == 200
    assert response.json()["interval"] == "month"
    assert [call[0] for call in calls] == [
        "/v1/subscriptions/sub_switch",
        "/v1/subscription_schedules",
        "/v1/subscription_schedules/sched_switch",
    ]
    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == "01TESTUSERSWITCHMONTHLY").one()
        assert subscription.billing_interval == "year"
        assert subscription.provider_price_id == "price_year"
        assert subscription.amount == 35.0
        assert subscription.pending_billing_interval == "month"
        assert subscription.pending_provider_price_id == "price_1TTR20GRl5Hb5Deyw0zaAes6"
        assert subscription.pending_amount == 3.99
        assert subscription.pending_change_effective_at.replace(tzinfo=UTC) == datetime(2026, 6, 1, tzinfo=UTC)
        assert subscription.cancel_at_period_end is False

    history = client.get(
        "/api/v1/billing/invoices",
        headers={"Authorization": f"Bearer {create_token('01TESTUSERSWITCHMONTHLY', 'access', 30)}"},
    )
    assert history.status_code == 200
    assert history.json()["items"][0]["item_type"] == "event"
    assert history.json()["items"][0]["title"] == "Plan change scheduled"
    assert history.json()["items"][0]["amount_label"] == "No charge"


def test_cancel_scheduled_stripe_subscription_interval_change_releases_schedule(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-cancel-scheduled-change.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    from phora.db.session import get_session_factory
    from phora.models import User

    calls: list[tuple[str, dict[str, object] | None]] = []

    def fake_stripe_get(self, path: str, *, params: dict[str, object] | None = None) -> dict[str, object]:
        calls.append((path, params))
        assert path == "/v1/subscriptions/sub_cancel_schedule"
        return {
            "id": "sub_cancel_schedule",
            "status": "active",
            "cancel_at_period_end": False,
            "current_period_end": int(datetime(2026, 6, 1, tzinfo=UTC).timestamp()),
            "schedule": {"id": "sched_cancel"},
        }

    def fake_stripe_post(self, path: str, *, data: dict[str, str]) -> dict[str, object]:
        calls.append((path, data))
        assert path == "/v1/subscription_schedules/sched_cancel/release"
        assert data == {}
        return {"id": "sched_cancel", "released_subscription": "sub_cancel_schedule"}

    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_get", fake_stripe_get)
    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_post", fake_stripe_post)

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(
            id="01TESTUSERCANCELSCHEDULE",
            email="cancel-schedule@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="stripe",
                provider_subscription_id="sub_cancel_schedule",
                provider_customer_id="cus_cancel_schedule",
                provider_price_id="price_year",
                tier="premium_plus",
                status="active",
                billing_interval="year",
                currency="GBP",
                amount=35.0,
                current_period_end=datetime(2026, 6, 1, tzinfo=UTC),
                pending_billing_interval="month",
                pending_provider_price_id="price_month",
                pending_currency="GBP",
                pending_amount=3.99,
                pending_change_effective_at=datetime(2026, 6, 1, tzinfo=UTC),
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/billing/subscription/change-interval/cancel",
        headers={"Authorization": f"Bearer {create_token('01TESTUSERCANCELSCHEDULE', 'access', 30)}"},
    )

    assert response.status_code == 200
    assert [call[0] for call in calls] == [
        "/v1/subscriptions/sub_cancel_schedule",
        "/v1/subscription_schedules/sched_cancel/release",
    ]
    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == "01TESTUSERCANCELSCHEDULE").one()
        assert subscription.pending_billing_interval is None
        assert subscription.pending_provider_price_id is None
        assert subscription.pending_amount is None
        assert subscription.pending_currency is None
        assert subscription.pending_change_effective_at is None
        assert subscription.billing_interval == "year"
        assert subscription.provider_price_id == "price_year"

    history = client.get(
        "/api/v1/billing/invoices",
        headers={"Authorization": f"Bearer {create_token('01TESTUSERCANCELSCHEDULE', 'access', 30)}"},
    )
    assert history.status_code == 200
    assert history.json()["items"][0]["item_type"] == "event"
    assert history.json()["items"][0]["title"] == "Scheduled plan change canceled"
    assert history.json()["items"][0]["amount_label"] == "No charge"


def test_billing_history_payment_links_to_wearable_order_detail(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-history-wearable.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)
    user_id = "01TESTUSERHISTORYWEARABLE"

    with get_session_factory()() as db:
        user = User(
            id=user_id,
            email="history-wearable@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        subscription = Subscription(
            user_id=user.id,
            provider="stripe",
            provider_subscription_id="sub_history_wearable",
            tier="premium_plus",
            status="active",
            billing_interval="year",
            currency="EUR",
            amount=65.91,
        )
        db.add(subscription)
        db.flush()
        invoice = Invoice(
            subscription_id=subscription.id,
            provider_invoice_id="in_history_wearable",
            provider_payment_intent_id="pi_history_wearable",
            total=65.91,
            currency="EUR",
            status="paid",
        )
        db.add(invoice)
        order = WearableOrder(
            user_id=user.id,
            subscription_id=subscription.id,
            order_number="#VYLA-HISTORY",
            wearable_sku="VYLA-WEARABLE-V1",
            wearable_name="Vyla Wearable",
            wearable_price=29.11,
            wearable_currency="EUR",
            payment_status="paid",
            fulfillment_status="pending",
            shipping_address_json={},
            timeline_json=[],
            provider_payment_intent_id="pi_history_wearable",
        )
        db.add(order)
        db.commit()
        order_id = order.id

    response = client.get(
        "/api/v1/billing/invoices",
        headers={"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"},
    )

    assert response.status_code == 200
    item = response.json()["items"][0]
    assert item["title"] == "Payment received"
    assert item["subtitle"] == "View order details"
    assert item["amount_label"] == "€65.91"
    assert item["action_url"] == f"/wearable/orders/{order_id}"


def test_restart_stripe_subscription_turns_renewal_back_on(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-restart-stripe.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_STRIPE_SECRET_KEY", "sk_test_123")
    monkeypatch.setenv("PHORA_STRIPE_PUBLISHABLE_KEY", "pk_test_123")

    from phora.db.session import get_session_factory
    from phora.models import User

    calls: list[tuple[str, dict[str, str]]] = []

    def fake_stripe_post(self, path: str, *, data: dict[str, str]) -> dict[str, object]:
        calls.append((path, data))
        return {
            "id": "sub_restart",
            "status": "active",
            "cancel_at_period_end": False,
            "current_period_end": int(datetime(2026, 6, 1, tzinfo=UTC).timestamp()),
        }

    monkeypatch.setattr("phora.services.stripe_billing.StripeBillingService._stripe_post", fake_stripe_post)

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(
            id="01TESTUSERRESTARTSTRIPE",
            email="restart-stripe@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="stripe",
                provider_subscription_id="sub_restart",
                provider_customer_id="cus_restart",
                provider_price_id="price_123",
                tier="premium_plus",
                status="active",
                billing_interval="month",
                currency="GBP",
                amount=3.99,
                current_period_end=datetime(2026, 6, 1, tzinfo=UTC),
                cancel_at_period_end=True,
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/billing/subscription/restart",
        headers={"Authorization": f"Bearer {create_token('01TESTUSERRESTARTSTRIPE', 'access', 30)}"},
    )

    assert response.status_code == 200
    assert calls == [("/v1/subscriptions/sub_restart", {"cancel_at_period_end": "false"})]
    assert response.json()["cancel_at_period_end"] is False
    with get_session_factory()() as db:
        subscription = db.query(Subscription).filter(Subscription.user_id == "01TESTUSERRESTARTSTRIPE").one()
        assert subscription.cancel_at_period_end is False


def test_cancel_flutterwave_subscription_calls_provider_and_updates_state(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-cancel-flutterwave.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_PUBLIC_KEY", "FLWPUBK_TEST-123")

    from phora.db.session import get_session_factory
    from phora.models import User

    get_calls: list[tuple[str, dict[str, object] | None]] = []
    put_calls: list[str] = []

    def fake_flutterwave_get(self, path: str, *, params: dict[str, object] | None = None) -> dict[str, object]:
        get_calls.append((path, params))
        return {"status": "success", "data": [{"id": 991}]}

    def fake_flutterwave_put(self, path: str, *, json: dict[str, object] | None = None) -> dict[str, object]:
        put_calls.append(path)
        return {"status": "success", "message": "Subscription cancelled"}

    monkeypatch.setattr("phora.services.flutterwave_billing.FlutterwaveBillingService._flutterwave_get", fake_flutterwave_get)
    monkeypatch.setattr("phora.services.flutterwave_billing.FlutterwaveBillingService._flutterwave_put", fake_flutterwave_put)

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(
            id="01TESTUSERCANCELFLW0000000",
            email="cancel-flw@example.com",
            password_hash="!phora-unusable-password$test",
            email_verified=True,
        )
        db.add(user)
        db.add(
            Subscription(
                user_id=user.id,
                provider="flutterwave",
                provider_subscription_id="phora-ref-123",
                provider_customer_id="cancel-flw@example.com",
                provider_price_id="8801",
                tier="premium_plus",
                status="active",
                billing_interval="month",
                currency="NGN",
                amount=3000.0,
                current_period_end=datetime(2026, 6, 1, tzinfo=UTC),
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/billing/subscription/cancel",
        headers={"Authorization": f"Bearer {create_token('01TESTUSERCANCELFLW0000000', 'access', 30)}"},
        json={"immediate": False},
    )

    assert response.status_code == 200
    assert get_calls == [
        (
            "/v3/subscriptions",
            {"email": "cancel-flw@example.com", "plan": "8801", "status": "active", "page": 1},
        )
    ]
    assert put_calls == ["/v3/subscriptions/991/cancel"]
    assert response.json()["status"] == "canceled"
    assert response.json()["is_active"] is True
    assert response.json()["show_subscription_screen"] is False
    assert response.json()["current_period_end"] in {
        "2026-06-01T00:00:00+00:00",
        "2026-06-01T00:00:00",
    }


def _post_signed_webhook(client: TestClient, secret: str, event: dict) -> object:
    payload = json.dumps(event).encode("utf-8")
    timestamp = str(int(datetime.now(UTC).timestamp()))
    signed_payload = f"{timestamp}.{payload.decode('utf-8')}".encode("utf-8")
    signature = hmac.new(secret.encode("utf-8"), signed_payload, hashlib.sha256).hexdigest()
    return client.post(
        "/api/v1/billing/stripe/webhook",
        content=payload,
        headers={"Stripe-Signature": f"t={timestamp},v1={signature}"},
    )
