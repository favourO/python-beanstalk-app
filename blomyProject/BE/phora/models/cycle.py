import uuid
from datetime import UTC, datetime, date

from sqlalchemy import JSON, Boolean, Date, DateTime, Enum, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from phora.db.base import Base, HEALTH_SCHEMA, schema_table_args
from phora.models.enums import LogType


class CycleRecord(Base):
    __tablename__ = "cycle_records"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"), index=True)
    period_start_date: Mapped[date] = mapped_column(Date)
    period_end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    cycle_length_days: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ovulation_predicted_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    ovulation_confirmed_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    lh_surge_detected_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    luteal_length_days: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_anovulatory: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    mu_cycle: Mapped[float | None] = mapped_column(Float, nullable=True)
    sigma_cycle: Mapped[float | None] = mapped_column(Float, nullable=True)
    menses_length: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))


class DailyLog(Base):
    __tablename__ = "daily_logs"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"), index=True)
    cycle_id: Mapped[str | None] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}cycle_records.id"), nullable=True)
    log_date: Mapped[date] = mapped_column(Date, index=True)
    log_type: Mapped[LogType] = mapped_column(Enum(LogType))
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    is_noisy: Mapped[bool] = mapped_column(Boolean, default=False)
    logged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

