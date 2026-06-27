import json
import logging
from datetime import UTC, datetime
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel
from fastapi.responses import RedirectResponse
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_settings_dep
from phora.core.config import Settings
from phora.db.session import get_db
from phora.models import BillingActivity, Invoice, Subscription, StripeWebhookErrorLog, User
from phora.models.wearable_commerce import WearableOrder
from phora.schemas.billing import (
    BillingInvoiceItem,
    BillingInvoiceListResponse,
    BillingSubscriptionIntervalChangeCancelResponse,
    BillingSubscriptionIntervalChangeRequest,
    BillingSubscriptionIntervalChangeResponse,
    BillingSubscriptionCancelRequest,
    BillingSubscriptionStatusResponse,
    BillingPlanOffersResponse,
    PricingEligibilityRequest,
    PricingEligibilityResponse,
    BillingSubscriptionSelectionRequest,
    StripeCheckoutSessionRequest,
    StripeCheckoutSessionResponse,
    StripePaymentSheetRequest,
    StripePaymentSheetResponse,
    StripePaymentSheetSyncRequest,
    StripeWebhookResponse,
)
from phora.services.apple_billing import APPLE_PRODUCT_INTERVAL, AppleBillingError, AppleBillingService
from phora.services.billing_catalog import PRICING_STRATEGY, build_plan_offers, resolve_billing_price
from phora.services.premium_access import PremiumAccessService
from phora.services.pricing_eligibility import PricingEligibilityDecision, PricingEligibilityService
from phora.services.stripe_billing import StripeBillingError, StripeBillingService, StripeWebhookError

router = APIRouter(prefix="/billing", tags=["billing"])
admin_router = APIRouter(prefix="/admin/billing", tags=["admin-billing"])
_log = logging.getLogger(__name__)

_ACTIVE_SUBSCRIPTION_STATUSES = {"active", "trialing"}
_ACTIVE_BILLING_PROVIDERS = {"stripe", "africa_free_launch", "apple_iap"}


def _provider_checkout_details(settings: Settings, provider: str | None) -> tuple[bool, str | None, str | None]:
    if provider == "stripe":
        return (
            bool(settings.stripe_secret_key and settings.stripe_publishable_key),
            "/api/v1/billing/stripe/payment-sheet",
            settings.stripe_publishable_key,
        )
    return True, None, None


def _append_query_value(url: str, key: str, value: str) -> str:
    parsed = urlparse(url)
    query = parse_qsl(parsed.query, keep_blank_values=True)
    query.append((key, value))
    return urlunparse(parsed._replace(query=urlencode(query)))


def _inject_session_id(url: str, session_id: str) -> str:
    placeholder = "{CHECKOUT_SESSION_ID}"
    if placeholder in url:
        return url.replace(placeholder, session_id)
    return _append_query_value(url, "session_id", session_id)


def _normalize_stripe_redirect_url(request: Request, url: str | None, *, success: bool) -> str | None:
    if not url:
        return None

    parsed = urlparse(url)
    if parsed.scheme in {"http", "https"} or not parsed.scheme:
        return url

    endpoint = "stripe_checkout_return_success" if success else "stripe_checkout_return_cancel"
    callback_url = str(request.url_for(endpoint))
    callback_url = _append_query_value(callback_url, "target", url)
    if success:
        callback_url = _append_query_value(callback_url, "session_id", "{CHECKOUT_SESSION_ID}")
    return callback_url


def _latest_subscription(db: Session, user_id: str) -> Subscription | None:
    return (
        db.query(Subscription)
        .filter(Subscription.user_id == user_id)
        .order_by(Subscription.created_at.desc())
        .first()
    )


def _subscription_has_active_access(subscription: Subscription) -> bool:
    if subscription.tier == "free":
        return True
    if subscription.provider not in _ACTIVE_BILLING_PROVIDERS:
        return False
    if subscription.status in _ACTIVE_SUBSCRIPTION_STATUSES:
        return True
    if subscription.status in {"canceled", "cancelled"} and subscription.current_period_end:
        current_period_end = subscription.current_period_end
        if current_period_end.tzinfo is None:
            current_period_end = current_period_end.replace(tzinfo=UTC)
        return current_period_end > datetime.now(UTC)
    return False


def _pending_change_fields(subscription: Subscription) -> dict[str, str | float | None]:
    effective_at = subscription.pending_change_effective_at
    if effective_at and effective_at.tzinfo is None:
        effective_at = effective_at.replace(tzinfo=UTC)
    if (
        subscription.pending_billing_interval
        and effective_at
        and effective_at > datetime.now(UTC)
    ):
        return {
            "pending_billing_interval": subscription.pending_billing_interval,
            "pending_provider_price_id": subscription.pending_provider_price_id,
            "pending_amount": subscription.pending_amount,
            "pending_currency": subscription.pending_currency,
            "pending_change_effective_at": effective_at.isoformat(),
        }
    return {
        "pending_billing_interval": None,
        "pending_provider_price_id": None,
        "pending_amount": None,
        "pending_currency": None,
        "pending_change_effective_at": None,
    }


