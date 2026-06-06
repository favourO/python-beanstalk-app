from datetime import datetime, UTC

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_current_admin_user, get_settings_dep
from phora.core.config import Settings
from phora.db.session import get_db
from phora.models.wearable_commerce import WearableInventory, WearableOrder
from phora.schemas.wearable_commerce import (
    AdminUpdateCountryAvailabilityRequest,
    AdminWearableAnalyticsResponse,
    AdminWearableInventoryResponse,
    AdminWearableOrderListResponse,
    AdminWearableStatusOptionsResponse,
    AdminUpdateFulfillmentRequest,
    AdminUpdateInventoryRequest,
    WearableAvailabilityResponse,
    WearableOrderListResponse,
    WearableOrderResponse,
)
from phora.services.wearable_commerce import (
    FULFILLMENT_CANCELLED,
    FULFILLMENT_DELIVERED,
    FULFILLMENT_DISPATCHED,
    FULFILLMENT_PENDING,
    FULFILLMENT_STATUSES,
    PAYMENT_PAID,
    PAYMENT_PENDING,
    PAYMENT_STATUSES,
    WearableCommerceService,
)
from phora.services.stripe_billing import StripeBillingError, StripeBillingService

router = APIRouter(prefix="/wearable", tags=["wearable"])
admin_router = APIRouter(prefix="/admin/wearable", tags=["admin-wearable"])


# ── User: Inventory ────────────────────────────────────────────────────────────

@router.get("/inventory/availability", response_model=WearableAvailabilityResponse)
def get_inventory_availability(
    sku: str = "VYLA-WEARABLE-V1",
    country: str | None = None,
    db: Session = Depends(get_db),
):
    svc = WearableCommerceService(db)
    data = svc.check_availability(sku, country=country)
    return WearableAvailabilityResponse(**data)


# ── User: Orders ───────────────────────────────────────────────────────────────

@router.get("/orders/my", response_model=WearableOrderListResponse)
def list_my_orders(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    svc = WearableCommerceService(db)
    orders = svc.get_user_orders(user_id)
    return WearableOrderListResponse(orders=[svc.serialize_order(o) for o in orders])


@router.get("/orders/{order_id}", response_model=WearableOrderResponse)
def get_my_order(
    order_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    svc = WearableCommerceService(db)
    order = svc.get_user_order(user_id, order_id)
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")
    return WearableOrderResponse(**svc.serialize_order(order))


@router.get("/orders/{order_id}/tracking", response_model=WearableOrderResponse)
def get_order_tracking(
    order_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    svc = WearableCommerceService(db)
    order = svc.get_user_order(user_id, order_id)
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")
    return WearableOrderResponse(**svc.serialize_order(order))


# ── User: Checkout ─────────────────────────────────────────────────────────────

@router.post("/checkout/addon")
def wearable_addon_checkout(
    body: dict,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
):
    """
    Create a Stripe payment sheet for a subscription + optional wearable add-on.
    Expected body keys: country, plan_id, interval, wearable_sku, shipping_address
    """
    country = body.get("country", "")
    plan_id = body.get("plan_id", "")
    interval = body.get("interval", "month")
    wearable_sku = body.get("wearable_sku", "")
    shipping_address = body.get("shipping_address", {})

    if not country or not plan_id or not interval:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Missing required fields.")

    svc = WearableCommerceService(db)

    wearable_minor = 0
    wearable_name = ""
    availability = None

    if wearable_sku:
        availability = svc.check_availability(wearable_sku, country=country)
        if not availability["available"]:
            reason = availability.get("availability_reason", "out_of_stock")
            if reason == "country_not_allowed":
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Wearable is not available in your country.")
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Wearable is out of stock.")
        wearable_minor = availability["price_minor"]
        wearable_name = availability["product_name"]

    try:
        stripe_svc = StripeBillingService(db, settings)
        result = stripe_svc.create_payment_sheet_subscription(
            user_id=user_id,
            country=country,
            plan_id=plan_id,
            interval=interval,
            wearable_sku=wearable_sku or None,
            wearable_price_minor=wearable_minor,
            shipping_address=shipping_address if wearable_sku else {},
        )
    except StripeBillingError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))

    sub_minor = result["amount_minor"]

    return {
        **result,
        "wearable_sku": wearable_sku,
        "wearable_name": wearable_name,
        "wearable_amount_minor": wearable_minor,
        "subscription_amount_minor": sub_minor,
        "total_amount_minor": sub_minor + wearable_minor,
    }


@router.post("/checkout/standalone")
def wearable_standalone_checkout(
    body: dict,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
):
    wearable_sku = body.get("wearable_sku", "")
    shipping_address = body.get("shipping_address", {})
    country = body.get("country") or None
    if not wearable_sku:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Missing wearable_sku.")

    svc = WearableCommerceService(db)
    availability = svc.check_availability(wearable_sku, country=country)
    if not availability["available"]:
        reason = availability.get("availability_reason", "out_of_stock")
        if reason == "country_not_allowed":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Wearable is not available in your country.")
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Wearable is out of stock.")
    inv = svc.get_inventory(wearable_sku)
    if not inv:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Wearable is unavailable.")

    price_minor = availability["price_minor"]
    currency = availability["currency"]

    try:
        stripe_svc = StripeBillingService(db, settings)
        result = stripe_svc.create_payment_sheet_wearable_purchase(
            user_id=user_id,
            wearable_sku=wearable_sku,
            wearable_price_minor=price_minor,
            currency=currency,
            shipping_address=shipping_address,
        )
    except StripeBillingError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))

    return {
        **result,
        "wearable_sku": wearable_sku,
        "wearable_name": availability["product_name"],
        "wearable_amount_minor": price_minor,
        "subscription_amount_minor": 0,
        "total_amount_minor": price_minor,
    }


