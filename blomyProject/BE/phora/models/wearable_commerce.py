import uuid
from datetime import UTC, datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column

from phora.db.base import Base, BILLING_SCHEMA, HEALTH_SCHEMA, schema_table_args


class WearableInventory(Base):
    __tablename__ = "wearable_inventory"
    __table_args__ = schema_table_args(BILLING_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    product_name: Mapped[str] = mapped_column(String(128))
    sku: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    total_stock: Mapped[int] = mapped_column(Integer, default=0)
    available_stock: Mapped[int] = mapped_column(Integer, default=0)
    reserved_stock: Mapped[int] = mapped_column(Integer, default=0)
    price_minor: Mapped[int] = mapped_column(Integer, default=0)
    currency: Mapped[str] = mapped_column(String(8), default="GBP")
    currency_symbol: Mapped[str] = mapped_column(String(4), default="£")
    low_stock_threshold: Mapped[int] = mapped_column(Integer, default=5)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    allowed_country_codes: Mapped[list] = mapped_column(JSON, default=lambda: ["GB"])
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class WearableOrder(Base):
    __tablename__ = "wearable_orders"
    __table_args__ = schema_table_args(BILLING_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    subscription_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey(f"{BILLING_SCHEMA + '.' if BILLING_SCHEMA else ''}subscriptions.id"),
        nullable=True,
        index=True,
    )
    order_number: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    wearable_sku: Mapped[str] = mapped_column(String(64))
    wearable_name: Mapped[str] = mapped_column(String(128))
    wearable_price: Mapped[float] = mapped_column(Float, default=0.0)
    wearable_currency: Mapped[str] = mapped_column(String(8), default="GBP")
    payment_status: Mapped[str] = mapped_column(String(32), default="pending", index=True)
    fulfillment_status: Mapped[str] = mapped_column(String(32), default="pending", index=True)
    tracking_number: Mapped[str | None] = mapped_column(String(128), nullable=True)
    tracking_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    courier: Mapped[str | None] = mapped_column(String(64), nullable=True)
    estimated_delivery_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    shipped_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    shipping_address_json: Mapped[dict] = mapped_column(JSON, default=dict)
    timeline_json: Mapped[list] = mapped_column(JSON, default=list)
    provider_payment_intent_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