def _format_invoice_amount(total: float, currency: str | None) -> str:
    symbol = {
        "GBP": "£",
        "USD": "$",
        "EUR": "€",
        "NGN": "₦",
    }.get((currency or "").upper(), (currency or "").upper())
    separator = "" if len(symbol) == 1 else " "
    return f"{symbol}{separator}{total:.2f}"


def _wearable_order_action_url(order: WearableOrder | None) -> str | None:
    if order is None:
        return None
    if order.fulfillment_status == "delivered":
        return f"/wearable/orders/{order.id}/delivered"
    if order.fulfillment_status in {"dispatched", "out_for_delivery"}:
        return f"/wearable/orders/{order.id}/tracking"
    return f"/wearable/orders/{order.id}"


def _interval_plan_label(interval: str | None) -> str:
    normalized = (interval or "").strip().lower()
    if normalized in {"year", "annual", "yearly"}:
        return "Premium Annual"
    if normalized in {"month", "monthly"}:
        return "Premium Monthly"
    return "Premium"


def _format_billing_date(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.date().isoformat()


def _record_billing_activity(
    db: Session,
    subscription: Subscription,
    *,
    event_type: str,
    title: str,
    subtitle: str | None = None,
) -> None:
    db.add(
        BillingActivity(
            user_id=subscription.user_id,
            subscription_id=subscription.id,
            event_type=event_type,
            title=title,
            subtitle=subtitle,
        )
    )


def _record_billing_activity_best_effort(
    db: Session,
    subscription: Subscription,
    *,
    event_type: str,
    title: str,
    subtitle: str | None = None,
) -> None:
    try:
        _record_billing_activity(
            db,
            subscription,
            event_type=event_type,
            title=title,
            subtitle=subtitle,
        )
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        _log.exception("Failed to record billing activity %s for subscription %s", event_type, subscription.id)
        try:
            db.refresh(subscription)
        except SQLAlchemyError:
            db.rollback()


def _require_admin_user(db: Session, user_id: str) -> User:
    user = db.query(User).filter(User.id == user_id).one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


def _subscription_response_flags(subscription: Subscription | None) -> tuple[bool, bool, bool]:
    if not subscription:
        return False, False, True
    selection_made = subscription.tier in {"free", "premium_plus"}
    is_active = _subscription_has_active_access(subscription)
    redirect_to_home = is_active
    show_subscription_screen = not is_active
    return selection_made, redirect_to_home, show_subscription_screen


def _is_removed_payment_provider(subscription: Subscription) -> bool:
    return subscription.tier != "free" and subscription.provider not in _ACTIVE_BILLING_PROVIDERS


def _pricing_payload(country: str | None) -> BillingPlanOffersResponse:
    return build_plan_offers(country=country or "GB", include_free=True)


def _eligibility_response(decision: PricingEligibilityDecision) -> PricingEligibilityResponse:
    pricing = _pricing_payload(decision.country)
    return PricingEligibilityResponse(
        is_free_region=decision.is_free_region,
        requires_payment=decision.requires_payment,
        country=decision.country,
        currency=None if decision.is_free_region else pricing.currency,
        pricing_tier="AFRICA_FREE_LAUNCH" if decision.is_free_region else pricing.pricing_tier,
        pricing_strategy=PRICING_STRATEGY,
        plan_type=decision.plan_type,
        pricing_rule=decision.pricing_rule,
        free_launch_plan_id=decision.free_launch_plan_id,
        monthly=None if decision.is_free_region else pricing.monthly,
        yearly=None if decision.is_free_region else pricing.yearly,
        fallback_applied=False if decision.is_free_region else pricing.fallback_applied,
        fallback_reason=None if decision.is_free_region else pricing.fallback_reason,
        review_flagged=decision.review_flagged,
        reason=decision.reason,
    )


def _subscription_status_response(
    *,
    settings: Settings,
    subscription: Subscription,
    is_active: bool | None = None,
) -> BillingSubscriptionStatusResponse:
    configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, subscription.provider)
    selection_made, redirect_to_home, show_subscription_screen = _subscription_response_flags(subscription)
    return BillingSubscriptionStatusResponse(
        provider=subscription.provider,
        tier=subscription.tier,
        status=subscription.status,
        selection_made=selection_made,
        plan_saved=selection_made,
        is_active=_subscription_has_active_access(subscription) if is_active is None else is_active,
        redirect_to_home=redirect_to_home,
        show_subscription_screen=show_subscription_screen,
        provider_configured=configured,
        checkout_endpoint=checkout_endpoint,
        checkout_public_key=checkout_public_key,
        currency=subscription.currency,
        amount=subscription.amount,
        billing_interval=subscription.billing_interval,
        provider_price_id=subscription.provider_price_id,
        current_period_end=subscription.current_period_end.isoformat() if subscription.current_period_end else None,
        cancel_at_period_end=subscription.cancel_at_period_end,
        **_pending_change_fields(subscription),
    )


