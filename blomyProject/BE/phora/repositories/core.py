from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, desc, select
from sqlalchemy.orm import Session

from phora.models import (
    AuditEvent,
    CycleRecord,
    DailyLog,
    DailyInsight,
    EmailOtpCode,
    GoogleHealthConnection,
    NotificationDevice,
    NotificationHistory,
    NotificationPreference,
    OnboardingProgress,
    PredictionSnapshot,
    RefreshTokenSession,
    SensorReading,
    StressScore,
    User,
    UserMFATOTP,
    UserProfile,
    WearableMetric,
)
from phora.models.enums import LogType


class UserRepository:
    def __init__(self, db: Session):
        self.db = db

    def by_id(self, user_id: str) -> User | None:
        return self.db.scalar(select(User).where(User.id == user_id))

    def by_email(self, email: str) -> User | None:
        return self.db.scalar(select(User).where(User.email == email.lower()))

    def active_user_ids(self) -> list[str]:
        stmt = select(User.id).where(User.deleted_at.is_(None))
        return list(self.db.scalars(stmt))

    def ensure_profile(self, user_id: str) -> UserProfile:
        profile = self.db.scalar(select(UserProfile).where(UserProfile.user_id == user_id))
        if profile:
            return profile
        profile = UserProfile(user_id=user_id)
        self.db.add(profile)
        self.db.flush()
        return profile

    def onboarding_progress(self, user_id: str) -> OnboardingProgress | None:
        return self.db.scalar(select(OnboardingProgress).where(OnboardingProgress.user_id == user_id))

    def ensure_onboarding_progress(self, user_id: str) -> OnboardingProgress:
        progress = self.onboarding_progress(user_id)
        if progress:
            return progress
        progress = OnboardingProgress(user_id=user_id)
        self.db.add(progress)
        self.db.flush()
        return progress


class OtpRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, otp: EmailOtpCode) -> EmailOtpCode:
        self.db.add(otp)
        self.db.flush()
        return otp

    def latest_active(self, email: str, purpose: str) -> EmailOtpCode | None:
        stmt = (
            select(EmailOtpCode)
            .where(
                EmailOtpCode.email == email.lower(),
                EmailOtpCode.purpose == purpose,
                EmailOtpCode.consumed_at.is_(None),
            )
            .order_by(desc(EmailOtpCode.created_at))
        )
        return self.db.scalar(stmt)

    def latest_active_for_user(self, user_id: str, purpose: str) -> EmailOtpCode | None:
        stmt = (
            select(EmailOtpCode)
            .where(
                EmailOtpCode.user_id == user_id,
                EmailOtpCode.purpose == purpose,
                EmailOtpCode.consumed_at.is_(None),
            )
            .order_by(desc(EmailOtpCode.created_at))
        )
        return self.db.scalar(stmt)


class TOTPRepository:
    def __init__(self, db: Session):
        self.db = db

    def by_user_id(self, user_id: str) -> UserMFATOTP | None:
        return self.db.scalar(select(UserMFATOTP).where(UserMFATOTP.user_id == user_id))

    def save(self, record: UserMFATOTP) -> UserMFATOTP:
        self.db.add(record)
        self.db.flush()
        return record


class RefreshTokenRepository:
    def __init__(self, db: Session):
        self.db = db

    def by_hash(self, token_hash: str) -> RefreshTokenSession | None:
        return self.db.scalar(select(RefreshTokenSession).where(RefreshTokenSession.token_hash == token_hash))

    def create(self, token: RefreshTokenSession) -> RefreshTokenSession:
        self.db.add(token)
        self.db.flush()
        return token

    def revoke_family(self, family_id: str, revoked_at: datetime) -> None:
        tokens = self.db.scalars(
            select(RefreshTokenSession).where(
                RefreshTokenSession.family_id == family_id,
                RefreshTokenSession.revoked_at.is_(None),
            )
        )
        for token in tokens:
            token.revoked_at = revoked_at

    def revoke_all_for_user(self, user_id: str, revoked_at: datetime) -> None:
        tokens = self.db.scalars(
            select(RefreshTokenSession).where(
                RefreshTokenSession.user_id == user_id,
                RefreshTokenSession.revoked_at.is_(None),
            )
        )
        for token in tokens:
            token.revoked_at = revoked_at

    def delete_expired(self, before: datetime) -> int:
        rows = self.db.scalars(
            select(RefreshTokenSession).where(RefreshTokenSession.expires_at < before)
        )
        count = 0
        for row in rows:
            self.db.delete(row)
            count += 1
        return count


