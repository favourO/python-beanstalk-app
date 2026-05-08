from enum import Enum
from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

from phora.schemas.onboarding import OnboardingProgressPayload


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    totp_code: str | None = Field(default=None, min_length=6, max_length=8)


class RecoveryPhraseLoginRequest(BaseModel):
    recovery_phrase: str = Field(min_length=16)
    totp_code: str | None = Field(default=None, min_length=6, max_length=8)


class SocialProvider(str, Enum):
    google = "google"
    facebook = "facebook"
    apple = "apple"


class SignupMethod(str, Enum):
    email = "email"
    google = "google"
    apple = "apple"


class SignupConsents(BaseModel):
    terms_accepted: bool | None = None
    privacy_policy_accepted: bool | None = None

    @property
    def accepted(self) -> bool:
        return self.terms_accepted is True and self.privacy_policy_accepted is True


class SignupRequest(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    country: str
    account_type: str
    birth_date: date | None = None
    signup_method: SignupMethod = SignupMethod.email
    consents: SignupConsents | None = None
    registration_context: dict[str, Any] = Field(default_factory=dict)

    @field_validator("birth_date")
    @classmethod
    def validate_birth_date(cls, value: date | None) -> date | None:
        if value is not None and value >= date.today():
            raise ValueError("birth_date must be a past date")
        return value

    @model_validator(mode="after")
    def validate_consents(self) -> "SignupRequest":
        if self.consents and not self.consents.accepted:
            raise ValueError("terms_accepted and privacy_policy_accepted must both be true")
        return self


class VerifyRequest(BaseModel):
    email: EmailStr
    code: str


class ResendOtpRequest(BaseModel):
    email: EmailStr
    purpose: str = "signup_verification"


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str = "If we find a matching account, we’ll send reset instructions."


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=8)
    new_password: str = Field(min_length=8, max_length=128)


class ResetPasswordResponse(BaseModel):
    message: str = "Password reset successful. You can now log in."


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class ChangePasswordResponse(BaseModel):
    message: str = "Password updated successfully."


class AuthUserResponse(BaseModel):
    id: str
    email: EmailStr
    first_name: str | None = None
    last_name: str | None = None
    country: str | None = None
    account_type: str | None = None
    email_verified: bool


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshTokenRequest(BaseModel):
    refresh_token: str | None = None


class AnonymousRegisterResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    recovery_phrase: str


class AnonymousLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AuthResponse(TokenPair):
    user: AuthUserResponse
    is_new_user: bool = False
    show_premium_screen: bool = False
    onboarding_completed: bool = False
    onboarding_current_step: int | None = None
    onboarding_progress: OnboardingProgressPayload | None = None
    show_onboarding_flow: bool = False
    subscription_selected: bool = False
    show_subscription_screen: bool = False
    subscription_tier: str = "free"
    subscription_active: bool = False
    subscription_interval: str | None = None
    mfa_required: bool = False


class SignupResponse(BaseModel):
    message: str


class SignoutResponse(BaseModel):
    message: str = "Signed out successfully."


class PendingVerificationResponse(BaseModel):
    requires_verification: bool = True
    email: str
    message: str = "Email not verified. A new verification code has been sent."


class SocialSignupMetadata(BaseModel):
    account_type: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    country: str | None = None
    birth_date: date | None = None
    signup_method: SignupMethod | None = None
    consents: SignupConsents | None = None
    registration_context: dict[str, Any] = Field(default_factory=dict)

    @field_validator("birth_date")
    @classmethod
    def validate_birth_date(cls, value: date | None) -> date | None:
        if value is not None and value >= date.today():
            raise ValueError("birth_date must be a past date")
        return value


class FirebaseLoginRequest(SocialSignupMetadata):
    provider: SocialProvider
    id_token: str = Field(min_length=20)
    totp_code: str | None = Field(default=None, min_length=6, max_length=8)

    @model_validator(mode="before")
    @classmethod
    def normalize_provider(cls, data: Any):
        if isinstance(data, dict):
            provider = data.get("provider")
            if isinstance(provider, str):
                normalized = provider.strip().lower()
                if normalized.endswith(".com"):
                    normalized = normalized.split(".")[0]
                data["provider"] = normalized
        return data


class GoogleLoginRequest(SocialSignupMetadata):
    id_token: str = Field(min_length=20)
    totp_code: str | None = Field(default=None, min_length=6, max_length=8)


class AppleLoginRequest(SocialSignupMetadata):
    id_token: str = Field(min_length=20)
    totp_code: str | None = Field(default=None, min_length=6, max_length=8)


class TOTPSetupStartResponse(BaseModel):
    message: str
    manual_entry_key: str
    otpauth_uri: str


class TOTPCodeVerifyRequest(BaseModel):
    code: str = Field(min_length=6, max_length=8)


class TOTPStatusResponse(BaseModel):
    configured: bool
    enabled: bool
    confirmed_at: datetime | None = None
    last_used_at: datetime | None = None


class TOTPToggleResponse(BaseModel):
    message: str
    enabled: bool
