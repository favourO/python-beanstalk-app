from datetime import date, datetime

from pydantic import BaseModel, Field


class TemperatureSeriesPoint(BaseModel):
    date: date
    delta_temp: float
    quality_score: float = 1.0
    illness_flag: bool = False
    alcohol_flag: bool = False


class SignalAvailability(BaseModel):
    temp: bool = False
    rhr: bool = False
    hrv: bool = False
    lh: bool = False


class MlEnsembleRequest(BaseModel):
    user_id: str
    cycle_id: str
    prediction_date: date
    cycle_day: int
    cycle_day_norm: float
    sigma_cycle: float | None = None
    mu_cycle: float | None = None
    age: int | None = None
    age_band: str | None = None
    age_at_menarche: int | None = None
    bmi: float | None = None
    temp_source: str | None = None
    wearable_source: str | None = None
    temp_series: list[TemperatureSeriesPoint] = Field(default_factory=list)
    stress_burden_7d: float | None = None
    lh_surge_state: str | None = None
    lh_surge_day: int | None = None
    pcos_flag: bool = False
    perimenopause_mode_active: bool = False
    menses_length: int | None = None
    ovulation_day: int | None = None
    mucus_score: float | None = None
    lh_proxy: float | None = None
    sleep_quality: float | None = None
    delta_temp: float | None = None
    rhr_dev: float | None = None
    hrv_dev: float | None = None
    signal_availability: SignalAvailability = Field(default_factory=SignalAvailability)


class ModelAudit(BaseModel):
    model_name: str
    model_version: str | None = None
    available: bool = True
    confidence: float | None = None
    explanation: str | None = None


class PredictionAudit(BaseModel):
    cusum_triggered: bool = False
    pcos_flag: bool = False
    lh_override_applied: bool = False
    ovulation_estimate_source: str = "calendar_fallback"
    rf_direct_threshold: float | None = None


class MlEnsembleResponse(BaseModel):
    user_id: str
    prediction_id: str
    current_phase: str
    phase_distribution: dict[str, float]
    ovulation_estimate: int | None = None
    confidence: float
    confidence_explanation: str
    warning_flags: list[str] = Field(default_factory=list)
    models_used: list[str] = Field(default_factory=list)
    model_audits: list[ModelAudit] = Field(default_factory=list)
    audit: PredictionAudit
    generated_at: datetime


class MlHealthResponse(BaseModel):
    status: str
    models_loaded: bool = False
    uptime: float | None = None


class MlLHStripResponse(BaseModel):
    strip_valid: bool
    strip_confidence: float
    state: str
    positive: bool
    ratio: float | None = None
    result_confidence: float
    explanation: str
    analysis_version: str
