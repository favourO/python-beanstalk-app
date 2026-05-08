import json
from datetime import UTC, datetime
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Request, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_settings_dep
from phora.core.config import Settings
from phora.db.session import get_db
from phora.models import FlutterwaveWebhookErrorLog, Subscription, StripeWebhookErrorLog, User
from phora.schemas.billing import (
    BillingSubscriptionCancelRequest,
    FlutterwaveWebhookErrorItem,
    FlutterwaveWebhookErrorListResponse,
    BillingSubscriptionStatusResponse,
    BillingPlanOffersResponse,
    BillingSubscriptionSelectionRequest,
    FlutterwaveCheckoutSessionRequest,
    FlutterwaveCheckoutSessionResponse,
    FlutterwaveWebhookResponse,
    StripeCheckoutSessionRequest,
    StripeCheckoutSessionResponse,
    StripePaymentSheetRequest,
    StripePaymentSheetResponse,
    StripePaymentSheetSyncRequest,
    StripeWebhookResponse,
)
from phora.services.billing_catalog import build_plan_offers, resolve_billing_price
from phora.services.flutterwave_billing import FlutterwaveBillingError, FlutterwaveBillingService, FlutterwaveWebhookError
from phora.services.premium_access import PremiumAccessService
from phora.services.stripe_billing import StripeBillingError, StripeBillingService, StripeWebhookError

router = APIRouter(prefix="/billing", tags=["billing"])
admin_router = APIRouter(prefix="/admin/billing", tags=["admin-billing"])

_ACTIVE_SUBSCRIPTION_STATUSES = {"active", "trialing"}


def _provider_checkout_details(settings: Settings, provider: str | None) -> tuple[bool, str | None, str | None]:
    if provider == "stripe":
        return (
            bool(settings.stripe_secret_key and settings.stripe_publishable_key),
            "/api/v1/billing/stripe/payment-sheet",
            settings.stripe_publishable_key,
        )
    if provider == "flutterwave":
        return (
            bool(settings.flutterwave_secret_key and settings.flutterwave_public_key),
            "/api/v1/billing/flutterwave/checkout-sessions",
            settings.flutterwave_public_key,
        )
    return True, None, None


def _flutterwave_error_response(exc: FlutterwaveBillingError) -> HTTPException:
    detail = str(exc)
    normalized = detail.lower()
    unavailable_markers = (
        "not configured",
        "key has expired",
        "unauthorized",
        "authentication failed",
        "invalid secret",
        "invalid public key",
        "access denied",
    )
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE if any(marker in normalized for marker in unavailable_markers) else status.HTTP_400_BAD_REQUEST
    message = "Payment is temporarily unavailable in this region." if status_code == status.HTTP_503_SERVICE_UNAVAILABLE else detail
    return HTTPException(status_code=status_code, detail=message)


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


def _normalize_flutterwave_redirect_url(request: Request, url: str | None) -> str | None:
    if not url:
        return None

    parsed = urlparse(url)
    if parsed.scheme in {"http", "https"} or not parsed.scheme:
        return url

    callback_url = str(request.url_for("flutterwave_checkout_return"))
    return _append_query_value(callback_url, "target", url)


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
    if subscription.status in _ACTIVE_SUBSCRIPTION_STATUSES:
        return True
    if subscription.status in {"canceled", "cancelled"} and subscription.current_period_end:
        current_period_end = subscription.current_period_end
        if current_period_end.tzinfo is None:
            current_period_end = current_period_end.replace(tzinfo=UTC)
        return current_period_end > datetime.now(UTC)
    return False


def _require_admin_user(db: Session, user_id: str) -> User:
    user = db.query(User).filter(User.id == user_id).one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


