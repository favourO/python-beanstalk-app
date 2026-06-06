from datetime import date, datetime

from pydantic import BaseModel, Field


class DeleteAccountResponse(BaseModel):
    message: str = "Account scheduled for deletion. All personal information has been removed."


class DeleteAccountRequest(BaseModel):
    otp_code: str = Field(min_length=4, max_length=10)


class AgeProfileResponse(BaseModel):
    date_of_birth: date | None = None
    age_at_menarche: int | None = None
    current_age: int | None = None
    age_band: str | None = None
    age_band_label: str | None = None
    perimenopause_mode_active: bool = False
    perimenopause_mode_source: str | None = None
    population_priors_for_band: dict = Field(default_factory=dict)


class AgeProfileUpdateRequest(BaseModel):
    date_of_birth: date | None = None
    age_at_menarche: int | None = None
    perimenopause_mode_active: bool | None = None


class ReproductiveStageRequest(BaseModel):
    stage: str


class UserProfileResponse(BaseModel):
    user_id: str
    email: str | None = None
    email_verified: bool = False
    account_mode: str | None = None
    full_name: str | None = None
    date_of_birth: date | None = None
    age_at_menarche: int | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    bmi: float | None = None
    goal: str | None = None
    wearable_type: str | None = None
    timezone: str | None = None
    conditions: dict = Field(default_factory=dict)
    health_conditions: list[str] = Field(default_factory=list)
    privacy_preferences: dict = Field(default_factory=dict)
    onboarding_completed_at: datetime | None = None
    age_band: str | None = None
    perimenopause_mode_active: bool = False
    perimenopause_mode_source: str | None = None
