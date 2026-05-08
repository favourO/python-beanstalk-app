from datetime import date, time

from pydantic import BaseModel, Field


class PeriodStartRequest(BaseModel):
    start_date: date


class LHLogRequest(BaseModel):
    log_date: date
    test_time: time | None = None
    state: str | None = None
    raw_value: float | None = None
    ratio: float | None = None
    positive: bool = False


class LHLogHistoryItemResponse(BaseModel):
    id: str
    log_date: date
    test_time: str | None = None
    state: str | None = None
    raw_value: float | None = None
    ratio: float | None = None
    positive: bool
    cycle_day: int | None = None
    source: str
    strip_valid: bool | None = None
    confidence: float | None = None
    explanation: str | None = None
    analysis_version: str | None = None
    logged_at: str


class LHLogHistoryResponse(BaseModel):
    items: list[LHLogHistoryItemResponse] = Field(default_factory=list)
    total: int
    limit: int
    offset: int


class MucusLogRequest(BaseModel):
    log_date: date
    score: float


class SymptomLogRequest(BaseModel):
    log_date: date
    symptoms: list[str] = Field(min_length=1)
    severity: str | None = None
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)


class IntimacyLogRequest(BaseModel):
    log_date: date
    had_intimacy: bool = True
    protection_used: bool | None = None
    ejaculation: bool | None = None
    partner_gender: str | None = None
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)


class CycleTrendPoint(BaseModel):
    recorded_at: str
    value: float


class SymptomPatternsResponse(BaseModel):
    most_common: str | None = None
    energy_dips: str | None = None


class CycleStatsResponse(BaseModel):
    tracked_cycles: int
    first_period_start_date: date | None = None
    average_cycle_length_days: float | None = None
    average_period_length_days: float | None = None
    regularity_score: float | None = None
    temperature_trend: list[CycleTrendPoint] = Field(default_factory=list)
    hrv_trend: list[CycleTrendPoint] = Field(default_factory=list)
    symptom_patterns: SymptomPatternsResponse = Field(default_factory=SymptomPatternsResponse)
