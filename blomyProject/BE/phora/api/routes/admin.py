"""
Admin-only API routes for the Vyla Admin Portal.
All endpoints require is_admin == True on the authenticated user.
Every mutating action writes to audit_events.
"""
import json
import uuid
from datetime import UTC, date, datetime, timedelta
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from phora.api.deps import get_current_admin_user, get_db
from phora.core.config import get_settings
from phora.core.security import create_token, new_ulid, verify_password
from phora.models.ai import MedicalChatMessage, MedicalChatThread
from phora.models.audit import AuditEvent
from phora.models.billing import FlutterwaveWebhookErrorLog, Invoice, Subscription, StripeWebhookErrorLog
from phora.models.cycle import CycleRecord, DailyLog
from phora.models.growth import PremiumGrant, ReferralAttribution, ReferralProfile
from phora.models.notification import NotificationDevice, NotificationHistory
from phora.models.prediction import PredictionSnapshot
from phora.models.timeseries import WearableMetric
from phora.models.user import OnboardingProgress, User, UserProfile

router = APIRouter(prefix="/admin", tags=["admin"])


# ---------------------------------------------------------------------------
# Admin login (validates is_admin before issuing token)
# ---------------------------------------------------------------------------

class AdminLoginRequest(BaseModel):
    email: str
    password: str

class AdminLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

@router.post("/login", response_model=AdminLoginResponse)
def admin_login(payload: AdminLoginRequest, db: Session = Depends(get_db)) -> AdminLoginResponse:
    user = db.query(User).filter(User.email == payload.email.lower().strip()).first()
    if not user or not user.password_hash or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if user.deleted_at:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    settings = get_settings()
    token = create_token(
        user.id, "access", settings.access_token_exp_minutes,
        user.token_generation, {"jti": new_ulid()},
    )
    return AdminLoginResponse(access_token=token)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _audit(db: Session, actor_id: str, action: str, payload: dict[str, Any] = {}) -> None:
    db.add(AuditEvent(actor_user_id=actor_id, action=action, payload=payload))
    db.flush()


def _day_start(d: date) -> datetime:
    return datetime(d.year, d.month, d.day, tzinfo=UTC)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class OverviewOut(BaseModel):
    total_users: int
    active_users: int
    deleted_users: int
    anonymous_users: int
    premium_users: int
    free_users: int
    trialing_users: int
    wearable_connected_users: int
    onboarding_completed_users: int
    signups_today: int
    signups_this_week: int
    ai_threads_total: int
    daily_logs_today: int
    predictions_today: int
    total_invoiced_gbp: float
    flutterwave_errors_30d: int
    stripe_errors_30d: int
    referrals_total: int
    referrals_qualified: int
    active_premium_grants: int


class UserItem(BaseModel):
    id: str
    email: str | None
    account_mode: str
    email_verified: bool
    is_admin: bool
    deleted_at: str | None
    created_at: str
    full_name: str | None
    wearable_type: str | None
    subscription_tier: str | None
    subscription_status: str | None
    subscription_provider: str | None
    onboarding_completed: bool


class UserListOut(BaseModel):
    items: list[UserItem]
    total: int
    page: int
    page_size: int


class UserDetailOut(BaseModel):
    id: str
    email: str | None
    account_mode: str
    email_verified: bool
    is_admin: bool
    deleted_at: str | None
    created_at: str
    full_name: str | None
    date_of_birth: str | None
    goal: str | None
    wearable_type: str | None
    timezone: str | None
    onboarding_completed: bool
    onboarding_step: int | None
    subscription_tier: str | None
    subscription_status: str | None
    subscription_provider: str | None
    subscription_period_end: str | None
    cycle_records_count: int
    daily_logs_count: int
    ai_threads_count: int


class SubItem(BaseModel):
    id: str
    user_id: str
    user_email: str | None
    tier: str
    status: str
    provider: str | None
    billing_interval: str | None
    amount: float | None
    currency: str | None
    current_period_end: str | None
    created_at: str


class SubListOut(BaseModel):
    items: list[SubItem]
    total: int
    page: int
    page_size: int


class InvoiceItem(BaseModel):
    id: str
    subscription_id: str | None
    user_email: str | None
    provider_invoice_id: str | None
    provider_customer_id: str | None
    total: float
    currency: str
    status: str
    provider: str | None
    created_at: str


