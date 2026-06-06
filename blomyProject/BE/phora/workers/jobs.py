from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from phora.db.session import get_session_factory
from phora.core.config import get_settings
from phora.models.notification import NotificationPreference
from phora.repositories.core import PredictionRepository, UserRepository
from phora.schemas.notification import NotificationTriggerRequest
from phora.services.daily_insights import DailyInsightService
from phora.services.notification_i18n import translate
from phora.services.notification_service import NotificationService
from phora.workers.celery_app import celery_app


@celery_app.task
def build_cycle_prior(user_id: str) -> dict:
    return {"status": "queued", "job": "build_cycle_prior", "user_id": user_id}


@celery_app.task
def process_temperature_night(user_id: str, reading_id: str) -> dict:
    return {"status": "queued", "job": "process_temperature_night", "user_id": user_id, "reading_id": reading_id}


@celery_app.task
def process_lh_result(user_id: str, log_id: str) -> dict:
    return {"status": "queued", "job": "process_lh_result", "user_id": user_id, "log_id": log_id}


@celery_app.task
def run_daily_prediction(user_id: str) -> dict:
    return {"status": "queued", "job": "run_daily_prediction", "user_id": user_id}


@celery_app.task
def refresh_user_daily_insights(user_id: str) -> dict:
    with get_session_factory()() as db:
        profile = UserRepository(db).ensure_profile(user_id)
        snapshot = PredictionRepository(db).latest_for_user(user_id)
        phase = snapshot.current_phase if snapshot else None
        today = datetime.now(UTC).date()
        insight = DailyInsightService(db, get_settings()).get_or_generate(
            user_id=user_id,
            insight_date=today,
            phase=phase,
            force=True,
        )
        return {
            "status": "ok",
            "job": "refresh_user_daily_insights",
            "user_id": user_id,
            "insight_date": insight.insight_date.isoformat(),
            "source": insight.source,
            "timezone": profile.timezone,
        }


@celery_app.task
def refresh_all_daily_insights() -> dict:
    queued = 0
    with get_session_factory()() as db:
        for user_id in UserRepository(db).active_user_ids():
            profile = UserRepository(db).ensure_profile(user_id)
            if not _is_local_hour(profile.timezone, 0):
                continue
            refresh_user_daily_insights.delay(user_id)
            queued += 1
    return {"status": "queued", "job": "refresh_all_daily_insights", "queued": queued}


@celery_app.task
def confirm_ovulation(user_id: str, cycle_id: str) -> dict:
    return {"status": "queued", "job": "confirm_ovulation", "user_id": user_id, "cycle_id": cycle_id}


@celery_app.task
def close_cycle(user_id: str, cycle_id: str) -> dict:
    return {"status": "queued", "job": "close_cycle", "user_id": user_id, "cycle_id": cycle_id}


@celery_app.task
def retroactive_recalc(user_id: str, cycle_id: str) -> dict:
    return {"status": "queued", "job": "retroactive_recalc", "user_id": user_id, "cycle_id": cycle_id}


@celery_app.task
def detect_anovulatory(user_id: str, cycle_id: str) -> dict:
    return {"status": "queued", "job": "detect_anovulatory", "user_id": user_id, "cycle_id": cycle_id}


@celery_app.task
def send_push_notification(user_id: str, notification_type: str) -> dict:
    with get_session_factory()() as db:
        result = NotificationService(db).dispatch_pending(
            user_id=user_id,
            notification_type=notification_type,
            now=datetime.now(UTC),
        )
        return {
            "status": "ok",
            "job": "send_push_notification",
            "user_id": user_id,
            "type": notification_type,
            "dispatched": result.dispatched,
            "batched": result.batched,
        }


@celery_app.task
def morning_lh_reminder(user_id: str) -> dict:
    with get_session_factory()() as db:
        service = NotificationService(db)
        locale = service._user_locale(user_id)
        created = service.trigger_notification(
            user_id,
            payload=NotificationTriggerRequest(
                notification_type="lh_test_reminder",
                title=translate(locale, "morning_lh_reminder_title"),
                body=translate(locale, "morning_lh_reminder_body"),
                category="reminders",
                priority="low",
                action_url="/cycle/lh",
                action_labels=[
                    translate(locale, "log_lh_test"),
                    translate(locale, "remind_me_tomorrow"),
                    translate(locale, "morning_lh_reminder_skip"),
                ],
            ),
        )
        return {"status": "ok", "job": "morning_lh_reminder", "user_id": user_id, "created": created.created}


@celery_app.task
def nightly_sensor_check(user_id: str) -> dict:
    with get_session_factory()() as db:
        result = NotificationService(db).evaluate_due_notifications(user_id, now=datetime.now(UTC))
        return {
            "status": "ok",
            "job": "nightly_sensor_check",
            "user_id": user_id,
            "created": result.created,
            "dispatched": result.dispatched,
        }


