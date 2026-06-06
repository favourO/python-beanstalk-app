from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from phora.models.billing import Subscription
from phora.models.growth import PremiumGrant

_ACTIVE_SUBSCRIPTION_STATUSES = {"active", "trialing"}
_ACTIVE_BILLING_PROVIDERS = {"stripe", "africa_free_launch"}


@dataclass
class PremiumAccessStatus:
    tier: str
    is_active: bool
    source: str
    provider: str | None = None
    status: str = "inactive"
    billing_interval: str | None = None
    provider_price_id: str | None = None
    current_period_end: datetime | None = None
    amount: float | None = None
    currency: str | None = None


class PremiumAccessService:
    def __init__(self, db: Session):
        self.db = db

    @staticmethod
    def _now() -> datetime:
        return datetime.now(UTC)

    def latest_subscription(self, user_id: str) -> Subscription | None:
        return (
            self.db.query(Subscription)
            .filter(Subscription.user_id == user_id)
            .order_by(Subscription.created_at.desc())
            .first()
        )

    def active_grant(self, user_id: str) -> PremiumGrant | None:
        now = self._now()
        return (
            self.db.query(PremiumGrant)
            .filter(
                PremiumGrant.user_id == user_id,
                PremiumGrant.active.is_(True),
                PremiumGrant.starts_at <= now,
                PremiumGrant.ends_at >= now,
            )
            .order_by(PremiumGrant.ends_at.desc())
            .first()
        )

    def _subscription_has_active_access(self, subscription: Subscription) -> bool:
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
            return current_period_end > self._now()
        return False

    def status(self, user_id: str) -> PremiumAccessStatus:
        subscription = self.latest_subscription(user_id)
        if subscription and subscription.tier != "free" and self._subscription_has_active_access(subscription):
            return PremiumAccessStatus(
                tier=subscription.tier,
                is_active=True,
                source="subscription",
                provider=subscription.provider,
                status=subscription.status,
                billing_interval=subscription.billing_interval,
                provider_price_id=subscription.provider_price_id,
                current_period_end=subscription.current_period_end,
                amount=subscription.amount,
                currency=subscription.currency,
            )

        grant = self.active_grant(user_id)
        if grant:
            return PremiumAccessStatus(
                tier=grant.tier,
                is_active=True,
                source=grant.source_type,
                status="active",
                current_period_end=grant.ends_at,
            )

        if subscription and subscription.tier == "free":
            return PremiumAccessStatus(
                tier=subscription.tier,
                is_active=True,
                source="subscription",
                provider=subscription.provider,
                status=subscription.status,
                billing_interval=subscription.billing_interval,
                provider_price_id=subscription.provider_price_id,
                current_period_end=subscription.current_period_end,
                amount=subscription.amount,
                currency=subscription.currency,
            )

        if subscription:
            return PremiumAccessStatus(
                tier=subscription.tier,
                is_active=False,
                source="subscription",
                provider=subscription.provider,
                status=subscription.status,
                billing_interval=subscription.billing_interval,
                provider_price_id=subscription.provider_price_id,
                current_period_end=subscription.current_period_end,
                amount=subscription.amount,
                currency=subscription.currency,
            )

        return PremiumAccessStatus(tier="free", is_active=False, source="free")
