import uuid
from datetime import UTC, date, datetime

from sqlalchemy import JSON, Date, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from phora.db.base import Base, HEALTH_SCHEMA, schema_table_args


class PredictionSnapshot(Base):
    __tablename__ = "predictions"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    prediction_id: Mapped[str] = mapped_column(String(36), unique=True, index=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"), index=True)
    cycle_id: Mapped[str | None] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}cycle_records.id"), nullable=True)
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)
    current_phase: Mapped[str] = mapped_column(String(32))
    ovulation_estimate: Mapped[dict] = mapped_column(JSON, default=dict)
    confidence: Mapped[float] = mapped_column(Float, default=0.0)
    confidence_explanation: Mapped[str] = mapped_column(Text, default="")
    warning_flags: Mapped[list] = mapped_column(JSON, default=list)
    models_used: Mapped[list] = mapped_column(JSON, default=list)
    model_audits: Mapped[list] = mapped_column(JSON, default=list)
    audit: Mapped[dict] = mapped_column(JSON, default=dict)
    fertile_window: Mapped[dict] = mapped_column(JSON, default=dict)
    next_period_estimate: Mapped[dict] = mapped_column(JSON, default=dict)
    phase_distribution: Mapped[dict] = mapped_column(JSON, default=dict)
    contributing_signals: Mapped[list] = mapped_column(JSON, default=list)
    model_version: Mapped[str | None] = mapped_column(String(255), nullable=True)
    ml_payload: Mapped[dict] = mapped_column(JSON, default=dict)
    source: Mapped[str] = mapped_column(String(32), default="shadow")


class CycleForecastSuggestion(Base):
    __tablename__ = "cycle_forecast_suggestions"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"), index=True)
    cycle_id: Mapped[str | None] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}cycle_records.id"), nullable=True, index=True)
    suggestion_type: Mapped[str] = mapped_column(String(32), index=True)
    current_value: Mapped[date | None] = mapped_column(Date, nullable=True)
    suggested_value: Mapped[date] = mapped_column(Date)
    evidence: Mapped[list] = mapped_column(JSON, default=list)
    status: Mapped[str] = mapped_column(String(24), default="pending", index=True)
    source: Mapped[str] = mapped_column(String(64), default="system")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
