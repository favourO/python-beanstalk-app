import uuid
from datetime import UTC, datetime

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from phora.db.base import Base, HEALTH_SCHEMA, schema_table_args


class NotificationPreference(Base):
    __tablename__ = "notification_preferences"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"), unique=True)
    all_notifications: Mapped[bool] = mapped_column(Boolean, default=True)
    fertile_window_open: Mapped[bool] = mapped_column(Boolean, default=True)
    ovulation_confirmed: Mapped[bool] = mapped_column(Boolean, default=True)
    period_approaching: Mapped[bool] = mapped_column(Boolean, default=True)
    lh_test_reminder: Mapped[bool] = mapped_column(Boolean, default=False)
    period_detected: Mapped[bool] = mapped_column(Boolean, default=True)
    cycle_delay_alert: Mapped[bool] = mapped_column(Boolean, default=True)
    cycle_pattern_change: Mapped[bool] = mapped_column(Boolean, default=True)
    unusual_symptom: Mapped[bool] = mapped_column(Boolean, default=True)
    stress_alert: Mapped[bool] = mapped_column(Boolean, default=True)
    sleep_alert: Mapped[bool] = mapped_column(Boolean, default=False)
    daily_symptom_reminder: Mapped[bool] = mapped_column(Boolean, default=False)
    bangle_sync_reminder: Mapped[bool] = mapped_column(Boolean, default=False)
    temperature_logging_reminder: Mapped[bool] = mapped_column(Boolean, default=False)
    weekly_summary: Mapped[bool] = mapped_column(Boolean, default=True)
    feature_tips: Mapped[bool] = mapped_column(Boolean, default=True)
    blog_posts: Mapped[bool] = mapped_column(Boolean, default=True)
    wearable_ovulation_reminder: Mapped[bool] = mapped_column(Boolean, default=True)
    update_reminders: Mapped[bool] = mapped_column(Boolean, default=True)
    quiet_hours_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    quiet_hours_start: Mapped[str] = mapped_column(String(5), default="22:00")
    quiet_hours_end: Mapped[str] = mapped_column(String(5), default="08:00")
    allow_critical_in_quiet_hours: Mapped[bool] = mapped_column(Boolean, default=True)
    lock_screen_preview: Mapped[bool] = mapped_column(Boolean, default=False)
    push_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    in_app_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    email_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    sms_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class NotificationDevice(Base):
    __tablename__ = "notification_devices"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"), index=True)
    platform: Mapped[str] = mapped_column(String(16), index=True)
    device_id: Mapped[str] = mapped_column(String(128), index=True)
    fcm_token: Mapped[str] = mapped_column(String(512), unique=True, index=True)
    app_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    device_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    locale: Mapped[str | None] = mapped_column(String(16), nullable=True)
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)
    invalidated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class NotificationHistory(Base):
    __tablename__ = "notification_history"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"), index=True)
    notification_type: Mapped[str] = mapped_column(String(64))
    category: Mapped[str] = mapped_column(String(32), default="general")
    channel: Mapped[str] = mapped_column(String(16), default="in_app")
    title: Mapped[str] = mapped_column(String(120))
    body: Mapped[str] = mapped_column(Text)
    lock_screen_title: Mapped[str] = mapped_column(String(120))
    lock_screen_body: Mapped[str] = mapped_column(String(120), default="")
    status: Mapped[str] = mapped_column(String(32), default="pending")
    priority: Mapped[str] = mapped_column(String(16), default="low")
    batch_key: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    dedupe_key: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    action_url: Mapped[str | None] = mapped_column(String(255), nullable=True)
    action_labels: Mapped[list] = mapped_column(JSON, default=list)
    scheduled_for: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    notification_metadata: Mapped[dict] = mapped_column("metadata", JSON, default=dict)
    delivery_attempts: Mapped[int] = mapped_column(Integer, default=0)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
