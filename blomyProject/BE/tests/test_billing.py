import hashlib
import hmac
import json
from datetime import UTC, datetime

from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.core.config import Settings
from phora.core.security import create_token
from phora.db.session import get_session_factory
from phora.models import Invoice, Subscription
from phora.services.email import EmailService
from phora.services.flutterwave_billing import FlutterwaveBillingService


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
    assert body["checkout_endpoint"] == "/api/v1/billing/stripe/checkout-sessions"
    assert body["checkout_public_key"] == "pk_test_123"
    assert body["currency"] == "GBP"
    assert len(body["plans"]) == 2
    assert body["plans"][1]["id"] == "premium_plus"
    assert body["plans"][1]["display_price"] == "£3.99"
    assert body["plans"][1]["billing_period"] == "month"
    assert body["plans"][1]["provider_product_id"] == "prod_UHWvRGMUhkpAy5"
    assert body["plans"][1]["provider_price_id"] == "price_1TIxtDGRl5Hb5Dey7Bpnk3V6"
    assert body["plans"][1]["price_options"] == [
        {
            "interval": "month",
            "provider_price_id": "price_1TIxtDGRl5Hb5Dey7Bpnk3V6",
            "price_minor": 399,
            "display_price": "£3.99",
        },
        {
            "interval": "year",
            "provider_price_id": "price_1TIxtWGRl5Hb5DeyAghzRf6X",
            "price_minor": 3200,
            "display_price": "£32",
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

    app = create_app()
    client = TestClient(app)

    response = client.get("/api/v1/billing/plan-offers", params={"country": "United Kingdom"})

    assert response.status_code == 200
    body = response.json()
    assert body["primary_provider"] == "stripe"
    assert body["plans"][1]["provider_product_id"] == "prod_UHVB0yzeM3MbZU"
    assert body["plans"][1]["provider_price_id"] == "price_1TIwFQGRl5Hb5DeygcA8938Y"


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
    assert body["plans"][1]["provider_product_id"] == "prod_UHVB0yzeM3MbZU"
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

    def capture(self, recipient: str, code: str) -> None:
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
        assert data["line_items[0][price]"] == "price_1TIxtDGRl5Hb5Dey7Bpnk3V6"
        assert data["metadata[plan_id]"] == "premium_plus"
        assert data["subscription_data[metadata][interval]"] == "month"
        assert (
            data["success_url"]
            == "http://testserver/api/v1/billing/stripe/return/success"
            "?target=phora%3A%2F%2Fbilling%2Fsuccess%3Fsession_id%3D%7BCHECKOUT_SESSION_ID%7D"
            "&session_id=%7BCHECKOUT_SESSION_ID%7D"
        )
        assert (
            data["cancel_url"]
            == "http://testserver/api/v1/billing/stripe/return/cancel?target=phora%3A%2F%2Fbilling%2Fcancel"
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
            "success_url": "phora://billing/success?session_id={CHECKOUT_SESSION_ID}",
            "cancel_url": "phora://billing/cancel",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["provider"] == "stripe"
    assert body["checkout_session_id"] == "cs_test_123"
    assert body["checkout_url"] == "https://checkout.stripe.com/c/pay/cs_test_123"
    assert body["publishable_key"] == "pk_test_123"
    assert body["provider_product_id"] == "prod_UHWvRGMUhkpAy5"
    assert body["provider_price_id"] == "price_1TIxtDGRl5Hb5Dey7Bpnk3V6"


def test_stripe_checkout_return_success_redirects_back_to_app(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-return-success.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get(
        "/api/v1/billing/stripe/return/success",
        params={
            "target": "phora://billing/success?foo=bar",
            "session_id": "cs_test_123",
        },
        follow_redirects=False,
    )

    assert response.status_code == 307
    assert response.headers["location"] == "phora://billing/success?foo=bar&session_id=cs_test_123"


def test_stripe_checkout_return_success_replaces_placeholder_session_id(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-return-placeholder.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get(
        "/api/v1/billing/stripe/return/success",
        params={
            "target": "phora://billing/success?session_id={CHECKOUT_SESSION_ID}",
            "session_id": "cs_test_123",
        },
        follow_redirects=False,
    )

    assert response.status_code == 307
    assert response.headers["location"] == "phora://billing/success?session_id=cs_test_123"


def test_stripe_checkout_return_cancel_redirects_back_to_app(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-return-cancel.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.get(
        "/api/v1/billing/stripe/return/cancel",
        params={"target": "phora://billing/cancel"},
        follow_redirects=False,
    )

    assert response.status_code == 307
    assert response.headers["location"] == "phora://billing/cancel"


def test_create_flutterwave_checkout_session_returns_checkout_url(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-checkout.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_PUBLIC_KEY", "FLWPUBK_TEST-123")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
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
            "redirect_url": "phora://billing/flutterwave-callback",
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


def test_create_flutterwave_checkout_session_requires_flutterwave_country(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-flutterwave-country.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
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
            "redirect_url": "phora://billing/flutterwave-callback",
        },
    )

    assert response.status_code == 400
    assert "not available" in response.json()["detail"].lower()


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
                    "name": "Phora Premium+ Nigeria NGN month",
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
        "name": "Phora Premium+ Ghana GHS year",
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
        "checkout_endpoint": "/api/v1/billing/stripe/checkout-sessions",
        "checkout_public_key": None,
        "currency": "GBP",
        "amount": 3.99,
        "billing_interval": "month",
        "provider_price_id": "price_1TIwFQGRl5Hb5DeygcA8938Y",
        "current_period_end": "2026-05-05T00:00:00",
    }


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
                current_period_end=datetime(2026, 5, 1, tzinfo=UTC),
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


def test_subscription_selection_can_save_free_choice(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-selection-free.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
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
    }


def test_subscription_selection_requires_country_and_interval_for_premium_plus(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'billing-selection-premium.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_SECRET_KEY", "FLWSECK_TEST-123")
    monkeypatch.setenv("PHORA_FLUTTERWAVE_PUBLIC_KEY", "FLWPUBK_TEST-123")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
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

    def capture(self, recipient: str, code: str) -> None:
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
    assert response.json()["checkout_endpoint"] == "/api/v1/billing/stripe/checkout-sessions"
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

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
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
    assert response.json()["checkout_endpoint"] == "/api/v1/billing/stripe/checkout-sessions"


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