@router.get("/plan-offers", response_model=BillingPlanOffersResponse)
def get_plan_offers(
    request: Request,
    country: str = Query(min_length=2),
    include_free: bool = True,
    device_locale_country: str | None = None,
    device_location_country: str | None = None,
    app_store_country: str | None = None,
    play_store_country: str | None = None,
    billing_country: str | None = None,
    ip_country: str | None = None,
    settings: Settings = Depends(get_settings_dep),
    db: Session = Depends(get_db),
) -> BillingPlanOffersResponse:
    decision = PricingEligibilityService(db, settings).evaluate(
        request=request,
        country=country,
        device_locale_country=device_locale_country,
        device_location_country=device_location_country,
        app_store_country=app_store_country,
        play_store_country=play_store_country,
        billing_country=billing_country,
        ip_country=ip_country,
    )
    response = build_plan_offers(country=decision.country or country, include_free=include_free)
    response.is_free_region = decision.is_free_region
    response.requires_payment = decision.requires_payment
    response.pricing_rule = decision.pricing_rule
    response.plan_type = decision.plan_type
    response.free_launch_plan_id = decision.free_launch_plan_id
    response.review_flagged = decision.review_flagged
    if decision.is_free_region:
        response.supported = True
        response.pricing_tier = "AFRICA_FREE_LAUNCH"
        response.currency = "FREE"
        response.currency_symbol = ""
        response.monthly = None
        response.yearly = None
        response.fallback_applied = False
        response.fallback_reason = None
        response.primary_provider = None
        response.available_providers = []
        response.subheadline = "Free launch access is available in your region"
    elif response.fallback_applied:
        PricingEligibilityService(db, settings).log_pricing_fallback(
            user_id=None,
            resolved_country=decision.country or country,
            reason=response.fallback_reason or "default_pricing_fallback",
        )
    configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, response.primary_provider)
    response.provider_configured = configured
    response.checkout_endpoint = checkout_endpoint
    response.checkout_public_key = checkout_public_key
    return response


@router.post("/pricing-eligibility", response_model=PricingEligibilityResponse)
def check_pricing_eligibility(
    request: Request,
    payload: PricingEligibilityRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> PricingEligibilityResponse:
    decision = PricingEligibilityService(db, settings).evaluate(
        user_id=user_id,
        request=request,
        country=payload.country,
        device_locale_country=payload.device_locale_country,
        device_location_country=payload.device_location_country,
        app_store_country=payload.app_store_country,
        play_store_country=payload.play_store_country,
        phone_number=payload.phone_number,
        billing_country=payload.billing_country,
        ip_country=payload.ip_country,
    )
    if decision.is_free_region:
        PricingEligibilityService(db, settings).grant_free_launch_access(
            user_id=user_id,
            country=decision.country,
        )
    return _eligibility_response(decision)


@router.get("/subscription", response_model=BillingSubscriptionStatusResponse)
def get_subscription_status(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionStatusResponse:
    access = PremiumAccessService(db).status(user_id)
    subscription = _latest_subscription(db, user_id)
    if not subscription:
        configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, None)
        return BillingSubscriptionStatusResponse(
            tier=access.tier,
            status="active" if access.is_active else "inactive",
            selection_made=access.is_active,
            plan_saved=access.is_active,
            is_active=access.is_active,
            redirect_to_home=access.is_active,
            show_subscription_screen=not access.is_active,
            provider_configured=configured,
            checkout_endpoint=checkout_endpoint,
            checkout_public_key=checkout_public_key,
            current_period_end=access.current_period_end.isoformat() if access.current_period_end else None,
        )
    if _is_removed_payment_provider(subscription):
        configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, None)
        return BillingSubscriptionStatusResponse(
            tier="free",
            status="inactive",
            selection_made=False,
            plan_saved=False,
            is_active=False,
            redirect_to_home=False,
            show_subscription_screen=True,
            provider_configured=configured,
            checkout_endpoint=checkout_endpoint,
            checkout_public_key=checkout_public_key,
        )
    configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, subscription.provider)
    selection_made, redirect_to_home, show_subscription_screen = _subscription_response_flags(subscription)
    is_active = access.is_active
    return BillingSubscriptionStatusResponse(
        provider=access.provider or subscription.provider,
        tier=access.tier,
        status=access.status,
        selection_made=selection_made,
        plan_saved=selection_made,
        is_active=is_active,
        redirect_to_home=redirect_to_home,
        show_subscription_screen=show_subscription_screen,
        provider_configured=configured,
        checkout_endpoint=checkout_endpoint,
        checkout_public_key=checkout_public_key,
        currency=access.currency or subscription.currency,
        amount=access.amount if access.amount is not None else subscription.amount,
        billing_interval=access.billing_interval or subscription.billing_interval,
        provider_price_id=access.provider_price_id or subscription.provider_price_id,
        current_period_end=access.current_period_end.isoformat() if access.current_period_end else (subscription.current_period_end.isoformat() if subscription.current_period_end else None),
        cancel_at_period_end=subscription.cancel_at_period_end,
        **_pending_change_fields(subscription),
    )


