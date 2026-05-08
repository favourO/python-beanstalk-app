from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id
from phora.db.session import get_db
from phora.models import CycleRecord
from phora.repositories.core import AuditRepository, UserRepository
from phora.schemas.onboarding import (
    OnboardingCompleteRequest,
    OnboardingCompleteResponse,
    OnboardingCycleHistoryRequest,
    OnboardingGoalRequest,
    OnboardingProgressPatchRequest,
    OnboardingProgressResponse,
    OnboardingHealthConditionsRequest,
    OnboardingPrivacyPreferencesRequest,
    OnboardingProfileRequest,
    OnboardingWearableRequest,
    ProfileResponse,
)
from phora.services.age import derive_age_band, should_activate_perimenopause_mode
from phora.core.config import get_settings
from phora.services.daily_insights import DailyInsightService
from phora.services.referral_service import ReferralService
from phora.models.enums import WearableType

router = APIRouter(prefix="/onboarding", tags=["onboarding"])


def _is_connected_wearable(wearable_type: WearableType | None) -> bool:
    return wearable_type not in {None, WearableType.NONE, WearableType.MANUAL_BBT}


def _assert_single_wearable_connection(
    *,
    current: WearableType | None,
    requested: WearableType,
) -> None:
    if not _is_connected_wearable(current):
        return
    if not _is_connected_wearable(requested):
        return
    if current == requested:
        return
    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=(
            "Only one wearable can be connected at a time. "
            "Disconnect the current wearable before connecting a different one."
        ),
    )


def _refresh_today_insight(db: Session, user_id: str, phase: str | None = None) -> None:
    DailyInsightService(db, get_settings()).get_or_generate(
        user_id=user_id,
        insight_date=datetime.now(UTC).date(),
        phase=phase,
        force=True,
    )


def _create_cycle_history(
    db: Session,
    *,
    user_id: str,
    payload: OnboardingCycleHistoryRequest,
) -> CycleRecord:
    active = CycleRecord(
        user_id=user_id,
        period_start_date=payload.last_period_date,
        period_end_date=payload.last_period_end,
        mu_cycle=float(payload.avg_cycle_length or 28),
        sigma_cycle=5.5 if payload.irregularity_flag else 2.5,
        menses_length=payload.avg_period_duration,
        is_active=True,
    )
    db.add(active)
    db.flush()
    return active


def _save_goal(
    db: Session,
    *,
    user_id: str,
    payload: OnboardingGoalRequest,
):
    profile = UserRepository(db).ensure_profile(user_id)
    profile.goal = payload.goal
    return profile


def _save_health_conditions(
    db: Session,
    *,
    user_id: str,
    payload: OnboardingHealthConditionsRequest,
) -> list[str]:
    profile = UserRepository(db).ensure_profile(user_id)
    audit = AuditRepository(db)
    conditions = dict(profile.conditions or {})
    conditions["health_conditions"] = payload.conditions
    profile.conditions = conditions
    audit.log(user_id, "onboarding.health_conditions.updated", payload.model_dump(mode="json"))
    return payload.conditions


def _serialize_progress(progress) -> OnboardingProgressResponse:
    return OnboardingProgressResponse(
        current_step=progress.current_step,
        completed=progress.completed,
        period_length=progress.period_length,
        last_period_start=progress.last_period_start,
        last_period_end=progress.last_period_end,
        goal=progress.goal,
        health_conditions=list(progress.health_conditions or []),
        updated_at=progress.updated_at,
    )


def _clear_progress(progress) -> None:
    progress.current_step = None
    progress.completed = True
    progress.period_length = None
    progress.last_period_start = None
    progress.last_period_end = None
    progress.goal = None
    progress.health_conditions = []


