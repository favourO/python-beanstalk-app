from datetime import UTC, datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from phora.db.session import get_session_factory
from phora.core.config import get_settings
from phora.repositories.core import PredictionRepository, UserRepository
from phora.schemas.notification import NotificationTriggerRequest
from phora.services.daily_insights import DailyInsightService
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
        created = service.trigger_notification(
            user_id,
            payload=NotificationTriggerRequest(
                notification_type="lh_test_reminder",
                title="Consider taking an LH test",
                body="You're in your fertile window. LH tests can confirm ovulation timing.",
                category="reminders",
                priority="low",
                action_url="/cycle/lh",
                action_labels=["Log LH result", "Remind me tomorrow", "Not using LH tests"],
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
