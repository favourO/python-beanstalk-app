from datetime import UTC, date, datetime

from phora.api.app import create_app
from phora.db.session import get_session_factory, reset_db_state
from phora.models import CycleRecord, PredictionSnapshot, User, UserProfile
from phora.models.enums import Goal, WearableType
from phora.schemas.notification import (
    NotificationDeviceUpsertRequest,
    NotificationSettingsUpdateRequest,
    NotificationTriggerRequest,
)
from phora.services.notification_service import NotificationService
from phora.services.push_service import PushSendResult


def _boot_app(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'notifications.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "notifications-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    reset_db_state()
    create_app()


def _seed_user(db, *, timezone: str = "UTC", wearable_type: WearableType = WearableType.NONE, goal: Goal | None = Goal.TRACK) -> str:
    user = User(email="notify@example.com", password_hash="hash")
    db.add(user)
    db.flush()
    db.add(
        UserProfile(
            user_id=user.id,
            timezone=timezone,
            wearable_type=wearable_type,
            goal=goal,
        )
    )
    db.commit()
    return user.id


def test_notification_defaults_reflect_user_context(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)
    with get_session_factory()() as db:
        user_id = _seed_user(db, wearable_type=WearableType.MANUAL_BBT)
        prefs = NotificationService(db).get_preferences(user_id)

    assert prefs.temperature_logging_reminder is True
    assert prefs.bangle_sync_reminder is False
    assert prefs.sleep_alert is False
    assert prefs.fertile_window_open is True


def test_grouped_settings_match_notification_screen_contract(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)
    with get_session_factory()() as db:
        user_id = _seed_user(db, wearable_type=WearableType.NONE)
        settings = NotificationService(db).get_settings(user_id)

    assert settings.predictions.title == "Predictions & Forecasts"
    assert settings.health_insights.title == "Health Insights"
    assert settings.reminders.title == "Reminders"
    assert settings.critical_alerts.title == "Critical Alerts"
    assert settings.quiet_hours.start_time == "22:00"
    assert settings.quiet_hours.end_time == "08:00"
    assert all(item.can_disable is False for item in settings.critical_alerts.items)


def test_update_grouped_settings_updates_quiet_hours_and_toggles(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)
    with get_session_factory()() as db:
        user_id = _seed_user(db)
        service = NotificationService(db)
        settings = service.update_settings(
            user_id,
            NotificationSettingsUpdateRequest(
                all_notifications=True,
                stress_alert=False,
                daily_symptom_reminder=True,
                quiet_hours={
                    "enabled": True,
                    "start_time": "21:30",
                    "end_time": "07:30",
                    "allow_critical_alerts": False,
                },
            ),
        )

    assert any(item.key == "stress_alert" and item.enabled is False for item in settings.health_insights.items)
    assert any(item.key == "daily_symptom_reminder" and item.enabled is True for item in settings.reminders.items)
    assert settings.quiet_hours.start_time == "21:30"
    assert settings.quiet_hours.end_time == "07:30"
    assert settings.quiet_hours.allow_critical_alerts is False


def test_trigger_notification_redacts_lock_screen_and_defers_in_quiet_hours(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)
    with get_session_factory()() as db:
        user_id = _seed_user(db, timezone="UTC")
        service = NotificationService(db)
        result = service.trigger_notification(
            user_id,
            NotificationTriggerRequest(
                notification_type="period_approaching",
                title="Your period is coming soon",
                body="Expected to start in 3 days (April 8). Track symptoms to improve predictions.",
                category="predictions",
                priority="high",
                send_at=datetime(2026, 4, 6, 23, 30, tzinfo=UTC),
            ),
        )
        items, unread_count = service.list_notifications(user_id)

    assert result.created == 1
    assert result.dispatched == 0
    assert unread_count == 1
    assert items[0].lock_screen_title == "Your period is coming soon"
    assert items[0].lock_screen_body == ""
    assert items[0].scheduled_for.replace(tzinfo=UTC) == datetime(2026, 4, 7, 8, 0, tzinfo=UTC)


def test_dispatch_batches_multiple_due_notifications(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)
    with get_session_factory()() as db:
        user_id = _seed_user(db)
        service = NotificationService(db)
        now = datetime(2026, 4, 6, 12, 0, tzinfo=UTC)
        service._create_notification(
            user_id=user_id,
            notification_type="stress_alert",
            title="High stress detected",
            body="Your stress levels have been elevated.",
            category="health_insights",
            priority="medium",
            send_at=now,
            force_delivery=True,
        )
        service._create_notification(
            user_id=user_id,
            notification_type="sleep_alert",
            title="Poor sleep detected",
            body="You've averaged 5.2 hours of sleep.",
            category="health_insights",
            priority="medium",
            send_at=now,
            force_delivery=True,
        )
        result = service.dispatch_pending(user_id=user_id, now=now)
        items, _ = service.list_notifications(user_id)

    assert result.batched >= 2
    assert any(item.notification_type == "batch" and item.status == "sent" for item in items)
    assert sum(1 for item in items if item.status == "batched") >= 2


def test_evaluate_due_prediction_notifications_creates_period_and_ovulation_alerts(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)
    with get_session_factory()() as db:
        user_id = _seed_user(db)
        cycle = CycleRecord(
            user_id=user_id,
            period_start_date=date(2026, 3, 15),
            is_active=True,
        )
        db.add(cycle)
        db.flush()
        db.add(
            PredictionSnapshot(
                prediction_id="pred-1",
                user_id=user_id,
                cycle_id=cycle.id,
                generated_at=datetime(2026, 4, 6, 7, 0, tzinfo=UTC),
                current_phase="ovulatory",
                ovulation_estimate={"cycle_day": 23, "date": "2026-04-07"},
                confidence=0.87,
                confidence_explanation="Strong ensemble agreement.",
                warning_flags=[],
                models_used=["ensemble"],
                model_audits=[],
                audit={"ovulation_estimate_source": "ensemble"},
                fertile_window={"start": "2026-04-10", "end": "2026-04-12", "is_open": True, "method": "ensemble"},
                next_period_estimate={"date": "2026-04-07", "range_days": 2},
                phase_distribution={},
                contributing_signals=[],
                model_version="v1",
                ml_payload={},
                source="test",
            )
        )
        db.commit()

        result = NotificationService(db).evaluate_due_notifications(user_id, now=datetime(2026, 4, 6, 9, 0, tzinfo=UTC))
        items, _ = NotificationService(db).list_notifications(user_id)

    types = {item.notification_type for item in items}
    assert result.created == 2
    assert "period_approaching" in types
    assert len({"fertile_window_open", "ovulation_confirmed"} & types) == 1


def test_register_device_and_dispatch_uses_fcm_tokens(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    class StubPushService:
        def __init__(self):
            self.calls = []

        def send_notification(self, *, tokens, title, body, data=None):
            self.calls.append({"tokens": tokens, "title": title, "body": body, "data": data})
            return PushSendResult(delivered_tokens=tokens, invalid_tokens=[], failed_tokens=[])

    with get_session_factory()() as db:
        user_id = _seed_user(db)
        push = StubPushService()
        service = NotificationService(db, push_service=push)
        device = service.register_device(
            user_id,
            NotificationDeviceUpsertRequest(
                platform="android",
                device_id="pixel-1",
                fcm_token="fcm-token-1",
                app_version="1.0.0",
            ),
        )
        result = service.trigger_notification(
            user_id,
            NotificationTriggerRequest(
                notification_type="stress_alert",
                title="High stress detected",
                body="Your stress levels have been elevated.",
                category="health_insights",
                priority="medium",
                force_delivery=True,
            ),
        )

    assert device.fcm_token == "fcm-token-1"
    assert result.dispatched == 1
    assert push.calls[0]["tokens"] == ["fcm-token-1"]
    assert push.calls[0]["data"]["notification_type"] == "stress_alert"


def test_morning_cycle_notifications_include_daily_recommendations(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)
    with get_session_factory()() as db:
        user_id = _seed_user(db)
        profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).one()
        profile.height_cm = 165
        profile.weight_kg = 65
        profile.bmi = 23.88
        cycle = CycleRecord(
            user_id=user_id,
            period_start_date=date(2026, 4, 1),
            menses_length=5,
            is_active=True,
        )
        db.add(cycle)
        db.flush()
        db.add(
            PredictionSnapshot(
                prediction_id="pred-morning",
                user_id=user_id,
                cycle_id=cycle.id,
                generated_at=datetime(2026, 4, 1, 6, 0, tzinfo=UTC),
                current_phase="menstrual",
                ovulation_estimate={"date": "2026-04-14"},
                confidence=0.7,
                confidence_explanation="test",
                warning_flags=[],
                models_used=["test"],
                model_audits=[],
                audit={},
                fertile_window={"start": "2026-04-09", "end": "2026-04-15"},
                next_period_estimate={"date": "2026-04-02"},
                phase_distribution={},
                contributing_signals=[],
                model_version="v1",
                ml_payload={},
                source="test",
            )
        )
        db.commit()

        result = NotificationService(db).evaluate_morning_cycle_notifications(user_id, now=datetime(2026, 4, 1, 7, 0, tzinfo=UTC))
        items, _ = NotificationService(db).list_notifications(user_id)

    types = {item.notification_type for item in items}
    assert result.created == 2
    assert "period_approaching" in types
    assert "period_care_reminder" in types
    period_care_items = [item for item in items if item.notification_type == "period_care_reminder"]
    assert period_care_items
    assert "until April 5" in period_care_items[0].body
    assert "Log bleeding, pain, mood, and symptoms" in period_care_items[0].body
    assert period_care_items[0].payload["current_period_end_date"] == "2026-04-05"
    assert any(item.payload.get("nutrition_recommendation") for item in items)


def test_morning_cycle_notifications_send_daily_while_period_is_active(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)
    with get_session_factory()() as db:
        user_id = _seed_user(db)
        cycle = CycleRecord(
            user_id=user_id,
            period_start_date=date(2026, 4, 1),
            menses_length=5,
            is_active=True,
        )
        db.add(cycle)
        db.flush()
        db.add(
            PredictionSnapshot(
                prediction_id="pred-period-daily",
                user_id=user_id,
                cycle_id=cycle.id,
                generated_at=datetime(2026, 4, 1, 6, 0, tzinfo=UTC),
                current_phase="menstrual",
                ovulation_estimate={"date": "2026-04-14"},
                confidence=0.7,
                confidence_explanation="test",
                warning_flags=[],
                models_used=["test"],
                model_audits=[],
                audit={},
                fertile_window={"start": "2026-04-09", "end": "2026-04-15"},
                next_period_estimate={"date": "2026-05-01"},
                phase_distribution={},
                contributing_signals=[],
                model_version="v1",
                ml_payload={},
                source="test",
            )
        )
        db.commit()

        service = NotificationService(db)
        first = service.evaluate_morning_cycle_notifications(user_id, now=datetime(2026, 4, 1, 7, 0, tzinfo=UTC))
        second = service.evaluate_morning_cycle_notifications(user_id, now=datetime(2026, 4, 2, 7, 0, tzinfo=UTC))
        items, _ = service.list_notifications(user_id)

    period_care_items = [item for item in items if item.notification_type == "period_care_reminder"]
    assert first.created == 1
    assert second.created == 1
    assert len(period_care_items) == 2
    assert {item.payload["cycle_day"] for item in period_care_items} == {1, 2}


def test_invalid_fcm_tokens_are_disabled_after_send(tmp_path, monkeypatch):
    _boot_app(tmp_path, monkeypatch)

    class StubPushService:
        def send_notification(self, *, tokens, title, body, data=None):
            return PushSendResult(delivered_tokens=[], invalid_tokens=tokens, failed_tokens=[])

    with get_session_factory()() as db:
        user_id = _seed_user(db)
        service = NotificationService(db, push_service=StubPushService())
        service.register_device(
            user_id,
            NotificationDeviceUpsertRequest(
                platform="ios",
                device_id="iphone-1",
                fcm_token="stale-token",
            ),
        )
        result = service.trigger_notification(
            user_id,
            NotificationTriggerRequest(
                notification_type="stress_alert",
                title="High stress detected",
                body="Your stress levels have been elevated.",
                category="health_insights",
                priority="medium",
                force_delivery=True,
            ),
        )
        devices = service.list_devices(user_id)

    assert result.dispatched == 0
    assert devices == []
