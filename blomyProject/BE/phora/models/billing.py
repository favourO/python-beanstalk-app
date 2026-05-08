import uuid
from datetime import UTC, datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, JSON, String
from sqlalchemy.orm import Mapped, mapped_column

from phora.db.base import Base, BILLING_SCHEMA, schema_table_args


class Subscription(Base):
    __tablename__ = "subscriptions"
    __table_args__ = schema_table_args(BILLING_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    tier: Mapped[str] = mapped_column(String(32), default="free")
    status: Mapped[str] = mapped_column(String(32), default="active")
    provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    provider_subscription_id: Mapped[str | None] = mapped_column(String(255), index=True, nullable=True)
    provider_customer_id: Mapped[str | None] = mapped_column(String(255), index=True, nullable=True)
    provider_price_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    currency: Mapped[str | None] = mapped_column(String(8), nullable=True)
    billing_interval: Mapped[str | None] = mapped_column(String(16), nullable=True)
    current_period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class Invoice(Base):
    __tablename__ = "invoices"
    __table_args__ = schema_table_args(BILLING_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    subscription_id: Mapped[str | None] = mapped_column(String(36), ForeignKey(f"{BILLING_SCHEMA + '.' if BILLING_SCHEMA else ''}subscriptions.id"), nullable=True)
    provider_invoice_id: Mapped[str | None] = mapped_column(String(255), index=True, nullable=True)
    provider_customer_id: Mapped[str | None] = mapped_column(String(255), index=True, nullable=True)
    provider_payment_intent_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    total: Mapped[float] = mapped_column(Float, default=0.0)
    currency: Mapped[str] = mapped_column(String(8), default="GBP")
    status: Mapped[str] = mapped_column(String(32), default="draft")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class FlutterwaveWebhookErrorLog(Base):
    __tablename__ = "flutterwave_webhook_errors"
    __table_args__ = schema_table_args(BILLING_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    event_type: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    transaction_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    tx_ref: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    provider_customer_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    provider_plan_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    user_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    error_message: Mapped[str] = mapped_column(String(512))
    signature_present: Mapped[bool] = mapped_column(Boolean, default=False)
    legacy_hash_present: Mapped[bool] = mapped_column(Boolean, default=False)
    payload_summary: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)


class StripeWebhookErrorLog(Base):
    __tablename__ = "stripe_webhook_errors"
    __table_args__ = schema_table_args(BILLING_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    stripe_event_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    event_type: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    payment_intent_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    subscription_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    customer_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    error_message: Mapped[str] = mapped_column(String(512))
    error_category: Mapped[str] = mapped_column(String(32), default="unknown", index=True)
    signature_present: Mapped[bool] = mapped_column(Boolean, default=False)
    payload_summary: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)