class CycleRepository:
    def __init__(self, db: Session):
        self.db = db

    def active_for_user(self, user_id: str) -> CycleRecord | None:
        stmt = (
            select(CycleRecord)
            .where(CycleRecord.user_id == user_id, CycleRecord.is_active.is_(True))
            .order_by(desc(CycleRecord.period_start_date))
        )
        return self.db.scalar(stmt)

    def recent_logs(self, user_id: str, days: int = 30) -> list[DailyLog]:
        since = datetime.now(UTC).date() - timedelta(days=days)
        stmt = select(DailyLog).where(DailyLog.user_id == user_id, DailyLog.log_date >= since).order_by(DailyLog.log_date.asc())
        return list(self.db.scalars(stmt))

    def latest_lh_log(self, user_id: str) -> DailyLog | None:
        stmt = (
            select(DailyLog)
            .where(DailyLog.user_id == user_id, DailyLog.log_type == LogType.LH)
            .order_by(desc(DailyLog.log_date))
        )
        return self.db.scalar(stmt)

    def latest_mucus_log(self, user_id: str) -> DailyLog | None:
        stmt = (
            select(DailyLog)
            .where(DailyLog.user_id == user_id, DailyLog.log_type == LogType.MUCUS)
            .order_by(desc(DailyLog.log_date))
        )
        return self.db.scalar(stmt)


class PredictionRepository:
    def __init__(self, db: Session):
        self.db = db

    def save(self, snapshot: PredictionSnapshot) -> PredictionSnapshot:
        self.db.add(snapshot)
        self.db.flush()
        return snapshot

    def latest_for_user(self, user_id: str) -> PredictionSnapshot | None:
        stmt = select(PredictionSnapshot).where(PredictionSnapshot.user_id == user_id).order_by(desc(PredictionSnapshot.generated_at))
        return self.db.scalar(stmt)

    def recent_for_user(self, user_id: str, limit: int = 30) -> list[PredictionSnapshot]:
        stmt = (
            select(PredictionSnapshot)
            .where(PredictionSnapshot.user_id == user_id)
            .order_by(desc(PredictionSnapshot.generated_at))
            .limit(limit)
        )
        return list(self.db.scalars(stmt))


class DailyInsightRepository:
    def __init__(self, db: Session):
        self.db = db

    def by_user_and_date(self, user_id: str, insight_date) -> DailyInsight | None:
        stmt = select(DailyInsight).where(
            DailyInsight.user_id == user_id,
            DailyInsight.insight_date == insight_date,
        )
        return self.db.scalar(stmt)

    def latest_for_user(self, user_id: str) -> DailyInsight | None:
        stmt = select(DailyInsight).where(DailyInsight.user_id == user_id).order_by(desc(DailyInsight.insight_date))
        return self.db.scalar(stmt)

    def save(self, record: DailyInsight) -> DailyInsight:
        self.db.add(record)
        self.db.flush()
        return record


class NotificationPreferenceRepository:
    def __init__(self, db: Session):
        self.db = db

    def by_user_id(self, user_id: str) -> NotificationPreference | None:
        return self.db.scalar(select(NotificationPreference).where(NotificationPreference.user_id == user_id))

    def save(self, record: NotificationPreference) -> NotificationPreference:
        self.db.add(record)
        self.db.flush()
        return record