@router.post("/subscription/cancel", response_model=BillingSubscriptionStatusResponse)
def cancel_subscription(
    payload: BillingSubscriptionCancelRequest = Body(default_factory=BillingSubscriptionCancelRequest),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionStatusResponse:
    subscription = _latest_subscription(db, user_id)
    if not subscription or subscription.tier == "free":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No paid subscription to cancel.")

    try:
        if subscription.provider == "stripe":
            StripeBillingService(db, settings).cancel_subscription(subscription, immediate=payload.immediate)
        else:
            subscription.status = "canceled"
            subscription.current_period_end = None
            subscription.cancel_at_period_end = False
    except StripeBillingError as exc:
        detail = str(exc)
        status_code = status.HTTP_503_SERVICE_UNAVAILABLE if "not configured" in detail.lower() else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=detail) from exc

    db.commit()
    period = _format_billing_date(subscription.current_period_end)
    _record_billing_activity_best_effort(
        db,
        subscription,
        event_type="subscription_cancellation_scheduled",
        title="Subscription cancellation scheduled",
        subtitle=(
            f"{_interval_plan_label(subscription.billing_interval)} access continues until {period}."
            if period
            else "Premium access continues until the end of your current billing period."
        ),
    )
    configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, subscription.provider)
    selection_made, redirect_to_home, show_subscription_screen = _subscription_response_flags(subscription)
    is_active = _subscription_has_active_access(subscription)
    return BillingSubscriptionStatusResponse(
        provider=subscription.provider,
        tier=subscription.tier,
        status=subscription.status,
        selection_made=selection_made,
        plan_saved=selection_made,
        is_active=is_active,
        redirect_to_home=redirect_to_home,
        show_subscription_screen=show_subscription_screen,
        provider_configured=configured,
        checkout_endpoint=checkout_endpoint,
        checkout_public_key=checkout_public_key,
        currency=subscription.currency,
        amount=subscription.amount,
        billing_interval=subscription.billing_interval,
        provider_price_id=subscription.provider_price_id,
        current_period_end=subscription.current_period_end.isoformat() if subscription.current_period_end else None,
        cancel_at_period_end=subscription.cancel_at_period_end,
        **_pending_change_fields(subscription),
    )


@router.post("/subscription/restart", response_model=BillingSubscriptionStatusResponse)
def restart_subscription(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionStatusResponse:
    subscription = _latest_subscription(db, user_id)
    if not subscription or subscription.tier == "free":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No paid subscription to restart.")
    if not subscription.cancel_at_period_end:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Subscription renewal is already active.")

    try:
        if subscription.provider == "stripe":
            StripeBillingService(db, settings).restart_subscription(subscription)
        else:
            subscription.cancel_at_period_end = False
            if subscription.status in {"canceled", "cancelled"} and subscription.current_period_end:
                subscription.status = "active"
    except StripeBillingError as exc:
        detail = str(exc)
        status_code = status.HTTP_503_SERVICE_UNAVAILABLE if "not configured" in detail.lower() else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=detail) from exc

    db.commit()
    _record_billing_activity_best_effort(
        db,
        subscription,
        event_type="subscription_restarted",
        title="Subscription restarted",
        subtitle=f"{_interval_plan_label(subscription.billing_interval)} will renew as normal.",
    )
    configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, subscription.provider)
    selection_made, redirect_to_home, show_subscription_screen = _subscription_response_flags(subscription)
    is_active = _subscription_has_active_access(subscription)
    return BillingSubscriptionStatusResponse(
        provider=subscription.provider,
        tier=subscription.tier,
        status=subscription.status,
        selection_made=selection_made,
        plan_saved=selection_made,
        is_active=is_active,
        redirect_to_home=redirect_to_home,
        show_subscription_screen=show_subscription_screen,
        provider_configured=configured,
        checkout_endpoint=checkout_endpoint,
        checkout_public_key=checkout_public_key,
        currency=subscription.currency,
        amount=subscription.amount,
        billing_interval=subscription.billing_interval,
        provider_price_id=subscription.provider_price_id,
        current_period_end=subscription.current_period_end.isoformat() if subscription.current_period_end else None,
        cancel_at_period_end=subscription.cancel_at_period_end,
        **_pending_change_fields(subscription),
    )


