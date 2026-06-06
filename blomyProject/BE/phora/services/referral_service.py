import secrets
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import User
from phora.models.growth import PremiumGrant, ReferralAttribution, ReferralProfile
from phora.repositories.core import AuditRepository, UserRepository


class ReferralService:
    QUALIFIED_STATUSES = {"qualified"}
    MILESTONE_SIZE = 5
    REWARD_DAYS = 30

    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings
        self.audit = AuditRepository(db)
        self.users = UserRepository(db)

    @staticmethod
    def _now() -> datetime:
        return datetime.now(UTC)

    def ensure_profile(self, user_id: str) -> ReferralProfile:
        profile = self.db.query(ReferralProfile).filter(ReferralProfile.user_id == user_id).one_or_none()
        if profile:
            return profile
        code = self._unique_code()
        profile = ReferralProfile(user_id=user_id, referral_code=code)
        self.db.add(profile)
        self.db.flush()
        return profile

    def get_status(self, user_id: str) -> dict:
        profile = self.ensure_profile(user_id)
        attribution = (
            self.db.query(ReferralAttribution)
            .filter(ReferralAttribution.invited_user_id == user_id)
            .order_by(ReferralAttribution.created_at.desc())
            .first()
        )
        claimed_inviter_name = None
        if attribution and attribution.inviter_user_id:
            inviter = self.users.by_id(attribution.inviter_user_id)
            if inviter:
                inviter_profile = self.users.ensure_profile(inviter.id)
                claimed_inviter_name = inviter_profile.full_name or inviter.email
        return {
            "referral_code": profile.referral_code,
            "invite_link": f"vyla://sign-up?ref={profile.referral_code}&source=invite",
            "qualified_invites_count": profile.qualified_invites_count,
            "rewarded_milestones": profile.rewarded_milestones,
            "invites_until_next_reward": self.MILESTONE_SIZE - (profile.qualified_invites_count % self.MILESTONE_SIZE or self.MILESTONE_SIZE),
            "total_premium_days_earned": profile.rewarded_milestones * self.REWARD_DAYS,
            "claimed_referral_code": attribution.referral_code if attribution else None,
            "claimed_inviter_name": claimed_inviter_name,
        }

    def claim_code(self, user_id: str, referral_code: str, *, source: str | None, deep_link_id: str | None) -> None:
        invitee = self.users.by_id(user_id)
        if not invitee:
            raise ValueError("Invitee not found")
        invitee_profile = self.ensure_profile(user_id)
        if invitee_profile.referral_code == referral_code:
            raise ValueError("You cannot use your own referral code")

        inviter_profile = (
            self.db.query(ReferralProfile).filter(ReferralProfile.referral_code == referral_code.upper().strip()).one_or_none()
        )
        if not inviter_profile:
            raise ValueError("Referral code not found")
        if inviter_profile.user_id == user_id:
            raise ValueError("You cannot use your own referral code")
        existing = (
            self.db.query(ReferralAttribution)
            .filter(ReferralAttribution.invited_user_id == user_id)
            .one_or_none()
        )
        if existing:
            raise ValueError("Referral has already been claimed")

        attribution = ReferralAttribution(
            inviter_user_id=inviter_profile.user_id,
            invited_user_id=user_id,
            referral_code=inviter_profile.referral_code,
            source=source,
            deep_link_id=deep_link_id,
            status="pending",
            claimed_at=self._now(),
            payload={"anti_abuse": self._anti_abuse_snapshot(invitee)},
        )
        self.db.add(attribution)
        self.db.flush()
        self.audit.log(
            user_id,
            "growth.referral_claimed",
            {"referral_code": inviter_profile.referral_code, "inviter_user_id": inviter_profile.user_id, "source": source, "deep_link_id": deep_link_id},
        )

    def evaluate_user_qualification(self, user_id: str) -> None:
        attribution = (
            self.db.query(ReferralAttribution)
            .filter(ReferralAttribution.invited_user_id == user_id)
            .one_or_none()
        )
        if not attribution:
            return
        user = self.users.by_id(user_id)
        if not user:
            return
        profile = self.users.ensure_profile(user_id)

        qualified, reason = self._is_qualified(user, profile)
        if qualified:
            if attribution.status != "qualified":
                attribution.status = "qualified"
                attribution.qualified_at = self._now()
                attribution.qualification_reason = "completed_onboarding"
                inviter_profile = self.ensure_profile(attribution.inviter_user_id)
                inviter_profile.qualified_invites_count = self._qualified_count(attribution.inviter_user_id)
                self.audit.log(
                    attribution.inviter_user_id,
                    "growth.referral_qualified",
                    {"invited_user_id": user_id, "referral_code": attribution.referral_code},
                )
                self._grant_rewards_if_needed(inviter_profile)
        else:
            attribution.status = "disqualified"
            attribution.disqualified_at = self._now()
            attribution.qualification_reason = reason

    def _grant_rewards_if_needed(self, profile: ReferralProfile) -> None:
        milestone_count = profile.qualified_invites_count // self.MILESTONE_SIZE
        while profile.rewarded_milestones < milestone_count:
            profile.rewarded_milestones += 1
            start = self._next_grant_start(profile.user_id)
            end = start + timedelta(days=self.REWARD_DAYS)
            grant = PremiumGrant(
                user_id=profile.user_id,
                tier="premium_plus",
                source_type="referral_reward",
                source_ref_id=f"{profile.user_id}:{profile.rewarded_milestones}",
                days_granted=self.REWARD_DAYS,
                starts_at=start,
                ends_at=end,
                payload={"rewarded_milestone": profile.rewarded_milestones},
            )
            self.db.add(grant)
            self.db.flush()
            self.audit.log(
                profile.user_id,
                "growth.referral_reward_granted",
                {"rewarded_milestone": profile.rewarded_milestones, "grant_id": grant.id, "ends_at": end.isoformat()},
            )

    def _next_grant_start(self, user_id: str) -> datetime:
        latest = (
            self.db.query(PremiumGrant)
            .filter(PremiumGrant.user_id == user_id)
            .order_by(PremiumGrant.ends_at.desc())
            .first()
        )
        now = self._now()
        if latest and latest.ends_at > now:
            return latest.ends_at
        return now

    def _qualified_count(self, inviter_user_id: str) -> int:
        return (
            self.db.query(ReferralAttribution)
            .filter(
                ReferralAttribution.inviter_user_id == inviter_user_id,
                ReferralAttribution.status == "qualified",
            )
            .count()
        )

    def _is_qualified(self, user: User, profile) -> tuple[bool, str]:
        if not user.email_verified:
            return False, "email_unverified"
        if profile.onboarding_completed_at is None:
            return False, "onboarding_incomplete"
        return True, "qualified"

    def _anti_abuse_snapshot(self, user: User) -> dict:
        return {
            "email_verified": user.email_verified,
            "account_mode": user.account_mode,
            "created_at": user.created_at.isoformat() if user.created_at else None,
        }

    def _unique_code(self) -> str:
        while True:
            candidate = secrets.token_urlsafe(6).replace("-", "").replace("_", "").upper()[:10]
            existing = self.db.query(ReferralProfile).filter(ReferralProfile.referral_code == candidate).one_or_none()
            if not existing:
                return candidate
