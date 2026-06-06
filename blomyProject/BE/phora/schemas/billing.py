from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, HttpUrl


class PricingEligibilityRequest(BaseModel):
    country: str | None = Field(default=None, min_length=2)
    device_locale_country: str | None = Field(default=None, min_length=2)
    device_location_country: str | None = Field(default=None, min_length=2)
    app_store_country: str | None = Field(default=None, min_length=2)
    play_store_country: str | None = Field(default=None, min_length=2)
    phone_number: str | None = None
    billing_country: str | None = Field(default=None, min_length=2)
    ip_country: str | None = Field(default=None, min_length=2)


class PricingEligibilityResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    is_free_region: bool = Field(default=False, alias="isFreeRegion")
    requires_payment: bool = Field(default=True, alias="requiresPayment")
    country: str | None = None
    currency: str | None = None
    pricing_tier: str | None = Field(default=None, alias="pricingTier")
    pricing_strategy: str | None = Field(default=None, alias="pricingStrategy")
    plan_type: str | None = Field(default=None, alias="planType")
    pricing_rule: str = Field(default="standard_paid_pricing", alias="pricingRule")
    free_launch_plan_id: str | None = Field(default=None, alias="freeLaunchPlanId")
    monthly: dict | None = None
    yearly: dict | None = None
    fallback_applied: bool = Field(default=False, alias="fallbackApplied")
    fallback_reason: str | None = Field(default=None, alias="fallbackReason")
    review_flagged: bool = Field(default=False, alias="reviewFlagged")
    reason: str


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
    model_config = ConfigDict(populate_by_name=True)

    country: str
    normalized_country: str
    supported: bool
    is_free_region: bool = Field(default=False, alias="isFreeRegion")
    requires_payment: bool = Field(default=True, alias="requiresPayment")
    pricing_rule: str = Field(default="standard_paid_pricing", alias="pricingRule")
    pricing_tier: str | None = Field(default=None, alias="pricingTier")
    pricing_strategy: str | None = Field(default=None, alias="pricingStrategy")
    plan_type: str | None = Field(default=None, alias="planType")
    free_launch_plan_id: str | None = Field(default=None, alias="freeLaunchPlanId")
    monthly: dict | None = None
    yearly: dict | None = None
    fallback_applied: bool = Field(default=False, alias="fallbackApplied")
    fallback_reason: str | None = Field(default=None, alias="fallbackReason")
    review_flagged: bool = Field(default=False, alias="reviewFlagged")
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
    device_locale_country: str | None = Field(default=None, min_length=2)
    device_location_country: str | None = Field(default=None, min_length=2)
    app_store_country: str | None = Field(default=None, min_length=2)
    play_store_country: str | None = Field(default=None, min_length=2)
    phone_number: str | None = None
    billing_country: str | None = Field(default=None, min_length=2)
    ip_country: str | None = Field(default=None, min_length=2)
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
    device_locale_country: str | None = Field(default=None, min_length=2)
    device_location_country: str | None = Field(default=None, min_length=2)
    app_store_country: str | None = Field(default=None, min_length=2)
    play_store_country: str | None = Field(default=None, min_length=2)
    phone_number: str | None = None
    billing_country: str | None = Field(default=None, min_length=2)
    ip_country: str | None = Field(default=None, min_length=2)


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


class StripeWebhookResponse(BaseModel):
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
    cancel_at_period_end: bool = False
    pending_billing_interval: str | None = None
    pending_provider_price_id: str | None = None
    pending_amount: float | None = None
    pending_currency: str | None = None
    pending_change_effective_at: str | None = None


class BillingSubscriptionSelectionRequest(BaseModel):
    tier: Literal["free", "premium_plus"]
    interval: Literal["month", "year"] | None = None
    country: str | None = Field(default=None, min_length=2)
    device_locale_country: str | None = Field(default=None, min_length=2)
    device_location_country: str | None = Field(default=None, min_length=2)
    app_store_country: str | None = Field(default=None, min_length=2)
    play_store_country: str | None = Field(default=None, min_length=2)
    phone_number: str | None = None
    billing_country: str | None = Field(default=None, min_length=2)
    ip_country: str | None = Field(default=None, min_length=2)


class BillingSubscriptionCancelRequest(BaseModel):
    immediate: bool = False


class BillingSubscriptionIntervalChangeRequest(BaseModel):
    country: str = Field(min_length=2)
    interval: Literal["month", "year"]


class BillingSubscriptionIntervalChangeResponse(BaseModel):
    status: str = "scheduled"
    interval: Literal["month", "year"]
    current_period_end: str | None = None
    pending_billing_interval: str | None = None
    pending_change_effective_at: str | None = None


class BillingSubscriptionIntervalChangeCancelResponse(BaseModel):
    status: str = "canceled"
    current_period_end: str | None = None


class BillingInvoiceItem(BaseModel):
    id: str
    item_type: str = "payment"
    provider_invoice_id: str | None = None
    title: str | None = None
    subtitle: str | None = None
    action_url: str | None = None
    amount_label: str
    status: str
    created_at: str


class BillingInvoiceListResponse(BaseModel):
    items: list[BillingInvoiceItem] = Field(default_factory=list)