@router.get("/invoices", response_model=BillingInvoiceListResponse)
def list_billing_invoices(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> BillingInvoiceListResponse:
    subscriptions = (
        db.query(Subscription)
        .filter(Subscription.user_id == user_id)
        .all()
    )
    subscription_ids = [subscription.id for subscription in subscriptions]
    if not subscription_ids:
        return BillingInvoiceListResponse(items=[])

    invoices = (
        db.query(Invoice)
        .filter(Invoice.subscription_id.in_(subscription_ids))
        .filter(Invoice.total > 0)
        .order_by(Invoice.created_at.desc())
        .limit(50)
        .all()
    )
    invoice_payment_intents = [
        invoice.provider_payment_intent_id
        for invoice in invoices
        if invoice.provider_payment_intent_id
    ]
    wearable_order_query = db.query(WearableOrder).filter(
        WearableOrder.user_id == user_id,
    )
    if invoice_payment_intents:
        wearable_order_query = wearable_order_query.filter(
            WearableOrder.provider_payment_intent_id.in_(invoice_payment_intents)
            | WearableOrder.subscription_id.in_(subscription_ids)
        )
    else:
        wearable_order_query = wearable_order_query.filter(
            WearableOrder.subscription_id.in_(subscription_ids)
        )
    wearable_orders = wearable_order_query.all()
    wearable_order_by_payment_intent = {
        order.provider_payment_intent_id: order
        for order in wearable_orders
        if order.provider_payment_intent_id
    }
    wearable_order_by_subscription = {
        order.subscription_id: order
        for order in wearable_orders
        if order.subscription_id
    }
    activities = (
        db.query(BillingActivity)
        .filter(BillingActivity.user_id == user_id)
        .order_by(BillingActivity.created_at.desc())
        .limit(50)
        .all()
    )
    items: list[BillingInvoiceItem] = [
        BillingInvoiceItem(
            id=invoice.id,
            item_type="payment",
            provider_invoice_id=invoice.provider_invoice_id,
            title="Payment received",
            subtitle="View order details"
            if (
                invoice.provider_payment_intent_id in wearable_order_by_payment_intent
                or invoice.subscription_id in wearable_order_by_subscription
            )
            else None,
            action_url=_wearable_order_action_url(
                wearable_order_by_payment_intent.get(invoice.provider_payment_intent_id or "")
                or wearable_order_by_subscription.get(invoice.subscription_id or "")
            ),
            amount_label=_format_invoice_amount(invoice.total, invoice.currency),
            status=invoice.status,
            created_at=invoice.created_at.isoformat(),
        )
        for invoice in invoices
    ]
    items.extend(
        BillingInvoiceItem(
            id=activity.id,
            item_type="event",
            title=activity.title,
            subtitle=activity.subtitle,
            amount_label="No charge",
            status=activity.event_type,
            created_at=activity.created_at.isoformat(),
        )
        for activity in activities
    )
    items.sort(key=lambda item: item.created_at, reverse=True)
    return BillingInvoiceListResponse(
        items=items[:50]
    )


@router.post(
    "/subscription/change-interval",
    response_model=BillingSubscriptionIntervalChangeResponse,
)
def change_subscription_interval(
    payload: BillingSubscriptionIntervalChangeRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionIntervalChangeResponse:
    subscription = _latest_subscription(db, user_id)
    if not subscription or subscription.tier == "free":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No paid subscription to update.",
        )
    if subscription.provider != "stripe":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Plan changes are currently available for Stripe subscriptions only.",
        )

    try:
        StripeBillingService(db, settings).change_subscription_interval(
            subscription,
            country=payload.country,
            interval=payload.interval,
        )
    except (StripeBillingError, ValueError) as exc:
        detail = str(exc)
        status_code = (
            status.HTTP_503_SERVICE_UNAVAILABLE
            if "not configured" in detail.lower()
            else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(status_code=status_code, detail=detail) from exc

    db.commit()
    effective = _format_billing_date(subscription.pending_change_effective_at)
    _record_billing_activity_best_effort(
        db,
        subscription,
        event_type="plan_change_scheduled",
        title="Plan change scheduled",
        subtitle=(
            f"{_interval_plan_label(subscription.billing_interval)} continues until {effective}. "
            f"{_interval_plan_label(subscription.pending_billing_interval)} starts after that."
            if effective
            else f"{_interval_plan_label(subscription.pending_billing_interval)} starts after your current paid period."
        ),
    )
    return BillingSubscriptionIntervalChangeResponse(
        interval=payload.interval,
        current_period_end=(
            subscription.current_period_end.isoformat()
            if subscription.current_period_end
            else None
        ),
        pending_billing_interval=subscription.pending_billing_interval,
        pending_change_effective_at=(
            subscription.pending_change_effective_at.isoformat()
            if subscription.pending_change_effective_at
            else None
        ),
    )


@router.post(
    "/subscription/change-interval/cancel",
    response_model=BillingSubscriptionIntervalChangeCancelResponse,
)
def cancel_subscription_interval_change(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionIntervalChangeCancelResponse:
    subscription = _latest_subscription(db, user_id)
    if not subscription or subscription.tier == "free":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No paid subscription to update.",
        )
    if not subscription.pending_billing_interval:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No scheduled plan change to cancel.",
        )
    if subscription.provider != "stripe":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Plan changes are currently available for Stripe subscriptions only.",
        )

    try:
        StripeBillingService(db, settings).cancel_scheduled_interval_change(
            subscription,
        )
    except (StripeBillingError, ValueError) as exc:
        detail = str(exc)
        status_code = (
            status.HTTP_503_SERVICE_UNAVAILABLE
            if "not configured" in detail.lower()
            else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(status_code=status_code, detail=detail) from exc

    db.commit()
    _record_billing_activity_best_effort(
        db,
        subscription,
        event_type="plan_change_canceled",
        title="Scheduled plan change canceled",
        subtitle=f"{_interval_plan_label(subscription.billing_interval)} will continue.",
    )
    return BillingSubscriptionIntervalChangeCancelResponse(
        current_period_end=(
            subscription.current_period_end.isoformat()
            if subscription.current_period_end
            else None
        ),
    )


@router.post("/subscription-selection", response_model=BillingSubscriptionStatusResponse)
def save_subscription_selection(
    request: Request,
    payload: BillingSubscriptionSelectionRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionStatusResponse:
    subscription = _latest_subscription(db, user_id)
    # Do not let a stale client-side free-plan selection overwrite an existing
    # paid subscription while the user still has premium access.
    if (
        payload.tier == "free"
        and subscription
        and subscription.tier != "free"
        and (
            subscription.status in {"active", "trialing"}
            or _subscription_has_active_access(subscription)
        )
    ):
        configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, subscription.provider)
        selection_made, redirect_to_home, show_subscription_screen = _subscription_response_flags(subscription)
        return BillingSubscriptionStatusResponse(
            provider=subscription.provider,
            tier=subscription.tier,
            status=subscription.status,
            selection_made=selection_made,
            plan_saved=selection_made,
            is_active=_subscription_has_active_access(subscription),
            redirect_to_home=redirect_to_home,
            show_subscription_screen=show_subscription_screen,
            provider_configured=configured,
            checkout_endpoint=checkout_endpoint,
            checkout_public_key=checkout_public_key,
            currency=subscription.currency,
            amount=subscription.amount,
            billing_interval=subscription.billing_interval,
            provider_price_id=subscription.provider_price_id,
            current_period_end=subscription.current_period_end.isoformat() if subscription.current_period_end else None,
            cancel_at_period_end=subscription.cancel_at_period_end,
            **_pending_change_fields(subscription),
        )

    if payload.tier == "premium_plus":
        if not payload.interval:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="interval is required for premium_plus")
        if not payload.country:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="country is required for premium_plus")
        free_launch_decision = PricingEligibilityService(db, settings).evaluate(
            user_id=user_id,
            request=request,
            country=payload.country,
            device_locale_country=payload.device_locale_country,
            device_location_country=payload.device_location_country,
            app_store_country=payload.app_store_country,
            play_store_country=payload.play_store_country,
            phone_number=payload.phone_number,
            billing_country=payload.billing_country,
            ip_country=payload.ip_country,
        )
        if free_launch_decision.is_free_region:
            subscription = PricingEligibilityService(db, settings).grant_free_launch_access(
                user_id=user_id,
                country=free_launch_decision.country,
            )
            return _subscription_status_response(
                settings=settings,
                subscription=subscription,
            )
        try:
            details = resolve_billing_price(free_launch_decision.country or payload.country, payload.tier, payload.interval)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    else:
        details = resolve_billing_price("free", "free", "month")

    if not subscription:
        subscription = Subscription(user_id=user_id)
        db.add(subscription)

    subscription.tier = payload.tier
    subscription.provider = details["provider"]
    subscription.currency = details["currency"]
    subscription.amount = float(details["price_minor"]) / 100 if details["currency"] else 0.0
    subscription.billing_interval = payload.interval if payload.tier != "free" else None
    subscription.provider_price_id = details["provider_price_id"]
    subscription.provider_subscription_id = None if payload.tier == "free" else subscription.provider_subscription_id
    subscription.provider_customer_id = None if payload.tier == "free" else subscription.provider_customer_id
    subscription.current_period_end = None if payload.tier == "free" else subscription.current_period_end
    subscription.cancel_at_period_end = False
    subscription.pending_billing_interval = None
    subscription.pending_provider_price_id = None
    subscription.pending_amount = None
    subscription.pending_currency = None
    subscription.pending_change_effective_at = None
    subscription.status = "active" if payload.tier == "free" else "selected"
    db.commit()
    configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, subscription.provider)
    selection_made, redirect_to_home, show_subscription_screen = _subscription_response_flags(subscription)

    return BillingSubscriptionStatusResponse(
        provider=subscription.provider,
        tier=subscription.tier,
        status=subscription.status,
        selection_made=selection_made,
        plan_saved=selection_made,
        is_active=_subscription_has_active_access(subscription),
        redirect_to_home=redirect_to_home,
        show_subscription_screen=show_subscription_screen,
        provider_configured=configured,
        checkout_endpoint=checkout_endpoint,
        checkout_public_key=checkout_public_key,
        currency=subscription.currency,
        amount=subscription.amount,
        billing_interval=subscription.billing_interval,
        provider_price_id=subscription.provider_price_id,
        current_period_end=subscription.current_period_end.isoformat() if subscription.current_period_end else None,
        cancel_at_period_end=subscription.cancel_at_period_end,
        **_pending_change_fields(subscription),
    )


