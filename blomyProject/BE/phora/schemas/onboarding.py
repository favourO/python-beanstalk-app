from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, Field, AliasChoices, field_validator, model_validator

from phora.models.enums import Goal, WearableType


class OnboardingProfileRequest(BaseModel):
    full_name: str | None = None
    date_of_birth: date | None = None
    age_at_menarche: int | None = Field(default=None, ge=8, le=18)
    height_cm: float | None = None
    weight_kg: float | None = None
    timezone: str = "UTC"
    conditions: dict = Field(default_factory=dict)


class OnboardingCycleHistoryRequest(BaseModel):
    last_period_date: date = Field(
        validation_alias=AliasChoices("last_period_date", "last_period_start"),
    )
    last_period_end: date | None = None
    avg_cycle_length: int | None = Field(
        default=None,
        validation_alias=AliasChoices("avg_cycle_length", "average_cycle_length"),
    )
    avg_period_duration: int | None = Field(
        default=None,
        validation_alias=AliasChoices("avg_period_duration", "average_period_length"),
    )
    irregularity_flag: bool = False
    years_menstruating: int | None = None

    @model_validator(mode="after")
    def derive_period_duration(self) -> "OnboardingCycleHistoryRequest":
        if self.last_period_end is not None:
            if self.last_period_end < self.last_period_date:
                raise ValueError("last_period_end must be on or after last_period_date")
            if self.avg_period_duration is None:
                self.avg_period_duration = (self.last_period_end - self.last_period_date).days + 1
        return self


class OnboardingGoalRequest(BaseModel):
    goal: Goal

    @field_validator("goal", mode="before")
    @classmethod
    def normalize_goal(cls, value: Any) -> Any:
        if not isinstance(value, str):
            return value
        normalized = value.strip().lower()
        mappings = {
            "cycle_tracking": Goal.TRACK,
            "track_cycle": Goal.TRACK,
            "track": Goal.TRACK,
            "avoid_pregnancy": Goal.AVOID,
            "tta": Goal.AVOID,
            "avoid": Goal.AVOID,
            "trying_to_conceive": Goal.CONCEIVE,
            "ttc": Goal.CONCEIVE,
            "conceive": Goal.CONCEIVE,
            "pregnancy": Goal.TRACK,
        }
        return mappings.get(normalized, normalized)


class OnboardingWearableRequest(BaseModel):
    wearable_type: WearableType


class OnboardingHealthConditionsRequest(BaseModel):
    conditions: list[str] = Field(default_factory=list)

    @field_validator("conditions")
    @classmethod
    def validate_conditions(cls, value: list[str]) -> list[str]:
        cleaned = [condition.strip() for condition in value if condition and condition.strip()]
        return cleaned


class OnboardingPrivacyPreferencesRequest(BaseModel):
    research_data_sharing: bool
    health_analytics: bool
    personalized_recommendations: bool
    product_messaging_optimization: bool


class OnboardingCompleteRequest(BaseModel):
    cycle_history: OnboardingCycleHistoryRequest
    goal: Goal
    health_conditions: list[str] = Field(default_factory=list)

    @field_validator("goal", mode="before")
    @classmethod
    def normalize_goal(cls, value: Any) -> Any:
        return OnboardingGoalRequest.normalize_goal(value)

    @field_validator("health_conditions")
    @classmethod
    def validate_health_conditions(cls, value: list[str]) -> list[str]:
        return OnboardingHealthConditionsRequest.validate_conditions(value)


class OnboardingCompleteResponse(BaseModel):
    status: str = "ok"
    cycle_id: str
    goal: Goal
    health_conditions: list[str]


class OnboardingProgressPayload(BaseModel):
    period_length: int | None = Field(default=None, ge=1, le=30)
    last_period_start: date | None = None
    last_period_end: date | None = None
    goal: Goal | None = None
    health_conditions: list[str] = Field(default_factory=list)

    @field_validator("goal", mode="before")
    @classmethod
    def normalize_optional_goal(cls, value: Any) -> Any:
        if value is None:
            return value
        return OnboardingGoalRequest.normalize_goal(value)

    @field_validator("health_conditions")
    @classmethod
    def normalize_health_conditions(cls, value: list[str]) -> list[str]:
        return [condition.strip() for condition in value if condition and condition.strip()]

    @model_validator(mode="after")
    def validate_period_range(self) -> "OnboardingProgressPayload":
        if self.last_period_start and self.last_period_end and self.last_period_end < self.last_period_start:
            raise ValueError("last_period_end must be on or after last_period_start")
        if self.period_length is None and self.last_period_start and self.last_period_end:
            self.period_length = (self.last_period_end - self.last_period_start).days + 1
        return self


class OnboardingProgressPatchRequest(OnboardingProgressPayload):
    current_step: int | None = Field(default=None, ge=1)


class OnboardingProgressResponse(OnboardingProgressPayload):
    current_step: int | None = None
    completed: bool = False
    updated_at: datetime


class ProfileResponse(BaseModel):
    user_id: str
    onboarding_completed_at: datetime | None = None
    bmi: float | None = None
    age_band: str | None = None
    perimenopause_mode_active: bool = False
