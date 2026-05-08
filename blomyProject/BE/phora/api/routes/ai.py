from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_settings_dep
from phora.core.config import Settings
from phora.db.session import get_db
from phora.repositories.core import AuditRepository, UserRepository
from phora.schemas.ai import (
    MedicalChatConsentRequest,
    MedicalChatConsentResponse,
    MedicalChatHistoryResponse,
    MedicalChatRequest,
    MedicalChatResponse,
    MedicalChatThreadListResponse,
    PeriodLogAssistRequest,
    PeriodLogAssistResponse,
)
from phora.services.medical_chat import MedicalChatError, MedicalChatService
from phora.services.period_log_assistant import PeriodLogAssistantService

router = APIRouter(prefix="/ai", tags=["ai"])


def _consent_response(profile_conditions: dict) -> MedicalChatConsentResponse:
    ai_preferences = dict(profile_conditions.get("ai_preferences") or {})
    accepted = ai_preferences.get("chat_consent_accepted") == True
    accepted_at = ai_preferences.get("chat_consent_accepted_at")
    if not isinstance(accepted_at, str) or not accepted_at.strip():
        accepted_at = None
    return MedicalChatConsentResponse(
        accepted=accepted,
        accepted_at=accepted_at,
    )


@router.get("/chat/consent", response_model=MedicalChatConsentResponse)
def get_medical_chat_consent(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> MedicalChatConsentResponse:
    profile = UserRepository(db).ensure_profile(user_id)
    return _consent_response(dict(profile.conditions or {}))


@router.post("/chat/consent", response_model=MedicalChatConsentResponse)
def update_medical_chat_consent(
    payload: MedicalChatConsentRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> MedicalChatConsentResponse:
    profile = UserRepository(db).ensure_profile(user_id)
    conditions = dict(profile.conditions or {})
    ai_preferences = dict(conditions.get("ai_preferences") or {})
    if payload.accepted:
        ai_preferences["chat_consent_accepted"] = True
        ai_preferences["chat_consent_accepted_at"] = datetime.now(UTC).isoformat()
    else:
        ai_preferences["chat_consent_accepted"] = False
        ai_preferences.pop("chat_consent_accepted_at", None)
    conditions["ai_preferences"] = ai_preferences
    profile.conditions = conditions
    AuditRepository(db).log(
        user_id,
        "ai.chat.consent.updated",
        payload.model_dump(mode="json"),
    )
    db.commit()
    return _consent_response(conditions)


@router.post("/chat", response_model=MedicalChatResponse)
def medical_chat(
    payload: MedicalChatRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> MedicalChatResponse:
    service = MedicalChatService(db, settings)
    try:
        return service.chat(
            user_id=user_id,
            message=payload.message,
            thread_id=payload.thread_id,
            data_action=payload.data_action,
        )
    except MedicalChatError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/chat/latest", response_model=MedicalChatHistoryResponse)
def latest_medical_chat(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> MedicalChatHistoryResponse:
    service = MedicalChatService(db, settings)
    return service.latest_thread_history(user_id=user_id)


@router.get("/chat/threads", response_model=MedicalChatThreadListResponse)
def list_medical_chat_threads(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> MedicalChatThreadListResponse:
    service = MedicalChatService(db, settings)
    return service.list_threads(user_id=user_id)


@router.get("/chat/threads/{thread_id}", response_model=MedicalChatHistoryResponse)
def medical_chat_thread_history(
    thread_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> MedicalChatHistoryResponse:
    service = MedicalChatService(db, settings)
    try:
        return service.thread_history(user_id=user_id, thread_id=thread_id)
    except MedicalChatError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/log/period-assist", response_model=PeriodLogAssistResponse)
def assist_period_log(
    payload: PeriodLogAssistRequest,
    _: str = Depends(get_current_user_id),
    settings: Settings = Depends(get_settings_dep),
) -> PeriodLogAssistResponse:
    service = PeriodLogAssistantService(settings)
    return PeriodLogAssistResponse.model_validate(
        service.assist(
            message=payload.message,
            current_period=payload.current.period,
            current_symptoms=payload.current.symptoms,
        )
    )
