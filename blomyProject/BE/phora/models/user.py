import uuid
from datetime import UTC, datetime, date

from sqlalchemy import JSON, Boolean, Date, DateTime, Enum, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from phora.db.base import Base, HEALTH_SCHEMA, schema_table_args
from phora.core.security import new_ulid
from phora.models.enums import Goal, WearableType


class User(Base):
    __tablename__ = "users"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_ulid)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, index=True, nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    account_mode: Mapped[str] = mapped_column(String(32), default="registered", index=True)
    token_generation: Mapped[int] = mapped_column(default=0)
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

    profile: Mapped["UserProfile"] = relationship(back_populates="user", uselist=False)
    otp_codes: Mapped[list["EmailOtpCode"]] = relationship(back_populates="user")
    mfa_totp: Mapped["UserMFATOTP | None"] = relationship(back_populates="user", uselist=False)
    refresh_tokens: Mapped[list["RefreshTokenSession"]] = relationship(back_populates="user")


class UserProfile(Base):
    __tablename__ = "user_profiles"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"), unique=True)
    full_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    date_of_birth: Mapped[date | None] = mapped_column(Date, nullable=True)
    age_at_menarche: Mapped[int | None] = mapped_column(nullable=True)
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    bmi: Mapped[float | None] = mapped_column(Float, nullable=True)
    goal: Mapped[Goal | None] = mapped_column(Enum(Goal), nullable=True)
    conditions: Mapped[dict] = mapped_column(JSON, default=dict)
    wearable_type: Mapped[WearableType] = mapped_column(Enum(WearableType), default=WearableType.NONE)
    timezone: Mapped[str] = mapped_column(String(64), default="UTC")
    onboarding_completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    age_band: Mapped[str | None] = mapped_column(String(1), nullable=True)
    perimenopause_mode_active: Mapped[bool] = mapped_column(Boolean, default=False)
    perimenopause_mode_source: Mapped[str | None] = mapped_column(String(64), nullable=True)
    age_band_updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    age_band_notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[User] = relationship(back_populates="profile")


class OnboardingProgress(Base):
    __tablename__ = "onboarding_progress"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        primary_key=True,
    )
    current_step: Mapped[int | None] = mapped_column(nullable=True)
    completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    period_length: Mapped[int | None] = mapped_column(nullable=True)
    last_period_start: Mapped[date | None] = mapped_column(Date, nullable=True)
    last_period_end: Mapped[date | None] = mapped_column(Date, nullable=True)
    goal: Mapped[Goal | None] = mapped_column(Enum(Goal), nullable=True)
    health_conditions: Mapped[list] = mapped_column(JSON, default=list, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    user: Mapped[User] = relationship()


class EmailOtpCode(Base):
    __tablename__ = "email_otp_codes"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"), index=True)
    email: Mapped[str] = mapped_column(String(255), index=True)
    code_hash: Mapped[str] = mapped_column(String(128))
    purpose: Mapped[str] = mapped_column(String(32), default="signup_verification")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

    user: Mapped[User] = relationship(back_populates="otp_codes")


class RefreshTokenSession(Base):
    __tablename__ = "refresh_token_sessions"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_ulid)
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        index=True,
    )
    family_id: Mapped[str] = mapped_column(String(36), index=True)
    token_jti: Mapped[str] = mapped_column(String(36), unique=True, index=True)
    token_hash: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    replaced_by_jti: Mapped[str | None] = mapped_column(String(36), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))

    user: Mapped[User] = relationship(back_populates="refresh_tokens")


class UserMFATOTP(Base):
    __tablename__ = "user_mfa_totp"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        primary_key=True,
    )
    secret_encrypted: Mapped[str] = mapped_column(String(255))
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    user: Mapped[User] = relationship(back_populates="mfa_totp")
