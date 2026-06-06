from datetime import datetime

from pydantic import BaseModel, Field


# ── Inventory ──────────────────────────────────────────────────────────────────

class WearableAvailabilityResponse(BaseModel):
    sku: str
    product_name: str
    available: bool
    available_stock: int
    low_stock: bool
    low_stock_threshold: int
    price_minor: int
    currency: str
    currency_symbol: str
    display_price: str
    country: str | None = None
    country_code: str | None = None
    availability_reason: str = "in_stock"
    supported_country_codes: list[str] = Field(default_factory=list)


# ── Checkout ───────────────────────────────────────────────────────────────────

class WearableAddonCheckoutRequest(BaseModel):
    country: str = Field(min_length=2)
    plan_id: str = Field(min_length=1)
    interval: str = Field(min_length=1)
    wearable_sku: str = Field(min_length=1)
    shipping_address: "ShippingAddressInput"


class ShippingAddressInput(BaseModel):
    full_name: str = Field(min_length=1)
    line1: str = Field(min_length=1)
    line2: str | None = None
    city: str = Field(min_length=1)
    county: str | None = None
    postcode: str = Field(min_length=1)
    country: str = Field(min_length=2)
    phone: str | None = None


WearableAddonCheckoutRequest.model_rebuild()


class WearableAddonCheckoutResponse(BaseModel):
    payment_intent_client_secret: str
    customer_id: str
    customer_ephemeral_key_secret: str
    publishable_key: str
    customer_email: str | None = None
    provider_subscription_id: str
    plan_id: str
    interval: str
    currency: str
    subscription_amount_minor: int
    wearable_amount_minor: int
    total_amount_minor: int
    display_price: str
    wearable_sku: str
    wearable_name: str


# ── Order ──────────────────────────────────────────────────────────────────────

class TimelineEntry(BaseModel):
    status: str
    title: str
    description: str
    completed_at: str | None = None


class ShippingAddress(BaseModel):
    full_name: str | None = None
    line1: str | None = None
    line2: str | None = None
    city: str | None = None
    county: str | None = None
    postcode: str | None = None
    country: str | None = None
    phone: str | None = None


class WearableOrderResponse(BaseModel):
    id: str
    order_number: str
    wearable_sku: str
    wearable_name: str
    wearable_price: float
    wearable_currency: str
    display_price: str
    payment_status: str
    fulfillment_status: str
    tracking_number: str | None = None
    tracking_url: str | None = None
    courier: str | None = None
    estimated_delivery_date: str | None = None
    shipped_at: str | None = None
    delivered_at: str | None = None
    shipping_address: ShippingAddress
    timeline: list[TimelineEntry] = Field(default_factory=list)
    created_at: str
    updated_at: str


class WearableOrderListResponse(BaseModel):
    orders: list[WearableOrderResponse] = Field(default_factory=list)


# ── Admin ──────────────────────────────────────────────────────────────────────

class AdminWearableOrderListResponse(BaseModel):
    orders: list[WearableOrderResponse] = Field(default_factory=list)
    total: int
    limit: int
    offset: int


class AdminWearableInventoryItem(BaseModel):
    id: str
    sku: str
    product_name: str
    total_stock: int
    available_stock: int
    reserved_stock: int
    low_stock_threshold: int
    low_stock: bool
    price_minor: int
    currency: str
    currency_symbol: str
    display_price: str
    is_active: bool
    allowed_country_codes: list[str] = Field(default_factory=list)
    created_at: str
    updated_at: str


class AdminWearableInventoryResponse(BaseModel):
    items: list[AdminWearableInventoryItem] = Field(default_factory=list)


class AdminWearableAnalyticsResponse(BaseModel):
    total_orders: int
    paid_orders: int
    pending_orders: int
    dispatched_orders: int
    delivered_orders: int
    cancelled_orders: int
    revenue_minor: int
    currency: str
    low_stock_items: int
    active_inventory_items: int
    fulfillment_counts: dict[str, int] = Field(default_factory=dict)
    payment_counts: dict[str, int] = Field(default_factory=dict)


class AdminWearableStatusOptionsResponse(BaseModel):
    fulfillment_statuses: list[str]
    payment_statuses: list[str]


class AdminUpdateFulfillmentRequest(BaseModel):
    fulfillment_status: str = Field(min_length=1)
    tracking_number: str | None = None
    tracking_url: str | None = None
    courier: str | None = None
    estimated_delivery_date: str | None = None


class AdminUpdateInventoryRequest(BaseModel):
    sku: str = Field(min_length=1)
    total_stock: int | None = Field(default=None, ge=0)
    available_stock: int | None = Field(default=None, ge=0)
    price_minor: int | None = Field(default=None, ge=0)
    low_stock_threshold: int | None = Field(default=None, ge=0)
    is_active: bool | None = None
    allowed_country_codes: list[str] | None = None


class AdminUpdateCountryAvailabilityRequest(BaseModel):
    allowed_country_codes: list[str] = Field(min_length=0)
