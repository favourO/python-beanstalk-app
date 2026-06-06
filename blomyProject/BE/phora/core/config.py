from functools import lru_cache
from typing import Literal

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="PHORA_", extra="ignore")

    app_name: str = "phora-api"
    environment: Literal["local", "dev", "stage", "staging", "prod"] = "local"
    api_prefix: str = "/api/v1"
    database_url: str = "sqlite:///./phora.db"
    redis_url: str = "redis://localhost:6379/0"
    broker_url: str = "redis://localhost:6379/1"
    result_backend: str = "redis://localhost:6379/2"
    secret_key: str = "change-me"
    access_token_exp_minutes: int = 365 * 24 * 60
    refresh_token_exp_minutes: int = 365 * 24 * 60
    algorithm: str = "HS256"
    blocked_signup_email_domains: list[str] = Field(default_factory=list)
    api_prefix_legacy: str = "/api/0.1.0"
    ml_enabled: bool = True
    ml_inprocess: bool = True
    ml_base_url: str | None = None
    ml_timeout_ms: int = 5000
    ml_retry_count: int = 2
    ml_shadow_mode: bool = False
    auto_create_tables: bool = True
    health_schema: str = "health"
    billing_schema: str = "billing"
    audit_schema: str = "audit"
    metrics_path: str = "/metrics"
    medical_disclaimer: str = (
        "Vyla is a prediction application. It is not a medical device and must not be used for "
        "clinical, diagnostic, or contraceptive decision-making."
    )
    internal_admin_reload_enabled: bool = False
    request_id_header: str = "x-request-id"
    cors_origins: list[str] = Field(default_factory=lambda: ["*"])
    otp_expiration_minutes: int = 10
    otp_length: int = 6
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_username: str | None = None
    smtp_password: str | None = None
    smtp_from_email: str | None = None
    smtp_from_name: str = "Vyla"
    smtp_use_tls: bool = True
    smtp_use_ssl: bool = False
    smtp_enabled: bool = False
    firebase_project_id: str | None = None
    firebase_credentials_json: str | None = None
    firebase_web_client_id: str | None = None
    firebase_ios_client_id: str | None = None
    firebase_android_client_id: str | None = None
    google_oauth_client_id: str | None = None
    google_health_client_id: str | None = None
    google_health_client_secret: str | None = None
    google_health_redirect_uri: str | None = None
    google_health_oauth_success_redirect: str = "vyla://wearables/google-health?status=connected"
    google_health_oauth_error_redirect: str = "vyla://wearables/google-health?status=error"
    apple_bundle_id: str | None = None
    apple_service_id: str | None = None
    stripe_secret_key: str | None = None
    stripe_publishable_key: str | None = None
    stripe_webhook_secret: str | None = None
    stripe_webhook_tolerance_seconds: int = 300
    stripe_checkout_success_url: str | None = None
    stripe_checkout_cancel_url: str | None = None
    africa_free_launch_enabled: bool = Field(
        default=False,
        validation_alias=AliasChoices("AFRICA_FREE_LAUNCH_ENABLED", "PHORA_AFRICA_FREE_LAUNCH_ENABLED"),
    )
    africa_free_launch_country_codes: list[str] = Field(
        default_factory=lambda: [
            "DZ", "AO", "BJ", "BW", "BF", "BI", "CV", "CM", "CF", "TD",
            "KM", "CG", "CD", "CI", "DJ", "EG", "GQ", "ER", "SZ", "ET",
            "GA", "GM", "GH", "GN", "GW", "KE", "LS", "LR", "LY", "MG",
            "MW", "ML", "MR", "MU", "MA", "MZ", "NA", "NE", "NG", "RW",
            "ST", "SN", "SC", "SL", "SO", "ZA", "SS", "SD", "TZ", "TG",
            "TN", "UG", "ZM", "ZW",
        ],
        validation_alias=AliasChoices("AFRICA_FREE_LAUNCH_COUNTRY_CODES", "PHORA_AFRICA_FREE_LAUNCH_COUNTRY_CODES"),
    )
    local_currency_pricing_enabled: bool = Field(
        default=True,
        validation_alias=AliasChoices("LOCAL_CURRENCY_PRICING_ENABLED", "PHORA_LOCAL_CURRENCY_PRICING_ENABLED"),
    )
    default_pricing_country: str = Field(
        default="GB",
        validation_alias=AliasChoices("DEFAULT_PRICING_COUNTRY", "PHORA_DEFAULT_PRICING_COUNTRY"),
    )
    default_currency: str = Field(
        default="GBP",
        validation_alias=AliasChoices("DEFAULT_CURRENCY", "PHORA_DEFAULT_CURRENCY"),
    )
    llm_api_key: str | None = None
    llm_base_url: str = "https://api.openai.com/v1"
    llm_model: str = "gpt-4.1-mini"
    llm_timeout_seconds: int = 20
    public_app_url: str | None = None
    report_share_bucket: str | None = None
    report_share_url_expiration_seconds: int = 60 * 60 * 24 * 7
    android_release_bucket: str | None = None
    android_release_manifest_key: str = "android/latest.json"
    android_release_presign_expiration_seconds: int = 60 * 60
    android_download_url: str | None = None
    enable_apple_health_predictions: bool = False


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