@celery_app.task
def send_morning_cycle_notifications(user_id: str) -> dict:
    with get_session_factory()() as db:
        result = NotificationService(db).evaluate_morning_cycle_notifications(user_id, now=datetime.now(UTC))
        return {
            "status": "ok",
            "job": "send_morning_cycle_notifications",
            "user_id": user_id,
            "created": result.created,
            "dispatched": result.dispatched,
        }


@celery_app.task
def send_all_morning_cycle_notifications() -> dict:
    queued = 0
    with get_session_factory()() as db:
        for user_id in UserRepository(db).active_user_ids():
            profile = UserRepository(db).ensure_profile(user_id)
            if not _is_local_hour(profile.timezone, 7):
                continue
            send_morning_cycle_notifications.delay(user_id)
            queued += 1
    return {"status": "queued", "job": "send_all_morning_cycle_notifications", "queued": queued}


def _is_local_hour(timezone_name: str | None, hour: int) -> bool:
    try:
        tz = ZoneInfo(timezone_name or "UTC")
    except ZoneInfoNotFoundError:
        tz = ZoneInfo("UTC")
    local_now = datetime.now(UTC).astimezone(tz)
    return local_now.hour == hour


@celery_app.task
def send_wearable_ovulation_reminder(user_id: str) -> dict:
    with get_session_factory()() as db:
        pref = db.query(NotificationPreference).filter(NotificationPreference.user_id == user_id).first()
        if not pref or not getattr(pref, "wearable_ovulation_reminder", True) or not pref.all_notifications:
            return {"status": "skipped", "reason": "preference_off", "user_id": user_id}

        snapshot = PredictionRepository(db).latest_for_user(user_id)
        if not snapshot:
            return {"status": "skipped", "reason": "no_snapshot", "user_id": user_id}

        phase = snapshot.current_phase
        if phase not in {"menstrual", "ovulatory", "late_follicular"}:
            return {"status": "skipped", "reason": f"phase={phase}", "user_id": user_id}

        from phora.models.timeseries import WearableMetric
        from sqlalchemy import select as sa_select
        cutoff = datetime.now(UTC) - timedelta(days=3)
        has_recent = db.scalar(
            sa_select(WearableMetric.id).where(
                WearableMetric.user_id == user_id,
                WearableMetric.measured_at >= cutoff,
            ).limit(1)
        )
        if has_recent:
            return {"status": "skipped", "reason": "wearable_active", "user_id": user_id}

        service = NotificationService(db)
        locale = service._user_locale(user_id)
        phase_label = "period" if phase == "menstrual" else "ovulation window"
        created = service.trigger_notification(
            user_id,
            payload=NotificationTriggerRequest(
                notification_type="wearable_ovulation_reminder",
                title=translate(locale, "wearable_reminder_title") or f"Track your {phase_label}",
                body=translate(locale, "wearable_reminder_body") or f"Connect your Vyla or Apple Watch during your {phase_label} for more accurate insights.",
                category="reminders",
                priority="low",
                action_url="/connected-devices",
            ),
        )
        return {"status": "ok", "job": "send_wearable_ovulation_reminder", "user_id": user_id, "created": created.created}


@celery_app.task
def send_all_wearable_ovulation_reminders() -> dict:
    queued = 0
    with get_session_factory()() as db:
        for user_id in UserRepository(db).active_user_ids():
            profile = UserRepository(db).ensure_profile(user_id)
            if not _is_local_hour(profile.timezone, 8):
                continue
            send_wearable_ovulation_reminder.delay(user_id)
            queued += 1
    return {"status": "queued", "job": "send_all_wearable_ovulation_reminders", "queued": queued}


@celery_app.task
def retrain_personal_lstm(user_id: str) -> dict:
    return {"status": "queued", "job": "retrain_personal_lstm", "user_id": user_id}


@celery_app.task
def retrain_population_model() -> dict:
    return {"status": "queued", "job": "retrain_population_model"}


@celery_app.task
def compute_cycle_statistics() -> dict:
    return {"status": "queued", "job": "compute_cycle_statistics"}


@celery_app.task
def gdpr_data_purge(user_id: str) -> dict:
    return {"status": "queued", "job": "gdpr_data_purge", "user_id": user_id}


@celery_app.task
def baseline_recalibration(user_id: str) -> dict:
    return {"status": "queued", "job": "baseline_recalibration", "user_id": user_id}


@celery_app.task
def update_age_bands() -> dict:
    return {"status": "queued", "job": "update_age_bands"}


@celery_app.task
def check_perimenopause_activation(user_id: str) -> dict:
    return {"status": "queued", "job": "check_perimenopause_activation", "user_id": user_id}


@celery_app.task
def perimenopause_mode_push(user_id: str) -> dict:
    return {"status": "queued", "job": "perimenopause_mode_push", "user_id": user_id}


@celery_app.task
def recalibrate_age_priors() -> dict:
    return {"status": "queued", "job": "recalibrate_age_priors"}