class InvoiceListOut(BaseModel):
    items: list[InvoiceItem]
    total: int
    page: int
    page_size: int


class FlwErrorItem(BaseModel):
    id: str
    event_type: str | None
    transaction_id: str | None
    tx_ref: str | None
    provider_customer_id: str | None
    user_id: str | None
    error_message: str
    signature_present: bool
    legacy_hash_present: bool
    created_at: str


class FlwErrorListOut(BaseModel):
    items: list[FlwErrorItem]
    total: int


class StripeErrorItem(BaseModel):
    id: str
    stripe_event_id: str | None
    event_type: str | None
    payment_intent_id: str | None
    subscription_id: str | None
    customer_id: str | None
    error_message: str
    error_category: str
    signature_present: bool
    created_at: str


class StripeErrorListOut(BaseModel):
    items: list[StripeErrorItem]
    total: int


class PredictionItem(BaseModel):
    id: str
    user_id: str
    user_email: str | None
    current_phase: str
    confidence: float
    warning_flags: list
    models_used: list
    model_version: str | None
    source: str
    generated_at: str


class PredictionListOut(BaseModel):
    items: list[PredictionItem]
    total: int
    page: int
    page_size: int


class WearableUserItem(BaseModel):
    user_id: str
    user_email: str | None
    wearable_type: str
    latest_sync: str | None
    metrics_count: int


class WearableListOut(BaseModel):
    items: list[WearableUserItem]
    total: int


class NotifHistoryItem(BaseModel):
    id: str
    user_id: str
    notification_type: str
    category: str
    channel: str
    title: str
    status: str
    priority: str
    delivery_attempts: int
    scheduled_for: str
    delivered_at: str | None


class NotifHistoryOut(BaseModel):
    items: list[NotifHistoryItem]
    total: int
    page: int
    page_size: int


class ReferralItem(BaseModel):
    id: str
    inviter_user_id: str
    inviter_email: str | None
    invited_user_id: str | None
    referral_code: str
    source: str | None
    status: str
    created_at: str
    qualified_at: str | None


class ReferralListOut(BaseModel):
    items: list[ReferralItem]
    total: int
    page: int
    page_size: int


class GrantItem(BaseModel):
    id: str
    user_id: str
    user_email: str | None
    tier: str
    source_type: str
    days_granted: int
    starts_at: str
    ends_at: str
    active: bool
    created_at: str


class GrantListOut(BaseModel):
    items: list[GrantItem]
    total: int
    page: int
    page_size: int


class AiThreadItem(BaseModel):
    id: str
    user_id: str
    user_email: str | None
    title: str | None
    message_count: int
    created_at: str
    updated_at: str


class AiThreadListOut(BaseModel):
    items: list[AiThreadItem]
    total: int
    page: int
    page_size: int


class AuditEventItem(BaseModel):
    id: str
    actor_user_id: str | None
    action: str
    payload: dict
    created_at: str


class AuditEventListOut(BaseModel):
    items: list[AuditEventItem]
    total: int
    page: int
    page_size: int


class ActionResponse(BaseModel):
    ok: bool
    message: str


class GrantPremiumRequest(BaseModel):
    days: int = 30
    reason: str = "manual_admin_grant"


# ---------------------------------------------------------------------------
# Helper: build user_email map from a list of user_ids
# ---------------------------------------------------------------------------

