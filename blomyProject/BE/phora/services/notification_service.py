from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from phora.core.config import Settings, get_settings
from phora.models import NotificationDevice, NotificationHistory, NotificationPreference, UserProfile
from phora.models.enums import Goal, WearableType
from phora.repositories.core import (
    AuditRepository,
    CycleRepository,
    NotificationDeviceRepository,
    NotificationHistoryRepository,
    NotificationPreferenceRepository,
    PredictionRepository,
    UserRepository,
)
from phora.schemas.notification import (
    NotificationDispatchResponse,
    NotificationDeviceResponse,
    NotificationDeviceUpsertRequest,
    NotificationPreferencesResponse,
    NotificationPreferencesUpdateRequest,
    NotificationSettingsResponse,
    NotificationSettingsSectionResponse,
    NotificationSettingItemResponse,
    NotificationSettingsUpdateRequest,
    QuietHoursSettingsResponse,
    NotificationResponse,
    NotificationTriggerRequest,
)
from phora.services.daily_insights import DailyInsightService
from phora.services.notification_i18n import format_month_day, normalize_locale, translate
from phora.services.push_service import FcmPushService


@dataclass(frozen=True)
class NotificationRule:
    category: str
    priority: str
    preference_field: str | None
    private_title: str
    critical: bool = False
    user_configurable: bool = True


NOTIFICATION_RULES: dict[str, NotificationRule] = {
    "period_approaching": NotificationRule("predictions", "high", "period_approaching", "Your period is coming soon"),
    "period_care_reminder": NotificationRule("predictions", "medium", "period_approaching", "Period care reminder"),
    "period_detected": NotificationRule("predictions", "high", "period_detected", "Period detected"),
    "fertile_window_open": NotificationRule("predictions", "high", "fertile_window_open", "Fertile window update"),
    "ovulation_confirmed": NotificationRule("predictions", "high", "ovulation_confirmed", "Ovulation update"),
    "cycle_delay_alert": NotificationRule("predictions", "high", "cycle_delay_alert", "Cycle update"),
    "cycle_pattern_change": NotificationRule("health_insights", "medium", "cycle_pattern_change", "Cycle insight"),
    "unusual_symptom": NotificationRule("health_insights", "medium", "unusual_symptom", "Health insight"),
    "stress_alert": NotificationRule("health_insights", "medium", "stress_alert", "Wellness insight"),
    "sleep_alert": NotificationRule("health_insights", "medium", "sleep_alert", "Sleep insight"),
    "daily_symptom_reminder": NotificationRule("reminders", "low", "daily_symptom_reminder", "Vyla reminder"),
    "bangle_sync_reminder": NotificationRule("reminders", "low", "bangle_sync_reminder", "Vyla Bangle"),
    "temperature_logging_reminder": NotificationRule("reminders", "low", "temperature_logging_reminder", "Temperature reminder"),
    "lh_test_reminder": NotificationRule("reminders", "low", "lh_test_reminder", "Fertility reminder"),
    "weekly_summary": NotificationRule("app_engagement", "low", "weekly_summary", "Vyla weekly summary"),
    "feature_tips": NotificationRule("app_engagement", "low", "feature_tips", "Vyla tip"),
    "prediction_accuracy_milestone": NotificationRule("app_engagement", "low", None, "Vyla update", user_configurable=False),
    "heavy_bleeding": NotificationRule("critical_alerts", "critical", None, "Health alert", critical=True, user_configurable=False),
    "potential_pregnancy": NotificationRule("critical_alerts", "critical", None, "Cycle alert", critical=True, user_configurable=False),
    "bangle_battery_critical": NotificationRule("critical_alerts", "critical", None, "Vyla Bangle", critical=True, user_configurable=False),
}

FREQUENCY_LIMITS = {
    "predictions": {"day": 2, "week": 7, "month": 15},
    "health_insights": {"day": 1, "week": 3, "month": 10},
    "reminders": {"day": 2, "week": 10, "month": 30},
    "app_engagement": {"day": 1, "week": 2, "month": 5},
}


