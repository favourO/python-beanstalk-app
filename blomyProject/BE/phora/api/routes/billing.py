from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_settings_dep
from phora.core.config import Settings
from phora.db.session import get_db
from phora.models import Subscription
from phora.schemas.billing import (
    BillingSubscriptionStatusResponse,
    BillingPlanOffersResponse,
    BillingSubscriptionSelectionRequest,
    FlutterwaveCheckoutSessionRequest,
    FlutterwaveCheckoutSessionResponse,
    FlutterwaveWebhookResponse,
    StripeCheckoutSessionRequest,
    StripeCheckoutSessionResponse,
    StripeWebhookResponse,
)
from phora.services.billing_catalog import build_plan_offers, resolve_billing_price
from phora.services.flutterwave_billing import FlutterwaveBillingError, FlutterwaveBillingService, FlutterwaveWebhookError
from phora.services.stripe_billing import StripeBillingError, StripeBillingService, StripeWebhookError

router = APIRouter(prefix="/billing", tags=["billing"])

_ACTIVE_SUBSCRIPTION_STATUSES = {"active", "trialing"}


def _provider_checkout_details(settings: Settings, provider: str | None) -> tuple[bool, str | None, str | None]:
    if provider == "stripe":
        return (
            bool(settings.stripe_secret_key and settings.stripe_publishable_key),
            "/api/v1/billing/stripe/checkout-sessions",
            settings.stripe_publishable_key,
        )
    if provider == "flutterwave":
        return (
            bool(settings.flutterwave_secret_key and settings.flutterwave_public_key),
            "/api/v1/billing/flutterwave/checkout-sessions",
            settings.flutterwave_public_key,
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


def _subscription_response_flags(subscription: Subscription | None) -> tuple[bool, bool, bool]:
    if not subscription:
        return False, False, True
    selection_made = subscription.tier in {"free", "premium_plus"}
    is_active = subscription.tier == "free" or subscription.status in _ACTIVE_SUBSCRIPTION_STATUSES
    redirect_to_home = is_active
    show_subscription_screen = not is_active
    return selection_made, redirect_to_home, show_subscription_screen


@router.get("/plan-offers", response_model=BillingPlanOffersResponse)
def get_plan_offers(
    country: str = Query(min_length=2),
    include_free: bool = True,
    settings: Settings = Depends(get_settings_dep),
) -> BillingPlanOffersResponse:
    response = build_plan_offers(country=country, include_free=include_free)
    configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, response.primary_provider)
    response.provider_configured = configured
    response.checkout_endpoint = checkout_endpoint
    response.checkout_public_key = checkout_public_key
    return response


@router.get("/subscription", response_model=BillingSubscriptionStatusResponse)
def get_subscription_status(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionStatusResponse:
    subscription = _latest_subscription(db, user_id)
    if not subscription:
        configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, None)
        return BillingSubscriptionStatusResponse(
            show_subscription_screen=True,
            provider_configured=configured,
            checkout_endpoint=checkout_endpoint,
            checkout_public_key=checkout_public_key,
        )
    configured, checkout_endpoint, checkout_public_key = _provider_checkout_details(settings, subscription.provider)
    selection_made, redirect_to_home, show_subscription_screen = _subscription_response_flags(subscription)
    is_active = subscription.tier == "free" or subscription.status in _ACTIVE_SUBSCRIPTION_STATUSES
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
    )


@router.post("/subscription-selection", response_model=BillingSubscriptionStatusResponse)
def save_subscription_selection(
    payload: BillingSubscriptionSelectionRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> BillingSubscriptionStatusResponse:
    if payload.tier == "premium_plus":
        if not payload.interval:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="interval is required for premium_plus")
        if not payload.country:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="country is required for premium_plus")
        try:
            details = resolve_billing_price(payload.country, payload.tier, payload.interval)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    else:
        details = resolve_billing_price("free", "free", "month")

    subscription = _latest_subscription(db, user_id)
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
        is_active=subscription.tier == "free" or subscription.status in _ACTIVE_SUBSCRIPTION_STATUSES,
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
    )


@router.post("/stripe/checkout-sessions", response_model=StripeCheckoutSessionResponse)
def create_stripe_checkout_session(
    request: Request,
    payload: StripeCheckoutSessionRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> StripeCheckoutSessionResponse:
    service = StripeBillingService(db, settings)
    try:
        response = service.create_checkout_session(
            user_id=user_id,
            country=payload.country,
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


@router.post("/flutterwave/checkout-sessions", response_model=FlutterwaveCheckoutSessionResponse)
def create_flutterwave_checkout_session(
    payload: FlutterwaveCheckoutSessionRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> FlutterwaveCheckoutSessionResponse:
    service = FlutterwaveBillingService(db, settings)
    try:
        response = service.create_checkout_session(
            user_id=user_id,
            country=payload.country,
            plan_id=payload.plan_id,
            interval=payload.interval,
            redirect_url=str(payload.redirect_url) if payload.redirect_url else None,
        )
    except FlutterwaveBillingError as exc:
        detail = str(exc)
        status_code = status.HTTP_503_SERVICE_UNAVAILABLE if "not configured" in detail.lower() else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=detail) from exc
    return FlutterwaveCheckoutSessionResponse(**response)


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
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return StripeWebhookResponse(**response)


@router.post("/flutterwave/webhook", response_model=FlutterwaveWebhookResponse)
async def flutterwave_webhook(
    request: Request,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> FlutterwaveWebhookResponse:
    payload = await request.body()
    signature = request.headers.get("flutterwave-signature")
    legacy_hash = request.headers.get("verif-hash")
    service = FlutterwaveBillingService(db, settings)
    try:
        response = service.handle_webhook(payload=payload, signature=signature, legacy_hash=legacy_hash)
    except FlutterwaveWebhookError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return FlutterwaveWebhookResponse(**response)
