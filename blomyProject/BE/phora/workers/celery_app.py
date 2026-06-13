from celery import Celery
from celery.schedules import crontab

from phora.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "phora",
    broker=settings.broker_url,
    backend=settings.result_backend,
    include=["phora.workers.jobs"],
)

celery_app.conf.task_routes = {
    "phora.workers.jobs.run_daily_prediction": {"queue": "default"},
    "phora.workers.jobs.refresh_all_daily_insights": {"queue": "default"},
    "phora.workers.jobs.refresh_user_daily_insights": {"queue": "default"},
    "phora.workers.jobs.send_all_morning_cycle_notifications": {"queue": "default"},
    "phora.workers.jobs.send_morning_cycle_notifications": {"queue": "default"},
    "phora.workers.jobs.process_temperature_night": {"queue": "critical"},
    "phora.workers.jobs.process_lh_result": {"queue": "critical"},
    "phora.workers.jobs.close_cycle": {"queue": "default"},
    "phora.workers.jobs.retroactive_recalc": {"queue": "default"},
    "phora.workers.jobs.retrain_population_model": {"queue": "low"},
    "phora.workers.jobs.recalibrate_age_priors": {"queue": "low"},
}

celery_app.conf.beat_schedule = {
    "refresh-daily-insights-at-midnight": {
        "task": "phora.workers.jobs.refresh_all_daily_insights",
        "schedule": crontab(hour=0, minute=0),
        "options": {"queue": "default"},
    },
    "send-cycle-reminders-at-7am": {
        "task": "phora.workers.jobs.send_all_morning_cycle_notifications",
        "schedule": crontab(hour=7, minute=0),
        "options": {"queue": "default"},
    },
}