class NotificationService:
    def __init__(self, db: Session, settings: Settings | None = None, push_service: FcmPushService | None = None):
        self.db = db
        self.settings = settings or get_settings()
        self.users = UserRepository(db)
        self.cycles = CycleRepository(db)
        self.predictions = PredictionRepository(db)
        self.preferences = NotificationPreferenceRepository(db)
        self.devices = NotificationDeviceRepository(db)
        self.history = NotificationHistoryRepository(db)
        self.audit = AuditRepository(db)
        self.push_service = push_service or FcmPushService(self.settings)

    def get_preferences(self, user_id: str) -> NotificationPreferencesResponse:
        record = self._ensure_preferences(user_id)
        return self._preferences_response(record)

    def update_preferences(
        self,
        user_id: str,
        payload: NotificationPreferencesUpdateRequest,
    ) -> NotificationPreferencesResponse:
        record = self._ensure_preferences(user_id)
        updates = payload.model_dump(exclude_none=True)
        for field, value in updates.items():
            setattr(record, field, value)
        self.audit.log(user_id, "notification.preferences.updated", updates)
        self.db.commit()
        self.db.refresh(record)
        return self._preferences_response(record)

    def get_settings(self, user_id: str) -> NotificationSettingsResponse:
        record = self._ensure_preferences(user_id)
        return self._settings_response(user_id, record)

    def update_settings(self, user_id: str, payload: NotificationSettingsUpdateRequest) -> NotificationSettingsResponse:
        record = self._ensure_preferences(user_id)
        updates = payload.model_dump(exclude_none=True)
        quiet_hours = updates.pop("quiet_hours", None)
        for field, value in updates.items():
            setattr(record, field, value)
        if quiet_hours:
            if quiet_hours.get("enabled") is not None:
                record.quiet_hours_enabled = quiet_hours["enabled"]
            if quiet_hours.get("start_time") is not None:
                record.quiet_hours_start = quiet_hours["start_time"]
            if quiet_hours.get("end_time") is not None:
                record.quiet_hours_end = quiet_hours["end_time"]
            if quiet_hours.get("allow_critical_alerts") is not None:
                record.allow_critical_in_quiet_hours = quiet_hours["allow_critical_alerts"]
        self.audit.log(user_id, "notification.settings.updated", payload.model_dump(mode="json", exclude_none=True))
        self.db.commit()
        self.db.refresh(record)
        return self._settings_response(user_id, record)

    def list_notifications(self, user_id: str, *, unread_only: bool = False, limit: int = 50) -> tuple[list[NotificationResponse], int]:
        items = self.history.list_for_user(user_id, unread_only=unread_only, limit=limit)
        unread_count = len(self.history.list_for_user(user_id, unread_only=True, limit=500))
        return [self._to_response(item) for item in items], unread_count

    def list_devices(self, user_id: str) -> list[NotificationDeviceResponse]:
        return [self._device_response(item) for item in self.devices.active_for_user(user_id)]

    def register_device(self, user_id: str, payload: NotificationDeviceUpsertRequest) -> NotificationDeviceResponse:
        now = datetime.now(UTC)
        record = self.devices.by_user_and_device(user_id, payload.device_id)
        if not record:
            record = self.devices.by_token(payload.fcm_token)

        if record:
            record.user_id = user_id
            record.platform = payload.platform
            record.device_id = payload.device_id
            record.fcm_token = payload.fcm_token
            record.app_version = payload.app_version
            record.device_name = payload.device_name
            record.locale = payload.locale
            record.notifications_enabled = payload.notifications_enabled
            record.invalidated_at = None
            record.last_seen_at = now
        else:
            record = NotificationDevice(
                user_id=user_id,
                platform=payload.platform,
                device_id=payload.device_id,
                fcm_token=payload.fcm_token,
                app_version=payload.app_version,
                device_name=payload.device_name,
                locale=payload.locale,
                notifications_enabled=payload.notifications_enabled,
                last_seen_at=now,
            )
            self.devices.save(record)

        self.audit.log(user_id, "notification.device.registered", payload.model_dump(mode="json"))
        self.db.commit()
        self.db.refresh(record)
        return self._device_response(record)

    def unregister_device(self, user_id: str, device_id: str) -> int:
        record = self.devices.by_user_and_device(user_id, device_id)
        if not record:
            return 0
        record.notifications_enabled = False
        record.invalidated_at = datetime.now(UTC)
        self.audit.log(user_id, "notification.device.unregistered", {"device_id": device_id})
        self.db.commit()
        return 1

    def mark_all_read(self, user_id: str) -> int:
        updated = self.history.mark_all_read(user_id, now=datetime.now(UTC))
        self.audit.log(user_id, "notification.read_all", {"updated": updated})
        self.db.commit()
        return updated

    def mark_read(self, user_id: str, notification_id: str) -> int:
        updated = self.history.mark_read(
            user_id,
            notification_id,
            now=datetime.now(UTC),
        )
        self.audit.log(
            user_id,
            "notification.read",
            {"updated": updated, "notification_id": notification_id},
        )
        self.db.commit()
        return updated

    def trigger_notification(self, user_id: str, payload: NotificationTriggerRequest) -> NotificationDispatchResponse:
        record = self._create_notification(
            user_id=user_id,
            notification_type=payload.notification_type,
            title=payload.title,
            body=payload.body,
            category=payload.category,
            priority=payload.priority,
            action_url=payload.action_url,
            action_labels=payload.action_labels,
            payload_data=payload.payload,
            send_at=payload.send_at,
            lock_screen_title=payload.lock_screen_title,
            lock_screen_body=payload.lock_screen_body,
            force_delivery=payload.force_delivery,
        )
        dispatched = self.dispatch_pending(user_id=user_id)
        return NotificationDispatchResponse(
            created=1 if record else 0,
            dispatched=dispatched.dispatched,
            deferred=dispatched.deferred,
            batched=dispatched.batched,
            skipped=dispatched.skipped,
            notifications=dispatched.notifications,
        )

    def evaluate_due_notifications(self, user_id: str, *, now: datetime | None = None) -> NotificationDispatchResponse:
        moment = now or datetime.now(UTC)
        created: list[NotificationHistory] = []
        snapshot = self.predictions.latest_for_user(user_id)
        cycle = self.cycles.active_for_user(user_id)
        if not snapshot or not cycle:
            return NotificationDispatchResponse(skipped=1)

        today = moment.date()
        next_period = snapshot.next_period_estimate.get("date")
        fertile_start = snapshot.fertile_window.get("start")
        ovulation_date = snapshot.ovulation_estimate.get("date")

        if next_period:
            next_period_date = date.fromisoformat(next_period)
            if next_period_date - today == timedelta(days=3):
                locale = self._user_locale(user_id)
                created_item = self._create_notification(
                    user_id=user_id,
                    notification_type="period_approaching",
                    title=translate(locale, "period_approaching_title"),
                    body=translate(
                        locale,
                        "period_approaching_body",
                        date=self._format_month_day(next_period_date, locale),
                    ),
                    action_url="/cycle/symptoms",
                    action_labels=[
                        translate(locale, "log_symptoms"),
                        translate(locale, "got_it"),
                    ],
                    payload_data={"predicted_period_date": next_period},
                    send_at=moment,
                    dedupe_key=f"period_approaching:{next_period}",
                )
                if created_item:
                    created.append(created_item)

            days_late = (today - next_period_date).days
            if days_late in {3, 7, 14}:
                locale = self._user_locale(user_id)
                created_item = self._create_notification(
                    user_id=user_id,
                    notification_type="cycle_delay_alert",
                    title=translate(locale, "cycle_delay_title"),
                    body=translate(
                        locale,
                        "cycle_delay_body",
                        expected_date=self._format_month_day(next_period_date, locale),
                        today_date=self._format_month_day(today, locale),
                    ),
                    action_url="/predictions/next-period",
                    action_labels=[
                        translate(locale, "pregnancy_test"),
                        translate(locale, "log_late_period"),
                        translate(locale, "remind_me_in_3_days"),
                    ],
                    payload_data={"predicted_period_date": next_period, "days_late": days_late},
                    send_at=moment,
                    dedupe_key=f"cycle_delay_alert:{next_period}:{days_late}",
                )
                if created_item:
                    created.append(created_item)

        if fertile_start:
            fertile_start_date = date.fromisoformat(fertile_start)
            if fertile_start_date - today == timedelta(days=1):
                locale = self._user_locale(user_id)
                fertile_end = snapshot.fertile_window.get("end")
                body = self._format_month_day(fertile_start_date, locale)
                if fertile_end:
                    body = (
                        f"{self._format_month_day(fertile_start_date, locale)} - "
                        f"{self._format_month_day(date.fromisoformat(fertile_end), locale)}"
                    )
                created_item = self._create_notification(
                    user_id=user_id,
                    notification_type="fertile_window_open",
                    title=translate(locale, "fertile_window_title"),
                    body=translate(locale, "fertile_window_body", window=body),
                    action_url="/cycle/intimacy",
                    action_labels=[
                        translate(locale, "track_intimacy"),
                        translate(locale, "remind_me_tomorrow"),
                        translate(locale, "got_it"),
                    ],
                    payload_data={"fertile_window": snapshot.fertile_window},
                    send_at=moment,
                    dedupe_key=f"fertile_window_open:{fertile_start}",
                )
                if created_item:
                    created.append(created_item)

        if ovulation_date and date.fromisoformat(ovulation_date) == today:
            locale = self._user_locale(user_id)
            confidence_pct = int(round(snapshot.confidence * 100))
            created_item = self._create_notification(
                user_id=user_id,
                notification_type="ovulation_confirmed",
                title=translate(locale, "ovulation_title"),
                body=translate(
                    locale,
                    "ovulation_body",
                    confidence_pct=confidence_pct,
                ),
                action_url="/cycle/lh",
                action_labels=[
                    translate(locale, "log_lh_test"),
                    translate(locale, "track_symptoms"),
                ],
                payload_data={"ovulation_estimate": snapshot.ovulation_estimate, "confidence": snapshot.confidence},
                send_at=moment,
                dedupe_key=f"ovulation_confirmed:{ovulation_date}",
            )
            if created_item:
                created.append(created_item)

        dispatched = self.dispatch_pending(user_id=user_id, now=moment)
        dispatched.created = len(created)
        return dispatched

    def evaluate_morning_cycle_notifications(self, user_id: str, *, now: datetime | None = None) -> NotificationDispatchResponse:
        moment = now or datetime.now(UTC)
        created: list[NotificationHistory] = []
        snapshot = self.predictions.latest_for_user(user_id)
        cycle = self.cycles.active_for_user(user_id)
        if not snapshot or not cycle:
            return NotificationDispatchResponse(skipped=1)

        profile = self.users.ensure_profile(user_id)
        local_today = moment.astimezone(self._tz(profile)).date()
        next_period = snapshot.next_period_estimate.get("date")
        current_phase = self._normalize_phase(snapshot.current_phase)
        cycle_day = max(1, (local_today - cycle.period_start_date).days + 1)
        insight = DailyInsightService(self.db, self.settings).get_or_generate(
            user_id=user_id,
            insight_date=local_today,
            phase=snapshot.current_phase,
            cycle_day=cycle_day,
        )
        insight_payload = dict(insight.payload or {})
        activity = insight_payload.get("activity_recommendation") or "Choose movement based on your energy today."
        nutrition = insight_payload.get("nutrition_recommendation") or "Choose balanced meals and hydration today."

        if next_period:
            next_period_date = date.fromisoformat(next_period)
            if next_period_date - local_today == timedelta(days=3):
                locale = self._user_locale(user_id)
                created_item = self._create_notification(
                    user_id=user_id,
                    notification_type="period_approaching",
                    title=translate(locale, "morning_period_title"),
                    body=f"{nutrition} {activity}",
                    action_url="/log",
                    action_labels=[
                        translate(locale, "log_symptoms"),
                        translate(locale, "view_insights"),
                    ],
                    payload_data={
                        "predicted_period_date": next_period,
                        "nutrition_recommendation": nutrition,
                        "activity_recommendation": activity,
                    },
                    send_at=moment,
                    dedupe_key=f"period_approaching_morning:{next_period}",
                )
                if created_item:
                    created.append(created_item)

        if current_phase == "menstrual" or cycle_day <= (cycle.menses_length or 5):
            locale = self._user_locale(user_id)
            created_item = self._create_notification(
                user_id=user_id,
                notification_type="period_care_reminder",
                title=translate(locale, "period_care_title"),
                body=f"{nutrition} {activity}",
                action_url="/log",
                action_labels=[
                    translate(locale, "log_period"),
                    translate(locale, "view_insights"),
                ],
                payload_data={
                    "phase": current_phase,
                    "cycle_day": cycle_day,
                    "nutrition_recommendation": nutrition,
                    "activity_recommendation": activity,
                    "foods_to_eat": insight_payload.get("foods_to_eat") or [],
                    "workout_exercises": insight_payload.get("workout_exercises") or [],
                },
                send_at=moment,
                dedupe_key=f"period_care_reminder:{local_today.isoformat()}",
            )
            if created_item:
                created.append(created_item)

        dispatched = self.dispatch_pending(user_id=user_id, now=moment)
        dispatched.created = len(created)
        return dispatched

    def dispatch_pending(
        self,
        *,
        user_id: str,
        notification_type: str | None = None,
        now: datetime | None = None,
    ) -> NotificationDispatchResponse:
        moment = now or datetime.now(UTC)
        pending = self.history.pending_for_user(user_id, now=moment, notification_type=notification_type)
        if not pending:
            self.db.commit()
            return NotificationDispatchResponse()

        batched = self._apply_batching(user_id, moment)
        sent_items: list[NotificationResponse] = []
        dispatched = 0

        for item in self.history.pending_for_user(user_id, now=moment, notification_type=notification_type):
            if item.status != "pending":
                continue
            delivery = self._deliver_notification(item, moment)
            if delivery:
                dispatched += 1
            sent_items.append(self._to_response(item))

        self.audit.log(user_id, "notification.dispatched", {"count": dispatched, "batched": batched})
        self.db.commit()
        return NotificationDispatchResponse(dispatched=dispatched, batched=batched, notifications=sent_items)

    def _create_notification(
        self,
        *,
        user_id: str,
        notification_type: str,
        title: str,
        body: str,
        category: str | None = None,
        priority: str | None = None,
        action_url: str | None = None,
        action_labels: list[str] | None = None,
        payload_data: dict | None = None,
        send_at: datetime | None = None,
        lock_screen_title: str | None = None,
        lock_screen_body: str | None = None,
        force_delivery: bool = False,
        dedupe_key: str | None = None,
    ) -> NotificationHistory | None:
        profile = self.users.ensure_profile(user_id)
        prefs = self._ensure_preferences(user_id)
        rule = NOTIFICATION_RULES.get(notification_type)
        resolved_category = category or (rule.category if rule else "general")
        resolved_priority = priority or (rule.priority if rule else "low")
        channel = "push" if prefs.push_enabled else "in_app"
        scheduled_for = send_at or datetime.now(UTC)

        if dedupe_key and self.history.by_dedupe_key(user_id, dedupe_key):
            return None
        if not force_delivery and not prefs.push_enabled and not prefs.in_app_enabled:
            return None
        if not force_delivery and not self._is_enabled(prefs, notification_type):
            return None
        if not force_delivery and self._exceeds_frequency_cap(user_id, resolved_category, scheduled_for):
            return None
        if not force_delivery and self._is_in_quiet_hours(profile, prefs, scheduled_for, critical=bool(rule and rule.critical)):
            scheduled_for = self._next_quiet_hour_end(profile, prefs, scheduled_for)

        public_title = title
        public_body = body
        locale = self._user_locale(user_id)
        private_title = lock_screen_title or self._private_title(notification_type, locale, fallback=rule.private_title if rule else None)
        private_body = lock_screen_body or ""
        if prefs.lock_screen_preview:
            private_title = title
            private_body = body

        item = NotificationHistory(
            user_id=user_id,
            notification_type=notification_type,
            category=resolved_category,
            channel=channel,
            title=public_title,
            body=public_body,
            lock_screen_title=private_title,
            lock_screen_body=private_body,
            status="pending",
            priority=resolved_priority,
            dedupe_key=dedupe_key,
            action_url=action_url,
            action_labels=action_labels or [],
            scheduled_for=scheduled_for,
            payload=payload_data or {},
            notification_metadata={"force_delivery": force_delivery, "locale": locale},
            sent_at=datetime.now(UTC),
        )
        self.history.save(item)
        self.db.flush()
        return item

    def _apply_batching(self, user_id: str, now: datetime) -> int:
        candidates = self.history.pending_batch_candidates(user_id, now=now, since=now - timedelta(hours=1))
        if len(candidates) < 2:
            return 0

        for item in candidates:
            item.status = "batched"

        locale = self._user_locale(user_id)
        title = translate(locale, "batch_title", count=len(candidates))
        summary = " + ".join(item.title for item in candidates[:2])
        batch = NotificationHistory(
            user_id=user_id,
            notification_type="batch",
            category="general",
            channel=candidates[0].channel,
            title=title,
            body=summary,
            lock_screen_title=translate(locale, "batch_lock_title"),
            lock_screen_body="",
            status="pending",
            priority="medium",
            batch_key=f"{user_id}:{int(now.timestamp())}",
            action_url="/notifications",
            action_labels=[translate(locale, "view_all")],
            scheduled_for=now,
            payload={"notification_ids": [item.id for item in candidates]},
            notification_metadata={
                "batched_types": [item.notification_type for item in candidates],
                "locale": locale,
            },
            sent_at=now,
        )
        self.history.save(batch)
        self.db.flush()
        return len(candidates)

    def _ensure_preferences(self, user_id: str) -> NotificationPreference:
        record = self.preferences.by_user_id(user_id)
        if record:
            return record

        profile = self.users.ensure_profile(user_id)
        defaults = self._default_preferences(profile)
        record = NotificationPreference(user_id=user_id, **defaults)
        self.preferences.save(record)
        self.db.flush()
        self.db.commit()
        self.db.refresh(record)
        return record

    def _default_preferences(self, profile: UserProfile) -> dict:
        has_connected_wearable = profile.wearable_type not in {WearableType.NONE, WearableType.MANUAL_BBT}
        manual_bbt = profile.wearable_type == WearableType.MANUAL_BBT
        fertility_enabled = not profile.perimenopause_mode_active and profile.goal in {Goal.TRACK, Goal.CONCEIVE, Goal.AVOID, None}
        return {
            "all_notifications": True,
            "fertile_window_open": fertility_enabled,
            "ovulation_confirmed": fertility_enabled,
            "period_approaching": True,
            "lh_test_reminder": False,
            "period_detected": True,
            "cycle_delay_alert": True,
            "cycle_pattern_change": True,
            "unusual_symptom": True,
            "stress_alert": True,
            "sleep_alert": has_connected_wearable,
            "daily_symptom_reminder": False,
            "bangle_sync_reminder": has_connected_wearable,
            "temperature_logging_reminder": manual_bbt,
            "weekly_summary": True,
            "feature_tips": True,
            "quiet_hours_enabled": True,
            "quiet_hours_start": "22:00",
            "quiet_hours_end": "08:00",
            "allow_critical_in_quiet_hours": True,
            "lock_screen_preview": False,
            "push_enabled": True,
            "in_app_enabled": True,
            "email_enabled": False,
            "sms_enabled": False,
        }

    def _preferences_response(self, record: NotificationPreference) -> NotificationPreferencesResponse:
        return NotificationPreferencesResponse(
            all_notifications=record.all_notifications,
            period_approaching=record.period_approaching,
            period_detected=record.period_detected,
            fertile_window_open=record.fertile_window_open,
            ovulation_confirmed=record.ovulation_confirmed,
            cycle_delay_alert=record.cycle_delay_alert,
            cycle_pattern_change=record.cycle_pattern_change,
            unusual_symptom=record.unusual_symptom,
            stress_alert=record.stress_alert,
            sleep_alert=record.sleep_alert,
            daily_symptom_reminder=record.daily_symptom_reminder,
            bangle_sync_reminder=record.bangle_sync_reminder,
            temperature_logging_reminder=record.temperature_logging_reminder,
            lh_test_reminder=record.lh_test_reminder,
            weekly_summary=record.weekly_summary,
            feature_tips=record.feature_tips,
            quiet_hours_enabled=record.quiet_hours_enabled,
            quiet_hours_start=record.quiet_hours_start,
            quiet_hours_end=record.quiet_hours_end,
            allow_critical_in_quiet_hours=record.allow_critical_in_quiet_hours,
            lock_screen_preview=record.lock_screen_preview,
            push_enabled=record.push_enabled,
            in_app_enabled=record.in_app_enabled,
            email_enabled=record.email_enabled,
            sms_enabled=record.sms_enabled,
        )

    def _settings_response(self, user_id: str, record: NotificationPreference) -> NotificationSettingsResponse:
        locale = self._user_locale(user_id)
        return NotificationSettingsResponse(
            all_notifications=record.all_notifications,
            predictions=NotificationSettingsSectionResponse(
                key="predictions",
                title=translate(locale, "predictions_title"),
                items=[
                    self._setting_item("period_approaching", translate(locale, "setting_period_approaching_title"), translate(locale, "setting_period_approaching_desc"), record.period_approaching),
                    self._setting_item("period_detected", translate(locale, "setting_period_detected_title"), translate(locale, "setting_period_detected_desc"), record.period_detected),
                    self._setting_item("fertile_window_open", translate(locale, "setting_fertile_window_open_title"), translate(locale, "setting_fertile_window_open_desc"), record.fertile_window_open),
                    self._setting_item("ovulation_confirmed", translate(locale, "setting_ovulation_confirmed_title"), translate(locale, "setting_ovulation_confirmed_desc"), record.ovulation_confirmed),
                    self._setting_item("cycle_delay_alert", translate(locale, "setting_cycle_delay_alert_title"), translate(locale, "setting_cycle_delay_alert_desc"), record.cycle_delay_alert),
                ],
            ),
            health_insights=NotificationSettingsSectionResponse(
                key="health_insights",
                title=translate(locale, "health_insights_title"),
                items=[
                    self._setting_item("cycle_pattern_change", translate(locale, "setting_cycle_pattern_change_title"), translate(locale, "setting_cycle_pattern_change_desc"), record.cycle_pattern_change),
                    self._setting_item("unusual_symptom", translate(locale, "setting_unusual_symptom_title"), translate(locale, "setting_unusual_symptom_desc"), record.unusual_symptom),
                    self._setting_item("stress_alert", translate(locale, "setting_stress_alert_title"), translate(locale, "setting_stress_alert_desc"), record.stress_alert),
                    self._setting_item("sleep_alert", translate(locale, "setting_sleep_alert_title"), translate(locale, "setting_sleep_alert_desc"), record.sleep_alert),
                ],
            ),
            reminders=NotificationSettingsSectionResponse(
                key="reminders",
                title=translate(locale, "reminders_title"),
                items=[
                    self._setting_item("daily_symptom_reminder", translate(locale, "setting_daily_symptom_reminder_title"), translate(locale, "setting_daily_symptom_reminder_desc"), record.daily_symptom_reminder),
                    self._setting_item("bangle_sync_reminder", translate(locale, "setting_bangle_sync_reminder_title"), translate(locale, "setting_bangle_sync_reminder_desc"), record.bangle_sync_reminder),
                    self._setting_item("lh_test_reminder", translate(locale, "setting_lh_test_reminder_title"), translate(locale, "setting_lh_test_reminder_desc"), record.lh_test_reminder),
                ],
            ),
            critical_alerts=NotificationSettingsSectionResponse(
                key="critical_alerts",
                title=translate(locale, "critical_alerts_title"),
                items=[
                    self._setting_item("heavy_bleeding", translate(locale, "setting_heavy_bleeding_title"), translate(locale, "setting_heavy_bleeding_desc"), True, can_disable=False),
                    self._setting_item("potential_pregnancy", translate(locale, "setting_potential_pregnancy_title"), translate(locale, "setting_potential_pregnancy_desc"), True, can_disable=False),
                    self._setting_item("bangle_battery_critical", translate(locale, "setting_bangle_battery_critical_title"), translate(locale, "setting_bangle_battery_critical_desc"), True, can_disable=False),
                ],
            ),
            quiet_hours=QuietHoursSettingsResponse(
                enabled=record.quiet_hours_enabled,
                start_time=record.quiet_hours_start,
                end_time=record.quiet_hours_end,
                allow_critical_alerts=record.allow_critical_in_quiet_hours,
            ),
        )

    def _to_response(self, item: NotificationHistory) -> NotificationResponse:
        return NotificationResponse(
            id=item.id,
            notification_type=item.notification_type,
            category=item.category,
            channel=item.channel,
            priority=item.priority,
            status=item.status,
            title=item.title,
            body=item.body,
            lock_screen_title=item.lock_screen_title,
            lock_screen_body=item.lock_screen_body,
            action_url=item.action_url,
            action_labels=list(item.action_labels or []),
            payload=dict(item.payload or {}),
            metadata=dict(item.notification_metadata or {}),
            scheduled_for=item.scheduled_for,
            delivered_at=item.delivered_at,
            read_at=item.read_at,
            sent_at=item.sent_at,
        )

    def _device_response(self, item: NotificationDevice) -> NotificationDeviceResponse:
        return NotificationDeviceResponse(
            id=item.id,
            platform=item.platform,
            device_id=item.device_id,
            fcm_token=item.fcm_token,
            app_version=item.app_version,
            device_name=item.device_name,
            locale=item.locale,
            notifications_enabled=item.notifications_enabled,
            last_seen_at=item.last_seen_at,
            invalidated_at=item.invalidated_at,
        )

    def _setting_item(
        self,
        key: str,
        title: str,
        description: str,
        enabled: bool,
        *,
        can_disable: bool = True,
    ) -> NotificationSettingItemResponse:
        return NotificationSettingItemResponse(
            key=key,
            title=title,
            description=description,
            enabled=enabled,
            can_disable=can_disable,
        )

    def _is_enabled(self, prefs: NotificationPreference, notification_type: str) -> bool:
        rule = NOTIFICATION_RULES.get(notification_type)
        if rule and not rule.user_configurable:
            return True
        if not prefs.all_notifications:
            return False
        if not rule or not rule.preference_field:
            return True
        return bool(getattr(prefs, rule.preference_field))

    def _exceeds_frequency_cap(self, user_id: str, category: str, when: datetime) -> bool:
        limits = FREQUENCY_LIMITS.get(category)
        if not limits:
            return False
        return (
            self.history.counts_since(user_id, category=category, since=when - timedelta(days=1)) >= limits["day"]
            or self.history.counts_since(user_id, category=category, since=when - timedelta(days=7)) >= limits["week"]
            or self.history.counts_since(user_id, category=category, since=when - timedelta(days=30)) >= limits["month"]
        )

    def _is_in_quiet_hours(
        self,
        profile: UserProfile,
        prefs: NotificationPreference,
        moment: datetime,
        *,
        critical: bool,
    ) -> bool:
        if not prefs.quiet_hours_enabled:
            return False
        if critical and prefs.allow_critical_in_quiet_hours:
            return False
        local_time = moment.astimezone(self._tz(profile)).time()
        start = self._parse_hhmm(prefs.quiet_hours_start)
        end = self._parse_hhmm(prefs.quiet_hours_end)
        if start <= end:
            return start <= local_time < end
        return local_time >= start or local_time < end

    def _next_quiet_hour_end(self, profile: UserProfile, prefs: NotificationPreference, moment: datetime) -> datetime:
        tz = self._tz(profile)
        local_moment = moment.astimezone(tz)
        quiet_end = self._parse_hhmm(prefs.quiet_hours_end)
        candidate_day = local_moment.date()
        candidate = datetime.combine(candidate_day, quiet_end, tz)
        if local_moment.time() >= quiet_end:
            candidate += timedelta(days=1)
        return candidate.astimezone(UTC)

    def _tz(self, profile: UserProfile) -> ZoneInfo:
        try:
            return ZoneInfo(profile.timezone or "UTC")
        except Exception:
            return ZoneInfo("UTC")

    def _parse_hhmm(self, value: str) -> time:
        hour, minute = value.split(":", 1)
        return time(hour=int(hour), minute=int(minute))

    def _user_locale(self, user_id: str) -> str:
        devices = self.devices.active_for_user(user_id)
        for device in devices:
            if device.locale:
                return normalize_locale(device.locale)
        return "en"

    def _private_title(
        self,
        notification_type: str,
        locale: str | None,
        *,
        fallback: str | None = None,
    ) -> str:
        key = f"private_{notification_type}"
        language = normalize_locale(locale)
        if key in {"private_batch"}:
            return translate(language, "batch_lock_title")
        strings = {
            "en",
            "es",
            "fr",
            "de",
            "pt",
        }
        if language in strings:
            try:
                return translate(language, key)
            except KeyError:
                pass
        return fallback or translate(language, "private_default")

    def _format_month_day(self, value: date, locale: str | None) -> str:
        return format_month_day(value, locale)

    def _normalize_phase(self, value: str | None) -> str | None:
        return "ovulation" if value == "ovulatory" else value

    def _deliver_notification(self, item: NotificationHistory, moment: datetime) -> bool:
        item.delivery_attempts += 1
        item.sent_at = moment

        if item.channel == "push":
            devices = self.devices.active_for_user(item.user_id)
            tokens = [device.fcm_token for device in devices]
            if not tokens:
                item.channel = "in_app"
                item.status = "sent"
                item.delivered_at = moment
                return True

            payload = {"notification_id": item.id, "notification_type": item.notification_type, "action_url": item.action_url or ""}
            try:
                result = self.push_service.send_notification(
                    tokens=tokens,
                    title=item.lock_screen_title,
                    body=item.lock_screen_body or item.body,
                    data=payload,
                )
            except Exception as exc:  # pragma: no cover
                item.status = "failed"
                item.notification_metadata = {
                    **dict(item.notification_metadata or {}),
                    "delivery_error": str(exc),
                }
                return False
            self._invalidate_tokens(result.invalid_tokens, moment)
            item.notification_metadata = {
                **dict(item.notification_metadata or {}),
                "delivered_tokens": result.delivered_tokens,
                "invalid_tokens": result.invalid_tokens,
                "failed_tokens": result.failed_tokens,
            }
            if result.delivered_tokens:
                item.status = "sent"
                item.delivered_at = moment
                return True
            item.status = "failed"
            return False

        item.status = "sent"
        item.delivered_at = moment
        return True

    def _invalidate_tokens(self, tokens: list[str], moment: datetime) -> None:
        for token in tokens:
            record = self.devices.by_token(token)
            if not record:
                continue
            record.notifications_enabled = False
            record.invalidated_at = moment
