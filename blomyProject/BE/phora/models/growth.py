import secrets
import uuid
from datetime import UTC, datetime

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from phora.db.base import Base, BILLING_SCHEMA, HEALTH_SCHEMA, schema_table_args


def _code_default() -> str:
    return secrets.token_urlsafe(6).replace("-", "").replace("_", "").upper()[:10]


class FriendConnection(Base):
    __tablename__ = "friend_connections"
    __table_args__ = (
        UniqueConstraint("requester_user_id", "addressee_user_id", name="uq_friend_connection_pair"),
        *(() if not schema_table_args(HEALTH_SCHEMA) else (schema_table_args(HEALTH_SCHEMA),)),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    requester_user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        index=True,
    )
    addressee_user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        index=True,
    )
    status: Mapped[str] = mapped_column(String(24), default="pending", index=True)
    requester_compare_opt_in: Mapped[bool] = mapped_column(Boolean, default=False)
    addressee_compare_opt_in: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
    accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    declined_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ReferralProfile(Base):
    __tablename__ = "referral_profiles"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        unique=True,
        index=True,
    )
    referral_code: Mapped[str] = mapped_column(String(32), unique=True, index=True, default=_code_default)
    qualified_invites_count: Mapped[int] = mapped_column(Integer, default=0)
    rewarded_milestones: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class ReferralAttribution(Base):
    __tablename__ = "referral_attributions"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    inviter_user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        index=True,
    )
    invited_user_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        nullable=True,
        unique=True,
        index=True,
    )
    referral_code: Mapped[str] = mapped_column(String(32), index=True)
    source: Mapped[str | None] = mapped_column(String(64), nullable=True)
    deep_link_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    status: Mapped[str] = mapped_column(String(24), default="pending", index=True)
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    qualified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    disqualified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    qualification_reason: Mapped[str | None] = mapped_column(String(128), nullable=True)
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class PremiumGrant(Base):
    __tablename__ = "premium_grants"
    __table_args__ = schema_table_args(BILLING_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    tier: Mapped[str] = mapped_column(String(32), default="premium_plus")
    source_type: Mapped[str] = mapped_column(String(32), index=True)
    source_ref_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    days_granted: Mapped[int] = mapped_column(Integer, default=30)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
