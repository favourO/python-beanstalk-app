from datetime import datetime, date

from pydantic import BaseModel


class TemperatureRecord(BaseModel):
    timestamp: datetime
    delta_c: float
    temperature_celsius: float | None = None
    unit: str = "celsius"
    metric_type: str = "body_temperature"
    measured_at: datetime | None = None
    collected_at: datetime | None = None
    sleep_minutes: int | None = None
    sleep_quality_score: float = 1.0
    illness_flag: bool = False
    alcohol_flag: bool = False
    stress_flag: bool = False
    travel_flag: bool = False
    is_user_entered: bool = False
    excluded_from_ovulation_prediction: bool | None = None
    exclusion_reason: str | None = None
    raw_payload: dict | None = None
    source: str = "manual"


class TemperatureIngestRequest(BaseModel):
    records: list[TemperatureRecord]


class HeartRateIngestRequest(BaseModel):
    date: date
    rhr_bpm: float
    min_hr_bpm: float | None = None
    hrv_sdnn_ms: float | None = None
    source: str = "manual"


class SleepIngestRequest(BaseModel):
    date: date
    total_minutes: int
    rem: int | None = None
    deep: int | None = None
    awake: int | None = None
    sleep_quality_score: float = 1.0