def _email_map(db: Session, user_ids: list[str]) -> dict[str, str | None]:
    if not user_ids:
        return {}
    rows = db.execute(
        select(User.id, User.email).where(User.id.in_(user_ids))
    ).all()
    return {row.id: row.email for row in rows}


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/overview", response_model=OverviewOut)
def get_overview(
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> OverviewOut:
    today = date.today()
    today_start = _day_start(today)
    week_start = _day_start(today - timedelta(days=7))
    month_ago = datetime.now(UTC) - timedelta(days=30)

    total_users = db.scalar(select(func.count(User.id))) or 0
    active_users = db.scalar(select(func.count(User.id)).where(User.deleted_at.is_(None))) or 0
    deleted_users = total_users - active_users
    anonymous_users = db.scalar(
        select(func.count(User.id)).where(User.account_mode == "anonymous", User.deleted_at.is_(None))
    ) or 0

    premium_users = db.scalar(
        select(func.count(Subscription.id)).where(
            Subscription.tier != "free",
            Subscription.status.in_(["active", "trialing"]),
        )
    ) or 0
    trialing_users = db.scalar(
        select(func.count(Subscription.id)).where(Subscription.status == "trialing")
    ) or 0
    free_users = max(0, active_users - premium_users)

    wearable_connected_users = db.scalar(
        select(func.count(UserProfile.id)).where(
            UserProfile.wearable_type.notin_(["none", "NONE"]),
            UserProfile.wearable_type.isnot(None),
        )
    ) or 0

    onboarding_completed_users = db.scalar(
        select(func.count(OnboardingProgress.user_id)).where(OnboardingProgress.completed.is_(True))
    ) or 0

    signups_today = db.scalar(
        select(func.count(User.id)).where(User.created_at >= today_start)
    ) or 0
    signups_this_week = db.scalar(
        select(func.count(User.id)).where(User.created_at >= week_start)
    ) or 0

    ai_threads_total = db.scalar(select(func.count(MedicalChatThread.id))) or 0

    daily_logs_today = db.scalar(
        select(func.count(DailyLog.id)).where(DailyLog.logged_at >= today_start)
    ) or 0

    predictions_today = db.scalar(
        select(func.count(PredictionSnapshot.id)).where(PredictionSnapshot.generated_at >= today_start)
    ) or 0

    total_invoiced_gbp = db.scalar(
        select(func.coalesce(func.sum(Invoice.total), 0.0)).where(Invoice.status == "paid")
    ) or 0.0

    flw_errors = db.scalar(
        select(func.count(FlutterwaveWebhookErrorLog.id)).where(
            FlutterwaveWebhookErrorLog.created_at >= month_ago
        )
    ) or 0

    stripe_errors = db.scalar(
        select(func.count(StripeWebhookErrorLog.id)).where(
            StripeWebhookErrorLog.created_at >= month_ago
        )
    ) or 0

    referrals_total = db.scalar(select(func.count(ReferralAttribution.id))) or 0
    referrals_qualified = db.scalar(
        select(func.count(ReferralAttribution.id)).where(ReferralAttribution.status == "qualified")
    ) or 0

    active_grants = db.scalar(
        select(func.count(PremiumGrant.id)).where(
            PremiumGrant.active.is_(True),
            PremiumGrant.ends_at >= datetime.now(UTC),
        )
    ) or 0

    return OverviewOut(
        total_users=total_users,
        active_users=active_users,
        deleted_users=deleted_users,
        anonymous_users=anonymous_users,
        premium_users=premium_users,
        free_users=free_users,
        trialing_users=trialing_users,
        wearable_connected_users=wearable_connected_users,
        onboarding_completed_users=onboarding_completed_users,
        signups_today=signups_today,
        signups_this_week=signups_this_week,
        ai_threads_total=ai_threads_total,
        daily_logs_today=daily_logs_today,
        predictions_today=predictions_today,
        total_invoiced_gbp=float(total_invoiced_gbp),
        flutterwave_errors_30d=flw_errors,
        stripe_errors_30d=stripe_errors,
        referrals_total=referrals_total,
        referrals_qualified=referrals_qualified,
        active_premium_grants=active_grants,
    )


@router.get("/users", response_model=UserListOut)
def list_users(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    search: str | None = Query(default=None),
    account_mode: str | None = Query(default=None),
    email_verified: bool | None = Query(default=None),
    include_deleted: bool = Query(default=False),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> UserListOut:
    stmt = select(User, UserProfile).outerjoin(UserProfile, UserProfile.user_id == User.id)

    if not include_deleted:
        stmt = stmt.where(User.deleted_at.is_(None))
    if account_mode:
        stmt = stmt.where(User.account_mode == account_mode)
    if email_verified is not None:
        stmt = stmt.where(User.email_verified == email_verified)
    if search:
        term = f"%{search.lower()}%"
        stmt = stmt.where(
            User.email.ilike(term) | User.id.ilike(term)
        )

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.execute(stmt.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()

    user_ids = [u.id for u, _ in rows]
    # latest subscription per user
    sub_rows = db.execute(
        select(Subscription).where(Subscription.user_id.in_(user_ids)).order_by(Subscription.created_at.desc())
    ).scalars().all()
    sub_map: dict[str, Subscription] = {}
    for s in sub_rows:
        if s.user_id not in sub_map:
            sub_map[s.user_id] = s

    # onboarding completion
    ob_rows = db.execute(
        select(OnboardingProgress).where(OnboardingProgress.user_id.in_(user_ids))
    ).scalars().all()
    ob_map = {o.user_id: o for o in ob_rows}

    items = []
    for u, p in rows:
        sub = sub_map.get(u.id)
        ob = ob_map.get(u.id)
        items.append(UserItem(
            id=u.id,
            email=u.email,
            account_mode=u.account_mode,
            email_verified=u.email_verified,
            is_admin=u.is_admin,
            deleted_at=u.deleted_at.isoformat() if u.deleted_at else None,
            created_at=u.created_at.isoformat(),
            full_name=p.full_name if p else None,
            wearable_type=p.wearable_type.value if p and p.wearable_type else None,
            subscription_tier=sub.tier if sub else None,
            subscription_status=sub.status if sub else None,
            subscription_provider=sub.provider if sub else None,
            onboarding_completed=bool(ob and ob.completed),
        ))

    return UserListOut(items=items, total=total, page=page, page_size=page_size)


@router.get("/users/{user_id}", response_model=UserDetailOut)
def get_user(
    user_id: str,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> UserDetailOut:
    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    _audit(db, admin.id, "admin.user.view", {"target_user_id": user_id})
    db.commit()

    profile = db.scalar(select(UserProfile).where(UserProfile.user_id == user_id))
    ob = db.scalar(select(OnboardingProgress).where(OnboardingProgress.user_id == user_id))
    sub = db.scalar(
        select(Subscription).where(Subscription.user_id == user_id).order_by(Subscription.created_at.desc())
    )

    cycle_count = db.scalar(
        select(func.count(CycleRecord.id)).where(CycleRecord.user_id == user_id)
    ) or 0

    daily_log_count = db.scalar(
        select(func.count(DailyLog.id)).where(DailyLog.user_id == user_id)
    ) or 0

    ai_thread_count = db.scalar(
        select(func.count(MedicalChatThread.id)).where(MedicalChatThread.user_id == user_id)
    ) or 0

    return UserDetailOut(
        id=user.id,
        email=user.email,
        account_mode=user.account_mode,
        email_verified=user.email_verified,
        is_admin=user.is_admin,
        deleted_at=user.deleted_at.isoformat() if user.deleted_at else None,
        created_at=user.created_at.isoformat(),
        full_name=profile.full_name if profile else None,
        date_of_birth=profile.date_of_birth.isoformat() if profile and profile.date_of_birth else None,
        goal=profile.goal.value if profile and profile.goal else None,
        wearable_type=profile.wearable_type.value if profile and profile.wearable_type else None,
        timezone=profile.timezone if profile else None,
        onboarding_completed=bool(ob and ob.completed),
        onboarding_step=ob.current_step if ob else None,
        subscription_tier=sub.tier if sub else None,
        subscription_status=sub.status if sub else None,
        subscription_provider=sub.provider if sub else None,
        subscription_period_end=sub.current_period_end.isoformat() if sub and sub.current_period_end else None,
        cycle_records_count=cycle_count,
        daily_logs_count=daily_log_count,
        ai_threads_count=ai_thread_count,
    )


@router.post("/users/{user_id}/suspend", response_model=ActionResponse)
def suspend_user(
    user_id: str,
    reason: str = Query(default="admin_suspend"),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> ActionResponse:
    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if user.deleted_at:
        return ActionResponse(ok=False, message="User is already suspended")
    user.deleted_at = datetime.now(UTC)
    _audit(db, admin.id, "admin.user.suspend", {"target_user_id": user_id, "reason": reason})
    db.commit()
    return ActionResponse(ok=True, message="User suspended")


@router.post("/users/{user_id}/reactivate", response_model=ActionResponse)
def reactivate_user(
    user_id: str,
    reason: str = Query(default="admin_reactivate"),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> ActionResponse:
    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if not user.deleted_at:
        return ActionResponse(ok=False, message="User is already active")
    user.deleted_at = None
    _audit(db, admin.id, "admin.user.reactivate", {"target_user_id": user_id, "reason": reason})
    db.commit()
    return ActionResponse(ok=True, message="User reactivated")


@router.get("/subscriptions", response_model=SubListOut)
def list_subscriptions(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    tier: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    provider: str | None = Query(default=None),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> SubListOut:
    stmt = select(Subscription)
    if tier:
        stmt = stmt.where(Subscription.tier == tier)
    if status_filter:
        stmt = stmt.where(Subscription.status == status_filter)
    if provider:
        stmt = stmt.where(Subscription.provider == provider)

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    subs = db.scalars(stmt.order_by(Subscription.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()

    user_ids = list({s.user_id for s in subs})
    email_map = _email_map(db, user_ids)

    items = [
        SubItem(
            id=s.id,
            user_id=s.user_id,
            user_email=email_map.get(s.user_id),
            tier=s.tier,
            status=s.status,
            provider=s.provider,
            billing_interval=s.billing_interval,
            amount=s.amount,
            currency=s.currency,
            current_period_end=s.current_period_end.isoformat() if s.current_period_end else None,
            created_at=s.created_at.isoformat(),
        )
        for s in subs
    ]
    return SubListOut(items=items, total=total, page=page, page_size=page_size)


@router.post("/subscriptions/{user_id}/grant-premium", response_model=ActionResponse)
def grant_premium(
    user_id: str,
    body: GrantPremiumRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> ActionResponse:
    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    now = datetime.now(UTC)
    grant = PremiumGrant(
        user_id=user_id,
        tier="premium_plus",
        source_type="admin_grant",
        source_ref_id=admin.id,
        days_granted=body.days,
        starts_at=now,
        ends_at=now + timedelta(days=body.days),
        active=True,
        payload={"reason": body.reason, "granted_by": admin.id},
    )
    db.add(grant)
    _audit(db, admin.id, "admin.subscription.grant_premium", {
        "target_user_id": user_id,
        "days": body.days,
        "reason": body.reason,
    })
    db.commit()
    return ActionResponse(ok=True, message=f"Granted {body.days} days of premium to user {user_id}")


@router.get("/billing/invoices", response_model=InvoiceListOut)
def list_invoices(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    status_filter: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> InvoiceListOut:
    stmt = select(Invoice)
    if status_filter:
        stmt = stmt.where(Invoice.status == status_filter)

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    invoices = db.scalars(stmt.order_by(Invoice.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()

    # resolve user emails via subscriptions → user_id
    sub_ids = [inv.subscription_id for inv in invoices if inv.subscription_id]
    sub_rows = db.execute(select(Subscription.id, Subscription.user_id).where(Subscription.id.in_(sub_ids))).all()
    sub_to_user = {row.id: row.user_id for row in sub_rows}
    user_ids = list(set(sub_to_user.values()))
    email_map = _email_map(db, user_ids)

    # determine provider from linked subscription
    sub_provider_map = {}
    if sub_ids:
        p_rows = db.execute(select(Subscription.id, Subscription.provider).where(Subscription.id.in_(sub_ids))).all()
        sub_provider_map = {r.id: r.provider for r in p_rows}

    items = []
    for inv in invoices:
        uid = sub_to_user.get(inv.subscription_id or "")
        items.append(InvoiceItem(
            id=inv.id,
            subscription_id=inv.subscription_id,
            user_email=email_map.get(uid or "") if uid else None,
            provider_invoice_id=inv.provider_invoice_id,
            provider_customer_id=inv.provider_customer_id,
            total=inv.total,
            currency=inv.currency,
            status=inv.status,
            provider=sub_provider_map.get(inv.subscription_id or ""),
            created_at=inv.created_at.isoformat(),
        ))
    return InvoiceListOut(items=items, total=total, page=page, page_size=page_size)


@router.get("/billing/webhook-errors/flutterwave", response_model=FlwErrorListOut)
def list_flw_webhook_errors(
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> FlwErrorListOut:
    total = db.scalar(select(func.count(FlutterwaveWebhookErrorLog.id))) or 0
    rows = db.scalars(
        select(FlutterwaveWebhookErrorLog).order_by(FlutterwaveWebhookErrorLog.created_at.desc()).limit(limit)
    ).all()
    items = [
        FlwErrorItem(
            id=r.id,
            event_type=r.event_type,
            transaction_id=r.transaction_id,
            tx_ref=r.tx_ref,
            provider_customer_id=r.provider_customer_id,
            user_id=r.user_id,
            error_message=r.error_message,
            signature_present=r.signature_present,
            legacy_hash_present=r.legacy_hash_present,
            created_at=r.created_at.isoformat(),
        )
        for r in rows
    ]
    return FlwErrorListOut(items=items, total=total)


@router.get("/billing/webhook-errors/stripe", response_model=StripeErrorListOut)
def list_stripe_webhook_errors(
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> StripeErrorListOut:
    total = db.scalar(select(func.count(StripeWebhookErrorLog.id))) or 0
    rows = db.scalars(
        select(StripeWebhookErrorLog).order_by(StripeWebhookErrorLog.created_at.desc()).limit(limit)
    ).all()
    items = [
        StripeErrorItem(
            id=r.id,
            stripe_event_id=r.stripe_event_id,
            event_type=r.event_type,
            payment_intent_id=r.payment_intent_id,
            subscription_id=r.subscription_id,
            customer_id=r.customer_id,
            error_message=r.error_message,
            error_category=r.error_category,
            signature_present=r.signature_present,
            created_at=r.created_at.isoformat(),
        )
        for r in rows
    ]
    return StripeErrorListOut(items=items, total=total)


@router.get("/predictions", response_model=PredictionListOut)
def list_predictions(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    user_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> PredictionListOut:
    stmt = select(PredictionSnapshot)
    if user_id:
        stmt = stmt.where(PredictionSnapshot.user_id == user_id)

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    preds = db.scalars(stmt.order_by(PredictionSnapshot.generated_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()

    user_ids = list({p.user_id for p in preds})
    email_map = _email_map(db, user_ids)

    items = [
        PredictionItem(
            id=p.id,
            user_id=p.user_id,
            user_email=email_map.get(p.user_id),
            current_phase=p.current_phase,
            confidence=p.confidence,
            warning_flags=p.warning_flags or [],
            models_used=p.models_used or [],
            model_version=p.model_version,
            source=p.source,
            generated_at=p.generated_at.isoformat(),
        )
        for p in preds
    ]
    return PredictionListOut(items=items, total=total, page=page, page_size=page_size)


@router.get("/wearables", response_model=WearableListOut)
def list_wearables(
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> WearableListOut:
    profiles = db.scalars(
        select(UserProfile).where(
            UserProfile.wearable_type.notin_(["none", "NONE"]),
            UserProfile.wearable_type.isnot(None),
        ).limit(limit)
    ).all()

    user_ids = [p.user_id for p in profiles]
    email_map = _email_map(db, user_ids)

    # latest sync per user
    metric_rows = db.execute(
        select(WearableMetric.user_id, func.max(WearableMetric.collected_at).label("latest"))
        .where(WearableMetric.user_id.in_(user_ids))
        .group_by(WearableMetric.user_id)
    ).all()
    latest_map = {r.user_id: r.latest for r in metric_rows}

    count_rows = db.execute(
        select(WearableMetric.user_id, func.count(WearableMetric.id).label("cnt"))
        .where(WearableMetric.user_id.in_(user_ids))
        .group_by(WearableMetric.user_id)
    ).all()
    count_map = {r.user_id: r.cnt for r in count_rows}

    total = db.scalar(
        select(func.count(UserProfile.id)).where(
            UserProfile.wearable_type.notin_(["none", "NONE"]),
            UserProfile.wearable_type.isnot(None),
        )
    ) or 0

    items = [
        WearableUserItem(
            user_id=p.user_id,
            user_email=email_map.get(p.user_id),
            wearable_type=p.wearable_type.value if p.wearable_type else "none",
            latest_sync=latest_map[p.user_id].isoformat() if p.user_id in latest_map and latest_map[p.user_id] else None,
            metrics_count=count_map.get(p.user_id, 0),
        )
        for p in profiles
    ]
    return WearableListOut(items=items, total=total)


@router.get("/notifications", response_model=NotifHistoryOut)
def list_notifications(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    category: str | None = Query(default=None),
    notification_status: str | None = Query(default=None),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> NotifHistoryOut:
    stmt = select(NotificationHistory)
    if category:
        stmt = stmt.where(NotificationHistory.category == category)
    if notification_status:
        stmt = stmt.where(NotificationHistory.status == notification_status)

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(stmt.order_by(NotificationHistory.sent_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()

    items = [
        NotifHistoryItem(
            id=r.id,
            user_id=r.user_id,
            notification_type=r.notification_type,
            category=r.category,
            channel=r.channel,
            title=r.title,
            status=r.status,
            priority=r.priority,
            delivery_attempts=r.delivery_attempts,
            scheduled_for=r.scheduled_for.isoformat(),
            delivered_at=r.delivered_at.isoformat() if r.delivered_at else None,
        )
        for r in rows
    ]
    return NotifHistoryOut(items=items, total=total, page=page, page_size=page_size)


@router.get("/growth/referrals", response_model=ReferralListOut)
def list_referrals(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    ref_status: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> ReferralListOut:
    stmt = select(ReferralAttribution)
    if ref_status:
        stmt = stmt.where(ReferralAttribution.status == ref_status)

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(stmt.order_by(ReferralAttribution.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()

    inviter_ids = list({r.inviter_user_id for r in rows})
    email_map = _email_map(db, inviter_ids)

    items = [
        ReferralItem(
            id=r.id,
            inviter_user_id=r.inviter_user_id,
            inviter_email=email_map.get(r.inviter_user_id),
            invited_user_id=r.invited_user_id,
            referral_code=r.referral_code,
            source=r.source,
            status=r.status,
            created_at=r.created_at.isoformat(),
            qualified_at=r.qualified_at.isoformat() if r.qualified_at else None,
        )
        for r in rows
    ]
    return ReferralListOut(items=items, total=total, page=page, page_size=page_size)


@router.get("/growth/grants", response_model=GrantListOut)
def list_grants(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    active_only: bool = Query(default=False),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> GrantListOut:
    stmt = select(PremiumGrant)
    if active_only:
        stmt = stmt.where(PremiumGrant.active.is_(True), PremiumGrant.ends_at >= datetime.now(UTC))

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(stmt.order_by(PremiumGrant.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()

    user_ids = list({r.user_id for r in rows})
    email_map = _email_map(db, user_ids)

    items = [
        GrantItem(
            id=r.id,
            user_id=r.user_id,
            user_email=email_map.get(r.user_id),
            tier=r.tier,
            source_type=r.source_type,
            days_granted=r.days_granted,
            starts_at=r.starts_at.isoformat(),
            ends_at=r.ends_at.isoformat(),
            active=r.active,
            created_at=r.created_at.isoformat(),
        )
        for r in rows
    ]
    return GrantListOut(items=items, total=total, page=page, page_size=page_size)


@router.get("/ai/threads", response_model=AiThreadListOut)
def list_ai_threads(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    user_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> AiThreadListOut:
    stmt = select(MedicalChatThread)
    if user_id:
        stmt = stmt.where(MedicalChatThread.user_id == user_id)

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    threads = db.scalars(stmt.order_by(MedicalChatThread.updated_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()

    thread_ids = [t.id for t in threads]
    msg_counts = db.execute(
        select(MedicalChatMessage.thread_id, func.count(MedicalChatMessage.id).label("cnt"))
        .where(MedicalChatMessage.thread_id.in_(thread_ids))
        .group_by(MedicalChatMessage.thread_id)
    ).all()
    msg_map = {r.thread_id: r.cnt for r in msg_counts}

    user_ids = list({t.user_id for t in threads})
    email_map = _email_map(db, user_ids)

    items = [
        AiThreadItem(
            id=t.id,
            user_id=t.user_id,
            user_email=email_map.get(t.user_id),
            title=t.title,
            message_count=msg_map.get(t.id, 0),
            created_at=t.created_at.isoformat(),
            updated_at=t.updated_at.isoformat(),
        )
        for t in threads
    ]
    return AiThreadListOut(items=items, total=total, page=page, page_size=page_size)


@router.get("/audit-events", response_model=AuditEventListOut)
def list_audit_events(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    actor_id: str | None = Query(default=None),
    action_prefix: str | None = Query(default=None),
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_admin_user),
) -> AuditEventListOut:
    stmt = select(AuditEvent)
    if actor_id:
        stmt = stmt.where(AuditEvent.actor_user_id == actor_id)
    if action_prefix:
        stmt = stmt.where(AuditEvent.action.ilike(f"{action_prefix}%"))

    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(stmt.order_by(AuditEvent.created_at.desc()).offset((page - 1) * page_size).limit(page_size)).all()

    items = [
        AuditEventItem(
            id=r.id,
            actor_user_id=r.actor_user_id,
            action=r.action,
            payload=r.payload,
            created_at=r.created_at.isoformat(),
        )
        for r in rows
    ]
    return AuditEventListOut(items=items, total=total, page=page, page_size=page_size)
