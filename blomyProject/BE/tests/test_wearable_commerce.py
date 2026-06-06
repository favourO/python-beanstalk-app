from datetime import UTC, datetime

from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.core.config import Settings
from phora.core.security import create_token
from phora.db.session import get_session_factory, reset_db_state
from phora.models import NotificationHistory, User, UserProfile
from phora.models.wearable_commerce import WearableInventory, WearableOrder
from phora.services.stripe_billing import StripeBillingService
from phora.services.wearable_commerce import WearableCommerceService


def _boot_app(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'wearable-commerce.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "wearable-commerce-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    reset_db_state()
    return create_app()


def _seed_user(db, *, email: str = "wearable@example.com", is_admin: bool = False) -> str:
    user = User(email=email, password_hash="hash", is_admin=is_admin)
    db.add(user)
    db.flush()
    db.add(UserProfile(user_id=user.id, timezone="UTC"))
    db.commit()
    return user.id


def _seed_inventory(db, *, allowed_country_codes: list[str] | None = None) -> None:
    db.add(
        WearableInventory(
            product_name="Vyla Wearable",
            sku="VYLA-WEARABLE-V1",
            total_stock=50,
            available_stock=50,
            reserved_stock=0,
            low_stock_threshold=5,
            price_minor=2500,
            currency="GBP",
            currency_symbol="£",
            is_active=True,
            allowed_country_codes=allowed_country_codes if allowed_country_codes is not None else ["GB"],
        )
    )
    db.commit()


def test_paid_wearable_order_notifies_user_and_admin(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        user_id = _seed_user(db)
        admin_id = _seed_user(db, email="admin@example.com", is_admin=True)
        _seed_inventory(db)

        order = WearableCommerceService(db).create_order(
            user_id=user_id,
            subscription_id=None,
            sku="VYLA-WEARABLE-V1",
            shipping_address={"full_name": "Emma Johnson", "line1": "12 Willow Lane"},
            payment_intent_id="pi_test",
        )

        user_notification = (
            db.query(NotificationHistory)
            .filter(NotificationHistory.user_id == user_id, NotificationHistory.notification_type == "wearable_order_confirmed")
            .one()
        )
        admin_notification = (
            db.query(NotificationHistory)
            .filter(NotificationHistory.user_id == admin_id, NotificationHistory.notification_type == "admin_wearable_order_paid")
            .one()
        )

    assert user_notification.status == "sent"
    assert user_notification.action_url == f"/wearable/orders/{order.id}/tracking"
    assert user_notification.payload["order_id"] == order.id
    assert admin_notification.status == "sent"
    assert admin_notification.category == "wearable_orders"
    assert admin_notification.payload["order_number"] == order.order_number


def test_dispatch_with_tracking_notifies_user_with_tracking_route(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        user_id = _seed_user(db)
        _seed_inventory(db)
        order = WearableCommerceService(db).create_order(
            user_id=user_id,
            subscription_id=None,
            sku="VYLA-WEARABLE-V1",
            shipping_address={"full_name": "Emma Johnson", "line1": "12 Willow Lane"},
            payment_intent_id="pi_test",
        )

        updated = WearableCommerceService(db).update_fulfillment(
            order,
            fulfillment_status="dispatched",
            tracking_number="RM123456789GB",
            tracking_url="https://www.royalmail.com/track-your-item#/tracking-results/RM123456789GB",
            courier="Royal Mail",
            estimated_delivery_date=datetime(2026, 5, 22, tzinfo=UTC),
        )

        notification = (
            db.query(NotificationHistory)
            .filter(NotificationHistory.user_id == user_id, NotificationHistory.notification_type == "wearable_dispatched")
            .one()
        )

    assert updated.tracking_url is not None
    assert notification.status == "sent"
    assert notification.action_url == f"/wearable/orders/{order.id}/tracking"
    assert notification.payload["tracking_number"] == "RM123456789GB"
    assert notification.payload["courier"] == "Royal Mail"


def test_status_update_persists_progressive_timeline_and_notifies_user(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        user_id = _seed_user(db)
        _seed_inventory(db)
        order = WearableCommerceService(db).create_order(
            user_id=user_id,
            subscription_id=None,
            sku="VYLA-WEARABLE-V1",
            shipping_address={"full_name": "Emma Johnson", "line1": "12 Willow Lane"},
            payment_intent_id="pi_progress",
        )

        updated = WearableCommerceService(db).update_fulfillment(
            order,
            fulfillment_status="dispatched",
            tracking_number="RM123456789GB",
            tracking_url="https://www.royalmail.com/track-your-item#/tracking-results/RM123456789GB",
            courier="Royal Mail",
        )

        completed = {
            entry["status"]
            for entry in updated.timeline_json
            if entry.get("completed_at")
        }
        notification = (
            db.query(NotificationHistory)
            .filter(
                NotificationHistory.user_id == user_id,
                NotificationHistory.notification_type == "wearable_dispatched",
            )
            .one()
        )

    assert updated.fulfillment_status == "dispatched"
    assert {"ORDER_CONFIRMED", "PROCESSING", "DISPATCHED"}.issubset(completed)
    assert notification.payload["fulfillment_status"] == "dispatched"


def test_confirmed_stripe_payment_creates_order_for_admin_dashboard(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    def fake_stripe_get(self, path, *, params=None):
        assert path == "/v1/payment_intents/pi_confirmed"
        return {
            "id": "pi_confirmed",
            "status": "succeeded",
            "metadata": {"user_id": user_id},
        }

    monkeypatch.setattr(StripeBillingService, "_stripe_get", fake_stripe_get)

    with get_session_factory()() as db:
        user_id = _seed_user(db)
        admin_id = _seed_user(db, email="admin-confirm@example.com", is_admin=True)
        _seed_inventory(db)

        StripeBillingService(
            db,
            Settings(stripe_secret_key="sk_test_123"),
        ).confirm_wearable_payment(
            user_id=user_id,
            payment_intent_id="pi_confirmed",
            wearable_sku="VYLA-WEARABLE-V1",
            shipping_address_json={
                "full_name": "Emma Johnson",
                "line1": "12 Willow Lane",
            },
        )

        order = (
            db.query(WearableOrder)
            .filter(WearableOrder.provider_payment_intent_id == "pi_confirmed")
            .one()
        )
        admin_notification = (
            db.query(NotificationHistory)
            .filter(
                NotificationHistory.user_id == admin_id,
                NotificationHistory.notification_type == "admin_wearable_order_paid",
            )
            .one()
        )

    assert order.user_id == user_id
    assert order.payment_status == "paid"
    assert order.fulfillment_status == "pending"
    assert admin_notification.payload["order_number"] == order.order_number


def test_wearable_addon_checkout_uses_country_converted_price(tmp_path, monkeypatch):
    app = _boot_app(tmp_path, monkeypatch)
    client = TestClient(app)

    captured: dict[str, object] = {}

    def fake_create_payment_sheet_subscription(self, **kwargs):
        captured.update(kwargs)
        return {
            "payment_intent_client_secret": "pi_addon_secret_123",
            "customer_id": "cus_addon",
            "customer_ephemeral_key_secret": "ek_addon",
            "publishable_key": "pk_test_123",
            "customer_email": "wearable@example.com",
            "provider_subscription_id": "sub_addon",
            "provider_product_id": "prod_test",
            "provider_price_id": "price_test",
            "plan_id": kwargs["plan_id"],
            "interval": kwargs["interval"],
            "currency": "EUR",
            "amount_minor": 3680,
            "display_price": "EUR36.80",
            "provider_payment_intent_id": "pi_addon",
        }

    monkeypatch.setattr(
        StripeBillingService,
        "create_payment_sheet_subscription",
        fake_create_payment_sheet_subscription,
    )

    with get_session_factory()() as db:
        user_id = _seed_user(db)
        _seed_inventory(db, allowed_country_codes=["GB", "DE"])

    response = client.post(
        "/api/v1/wearable/checkout/addon",
        headers={"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"},
        json={
            "country": "Germany",
            "plan_id": "premium_plus",
            "interval": "year",
            "wearable_sku": "VYLA-WEARABLE-V1",
            "shipping_address": {"country": "Germany"},
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert captured["country"] == "Germany"
    assert captured["wearable_price_minor"] == 2911
    assert body["currency"] == "EUR"
    assert body["subscription_amount_minor"] == 3680
    assert body["wearable_amount_minor"] == 2911
    assert body["total_amount_minor"] == 6591


def test_invoice_metadata_merges_subscription_and_wearable_line_metadata(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        metadata = StripeBillingService(
            db,
            Settings(stripe_secret_key="sk_test_123"),
        )._invoice_metadata(
            {
                "subscription_details": {
                    "metadata": {
                        "user_id": "user_123",
                        "plan_id": "premium_plus",
                        "interval": "year",
                        "shipping_address": '{"full_name":"Emma Johnson"}',
                    }
                },
                "lines": {
                    "data": [
                        {
                            "metadata": {
                                "user_id": "user_123",
                                "wearable_sku": "VYLA-WEARABLE-V1",
                            }
                        }
                    ]
                },
            }
        )

    assert metadata["user_id"] == "user_123"
    assert metadata["plan_id"] == "premium_plus"
    assert metadata["interval"] == "year"
    assert metadata["wearable_sku"] == "VYLA-WEARABLE-V1"
    assert metadata["shipping_address"] == '{"full_name":"Emma Johnson"}'


# ── Country availability tests ──────────────────────────────────────────────────

def test_uk_country_availability_returns_available(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        _seed_inventory(db)
        svc = WearableCommerceService(db)
        result = svc.check_availability("VYLA-WEARABLE-V1", country="GB")

    assert result["available"] is True
    assert result["country_code"] == "GB"
    assert result["availability_reason"] == "in_stock"
    assert "GB" in result["supported_country_codes"]


def test_non_uk_country_availability_returns_unavailable(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        _seed_inventory(db)
        svc = WearableCommerceService(db)
        result = svc.check_availability("VYLA-WEARABLE-V1", country="NG")

    assert result["available"] is False
    assert result["country_code"] == "NG"
    assert result["availability_reason"] == "country_not_allowed"
    assert result["supported_country_codes"] == ["GB"]


def test_country_name_resolves_to_code(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        _seed_inventory(db)
        svc = WearableCommerceService(db)
        result = svc.check_availability("VYLA-WEARABLE-V1", country="United Kingdom")

    assert result["available"] is True
    assert result["country_code"] == "GB"


def test_admin_can_update_country_allowlist(tmp_path, monkeypatch):
    app = _boot_app(tmp_path, monkeypatch)
    client = TestClient(app)

    with get_session_factory()() as db:
        admin_id = _seed_user(db, email="admin-country@example.com", is_admin=True)
        _seed_inventory(db)

    token = create_token(admin_id, "access", 30)
    response = client.patch(
        "/api/v1/admin/wearable/inventory/VYLA-WEARABLE-V1/country-availability",
        headers={"Authorization": f"Bearer {token}"},
        json={"allowed_country_codes": ["GB", "US"]},
    )
    assert response.status_code == 200

    with get_session_factory()() as db:
        svc = WearableCommerceService(db)
        result = svc.check_availability("VYLA-WEARABLE-V1", country="US")

    assert result["available"] is True
    assert result["availability_reason"] == "in_stock"


def test_admin_can_update_wearable_stock_from_inventory_endpoint(tmp_path, monkeypatch):
    app = _boot_app(tmp_path, monkeypatch)
    client = TestClient(app)

    with get_session_factory()() as db:
        admin_id = _seed_user(db, email="admin-stock@example.com", is_admin=True)
        _seed_inventory(db)

    token = create_token(admin_id, "access", 30)
    response = client.patch(
        "/api/v1/admin/wearable/inventory",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "sku": "VYLA-WEARABLE-V1",
            "total_stock": 42,
            "available_stock": 39,
            "low_stock_threshold": 4,
            "is_active": True,
        },
    )

    assert response.status_code == 200
    assert response.json()["available_stock"] == 39
    assert response.json()["low_stock_threshold"] == 4

    with get_session_factory()() as db:
        inv = db.query(WearableInventory).filter(WearableInventory.sku == "VYLA-WEARABLE-V1").one()
        assert inv.total_stock == 42
        assert inv.available_stock == 39
        assert inv.low_stock_threshold == 4


def test_admin_stock_update_cannot_reduce_total_below_available_plus_reserved(tmp_path, monkeypatch):
    app = _boot_app(tmp_path, monkeypatch)
    client = TestClient(app)

    with get_session_factory()() as db:
        admin_id = _seed_user(db, email="admin-stock-invalid@example.com", is_admin=True)
        _seed_inventory(db)
        inv = db.query(WearableInventory).filter(WearableInventory.sku == "VYLA-WEARABLE-V1").one()
        inv.available_stock = 8
        inv.reserved_stock = 3
        inv.total_stock = 11
        db.commit()

    token = create_token(admin_id, "access", 30)
    response = client.patch(
        "/api/v1/admin/wearable/inventory",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "sku": "VYLA-WEARABLE-V1",
            "total_stock": 10,
        },
    )

    assert response.status_code == 422
    assert "cannot exceed total stock" in response.json()["detail"].lower()

    with get_session_factory()() as db:
        inv = db.query(WearableInventory).filter(WearableInventory.sku == "VYLA-WEARABLE-V1").one()
        assert inv.total_stock == 11
        assert inv.available_stock == 8
        assert inv.reserved_stock == 3


def test_availability_reflects_admin_allowlist_update(tmp_path, monkeypatch):
    app = _boot_app(tmp_path, monkeypatch)
    client = TestClient(app)

    with get_session_factory()() as db:
        admin_id = _seed_user(db, email="admin-reflect@example.com", is_admin=True)
        _seed_inventory(db)

    token = create_token(admin_id, "access", 30)
    # DE is not allowed initially
    resp_before = client.get(
        "/api/v1/wearable/inventory/availability?sku=VYLA-WEARABLE-V1&country=DE",
    )
    assert resp_before.status_code == 200
    assert resp_before.json()["available"] is False
    assert resp_before.json()["availability_reason"] == "country_not_allowed"

    # Admin adds DE
    client.patch(
        "/api/v1/admin/wearable/inventory/VYLA-WEARABLE-V1/country-availability",
        headers={"Authorization": f"Bearer {token}"},
        json={"allowed_country_codes": ["GB", "DE"]},
    )

    resp_after = client.get(
        "/api/v1/wearable/inventory/availability?sku=VYLA-WEARABLE-V1&country=DE",
    )
    assert resp_after.status_code == 200
    assert resp_after.json()["available"] is True


def test_checkout_for_uk_can_proceed(tmp_path, monkeypatch):
    app = _boot_app(tmp_path, monkeypatch)
    client = TestClient(app)

    def fake_create_payment_sheet_subscription(self, **kwargs):
        return {
            "payment_intent_client_secret": "pi_uk_secret",
            "customer_id": "cus_uk",
            "customer_ephemeral_key_secret": "ek_uk",
            "publishable_key": "pk_test_123",
            "customer_email": None,
            "provider_subscription_id": "sub_uk",
            "provider_product_id": "prod_test",
            "provider_price_id": "price_test",
            "plan_id": kwargs["plan_id"],
            "interval": kwargs["interval"],
            "currency": "GBP",
            "amount_minor": 299,
            "display_price": "£2.99",
            "provider_payment_intent_id": "pi_uk",
        }

    monkeypatch.setattr(
        StripeBillingService,
        "create_payment_sheet_subscription",
        fake_create_payment_sheet_subscription,
    )

    with get_session_factory()() as db:
        user_id = _seed_user(db, email="uk-checkout@example.com")
        _seed_inventory(db)

    response = client.post(
        "/api/v1/wearable/checkout/addon",
        headers={"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"},
        json={
            "country": "GB",
            "plan_id": "premium_plus",
            "interval": "month",
            "wearable_sku": "VYLA-WEARABLE-V1",
            "shipping_address": {"country": "GB"},
        },
    )
    assert response.status_code == 200


def test_checkout_for_non_uk_is_rejected(tmp_path, monkeypatch):
    app = _boot_app(tmp_path, monkeypatch)
    client = TestClient(app)

    with get_session_factory()() as db:
        user_id = _seed_user(db, email="ng-checkout@example.com")
        _seed_inventory(db)

    response = client.post(
        "/api/v1/wearable/checkout/addon",
        headers={"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"},
        json={
            "country": "NG",
            "plan_id": "premium_plus",
            "interval": "month",
            "wearable_sku": "VYLA-WEARABLE-V1",
            "shipping_address": {"country": "NG"},
        },
    )
    assert response.status_code == 403
    assert "not available in your country" in response.json()["detail"].lower()


def test_invalid_country_codes_are_rejected(tmp_path, monkeypatch):
    app = _boot_app(tmp_path, monkeypatch)
    client = TestClient(app)

    with get_session_factory()() as db:
        admin_id = _seed_user(db, email="admin-invalid@example.com", is_admin=True)
        _seed_inventory(db)

    token = create_token(admin_id, "access", 30)
    response = client.patch(
        "/api/v1/admin/wearable/inventory/VYLA-WEARABLE-V1/country-availability",
        headers={"Authorization": f"Bearer {token}"},
        json={"allowed_country_codes": ["GB", "INVALID", "X"]},
    )
    assert response.status_code == 422
