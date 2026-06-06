from datetime import date, datetime

from pydantic import BaseModel, Field


class Gtl1HeartRateSummary(BaseModel):
    resting: float = 0
    avg: float = 0
    min: float = 0
    max: float = 0


class Gtl1SleepSummary(BaseModel):
    totalMinutes: int = 0
    deepMinutes: int = 0
    lightMinutes: int = 0
    awakeMinutes: int = 0


class Gtl1TemperatureSummary(BaseModel):
    avg: float = 0


class Gtl1StressSummary(BaseModel):
    avg: float = 0


class Gtl1BloodOxygenSummary(BaseModel):
    avg: float = 0
    min: float = 0


class Gtl1DailyHealthData(BaseModel):
    date: date
    steps: int = 0
    caloriesKcal: float = 0
    distanceMeters: float = 0
    heartRate: Gtl1HeartRateSummary = Field(default_factory=Gtl1HeartRateSummary)
    sleep: Gtl1SleepSummary = Field(default_factory=Gtl1SleepSummary)
    bloodOxygen: Gtl1BloodOxygenSummary = Field(default_factory=Gtl1BloodOxygenSummary)
    temperature: Gtl1TemperatureSummary = Field(default_factory=Gtl1TemperatureSummary)
    stress: Gtl1StressSummary = Field(default_factory=Gtl1StressSummary)
    sourceDevice: str | None = None
    syncTimestamp: str | None = None
    raw: dict = Field(default_factory=dict)


class WatchSyncRequest(BaseModel):
    device_type: str
    synced_at: datetime
    days: list[Gtl1DailyHealthData] = Field(default_factory=list)


class GoogleHealthAuthUrlResponse(BaseModel):
    authorization_url: str


class GoogleHealthStatusResponse(BaseModel):
    connected: bool
    provider: str = "google_health"
    last_synced_at: datetime | None = None
    sync_health: str = "unavailable"
    granted_scopes: list[str] = Field(default_factory=list)
    last_error: str | None = None


class GoogleHealthSyncResponse(BaseModel):
    synced: bool
    saved: int = 0
    last_synced_at: datetime | None = None
    detail: str | None = None


class AppleHealthDailyMetric(BaseModel):
    date: date
    sleep_minutes: int | None = None
    deep_sleep_minutes: int | None = None
    light_sleep_minutes: int | None = None
    steps: int | None = None
    resting_heart_rate: float | None = None
    hrv: float | None = None
    bbt: float | None = None
    body_temperature: float | None = None
    wrist_temperature: float | None = None
    external_id: str | None = None


class AppleHealthSyncRequest(BaseModel):
    synced_at: datetime
    days: list[AppleHealthDailyMetric] = Field(default_factory=list)


class AppleHealthSyncResponse(BaseModel):
    synced: bool
    saved: int = 0
    last_synced_at: datetime | None = None


class AppleHealthStatusResponse(BaseModel):
    connected: bool
    last_synced_at: datetime | None = None


class HealthMetricRecord(BaseModel):
    id: str
    user_id: str
    metric_type: str
    value: float
    unit: str
    data_source: str
    recorded_at: datetime
    external_id: str | None = None
    confidence: str = "medium"
    excluded_from_ovulation_prediction: bool = False
    source_label: str = ""


class HealthMetricsResponse(BaseModel):
    metrics: list[HealthMetricRecord] = Field(default_factory=list)
    total: int = 0
