from typing import Literal

from pydantic import BaseModel, Field, HttpUrl


class BillingPlanPriceOption(BaseModel):
    interval: str
    provider_price_id: str | None = None
    price_minor: int = Field(ge=0)
    display_price: str


class BillingPlanOffer(BaseModel):
    id: str
    name: str
    description: str
    provider: str | None = None
    provider_product_id: str | None = None
    provider_price_id: str | None = None
    price_minor: int = Field(ge=0)
    currency: str
    currency_symbol: str
    display_price: str
    billing_period: str
    highlighted: bool = False
    badge: str | None = None
    cta_label: str
    features: list[str] = Field(default_factory=list)
    price_options: list[BillingPlanPriceOption] = Field(default_factory=list)


class BillingPlanOffersResponse(BaseModel):
    country: str
    normalized_country: str
    supported: bool
    primary_provider: str | None = None
    available_providers: list[str] = Field(default_factory=list)
    provider_configured: bool = False
    checkout_endpoint: str | None = None
    checkout_public_key: str | None = None
    currency: str
    currency_symbol: str
    headline: str = "Choose your plan"
    subheadline: str
    plans: list[BillingPlanOffer] = Field(default_factory=list)


class StripeCheckoutSessionRequest(BaseModel):
    country: str = Field(min_length=2)
    plan_id: Literal["premium_plus"]
    interval: Literal["month", "year"] = "month"
    success_url: HttpUrl | str | None = None
    cancel_url: HttpUrl | str | None = None


class StripeCheckoutSessionResponse(BaseModel):
    provider: Literal["stripe"] = "stripe"
    checkout_session_id: str
    checkout_url: str
    publishable_key: str | None = None
    customer_email: str | None = None
    provider_product_id: str
    provider_price_id: str
    plan_id: Literal["premium_plus"]
    interval: Literal["month", "year"]


class StripePaymentSheetRequest(BaseModel):
    country: str = Field(min_length=2)
    plan_id: Literal["premium_plus"]
    interval: Literal["month", "year"] = "month"


class StripePaymentSheetResponse(BaseModel):
    provider: Literal["stripe"] = "stripe"
    payment_intent_client_secret: str
    customer_id: str
    customer_ephemeral_key_secret: str
    publishable_key: str
    customer_email: str | None = None
    provider_subscription_id: str
    provider_product_id: str
    provider_price_id: str
    plan_id: Literal["premium_plus"]
    interval: Literal["month", "year"]
    currency: str
    amount_minor: int = Field(ge=0)
    display_price: str


class StripePaymentSheetSyncRequest(BaseModel):
    provider_subscription_id: str = Field(min_length=1)


class FlutterwaveCheckoutSessionRequest(BaseModel):
    country: str = Field(min_length=2)
    plan_id: Literal["premium_plus"]
    interval: Literal["month", "year"] = "month"
    redirect_url: HttpUrl | str | None = None


class FlutterwaveCheckoutSessionResponse(BaseModel):
    provider: Literal["flutterwave"] = "flutterwave"
    checkout_url: str
    tx_ref: str
    public_key: str | None = None
    customer_email: str | None = None
    plan_id: Literal["premium_plus"]
    interval: Literal["month", "year"]
    currency: str
    amount_minor: int = Field(ge=0)
    display_price: str


class StripeWebhookResponse(BaseModel):
    status: str = "ok"


class FlutterwaveWebhookResponse(BaseModel):
    status: str = "ok"


class BillingSubscriptionStatusResponse(BaseModel):
    provider: str | None = None
    tier: str = "free"
    status: str = "inactive"
    selection_made: bool = False
    plan_saved: bool = False
    is_active: bool = False
    redirect_to_home: bool = False
    show_subscription_screen: bool = False
    provider_configured: bool = False
    checkout_endpoint: str | None = None
    checkout_public_key: str | None = None
    currency: str | None = None
    amount: float | None = None
    billing_interval: str | None = None
    provider_price_id: str | None = None
    current_period_end: str | None = None


class BillingSubscriptionSelectionRequest(BaseModel):
    tier: Literal["free", "premium_plus"]
    interval: Literal["month", "year"] | None = None
    country: str | None = Field(default=None, min_length=2)


class BillingSubscriptionCancelRequest(BaseModel):
    immediate: bool = False


class FlutterwaveWebhookErrorItem(BaseModel):
    id: str
    event_type: str | None = None
    transaction_id: str | None = None
    tx_ref: str | None = None
    provider_customer_id: str | None = None
    provider_plan_id: str | None = None
    user_id: str | None = None
    error_message: str
    signature_present: bool
    legacy_hash_present: bool
    payload_summary: dict = Field(default_factory=dict)
    created_at: str


class FlutterwaveWebhookErrorListResponse(BaseModel):
    items: list[FlutterwaveWebhookErrorItem] = Field(default_factory=list)
    limit: int = Field(ge=1)
