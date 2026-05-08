from datetime import date, datetime

from pydantic import BaseModel, Field


class HomeUserResponse(BaseModel):
    id: str
    first_name: str | None = None


class HomeMainStatusResponse(BaseModel):
    current_cycle_day: int | None = None
    current_phase: str | None = None
    current_phase_raw: str | None = None
    next_predicted_period_date: date | None = None
    countdown_to_next_period_days: int | None = None
    prediction_confidence: str
    prediction_confidence_score: float
    cycle_length_days: int | None = None
    period_length_days: int | None = None


class HomeFertilityResponse(BaseModel):
    fertile_today: bool = False
    fertile_window_start: date | None = None
    fertile_window_end: date | None = None
    predicted_ovulation_date: date | None = None
    prediction_method: str | None = None


class HomeTodayFocusResponse(BaseModel):
    title: str
    message: str
    tags: list[str] = Field(default_factory=list)
    nutrition_recommendation: str | None = None
    activity_recommendation: str | None = None
    foods_to_eat: list[str] = Field(default_factory=list)
    workout_exercises: list[str] = Field(default_factory=list)
    personalization_basis: list[str] = Field(default_factory=list)
    generated_at: datetime | None = None


class HomeFitnessGuidanceResponse(BaseModel):
    recommended_intensity: str
    recommended_focus: list[str] = Field(default_factory=list)
    recovery_priority: str
    message: str
    reason: str


class HomeHealthSnapshotResponse(BaseModel):
    wearable_connected: bool = False
    wearable_type: str | None = None
    body_signal_state: str = "connect_wearable"
    body_signal_title: str = "Connect wearable"
    body_signal_message: str = "Connect a wearable to show live body signals here."
    body_signal_action_label: str | None = "Connect wearable"
    sleep_hours: float | None = None
    sleep_deep_minutes: int | None = None
    sleep_light_minutes: int | None = None
    sleep_awake_minutes: int | None = None
    steps: int | None = None
    resting_heart_rate: float | None = None
    blood_oxygen_avg: float | None = None
    blood_oxygen_min: float | None = None
    stress_avg: float | None = None
    hrv: float | None = None
    temperature_delta_c: float | None = None
    latest_recorded_at: datetime | None = None
    cycle_support_signals: list[str] = Field(default_factory=list)


class HomeDeviceTrendPointResponse(BaseModel):
    recorded_at: datetime
    value: float


class HomeDeviceTrendResponse(BaseModel):
    metric: str
    label: str
    unit: str | None = None
    latest_value: float | None = None
    delta_percent: float | None = None
    points: list[HomeDeviceTrendPointResponse] = Field(default_factory=list)


class HomeCyclePredictionImpactResponse(BaseModel):
    before_ovulation_date: date | None = None
    before_period_date: date | None = None
    after_ovulation_date: date | None = None
    after_period_date: date | None = None
    confidence_before: float
    confidence_after: float
    confidence_delta: float
    method: str | None = None
    contributing_signals: list[str] = Field(default_factory=list)
    explanation: str


class HomeCycleInsightResponse(BaseModel):
    id: str
    type: str
    title: str
    summary: str
    advice: str
    cycle_impact: str
    confidence: str
    severity: str
    source_signals: list[str] = Field(default_factory=list)
    show_medical_disclaimer: bool = True
    cta_label: str | None = None
    cta_route: str | None = None


class HomeQuickActionResponse(BaseModel):
    type: str
    label: str


class HomeAlertResponse(BaseModel):
    type: str
    message: str


class HomeResponse(BaseModel):
    user: HomeUserResponse
    main_status: HomeMainStatusResponse
    fertility: HomeFertilityResponse
    today_focus: HomeTodayFocusResponse
    fitness_guidance: HomeFitnessGuidanceResponse
    health_snapshot: HomeHealthSnapshotResponse
    device_cycle_insights: list[HomeCycleInsightResponse] = Field(default_factory=list)
    device_trends: list[HomeDeviceTrendResponse] = Field(default_factory=list)
    cycle_prediction_impact: HomeCyclePredictionImpactResponse | None = None
    prediction_disclaimer: str
    quick_actions: list[HomeQuickActionResponse] = Field(default_factory=list)
    alerts: list[HomeAlertResponse] = Field(default_factory=list)