class NotificationDeviceRepository:
    def __init__(self, db: Session):
        self.db = db

    def by_user_and_device(self, user_id: str, device_id: str) -> NotificationDevice | None:
        stmt = select(NotificationDevice).where(NotificationDevice.user_id == user_id, NotificationDevice.device_id == device_id)
        return self.db.scalar(stmt)

    def by_token(self, fcm_token: str) -> NotificationDevice | None:
        return self.db.scalar(select(NotificationDevice).where(NotificationDevice.fcm_token == fcm_token))

    def active_for_user(self, user_id: str) -> list[NotificationDevice]:
        stmt = (
            select(NotificationDevice)
            .where(
                NotificationDevice.user_id == user_id,
                NotificationDevice.notifications_enabled.is_(True),
                NotificationDevice.invalidated_at.is_(None),
            )
            .order_by(desc(NotificationDevice.last_seen_at))
        )
        return list(self.db.scalars(stmt))

    def save(self, record: NotificationDevice) -> NotificationDevice:
        self.db.add(record)
        self.db.flush()
        return record


class NotificationHistoryRepository:
    def __init__(self, db: Session):
        self.db = db

    def save(self, record: NotificationHistory) -> NotificationHistory:
        self.db.add(record)
        self.db.flush()
        return record

    def list_for_user(self, user_id: str, *, unread_only: bool = False, limit: int = 50) -> list[NotificationHistory]:
        stmt = select(NotificationHistory).where(NotificationHistory.user_id == user_id)
        if unread_only:
            stmt = stmt.where(NotificationHistory.read_at.is_(None))
        stmt = stmt.order_by(desc(NotificationHistory.scheduled_for), desc(NotificationHistory.sent_at)).limit(limit)
        return list(self.db.scalars(stmt))

    def counts_since(self, user_id: str, *, category: str, since: datetime) -> int:
        stmt = select(NotificationHistory).where(
            NotificationHistory.user_id == user_id,
            NotificationHistory.category == category,
            NotificationHistory.sent_at >= since,
        )
        return len(list(self.db.scalars(stmt)))

    def by_dedupe_key(self, user_id: str, dedupe_key: str) -> NotificationHistory | None:
        stmt = select(NotificationHistory).where(
            NotificationHistory.user_id == user_id,
            NotificationHistory.dedupe_key == dedupe_key,
        )
        return self.db.scalar(stmt)

    def pending_for_user(
        self,
        user_id: str,
        *,
        now: datetime,
        notification_type: str | None = None,
    ) -> list[NotificationHistory]:
        stmt = select(NotificationHistory).where(
            NotificationHistory.user_id == user_id,
            NotificationHistory.status.in_(("pending", "batched")),
            NotificationHistory.scheduled_for <= now,
        )
        if notification_type:
            stmt = stmt.where(NotificationHistory.notification_type == notification_type)
        stmt = stmt.order_by(NotificationHistory.scheduled_for.asc(), NotificationHistory.sent_at.asc())
        return list(self.db.scalars(stmt))

    def pending_batch_candidates(
        self,
        user_id: str,
        *,
        now: datetime,
        since: datetime,
    ) -> list[NotificationHistory]:
        stmt = (
            select(NotificationHistory)
            .where(
                NotificationHistory.user_id == user_id,
                NotificationHistory.status == "pending",
                NotificationHistory.scheduled_for >= since,
                NotificationHistory.scheduled_for <= now,
            )
            .order_by(NotificationHistory.scheduled_for.asc(), NotificationHistory.sent_at.asc())
        )
        return list(self.db.scalars(stmt))

    def mark_all_read(self, user_id: str, *, now: datetime) -> int:
        items = self.list_for_user(user_id, unread_only=True, limit=500)
        for item in items:
            item.read_at = now
        self.db.flush()
        return len(items)

    def mark_read(self, user_id: str, notification_id: str, *, now: datetime) -> int:
        stmt = select(NotificationHistory).where(
            NotificationHistory.user_id == user_id,
            NotificationHistory.id == notification_id,
        )
        item = self.db.scalar(stmt)
        if item is None or item.read_at is not None:
            return 0
        item.read_at = now
        self.db.flush()
        return 1

    def delete_for_user(self, user_id: str, notification_id: str) -> int:
        result = self.db.execute(
            delete(NotificationHistory).where(
                NotificationHistory.user_id == user_id,
                NotificationHistory.id == notification_id,
            )
        )
        self.db.flush()
        return int(result.rowcount or 0)

    def delete_all_for_user(self, user_id: str) -> int:
        result = self.db.execute(
            delete(NotificationHistory).where(NotificationHistory.user_id == user_id)
        )
        self.db.flush()
        return int(result.rowcount or 0)


