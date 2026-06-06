from __future__ import annotations

import logging
from decimal import Decimal, ROUND_HALF_UP
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session
from sqlalchemy.orm.attributes import flag_modified

from phora.models.wearable_commerce import WearableInventory, WearableOrder
from phora.models.user import User
from phora.schemas.wearable_commerce import (
    ShippingAddressInput,
    WearableOrderResponse,
    TimelineEntry,
    ShippingAddress,
)
from phora.services.notification_service import NotificationService
from phora.services.billing_catalog import (
    _country_profile,
    _normalize_country,
    _COUNTRY_NAMES,
    _CURRENCY_SYMBOLS,
    _USD_TO_CURRENCY,
    _ZERO_DECIMAL_CURRENCIES,
    _format_minor_amount,
)

logger = logging.getLogger(__name__)

# ── Payment status constants ───────────────────────────────────────────────────
PAYMENT_PENDING = "pending"
PAYMENT_PAID = "paid"
PAYMENT_REFUNDED = "refunded"
PAYMENT_FAILED = "failed"

# ── Fulfillment status constants ───────────────────────────────────────────────
FULFILLMENT_PENDING = "pending"
FULFILLMENT_PROCESSING = "processing"
FULFILLMENT_DISPATCHED = "dispatched"
FULFILLMENT_OUT_FOR_DELIVERY = "out_for_delivery"
FULFILLMENT_DELIVERED = "delivered"
FULFILLMENT_CANCELLED = "cancelled"

# ── Timeline status keys ───────────────────────────────────────────────────────
TIMELINE_ORDER_CONFIRMED = "ORDER_CONFIRMED"
TIMELINE_PROCESSING = "PROCESSING"
TIMELINE_DISPATCHED = "DISPATCHED"
TIMELINE_OUT_FOR_DELIVERY = "OUT_FOR_DELIVERY"
TIMELINE_DELIVERED = "DELIVERED"

_VYLA_WEARABLE_SKU = "VYLA-WEARABLE-V1"

_INITIAL_TIMELINE = [
    {
        "status": TIMELINE_ORDER_CONFIRMED,
        "title": "Order confirmed",
        "description": "We've received your order.",
        "completed_at": None,
    },
    {
        "status": TIMELINE_PROCESSING,
        "title": "Processing",
        "description": "Processing your Vyla Wearable.",
        "completed_at": None,
    },
    {
        "status": TIMELINE_DISPATCHED,
        "title": "Dispatched",
        "description": "Your order has been dispatched.",
        "completed_at": None,
    },
    {
        "status": TIMELINE_OUT_FOR_DELIVERY,
        "title": "Out for delivery",
        "description": "Your order is out for delivery.",
        "completed_at": None,
    },
    {
        "status": TIMELINE_DELIVERED,
        "title": "Delivered",
        "description": "Your Vyla Wearable has been delivered.",
        "completed_at": None,
    },
]

_FULFILLMENT_NOTIFICATION = {
    FULFILLMENT_PENDING: ("Order confirmed ✨", "Your Vyla Wearable order has been confirmed.", "wearable_order_confirmed"),
    FULFILLMENT_PROCESSING: ("Processing your order", "We're getting your Vyla Wearable ready.", "wearable_order_processing"),
    FULFILLMENT_DISPATCHED: ("Your order is on the way! 📦", "Your Vyla Wearable has been dispatched.", "wearable_dispatched"),
    FULFILLMENT_OUT_FOR_DELIVERY: ("Out for delivery 🚚", "Your Vyla Wearable is on its way to you today.", "wearable_out_for_delivery"),
    FULFILLMENT_DELIVERED: ("Your Vyla Wearable has arrived! ✨", "Your package has been delivered. Let's get you connected.", "wearable_delivered"),
    FULFILLMENT_CANCELLED: ("Wearable order cancelled", "Your Vyla Wearable order has been cancelled.", "wearable_cancelled"),
}

FULFILLMENT_STATUSES = (
    FULFILLMENT_PENDING,
    FULFILLMENT_PROCESSING,
    FULFILLMENT_DISPATCHED,
    FULFILLMENT_OUT_FOR_DELIVERY,
    FULFILLMENT_DELIVERED,
    FULFILLMENT_CANCELLED,
)

PAYMENT_STATUSES = (
    PAYMENT_PENDING,
    PAYMENT_PAID,
    PAYMENT_REFUNDED,
    PAYMENT_FAILED,
)