@router.post("/stripe/checkout-sessions", response_model=StripeCheckoutSessionResponse | PricingEligibilityResponse)
def create_stripe_checkout_session(
    request: Request,
    payload: StripeCheckoutSessionRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> StripeCheckoutSessionResponse | PricingEligibilityResponse:
    free_launch_decision = PricingEligibilityService(db, settings).evaluate(
        user_id=user_id,
        request=request,
        country=payload.country,
        device_locale_country=payload.device_locale_country,
        device_location_country=payload.device_location_country,
        app_store_country=payload.app_store_country,
        play_store_country=payload.play_store_country,
        phone_number=payload.phone_number,
        billing_country=payload.billing_country,
        ip_country=payload.ip_country,
    )
    if free_launch_decision.is_free_region:
        PricingEligibilityService(db, settings).grant_free_launch_access(
            user_id=user_id,
            country=free_launch_decision.country,
        )
        return _eligibility_response(free_launch_decision)

    service = StripeBillingService(db, settings)
    try:
        response = service.create_checkout_session(
            user_id=user_id,
            country=free_launch_decision.country or payload.country,
            plan_id=payload.plan_id,
            interval=payload.interval,
            success_url=_normalize_stripe_redirect_url(
                request,
                str(payload.success_url) if payload.success_url else None,
                success=True,
            ),
            cancel_url=_normalize_stripe_redirect_url(
                request,
                str(payload.cancel_url) if payload.cancel_url else None,
                success=False,
            ),
        )
    except StripeBillingError as exc:
        detail = str(exc)
        status_code = status.HTTP_503_SERVICE_UNAVAILABLE if "not configured" in detail.lower() else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=detail) from exc
    return StripeCheckoutSessionResponse(**response)


