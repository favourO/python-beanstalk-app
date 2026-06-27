from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class NotificationPreferencesResponse(BaseModel):
    all_notifications: bool = True
    period_approaching: bool = True
    period_detected: bool = True
    fertile_window_open: bool = True
    ovulation_confirmed: bool = True
    cycle_delay_alert: bool = True
    cycle_pattern_change: bool = True
    unusual_symptom: bool = True
    stress_alert: bool = True
    sleep_alert: bool = False
    daily_symptom_reminder: bool = False
    bangle_sync_reminder: bool = False
    temperature_logging_reminder: bool = False
    lh_test_reminder: bool = False
    weekly_summary: bool = True
    feature_tips: bool = True
    blog_posts: bool = True
    wearable_ovulation_reminder: bool = True
    update_reminders: bool = True
    quiet_hours_enabled: bool = True
    quiet_hours_start: str = "22:00"
    quiet_hours_end: str = "08:00"
    allow_critical_in_quiet_hours: bool = True
    lock_screen_preview: bool = False
    push_enabled: bool = True
    in_app_enabled: bool = True
    email_enabled: bool = False
    sms_enabled: bool = False


class NotificationDeviceUpsertRequest(BaseModel):
    platform: Literal["ios", "android", "web"]
    device_id: str
    fcm_token: str
    app_version: str | None = None
    device_name: str | None = None
    locale: str | None = None
    notifications_enabled: bool = True


class NotificationDeviceResponse(BaseModel):
    id: str
    platform: str
    device_id: str
    fcm_token: str
    app_version: str | None = None
    device_name: str | None = None
    locale: str | None = None
    notifications_enabled: bool = True
    last_seen_at: datetime
    invalidated_at: datetime | None = None


class NotificationPreferencesUpdateRequest(BaseModel):
    all_notifications: bool | None = None
    period_approaching: bool | None = None
    period_detected: bool | None = None
    fertile_window_open: bool | None = None
    ovulation_confirmed: bool | None = None
    cycle_delay_alert: bool | None = None
    cycle_pattern_change: bool | None = None
    unusual_symptom: bool | None = None
    stress_alert: bool | None = None
    sleep_alert: bool | None = None
    daily_symptom_reminder: bool | None = None
    bangle_sync_reminder: bool | None = None
    temperature_logging_reminder: bool | None = None
    lh_test_reminder: bool | None = None
    weekly_summary: bool | None = None
    feature_tips: bool | None = None
    blog_posts: bool | None = None
    wearable_ovulation_reminder: bool | None = None
    update_reminders: bool | None = None
    quiet_hours_enabled: bool | None = None
    quiet_hours_start: str | None = None
    quiet_hours_end: str | None = None
    allow_critical_in_quiet_hours: bool | None = None
    lock_screen_preview: bool | None = None
    push_enabled: bool | None = None
    in_app_enabled: bool | None = None
    email_enabled: bool | None = None
    sms_enabled: bool | None = None


class NotificationSettingItemResponse(BaseModel):
    key: str
    title: str
    description: str
    enabled: bool
    can_disable: bool = True


class NotificationSettingsSectionResponse(BaseModel):
    key: str
    title: str
    items: list[NotificationSettingItemResponse] = Field(default_factory=list)


class QuietHoursSettingsResponse(BaseModel):
    enabled: bool = True
    start_time: str = "22:00"
    end_time: str = "08:00"
    allow_critical_alerts: bool = True


class NotificationSettingsResponse(BaseModel):
    all_notifications: bool = True
    blog_posts: bool = True
    wearable_ovulation_reminder: bool = True
    update_reminders: bool = True
    predictions: NotificationSettingsSectionResponse
    health_insights: NotificationSettingsSectionResponse
    reminders: NotificationSettingsSectionResponse
    critical_alerts: NotificationSettingsSectionResponse
    quiet_hours: QuietHoursSettingsResponse


class QuietHoursSettingsUpdateRequest(BaseModel):
    enabled: bool | None = None
    start_time: str | None = None
    end_time: str | None = None
    allow_critical_alerts: bool | None = None


class NotificationSettingsUpdateRequest(BaseModel):
    all_notifications: bool | None = None
    period_approaching: bool | None = None
    period_detected: bool | None = None
    fertile_window_open: bool | None = None
    ovulation_confirmed: bool | None = None
    cycle_delay_alert: bool | None = None
    cycle_pattern_change: bool | None = None
    unusual_symptom: bool | None = None
    stress_alert: bool | None = None
    sleep_alert: bool | None = None
    daily_symptom_reminder: bool | None = None
    bangle_sync_reminder: bool | None = None
    lh_test_reminder: bool | None = None
    blog_posts: bool | None = None
    wearable_ovulation_reminder: bool | None = None
    update_reminders: bool | None = None
    quiet_hours: QuietHoursSettingsUpdateRequest | None = None


class NotificationResponse(BaseModel):
    id: str
    notification_type: str
    category: str
    channel: str
    priority: str
    status: str
    title: str
    body: str
    lock_screen_title: str
    lock_screen_body: str
    action_url: str | None = None
    action_labels: list[str] = Field(default_factory=list)
    payload: dict = Field(default_factory=dict)
    metadata: dict = Field(default_factory=dict)
    scheduled_for: datetime
    delivered_at: datetime | None = None
    read_at: datetime | None = None
    sent_at: datetime


class NotificationListResponse(BaseModel):
    items: list[NotificationResponse] = Field(default_factory=list)
    unread_count: int = 0


class NotificationMarkReadResponse(BaseModel):
    updated: int


class NotificationDeviceDeleteRequest(BaseModel):
    device_id: str


class NotificationTriggerRequest(BaseModel):
    notification_type: str
    title: str
    body: str
    category: Literal["predictions", "health_insights", "reminders", "app_engagement", "critical_alerts"] = "predictions"
    priority: Literal["low", "medium", "high", "critical"] = "medium"
    action_url: str | None = None
    action_labels: list[str] = Field(default_factory=list)
    payload: dict = Field(default_factory=dict)
    lock_screen_title: str | None = None
    lock_screen_body: str | None = None
    send_at: datetime | None = None
    force_delivery: bool = False
    bypass_frequency_cap: bool = False


class NotificationDispatchResponse(BaseModel):
    created: int = 0
    dispatched: int = 0
    deferred: int = 0
    batched: int = 0
    skipped: int = 0
    notifications: list[NotificationResponse] = Field(default_factory=list)