def _order_number() -> str:
    import random
    n = random.randint(1, 99999)
    return f"#VYLA-{n:08d}"


def _currency_symbol(currency: str) -> str:
    return _CURRENCY_SYMBOLS.get(currency.upper(), currency.upper())


def _format_price(amount_minor: int, currency: str) -> str:
    return _format_minor_amount(currency.upper(), amount_minor)


# GBP is the inventory base currency. Convert to target via USD as intermediate.
_GBP_TO_USD = Decimal("1") / _USD_TO_CURRENCY.get("GBP", Decimal("0.79"))


def _convert_from_gbp(gbp_minor: int, target_currency: str) -> int:
    """Convert a GBP minor amount to target_currency minor amount."""
    if target_currency.upper() == "GBP":
        return gbp_minor
    usd = Decimal(gbp_minor) / Decimal("100") * _GBP_TO_USD
    rate = _USD_TO_CURRENCY.get(target_currency.upper(), Decimal("1"))
    converted = usd * rate
    if target_currency.upper() in _ZERO_DECIMAL_CURRENCIES:
        return int(converted.quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    return int((converted.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)) * 100)


class WearableCommerceService:
    def __init__(self, db: Session):
        self.db = db

    # ── Inventory ──────────────────────────────────────────────────────────────

    def get_inventory(self, sku: str) -> WearableInventory | None:
        return (
            self.db.query(WearableInventory)
            .filter(WearableInventory.sku == sku, WearableInventory.is_active.is_(True))
            .one_or_none()
        )

    def get_default_inventory(self) -> WearableInventory | None:
        return (
            self.db.query(WearableInventory)
            .filter(WearableInventory.is_active.is_(True))
            .order_by(WearableInventory.created_at)
            .first()
        )

    def check_availability(self, sku: str, country: str | None = None) -> dict:
        inv = self.get_inventory(sku)

        # Normalise country to ISO-3166 alpha-2 (e.g. "United Kingdom" → "GB")
        country_code: str | None = None
        country_name: str | None = None
        if country:
            country_code = _normalize_country(country)
            country_name = _COUNTRY_NAMES.get(country_code, country_code) if country_code else country

        # Resolve display currency (falls back to GBP when unknown)
        if country_code:
            profile = _country_profile(country_code)
            currency = profile.currency if profile.primary_provider == "stripe" else "GBP"
        else:
            currency = inv.currency if inv else "GBP"

        if not inv:
            return {
                "sku": sku,
                "product_name": "Vyla Wearable",
                "available": False,
                "available_stock": 0,
                "low_stock": False,
                "low_stock_threshold": 0,
                "price_minor": 0,
                "currency": currency,
                "currency_symbol": _currency_symbol(currency),
                "display_price": f"{_currency_symbol(currency)}0.00",
                "country": country_name,
                "country_code": country_code,
                "availability_reason": "sku_not_found",
                "supported_country_codes": [],
            }

        allowed: list[str] = list(inv.allowed_country_codes or ["GB"])

        # Country-based gate: if a country was supplied and it is not in the allowlist, block
        if country_code and country_code not in allowed:
            return {
                "sku": inv.sku,
                "product_name": inv.product_name,
                "available": False,
                "available_stock": inv.available_stock,
                "low_stock": False,
                "low_stock_threshold": inv.low_stock_threshold,
                "price_minor": 0,
                "currency": currency,
                "currency_symbol": _currency_symbol(currency),
                "display_price": f"{_currency_symbol(currency)}0.00",
                "country": country_name,
                "country_code": country_code,
                "availability_reason": "country_not_allowed",
                "supported_country_codes": allowed,
            }

        price_minor = _convert_from_gbp(inv.price_minor, currency)
        in_stock = inv.available_stock > 0
        return {
            "sku": inv.sku,
            "product_name": inv.product_name,
            "available": in_stock,
            "available_stock": inv.available_stock,
            "low_stock": 0 < inv.available_stock <= inv.low_stock_threshold,
            "low_stock_threshold": inv.low_stock_threshold,
            "price_minor": price_minor,
            "currency": currency,
            "currency_symbol": _currency_symbol(currency),
            "display_price": _format_price(price_minor, currency),
            "country": country_name,
            "country_code": country_code,
            "availability_reason": "in_stock" if in_stock else "out_of_stock",
            "supported_country_codes": allowed,
        }

    # ── Order creation ─────────────────────────────────────────────────────────

    def create_order(
        self,
        *,
        user_id: str,
        subscription_id: str | None,
        sku: str,
        shipping_address: dict,
        payment_intent_id: str | None = None,
    ) -> WearableOrder:
        inv = (
            self.db.query(WearableInventory)
            .filter(WearableInventory.sku == sku, WearableInventory.is_active.is_(True))
            .with_for_update()
            .one_or_none()
        )
        if not inv or inv.available_stock < 1:
            raise ValueError("Wearable is out of stock.")

        now = datetime.now(UTC)
        timeline = [dict(entry) for entry in _INITIAL_TIMELINE]
        timeline[0]["completed_at"] = now.isoformat()

        order = WearableOrder(
            user_id=user_id,
            subscription_id=subscription_id,
            order_number=_order_number(),
            wearable_sku=inv.sku,
            wearable_name=inv.product_name,
            wearable_price=inv.price_minor / 100,
            wearable_currency=inv.currency,
            payment_status=PAYMENT_PAID,
            fulfillment_status=FULFILLMENT_PENDING,
            shipping_address_json=shipping_address,
            timeline_json=timeline,
            provider_payment_intent_id=payment_intent_id,
        )
        self.db.add(order)

        inv.available_stock = max(0, inv.available_stock - 1)
        inv.reserved_stock = inv.reserved_stock + 1

        self.db.flush()
        self._dispatch_user_fulfillment_notification(order, fulfillment_status=FULFILLMENT_PENDING)
        self._dispatch_admin_order_notification(order)
        self.db.commit()
        return order

    # ── Order retrieval ────────────────────────────────────────────────────────

    def get_user_orders(self, user_id: str) -> list[WearableOrder]:
        return (
            self.db.query(WearableOrder)
            .filter(WearableOrder.user_id == user_id)
            .order_by(WearableOrder.created_at.desc())
            .all()
        )

    def get_user_order(self, user_id: str, order_id: str) -> WearableOrder | None:
        return (
            self.db.query(WearableOrder)
            .filter(WearableOrder.id == order_id, WearableOrder.user_id == user_id)
            .one_or_none()
        )

    # ── Admin fulfillment update ───────────────────────────────────────────────

    def update_fulfillment(
        self,
        order: WearableOrder,
        *,
        fulfillment_status: str,
        tracking_number: str | None = None,
        tracking_url: str | None = None,
        courier: str | None = None,
        estimated_delivery_date: datetime | None = None,
    ) -> WearableOrder:
        fulfillment_status = fulfillment_status.lower().strip()
        if fulfillment_status not in FULFILLMENT_STATUSES:
            raise ValueError("Invalid fulfillment status.")

        now = datetime.now(UTC)
        previous_status = order.fulfillment_status
        had_tracking = bool(order.tracking_number or order.tracking_url)
        order.fulfillment_status = fulfillment_status

        if tracking_number is not None:
            order.tracking_number = tracking_number
        if tracking_url is not None:
            order.tracking_url = tracking_url
        if courier is not None:
            order.courier = courier
        if estimated_delivery_date is not None:
            order.estimated_delivery_date = estimated_delivery_date

        if fulfillment_status == FULFILLMENT_DISPATCHED and not order.shipped_at:
            order.shipped_at = now
        if fulfillment_status == FULFILLMENT_DELIVERED and not order.delivered_at:
            order.delivered_at = now
            inv = self.get_inventory(order.wearable_sku)
            if inv:
                inv.reserved_stock = max(0, inv.reserved_stock - 1)

        timeline = list(order.timeline_json or [])
        status_to_timeline = {
            FULFILLMENT_PENDING: TIMELINE_ORDER_CONFIRMED,
            FULFILLMENT_PROCESSING: TIMELINE_PROCESSING,
            FULFILLMENT_DISPATCHED: TIMELINE_DISPATCHED,
            FULFILLMENT_OUT_FOR_DELIVERY: TIMELINE_OUT_FOR_DELIVERY,
            FULFILLMENT_DELIVERED: TIMELINE_DELIVERED,
        }
        timeline_order = [
            TIMELINE_ORDER_CONFIRMED,
            TIMELINE_PROCESSING,
            TIMELINE_DISPATCHED,
            TIMELINE_OUT_FOR_DELIVERY,
            TIMELINE_DELIVERED,
        ]
        timeline_key = status_to_timeline.get(fulfillment_status)
        if timeline_key:
            current_index = timeline_order.index(timeline_key)
            completed_statuses = set(timeline_order[: current_index + 1])
            for entry in timeline:
                if entry.get("status") in completed_statuses and not entry.get("completed_at"):
                    entry["completed_at"] = now.isoformat()

        order.timeline_json = timeline
        flag_modified(order, "timeline_json")
        self.db.flush()
        status_changed = previous_status != fulfillment_status
        tracking_added = not had_tracking and bool(order.tracking_number or order.tracking_url)
        if status_changed:
            self._dispatch_user_fulfillment_notification(order, fulfillment_status=fulfillment_status)
        elif tracking_added:
            self._dispatch_user_tracking_notification(order)
        self.db.commit()
        return order

    def update_inventory(self, inv: WearableInventory, **fields) -> WearableInventory:
        total_stock = fields.get("total_stock", inv.total_stock)
        available_stock = fields.get("available_stock", inv.available_stock)
        reserved_stock = fields.get("reserved_stock", inv.reserved_stock)
        if available_stock + reserved_stock > total_stock:
            raise ValueError("Available and reserved stock cannot exceed total stock.")
        if "allowed_country_codes" in fields:
            codes = fields["allowed_country_codes"]
            if codes is not None:
                invalid = [c for c in codes if not (isinstance(c, str) and len(c) == 2 and c.isalpha())]
                if invalid:
                    raise ValueError(f"Invalid country codes: {', '.join(invalid)}. Use ISO-3166 alpha-2 (e.g. GB, US).")
                inv.allowed_country_codes = [c.upper() for c in codes]
                flag_modified(inv, "allowed_country_codes")
            del fields["allowed_country_codes"]
        for key, value in fields.items():
            if value is not None and hasattr(inv, key):
                setattr(inv, key, value)
        self.db.commit()
        return inv

    def serialize_inventory(self, inv: WearableInventory) -> dict:
        return {
            "id": inv.id,
            "sku": inv.sku,
            "product_name": inv.product_name,
            "total_stock": inv.total_stock,
            "available_stock": inv.available_stock,
            "reserved_stock": inv.reserved_stock,
            "low_stock_threshold": inv.low_stock_threshold,
            "low_stock": 0 < inv.available_stock <= inv.low_stock_threshold,
            "price_minor": inv.price_minor,
            "currency": inv.currency,
            "currency_symbol": inv.currency_symbol,
            "display_price": _format_price(inv.price_minor, inv.currency),
            "is_active": inv.is_active,
            "allowed_country_codes": list(inv.allowed_country_codes or ["GB"]),
            "created_at": inv.created_at.isoformat(),
            "updated_at": inv.updated_at.isoformat(),
        }

    # ── Serialization ──────────────────────────────────────────────────────────

    def serialize_order(self, order: WearableOrder) -> dict:
        addr = order.shipping_address_json or {}
        timeline = [
            {
                "status": e.get("status", ""),
                "title": e.get("title", ""),
                "description": e.get("description", ""),
                "completed_at": e.get("completed_at"),
            }
            for e in (order.timeline_json or [])
        ]
        return {
            "id": order.id,
            "order_number": order.order_number,
            "wearable_sku": order.wearable_sku,
            "wearable_name": order.wearable_name,
            "wearable_price": order.wearable_price,
            "wearable_currency": order.wearable_currency,
            "display_price": _format_price(int(order.wearable_price * 100), order.wearable_currency),
            "payment_status": order.payment_status,
            "fulfillment_status": order.fulfillment_status,
            "tracking_number": order.tracking_number,
            "tracking_url": order.tracking_url,
            "courier": order.courier,
            "estimated_delivery_date": order.estimated_delivery_date.isoformat() if order.estimated_delivery_date else None,
            "shipped_at": order.shipped_at.isoformat() if order.shipped_at else None,
            "delivered_at": order.delivered_at.isoformat() if order.delivered_at else None,
            "shipping_address": {
                "full_name": addr.get("full_name"),
                "line1": addr.get("line1"),
                "line2": addr.get("line2"),
                "city": addr.get("city"),
                "county": addr.get("county"),
                "postcode": addr.get("postcode"),
                "country": addr.get("country"),
                "phone": addr.get("phone"),
            },
            "timeline": timeline,
            "created_at": order.created_at.isoformat(),
            "updated_at": order.updated_at.isoformat(),
        }

    # ── Notifications ──────────────────────────────────────────────────────────

    def _dispatch_user_fulfillment_notification(self, order: WearableOrder, *, fulfillment_status: str) -> None:
        info = _FULFILLMENT_NOTIFICATION.get(fulfillment_status)
        if not info:
            return
        title, body, category = info
        if fulfillment_status == FULFILLMENT_DISPATCHED and order.courier:
            body = f"Your Vyla Wearable has been dispatched with {order.courier}."
        if fulfillment_status == FULFILLMENT_DISPATCHED and order.tracking_url:
            body = f"{body} Tracking is now available in the app."
        action_url = (
            f"/wearable/orders/{order.id}/delivered"
            if fulfillment_status == FULFILLMENT_DELIVERED
            else f"/wearable/orders/{order.id}/tracking"
        )
        try:
            service = NotificationService(self.db)
            service._create_notification(
                user_id=order.user_id,
                notification_type=category,
                title=title,
                body=body,
                category=category,
                priority="high",
                action_url=action_url,
                payload_data={
                    "source": "wearable_commerce",
                    "order_id": order.id,
                    "order_number": order.order_number,
                    "fulfillment_status": fulfillment_status,
                    "tracking_number": order.tracking_number or "",
                    "tracking_url": order.tracking_url or "",
                    "courier": order.courier or "",
                },
                send_at=datetime.now(UTC),
                lock_screen_title=title,
                lock_screen_body=body,
                force_delivery=True,
                dedupe_key=f"wearable:{order.id}:{category}",
            )
            service.dispatch_pending(user_id=order.user_id, notification_type=category)
        except Exception:
            logger.exception("Failed to create wearable notification for user %s", order.user_id)

    def _dispatch_user_tracking_notification(self, order: WearableOrder) -> None:
        notification_type = "wearable_tracking_added"
        title = "Tracking is ready"
        body = "Tracking details have been added for your Vyla Wearable order."
        if order.courier:
            body = f"Tracking details from {order.courier} have been added for your Vyla Wearable order."
        try:
            service = NotificationService(self.db)
            service._create_notification(
                user_id=order.user_id,
                notification_type=notification_type,
                title=title,
                body=body,
                category="wearable_tracking",
                priority="high",
                action_url=f"/wearable/orders/{order.id}/tracking",
                payload_data={
                    "source": "wearable_commerce",
                    "order_id": order.id,
                    "order_number": order.order_number,
                    "fulfillment_status": order.fulfillment_status,
                    "tracking_number": order.tracking_number or "",
                    "tracking_url": order.tracking_url or "",
                    "courier": order.courier or "",
                },
                send_at=datetime.now(UTC),
                lock_screen_title=title,
                lock_screen_body=body,
                force_delivery=True,
                dedupe_key=f"wearable:{order.id}:{notification_type}",
            )
            service.dispatch_pending(user_id=order.user_id, notification_type=notification_type)
        except Exception:
            logger.exception("Failed to create wearable tracking notification for user %s", order.user_id)

    def _dispatch_admin_order_notification(self, order: WearableOrder) -> None:
        admins = self.db.query(User).filter(User.is_admin.is_(True), User.deleted_at.is_(None)).all()
        if not admins:
            return

        title = "New wearable order"
        body = f"{order.order_number} has been paid and is ready for fulfillment."
        for admin in admins:
            try:
                service = NotificationService(self.db)
                service._create_notification(
                    user_id=admin.id,
                    notification_type="admin_wearable_order_paid",
                    title=title,
                    body=body,
                    category="wearable_orders",
                    priority="high",
                    action_url="/wearables/orders",
                    payload_data={
                        "source": "wearable_commerce",
                        "order_id": order.id,
                        "order_number": order.order_number,
                        "customer_user_id": order.user_id,
                        "fulfillment_status": order.fulfillment_status,
                    },
                    send_at=datetime.now(UTC),
                    lock_screen_title=title,
                    lock_screen_body=body,
                    force_delivery=True,
                    dedupe_key=f"admin:wearable:{order.id}:paid",
                )
                service.dispatch_pending(user_id=admin.id, notification_type="admin_wearable_order_paid")
            except Exception:
                logger.exception("Failed to create admin wearable notification for admin %s", admin.id)