@router.post("/stripe/payment-sheet", response_model=StripePaymentSheetResponse | PricingEligibilityResponse)
def create_stripe_payment_sheet(
    request: Request,
    payload: StripePaymentSheetRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> StripePaymentSheetResponse | PricingEligibilityResponse:
    free_launch_decision = PricingEligibilityService(db, settings).evaluate(
        user_id=user_id,
        request=request,
        country=payload.country,
        device_locale_country=payload.device_locale_country,
        device_location_country=payload.device_location_country,
        app_store_country=payload.app_store_country,
        play_store_country=payload.play_store_country,
        phone_number=payload.phone_number,
        billing_country=payload.billing_country,
        ip_country=payload.ip_country,
    )
    if free_launch_decision.is_free_region:
        PricingEligibilityService(db, settings).grant_free_launch_access(
            user_id=user_id,
            country=free_launch_decision.country,
        )
        return _eligibility_response(free_launch_decision)

    service = StripeBillingService(db, settings)
    try:
        response = service.create_payment_sheet_subscription(
            user_id=user_id,
            country=free_launch_decision.country or payload.country,
            plan_id=payload.plan_id,
            interval=payload.interval,
        )
    except StripeBillingError as exc:
        detail = str(exc)
        status_code = status.HTTP_503_SERVICE_UNAVAILABLE if "not configured" in detail.lower() else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=detail) from exc
    return StripePaymentSheetResponse(**response)


@router.post("/stripe/payment-sheet/sync", response_model=BillingSubscriptionStatusResponse)
def sync_stripe_payment_sheet_subscription(
    payload: StripePaymentSheetSyncRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionStatusResponse:
    service = StripeBillingService(db, settings)
    try:
        subscription = service.sync_payment_sheet_subscription(
            user_id=user_id,
            provider_subscription_id=payload.provider_subscription_id,
        )
    except StripeBillingError as exc:
        detail = str(exc)
        status_code = status.HTTP_503_SERVICE_UNAVAILABLE if "not configured" in detail.lower() else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=detail) from exc

    configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, subscription.provider)
    selection_made, redirect_to_home, show_subscription_screen = _subscription_response_flags(subscription)
    is_active = _subscription_has_active_access(subscription)
    existing_started = (
        db.query(BillingActivity)
        .filter(
            BillingActivity.subscription_id == subscription.id,
            BillingActivity.event_type == "subscription_started",
        )
        .first()
    )
    if is_active and not existing_started:
        _record_billing_activity(
            db,
            subscription,
            event_type="subscription_started",
            title="Subscription started",
            subtitle=f"{_interval_plan_label(subscription.billing_interval)} is active.",
        )
        db.commit()
    return BillingSubscriptionStatusResponse(
        provider=subscription.provider,
        tier=subscription.tier,
        status=subscription.status,
        selection_made=selection_made,
        plan_saved=selection_made,
        is_active=is_active,
        redirect_to_home=redirect_to_home,
        show_subscription_screen=show_subscription_screen,
        provider_configured=configured,
        checkout_endpoint=checkout_endpoint,
        checkout_public_key=checkout_public_key,
        currency=subscription.currency,
        amount=subscription.amount,
        billing_interval=subscription.billing_interval,
        provider_price_id=subscription.provider_price_id,
        current_period_end=subscription.current_period_end.isoformat() if subscription.current_period_end else None,
        cancel_at_period_end=subscription.cancel_at_period_end,
        **_pending_change_fields(subscription),
    )


class _AppleVerifyReceiptRequest(BaseModel):
    receipt_data: str
    product_id: str


