import uuid
from datetime import UTC, date, datetime

from sqlalchemy import JSON, Date, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from phora.db.base import Base, HEALTH_SCHEMA, schema_table_args


class DailyInsight(Base):
    __tablename__ = "daily_insights"
    __table_args__ = (
        UniqueConstraint("user_id", "insight_date", name="uq_daily_insights_user_date"),
        schema_table_args(HEALTH_SCHEMA),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        index=True,
    )
    insight_date: Mapped[date] = mapped_column(Date, index=True)
    phase: Mapped[str | None] = mapped_column(String(32), nullable=True)
    source: Mapped[str] = mapped_column(String(32), default="rules")
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    anonymized_context: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
