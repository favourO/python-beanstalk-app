from datetime import date, datetime

from pydantic import BaseModel, Field


class PredictionSnapshotResponse(BaseModel):
    prediction_id: str
    user_id: str
    cycle_id: str | None = None
    generated_at: datetime
    current_phase: str
    ovulation_estimate: dict = Field(default_factory=dict)
    confidence: float
    confidence_explanation: str
    warning_flags: list[str] = Field(default_factory=list)
    models_used: list[str] = Field(default_factory=list)
    model_audits: list[dict] = Field(default_factory=list)
    audit: dict = Field(default_factory=dict)
    fertile_window: dict = Field(default_factory=dict)
    next_period_estimate: dict = Field(default_factory=dict)
    phase_distribution: dict[str, float] = Field(default_factory=dict)
    contributing_signals: list[dict] = Field(default_factory=list)
    model_version: str | None = None
    disclaimer: str


class CalendarPredictionResponse(BaseModel):
    date: date
    phase: str
    fertility_score: float
    is_period: bool
    is_fertile: bool
    is_ovulation_est: bool


class AgeContextResponse(BaseModel):
    age_band: str | None = None
    age_band_label: str | None = None
    perimenopause_mode_active: bool = False
    how_age_affects_predictions: str
    population_priors_for_band: dict = Field(default_factory=dict)