def _log_flutterwave_webhook_error(
    *,
    db: Session,
    payload: bytes,
    signature: str | None,
    legacy_hash: str | None,
    error_message: str,
) -> None:
    payload_summary: dict = {}
    event_type = None
    transaction_id = None
    tx_ref = None
    provider_customer_id = None
    provider_plan_id = None
    user_id = None

    try:
        parsed = json.loads(payload)
    except json.JSONDecodeError:
        parsed = None

    if isinstance(parsed, dict):
        data_object = parsed.get("data") or {}
        customer = data_object.get("customer") or {}
        metadata = data_object.get("meta") or {}
        event_type = parsed.get("event") or parsed.get("type")
        transaction_id = data_object.get("id")
        tx_ref = data_object.get("tx_ref") or data_object.get("reference")
        provider_customer_id = customer.get("email") or customer.get("id")
        user_id = metadata.get("user_id")
        plan = data_object.get("plan")
        if isinstance(plan, dict):
            provider_plan_id = plan.get("id")
        elif plan is not None:
            provider_plan_id = str(plan)
        payload_summary = {
            "event": event_type,
            "data_keys": sorted(data_object.keys()) if isinstance(data_object, dict) else [],
            "has_customer": bool(customer),
            "has_meta": bool(metadata),
        }

    db.add(
        FlutterwaveWebhookErrorLog(
            event_type=str(event_type) if event_type is not None else None,
            transaction_id=str(transaction_id) if transaction_id is not None else None,
            tx_ref=str(tx_ref) if tx_ref is not None else None,
            provider_customer_id=str(provider_customer_id) if provider_customer_id is not None else None,
            provider_plan_id=str(provider_plan_id) if provider_plan_id is not None else None,
            user_id=str(user_id) if user_id is not None else None,
            error_message=error_message[:512],
            signature_present=bool(signature),
            legacy_hash_present=bool(legacy_hash),
            payload_summary=payload_summary,
        )
    )
    db.commit()


def _subscription_response_flags(subscription: Subscription | None) -> tuple[bool, bool, bool]:
    if not subscription:
        return False, False, True
    selection_made = subscription.tier in {"free", "premium_plus"}
    is_active = _subscription_has_active_access(subscription)
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
        elif subscription.provider == "flutterwave":
            FlutterwaveBillingService(db, settings).cancel_subscription(subscription)
        else:
            subscription.status = "canceled"
            subscription.current_period_end = None
    except (StripeBillingError, FlutterwaveBillingError) as exc:
        detail = str(exc)
        status_code = status.HTTP_503_SERVICE_UNAVAILABLE if "not configured" in detail.lower() else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=status_code, detail=detail) from exc

    db.commit()
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
    )


@router.post("/subscription-selection", response_model=BillingSubscriptionStatusResponse)
def save_subscription_selection(
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
        )

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


@router.post("/stripe/payment-sheet", response_model=StripePaymentSheetResponse)
def create_stripe_payment_sheet(
    payload: StripePaymentSheetRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> StripePaymentSheetResponse:
    service = StripeBillingService(db, settings)
    try:
        response = service.create_payment_sheet_subscription(
            user_id=user_id,
            country=payload.country,
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
    request: Request,
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
            redirect_url=_normalize_flutterwave_redirect_url(
                request,
                str(payload.redirect_url) if payload.redirect_url else None,
            ),
        )
    except FlutterwaveBillingError as exc:
        raise _flutterwave_error_response(exc) from exc
    return FlutterwaveCheckoutSessionResponse(**response)


@router.get("/flutterwave/return", include_in_schema=False, name="flutterwave_checkout_return")
def flutterwave_checkout_return(
    target: str = Query(min_length=1),
    transaction_id: str | None = Query(default=None),
    tx_ref: str | None = Query(default=None),
    status_value: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> RedirectResponse:
    normalized_status = (status_value or "").strip().lower()
    if transaction_id and normalized_status in {"successful", "completed", "success"}:
        service = FlutterwaveBillingService(db, settings)
        try:
            service.confirm_transaction(
                transaction_id=transaction_id,
                tx_ref=tx_ref,
                status=normalized_status,
            )
        except FlutterwaveWebhookError:
            db.rollback()
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
        _log_flutterwave_webhook_error(
            db=db,
            payload=payload,
            signature=signature,
            legacy_hash=legacy_hash,
            error_message=str(exc),
        )
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return FlutterwaveWebhookResponse(**response)


@admin_router.get("/flutterwave/webhook-errors", response_model=FlutterwaveWebhookErrorListResponse)
def list_flutterwave_webhook_errors(
    limit: int = Query(default=50, ge=1, le=200),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> FlutterwaveWebhookErrorListResponse:
    _require_admin_user(db, user_id)
    rows = (
        db.query(FlutterwaveWebhookErrorLog)
        .order_by(FlutterwaveWebhookErrorLog.created_at.desc())
        .limit(limit)
        .all()
    )
    return FlutterwaveWebhookErrorListResponse(
        items=[
            FlutterwaveWebhookErrorItem(
                id=row.id,
                event_type=row.event_type,
                transaction_id=row.transaction_id,
                tx_ref=row.tx_ref,
                provider_customer_id=row.provider_customer_id,
                provider_plan_id=row.provider_plan_id,
                user_id=row.user_id,
                error_message=row.error_message,
                signature_present=row.signature_present,
                legacy_hash_present=row.legacy_hash_present,
                payload_summary=row.payload_summary or {},
                created_at=row.created_at.isoformat(),
            )
            for row in rows
        ],
        limit=limit,
    )
