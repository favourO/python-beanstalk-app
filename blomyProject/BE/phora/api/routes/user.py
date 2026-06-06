from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_settings_dep
from phora.db.session import get_db
from phora.repositories.core import AuditRepository, UserRepository
from phora.models import User
from phora.schemas.user import (
    AgeProfileResponse,
    DeleteAccountRequest,
    AgeProfileUpdateRequest,
    DeleteAccountResponse,
    ReproductiveStageRequest,
    UserProfileResponse,
)
from phora.services.auth import AuthService
from phora.services.email import EmailDeliveryError, EmailService
from phora.services.age import POPULATION_PRIORS, age_band_label, age_on_day, derive_age_band

router = APIRouter(prefix="/user", tags=["user"])


@router.get("/profile", response_model=UserProfileResponse)
def get_profile(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> UserProfileResponse:
    users = UserRepository(db)
    user = db.query(User).filter(User.id == user_id).one()
    profile = users.ensure_profile(user_id)
    conditions = dict(profile.conditions or {})
    return UserProfileResponse(
        user_id=user.id,
        email=user.email,
        email_verified=user.email_verified,
        account_mode=user.account_mode,
        full_name=profile.full_name,
        date_of_birth=profile.date_of_birth,
        age_at_menarche=profile.age_at_menarche,
        height_cm=profile.height_cm,
        weight_kg=profile.weight_kg,
        bmi=profile.bmi,
        goal=profile.goal.value if profile.goal else None,
        wearable_type=profile.wearable_type.value if profile.wearable_type else None,
        timezone=profile.timezone,
        conditions=conditions,
        health_conditions=conditions.get("health_conditions", []),
        privacy_preferences=conditions.get("privacy_preferences", {}),
        onboarding_completed_at=profile.onboarding_completed_at,
        age_band=profile.age_band,
        perimenopause_mode_active=profile.perimenopause_mode_active,
        perimenopause_mode_source=profile.perimenopause_mode_source,
    )


@router.get("/age-profile", response_model=AgeProfileResponse)
def get_age_profile(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> AgeProfileResponse:
    profile = UserRepository(db).ensure_profile(user_id)
    current_age = age_on_day(profile.date_of_birth, datetime.now(UTC).date())
    band = profile.age_band or derive_age_band(current_age)
    return AgeProfileResponse(
        date_of_birth=profile.date_of_birth,
        age_at_menarche=profile.age_at_menarche,
        current_age=current_age,
        age_band=band,
        age_band_label=age_band_label(band),
        perimenopause_mode_active=profile.perimenopause_mode_active,
        perimenopause_mode_source=profile.perimenopause_mode_source,
        population_priors_for_band=POPULATION_PRIORS.get(band or "", {}),
    )


@router.put("/age-profile", response_model=AgeProfileResponse)
def update_age_profile(
    payload: AgeProfileUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> AgeProfileResponse:
    profile = UserRepository(db).ensure_profile(user_id)
    if payload.date_of_birth is not None:
        profile.date_of_birth = payload.date_of_birth
        profile.age_band = derive_age_band(age_on_day(payload.date_of_birth, datetime.now(UTC).date()))
        profile.age_band_updated_at = datetime.now(UTC)
    if payload.age_at_menarche is not None:
        profile.age_at_menarche = payload.age_at_menarche
    if payload.perimenopause_mode_active is not None:
        profile.perimenopause_mode_active = payload.perimenopause_mode_active
        profile.perimenopause_mode_source = "user_set" if payload.perimenopause_mode_active else "user_deactivated"
    AuditRepository(db).log(user_id, "user.age_profile.updated", payload.model_dump(mode="json"))
    db.commit()
    return get_age_profile(user_id, db)


@router.post("/reproductive-stage")
def set_reproductive_stage(
    payload: ReproductiveStageRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    profile = UserRepository(db).ensure_profile(user_id)
    profile.perimenopause_mode_active = payload.stage == "perimenopause_aware"
    profile.perimenopause_mode_source = "user_set" if profile.perimenopause_mode_active else "user_deactivated"
    AuditRepository(db).log(user_id, "user.reproductive_stage.updated", payload.model_dump(mode="json"))
    db.commit()
    return {"status": "ok", "stage": payload.stage}


@router.post("/account/delete-otp", response_model=DeleteAccountResponse, status_code=200)
def request_delete_account_otp(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> DeleteAccountResponse:
    try:
        AuthService(db, settings, EmailService(settings)).request_delete_account_otp(user_id)
    except EmailDeliveryError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return DeleteAccountResponse(message="Confirmation code sent to your email.")


@router.delete("/account", response_model=DeleteAccountResponse, status_code=200)
def delete_account(
    payload: DeleteAccountRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> DeleteAccountResponse:
    try:
        AuthService(db, settings, EmailService(settings)).delete_account(user_id, payload.otp_code)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return DeleteAccountResponse()