class SensorRepository:
    def __init__(self, db: Session):
        self.db = db

    def recent(self, user_id: str, metric: str | None = None, days: int = 30, source: str | None = None) -> list[SensorReading]:
        since = datetime.now(UTC) - timedelta(days=days)
        stmt = select(SensorReading).where(SensorReading.user_id == user_id, SensorReading.recorded_at >= since)
        if metric:
            stmt = stmt.where(SensorReading.metric == metric)
        if source:
            stmt = stmt.where(SensorReading.source == source)
        stmt = stmt.order_by(SensorReading.recorded_at.asc())
        return list(self.db.scalars(stmt))

    def recent_stress(self, user_id: str, days: int = 7) -> list[StressScore]:
        since = datetime.now(UTC) - timedelta(days=days)
        stmt = select(StressScore).where(StressScore.user_id == user_id, StressScore.recorded_at >= since).order_by(StressScore.recorded_at.asc())
        return list(self.db.scalars(stmt))

    def recent_wearable_metrics(
        self,
        user_id: str,
        *,
        metric_types: list[str] | None = None,
        days: int = 30,
        include_excluded: bool = True,
        data_source: str | None = None,
    ) -> list[WearableMetric]:
        since = datetime.now(UTC) - timedelta(days=days)
        stmt = select(WearableMetric).where(
            WearableMetric.user_id == user_id,
            WearableMetric.measured_at >= since,
        )
        if metric_types:
            stmt = stmt.where(WearableMetric.metric_type.in_(metric_types))
        if not include_excluded:
            stmt = stmt.where(
                WearableMetric.excluded_from_ovulation_prediction.is_(False)
            )
        if data_source:
            stmt = stmt.where(WearableMetric.data_source == data_source)
        stmt = stmt.order_by(WearableMetric.measured_at.asc())
        return list(self.db.scalars(stmt))


class GoogleHealthConnectionRepository:
    def __init__(self, db: Session):
        self.db = db

    def by_user(self, user_id: str) -> GoogleHealthConnection | None:
        stmt = select(GoogleHealthConnection).where(
            GoogleHealthConnection.user_id == user_id,
            GoogleHealthConnection.revoked_at.is_(None),
        )
        return self.db.scalar(stmt)

    def any_by_user(self, user_id: str) -> GoogleHealthConnection | None:
        stmt = select(GoogleHealthConnection).where(
            GoogleHealthConnection.user_id == user_id,
        )
        return self.db.scalar(stmt)

    def save(self, connection: GoogleHealthConnection) -> GoogleHealthConnection:
        self.db.add(connection)
        self.db.flush()
        return connection


class AuditRepository:
    def __init__(self, db: Session):
        self.db = db

    def log(self, actor_user_id: str | None, action: str, payload: dict) -> AuditEvent:
        event = AuditEvent(actor_user_id=actor_user_id, action=action, payload=payload)
        self.db.add(event)
        self.db.flush()
        return event

    def latest_by_action(self, action: str) -> AuditEvent | None:
        stmt = select(AuditEvent).where(AuditEvent.action == action).order_by(desc(AuditEvent.created_at))
        return self.db.scalar(stmt)
