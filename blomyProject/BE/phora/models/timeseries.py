import uuid
from datetime import UTC, datetime

from sqlalchemy import Boolean, DateTime, Float, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from phora.db.base import Base, HEALTH_SCHEMA, schema_table_args


class SensorReading(Base):
    __tablename__ = "sensor_readings"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    metric: Mapped[str] = mapped_column(String(32), index=True)
    value: Mapped[float] = mapped_column(Float)
    delta: Mapped[float | None] = mapped_column(Float, nullable=True)
    quality_score: Mapped[float] = mapped_column(Float, default=1.0)
    source: Mapped[str] = mapped_column(String(32), default="manual")
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)


class StressScore(Base):
    __tablename__ = "stress_scores"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    score: Mapped[float] = mapped_column(Float, default=0.0)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)


class WearableMetric(Base):
    __tablename__ = "wearable_metrics"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    source: Mapped[str] = mapped_column(String(32), index=True)
    metric_type: Mapped[str] = mapped_column(String(48), index=True)
    value: Mapped[float] = mapped_column(Float)
    unit: Mapped[str] = mapped_column(String(24))
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    collected_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        index=True,
    )
    is_morning_bbt_window: Mapped[bool] = mapped_column(Boolean, default=False)
    is_user_entered: Mapped[bool] = mapped_column(Boolean, default=False)
    confidence: Mapped[str] = mapped_column(String(16), default="medium")
    excluded_from_ovulation_prediction: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )
    exclusion_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    raw_payload: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    data_source: Mapped[str] = mapped_column(String(50), index=True, default="vyla_wearable")
    external_id: Mapped[str | None] = mapped_column(String(255), nullable=True)


class GoogleHealthConnection(Base):
    __tablename__ = "google_health_connections"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    user_id: Mapped[str] = mapped_column(String(36), unique=True, index=True)
    oauth_type: Mapped[str] = mapped_column(String(24), default="google")
    google_user_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    fitbit_legacy_user_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    refresh_token_ciphertext: Mapped[str | None] = mapped_column(Text, nullable=True)
    access_token_ciphertext: Mapped[str | None] = mapped_column(Text, nullable=True)
    access_token_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    granted_scopes: Mapped[list | None] = mapped_column(JSON, nullable=True)
    raw_identity: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    connected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_sync_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