@router.post("/apple/verify-receipt", response_model=BillingSubscriptionStatusResponse)
def verify_apple_receipt(
    payload: _AppleVerifyReceiptRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionStatusResponse:
    service = AppleBillingService(
        shared_secret=settings.apple_iap_shared_secret,
        bundle_id=settings.apple_bundle_id or "com.vyla.health",
    )
    try:
        info = service.verify_receipt(
            receipt_data=payload.receipt_data,
            product_id=payload.product_id,
        )
    except AppleBillingError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    interval = APPLE_PRODUCT_INTERVAL.get(info["product_id"], "month")

    subscription = _latest_subscription(db, user_id)
    if not subscription:
        subscription = Subscription(user_id=user_id)
        db.add(subscription)

    subscription.tier = "premium_plus"
    subscription.provider = "apple_iap"
    subscription.status = "active"
    subscription.billing_interval = interval
    subscription.provider_price_id = info["product_id"]
    subscription.provider_subscription_id = info.get("original_transaction_id")
    subscription.current_period_end = info.get("expires_date")
    subscription.cancel_at_period_end = False
    subscription.currency = None
    subscription.amount = None
    subscription.pending_billing_interval = None
    subscription.pending_provider_price_id = None
    subscription.pending_amount = None
    subscription.pending_currency = None
    subscription.pending_change_effective_at = None
    db.commit()

    existing_started = (
        db.query(BillingActivity)
        .filter(
            BillingActivity.subscription_id == subscription.id,
            BillingActivity.event_type == "subscription_started",
        )
        .first()
    )
    if not existing_started:
        _record_billing_activity_best_effort(
            db,
            subscription,
            event_type="subscription_started",
            title="Subscription started",
            subtitle=f"{'Premium Annual' if interval == 'year' else 'Premium Monthly'} is active via Apple.",
        )

    return _subscription_status_response(settings=settings, subscription=subscription)


@router.get("/stripe/return/success", include_in_schema=False, name="stripe_checkout_return_success")
def stripe_checkout_return_success(
    target: str = Query(min_length=1),
    session_id: str | None = None,
) -> RedirectResponse:
    destination = target
    if session_id:
        destination = _inject_session_id(destination, session_id)
    return RedirectResponse(url=destination, status_code=status.HTTP_307_TEMPORARY_REDIRECT)


@router.get("/stripe/return/cancel", include_in_schema=False, name="stripe_checkout_return_cancel")
def stripe_checkout_return_cancel(target: str = Query(min_length=1)) -> RedirectResponse:
    return RedirectResponse(url=target, status_code=status.HTTP_307_TEMPORARY_REDIRECT)


def _log_stripe_webhook_error(
    *,
    db: Session,
    payload: bytes,
    signature: str | None,
    error_message: str,
) -> None:
    stripe_event_id = None
    event_type = None
    payment_intent_id = None
    subscription_id = None
    customer_id = None
    payload_summary: dict = {}

    msg_lower = error_message.lower()
    if any(k in msg_lower for k in ("signature", "secret", "configured", "missing stripe")):
        error_category = "signature"
    elif any(k in msg_lower for k in ("not found", "customer", "user")):
        error_category = "processing"
    else:
        error_category = "unknown"

    try:
        parsed = json.loads(payload)
    except Exception:
        parsed = None

    if isinstance(parsed, dict):
        stripe_event_id = parsed.get("id")
        event_type = parsed.get("type")
        data_object = ((parsed.get("data") or {}).get("object")) or {}
        if isinstance(data_object, dict):
            payment_intent_id = data_object.get("payment_intent")
            customer_id = data_object.get("customer")
            if event_type and "subscription" in event_type:
                subscription_id = data_object.get("id")
            else:
                subscription_id = data_object.get("subscription")
        payload_summary = {
            "event": event_type,
            "stripe_event_id": stripe_event_id,
            "data_keys": sorted(data_object.keys()) if isinstance(data_object, dict) else [],
        }

    try:
        db.add(StripeWebhookErrorLog(
            stripe_event_id=str(stripe_event_id) if stripe_event_id else None,
            event_type=str(event_type) if event_type else None,
            payment_intent_id=str(payment_intent_id) if payment_intent_id else None,
            subscription_id=str(subscription_id) if subscription_id else None,
            customer_id=str(customer_id) if customer_id else None,
            error_message=error_message[:512],
            error_category=error_category,
            signature_present=bool(signature),
            payload_summary=payload_summary,
        ))
        db.commit()
    except Exception:
        db.rollback()


@router.post("/stripe/webhook", response_model=StripeWebhookResponse)
async def stripe_webhook(
    request: Request,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> StripeWebhookResponse:
    payload = await request.body()
    signature = request.headers.get("Stripe-Signature")
    service = StripeBillingService(db, settings)
    try:
        response = service.handle_webhook(payload=payload, signature=signature)
    except StripeWebhookError as exc:
        db.rollback()
        _log_stripe_webhook_error(db=db, payload=payload, signature=signature, error_message=str(exc))
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except StripeBillingError as exc:
        db.rollback()
        _log_stripe_webhook_error(db=db, payload=payload, signature=signature, error_message=str(exc))
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return StripeWebhookResponse(**response)
