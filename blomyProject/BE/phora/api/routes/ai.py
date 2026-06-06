from datetime import UTC, datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import StreamingResponse
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
    MedicalDocumentAnalysisResponse,
    PeriodLogAssistRequest,
    PeriodLogAssistResponse,
)
from phora.services.medical_chat import (
    MEDICAL_DOCUMENT_MAX_BYTES,
    MedicalChatError,
    MedicalChatPremiumRequiredError,
    MedicalChatQuotaError,
    MedicalChatService,
)
from phora.services.period_log_assistant import PeriodLogAssistantService

router = APIRouter(prefix="/ai", tags=["ai"])


def _read_upload_file(file: UploadFile, *, max_bytes: int) -> bytes:
    chunks: list[bytes] = []
    total = 0
    chunk_size = 1024 * 1024
    while True:
        chunk = file.file.read(chunk_size)
        if not chunk:
            break
        total += len(chunk)
        if total > max_bytes:
            raise MedicalChatError("Please upload a medical document smaller than 25 MB.")
        chunks.append(chunk)
    return b"".join(chunks)


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


@router.post("/chat/stream")
def medical_chat_stream(
    payload: MedicalChatRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> StreamingResponse:
    service = MedicalChatService(db, settings)
    return StreamingResponse(
        service.chat_stream(
            user_id=user_id,
            message=payload.message,
            thread_id=payload.thread_id,
            data_action=payload.data_action,
        ),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


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
    except MedicalChatQuotaError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "message": str(exc),
                "tier": exc.tier,
                "chat_limit": exc.limit,
                "chats_used": exc.used,
                "chats_remaining": 0,
                "quota_reset_at": exc.reset_at.isoformat(),
            },
        ) from exc
    except MedicalChatError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/chat/document-analysis", response_model=MedicalDocumentAnalysisResponse)
def analyze_medical_document(
    file: UploadFile = File(...),
    question: str | None = Form(default=None),
    thread_id: str | None = Form(default=None),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> MedicalDocumentAnalysisResponse:
    service = MedicalChatService(db, settings)
    try:
        service.ensure_document_analysis_access(user_id)
        data = _read_upload_file(file, max_bytes=MEDICAL_DOCUMENT_MAX_BYTES)
        return service.analyze_document(
            user_id=user_id,
            filename=file.filename or "uploaded-document",
            content_type=file.content_type,
            data=data,
            question=question,
            thread_id=thread_id,
        )
    except MedicalChatPremiumRequiredError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={"message": str(exc), "paywall_reason": "ai_chat_premium"},
        ) from exc
    except MedicalChatQuotaError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "message": str(exc),
                "tier": exc.tier,
                "chat_limit": exc.limit,
                "chats_used": exc.used,
                "chats_remaining": 0,
                "quota_reset_at": exc.reset_at.isoformat(),
            },
        ) from exc
    except MedicalChatError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


def _parse_history_cursor(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid history cursor") from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed


@router.get("/chat/latest", response_model=MedicalChatHistoryResponse)
def latest_medical_chat(
    before: str | None = None,
    limit: int = 24,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> MedicalChatHistoryResponse:
    service = MedicalChatService(db, settings)
    return service.latest_thread_history(user_id=user_id, limit=limit, before=_parse_history_cursor(before))


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
    before: str | None = None,
    limit: int = 24,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> MedicalChatHistoryResponse:
    service = MedicalChatService(db, settings)
    try:
        return service.thread_history(user_id=user_id, thread_id=thread_id, limit=limit, before=_parse_history_cursor(before))
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