@router.get("/progress", response_model=OnboardingProgressResponse)
def onboarding_progress(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> OnboardingProgressResponse:
    progress = UserRepository(db).ensure_onboarding_progress(user_id)
    if progress.current_step is None and not progress.completed:
        progress.current_step = 1
        db.commit()
        db.refresh(progress)
    return _serialize_progress(progress)


@router.patch("/progress", response_model=OnboardingProgressResponse)
def update_onboarding_progress(
    payload: OnboardingProgressPatchRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> OnboardingProgressResponse:
    progress = UserRepository(db).ensure_onboarding_progress(user_id)
    data = payload.model_dump(exclude_unset=True)
    for field_name, value in data.items():
        setattr(progress, field_name, value)
    progress.completed = False
    db.commit()
    db.refresh(progress)
    return _serialize_progress(progress)


@router.post("/profile", response_model=ProfileResponse)
def onboarding_profile(
    payload: OnboardingProfileRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> ProfileResponse:
    users = UserRepository(db)
    audit = AuditRepository(db)
    profile = users.ensure_profile(user_id)
    profile.full_name = payload.full_name
    profile.date_of_birth = payload.date_of_birth
    profile.age_at_menarche = payload.age_at_menarche
    profile.height_cm = payload.height_cm
    profile.weight_kg = payload.weight_kg
    profile.timezone = payload.timezone
    profile.conditions = payload.conditions
    if payload.height_cm and payload.weight_kg:
        profile.bmi = round(payload.weight_kg / ((payload.height_cm / 100) ** 2), 2)
    age = None
    if payload.date_of_birth:
        age = datetime.now(UTC).date().year - payload.date_of_birth.year
    profile.age_band = derive_age_band(age)
    peri_active, peri_source = should_activate_perimenopause_mode(
        profile.age_band,
        None,
        bool(payload.conditions.get("perimenopause_self_reported")),
        payload.conditions,
    )
    profile.perimenopause_mode_active = peri_active
    profile.perimenopause_mode_source = peri_source
    profile.age_band_updated_at = datetime.now(UTC)
    audit.log(user_id, "onboarding.profile.updated", payload.model_dump(mode="json"))
    db.commit()
    _refresh_today_insight(db, user_id)
    return ProfileResponse(
        user_id=user_id,
        onboarding_completed_at=profile.onboarding_completed_at,
        bmi=profile.bmi,
        age_band=profile.age_band,
        perimenopause_mode_active=profile.perimenopause_mode_active,
    )


@router.post("/cycle-history")
def onboarding_cycle_history(
    payload: OnboardingCycleHistoryRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    active = _create_cycle_history(db, user_id=user_id, payload=payload)
    db.commit()
    _refresh_today_insight(db, user_id)
    return {"status": "created", "cycle_id": active.id}


@router.post("/goal")
def onboarding_goal(
    payload: OnboardingGoalRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    _save_goal(db, user_id=user_id, payload=payload)
    db.commit()
    return {"status": "ok", "goal": payload.goal}


@router.post("/wearable")
def onboarding_wearable(
    payload: OnboardingWearableRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    users = UserRepository(db)
    profile = users.ensure_profile(user_id)
    _assert_single_wearable_connection(
        current=profile.wearable_type,
        requested=payload.wearable_type,
    )
    profile.wearable_type = payload.wearable_type
    profile.onboarding_completed_at = datetime.now(UTC)
    progress = users.ensure_onboarding_progress(user_id)
    _clear_progress(progress)
    ReferralService(db, get_settings()).evaluate_user_qualification(user_id)
    db.commit()
    _refresh_today_insight(db, user_id)
    return {"status": "ok", "wearable_type": payload.wearable_type}


@router.post("/health-conditions")
def onboarding_health_conditions(
    payload: OnboardingHealthConditionsRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    _save_health_conditions(db, user_id=user_id, payload=payload)
    db.commit()
    return {"status": "ok", "conditions": payload.conditions}


@router.post("/complete", response_model=OnboardingCompleteResponse)
def onboarding_complete(
    payload: OnboardingCompleteRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> OnboardingCompleteResponse:
    active = _create_cycle_history(db, user_id=user_id, payload=payload.cycle_history)
    profile = _save_goal(db, user_id=user_id, payload=OnboardingGoalRequest(goal=payload.goal))
    conditions = _save_health_conditions(
        db,
        user_id=user_id,
        payload=OnboardingHealthConditionsRequest(conditions=payload.health_conditions),
    )
    profile.onboarding_completed_at = datetime.now(UTC)
    progress = UserRepository(db).ensure_onboarding_progress(user_id)
    _clear_progress(progress)
    ReferralService(db, get_settings()).evaluate_user_qualification(user_id)
    db.commit()
    _refresh_today_insight(db, user_id)
    return OnboardingCompleteResponse(
        cycle_id=active.id,
        goal=payload.goal,
        health_conditions=conditions,
    )


@router.post("/privacy-preferences")
def onboarding_privacy_preferences(
    payload: OnboardingPrivacyPreferencesRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    profile = UserRepository(db).ensure_profile(user_id)
    audit = AuditRepository(db)
    conditions = dict(profile.conditions or {})
    conditions["privacy_preferences"] = payload.model_dump(mode="json")
    profile.conditions = conditions
    audit.log(user_id, "onboarding.privacy_preferences.updated", payload.model_dump(mode="json"))
    db.commit()
    return {"status": "ok", "privacy_preferences": payload.model_dump(mode="json")}