@router.post("/checkout/confirm")
def confirm_wearable_checkout(
    body: dict,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
):
    payment_intent_id = body.get("provider_payment_intent_id") or body.get("payment_intent_id") or ""
    wearable_sku = body.get("wearable_sku") or ""
    shipping_address = body.get("shipping_address") or {}
    provider_subscription_id = body.get("provider_subscription_id") or None

    if not payment_intent_id or not wearable_sku:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Missing payment intent or wearable SKU.",
        )

    try:
        StripeBillingService(db, settings).confirm_wearable_payment(
            user_id=user_id,
            payment_intent_id=payment_intent_id,
            wearable_sku=wearable_sku,
            shipping_address_json=shipping_address,
            provider_subscription_id=provider_subscription_id,
        )
    except StripeBillingError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))

    svc = WearableCommerceService(db)
    return {"orders": [svc.serialize_order(order) for order in svc.get_user_orders(user_id)]}


# ── Admin: Orders ──────────────────────────────────────────────────────────────

@admin_router.get("/orders", response_model=AdminWearableOrderListResponse)
def admin_list_orders(
    limit: int = 50,
    offset: int = 0,
    fulfillment_status: str | None = None,
    _=Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    svc = WearableCommerceService(db)
    q = db.query(WearableOrder).order_by(WearableOrder.created_at.desc())
    if fulfillment_status:
        q = q.filter(WearableOrder.fulfillment_status == fulfillment_status.lower().strip())
    total = q.count()
    orders = q.offset(offset).limit(limit).all()
    return AdminWearableOrderListResponse(
        orders=[svc.serialize_order(o) for o in orders],
        total=total,
        limit=limit,
        offset=offset,
    )


@admin_router.get("/orders/{order_id}", response_model=WearableOrderResponse)
def admin_get_order(
    order_id: str,
    _=Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    svc = WearableCommerceService(db)
    order = db.query(WearableOrder).filter(WearableOrder.id == order_id).one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")
    return WearableOrderResponse(**svc.serialize_order(order))


@admin_router.patch("/orders/{order_id}/status", response_model=WearableOrderResponse)
def admin_update_fulfillment(
    order_id: str,
    body: AdminUpdateFulfillmentRequest,
    _=Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    order = db.query(WearableOrder).filter(WearableOrder.id == order_id).one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")

    estimated_dt: datetime | None = None
    if body.estimated_delivery_date:
        try:
            estimated_dt = datetime.fromisoformat(body.estimated_delivery_date).replace(tzinfo=UTC)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid estimated_delivery_date format.")

    svc = WearableCommerceService(db)
    if body.tracking_url and not body.tracking_url.startswith(("https://", "http://")):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid tracking_url format.")
    try:
        updated = svc.update_fulfillment(
            order,
            fulfillment_status=body.fulfillment_status,
            tracking_number=body.tracking_number,
            tracking_url=body.tracking_url,
            courier=body.courier,
            estimated_delivery_date=estimated_dt,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))
    return WearableOrderResponse(**svc.serialize_order(updated))


@admin_router.patch("/orders/{order_id}/tracking", response_model=WearableOrderResponse)
def admin_update_tracking(
    order_id: str,
    body: dict,
    _=Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    order = db.query(WearableOrder).filter(WearableOrder.id == order_id).one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")

    svc = WearableCommerceService(db)
    tracking_url = body.get("tracking_url")
    if tracking_url and not str(tracking_url).startswith(("https://", "http://")):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid tracking_url format.")
    estimated_dt: datetime | None = None
    estimated = body.get("estimated_delivery_date")
    if estimated:
        try:
            estimated_dt = datetime.fromisoformat(estimated).replace(tzinfo=UTC)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid estimated_delivery_date format.")
    try:
        updated = svc.update_fulfillment(
            order,
            fulfillment_status=order.fulfillment_status,
            tracking_number=body.get("tracking_number"),
            tracking_url=tracking_url,
            courier=body.get("courier"),
            estimated_delivery_date=estimated_dt,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))
    return WearableOrderResponse(**svc.serialize_order(updated))


@admin_router.get("/inventory", response_model=AdminWearableInventoryResponse)
def admin_list_inventory(
    _=Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    svc = WearableCommerceService(db)
    items = db.query(WearableInventory).order_by(WearableInventory.created_at.desc()).all()
    return AdminWearableInventoryResponse(items=[svc.serialize_inventory(i) for i in items])


@admin_router.patch("/inventory", response_model=WearableAvailabilityResponse)
def admin_update_inventory(
    body: AdminUpdateInventoryRequest,
    _=Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    svc = WearableCommerceService(db)
    inv = svc.get_inventory(body.sku)
    if not inv:
        total_stock = body.total_stock or 0
        available_stock = body.available_stock or 0
        if available_stock > total_stock:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Available stock cannot exceed total stock.")
        # Create new inventory record
        inv = WearableInventory(
            sku=body.sku,
            product_name="Vyla Wearable",
            total_stock=total_stock,
            available_stock=available_stock,
            price_minor=body.price_minor or 2500,
            currency="GBP",
            currency_symbol="£",
            low_stock_threshold=body.low_stock_threshold or 5,
            is_active=body.is_active if body.is_active is not None else True,
        )
        db.add(inv)
        db.commit()
    else:
        update_fields = {}
        if body.total_stock is not None:
            update_fields["total_stock"] = body.total_stock
        if body.available_stock is not None:
            update_fields["available_stock"] = body.available_stock
        if body.price_minor is not None:
            update_fields["price_minor"] = body.price_minor
        if body.low_stock_threshold is not None:
            update_fields["low_stock_threshold"] = body.low_stock_threshold
        if body.is_active is not None:
            update_fields["is_active"] = body.is_active
        if body.allowed_country_codes is not None:
            update_fields["allowed_country_codes"] = body.allowed_country_codes
        try:
            svc.update_inventory(inv, **update_fields)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))
        db.refresh(inv)

    return WearableAvailabilityResponse(**svc.check_availability(inv.sku))


@admin_router.patch("/inventory/{sku}/country-availability", response_model=AdminWearableInventoryResponse)
def admin_update_country_availability(
    sku: str,
    body: AdminUpdateCountryAvailabilityRequest,
    _=Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    svc = WearableCommerceService(db)
    inv = svc.get_inventory(sku)
    if not inv:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inventory SKU not found.")
    try:
        svc.update_inventory(inv, allowed_country_codes=body.allowed_country_codes)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))
    db.refresh(inv)
    items = db.query(WearableInventory).order_by(WearableInventory.created_at.desc()).all()
    return AdminWearableInventoryResponse(items=[svc.serialize_inventory(i) for i in items])


@admin_router.get("/analytics", response_model=AdminWearableAnalyticsResponse)
def admin_wearable_analytics(
    _=Depends(get_current_admin_user),
    db: Session = Depends(get_db),
):
    fulfillment_rows = db.query(WearableOrder.fulfillment_status, func.count(WearableOrder.id)).group_by(WearableOrder.fulfillment_status).all()
    payment_rows = db.query(WearableOrder.payment_status, func.count(WearableOrder.id)).group_by(WearableOrder.payment_status).all()
    fulfillment_counts = {status_key or "unknown": int(count) for status_key, count in fulfillment_rows}
    payment_counts = {status_key or "unknown": int(count) for status_key, count in payment_rows}
    revenue = (
        db.query(func.coalesce(func.sum(WearableOrder.wearable_price), 0))
        .filter(WearableOrder.payment_status == PAYMENT_PAID)
        .scalar()
        or 0
    )
    low_stock_items = (
        db.query(func.count(WearableInventory.id))
        .filter(
            WearableInventory.is_active.is_(True),
            WearableInventory.available_stock > 0,
            WearableInventory.available_stock <= WearableInventory.low_stock_threshold,
        )
        .scalar()
        or 0
    )
    active_inventory_items = db.query(func.count(WearableInventory.id)).filter(WearableInventory.is_active.is_(True)).scalar() or 0
    return AdminWearableAnalyticsResponse(
        total_orders=sum(fulfillment_counts.values()),
        paid_orders=payment_counts.get(PAYMENT_PAID, 0),
        pending_orders=fulfillment_counts.get(FULFILLMENT_PENDING, 0),
        dispatched_orders=fulfillment_counts.get(FULFILLMENT_DISPATCHED, 0),
        delivered_orders=fulfillment_counts.get(FULFILLMENT_DELIVERED, 0),
        cancelled_orders=fulfillment_counts.get(FULFILLMENT_CANCELLED, 0),
        revenue_minor=int(float(revenue) * 100),
        currency="GBP",
        low_stock_items=low_stock_items,
        active_inventory_items=active_inventory_items,
        fulfillment_counts=fulfillment_counts,
        payment_counts=payment_counts,
    )


@admin_router.get("/status-options", response_model=AdminWearableStatusOptionsResponse)
def admin_wearable_status_options(
    _=Depends(get_current_admin_user),
):
    return AdminWearableStatusOptionsResponse(
        fulfillment_statuses=list(FULFILLMENT_STATUSES),
        payment_statuses=list(PAYMENT_STATUSES),
    )
