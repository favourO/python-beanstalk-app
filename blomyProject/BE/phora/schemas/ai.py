from typing import Any, Literal

from pydantic import BaseModel, Field

from phora.schemas.daily_log import PeriodLogPayload, SymptomsLogPayload


class MedicalChatDataAction(BaseModel):
    action: Literal[
        "save_period_start",
        "save_temperature",
        "save_symptoms",
        "save_intimacy",
        "save_lh",
        "save_mucus",
        "save_profile",
    ]
    payload: dict[str, Any] = Field(default_factory=dict)


class MedicalChatRequest(BaseModel):
    message: str = Field(min_length=2, max_length=4000)
    thread_id: str | None = None
    data_action: MedicalChatDataAction | None = None


class MedicalChatMissingData(BaseModel):
    action: str
    endpoint: str
    reason: str
    prompt: str
    payload_template: dict[str, Any] = Field(default_factory=dict)


class MedicalChatResponse(BaseModel):
    thread_id: str | None = None
    answer: str
    medical_only: bool = True
    sufficient_data: bool = False
    chat_limit: int | None = None
    chats_used: int | None = None
    chats_remaining: int | None = None
    quota_reset_at: str | None = None
    used_user_data: list[str] = Field(default_factory=list)
    saved_records: list[str] = Field(default_factory=list)
    missing_data: list[MedicalChatMissingData] = Field(default_factory=list)
    disclaimer: str


class MedicalDocumentAnalysisResponse(MedicalChatResponse):
    filename: str
    extracted_text_chars: int = 0
    document_type: str


class MedicalChatHistoryItem(BaseModel):
    role: str
    content: str
    created_at: str | None = None


class MedicalChatThreadSummary(BaseModel):
    thread_id: str
    title: str | None = None
    preview: str | None = None
    created_at: str | None = None
    updated_at: str | None = None
    message_count: int = 0


class MedicalChatHistoryResponse(BaseModel):
    thread_id: str | None = None
    messages: list[MedicalChatHistoryItem] = Field(default_factory=list)
    has_more: bool = False
    next_before: str | None = None


class MedicalChatThreadListResponse(BaseModel):
    threads: list[MedicalChatThreadSummary] = Field(default_factory=list)
    has_more: bool = False
    next_before: str | None = None


class MedicalChatConsentRequest(BaseModel):
    accepted: bool = True


class MedicalChatConsentResponse(BaseModel):
    accepted: bool = False
    accepted_at: str | None = None


class PeriodLogAssistCurrent(BaseModel):
    period: PeriodLogPayload = Field(default_factory=PeriodLogPayload)
    symptoms: SymptomsLogPayload = Field(default_factory=SymptomsLogPayload)


class PeriodLogAssistRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    current: PeriodLogAssistCurrent = Field(default_factory=PeriodLogAssistCurrent)


class PeriodLogAssistResponse(BaseModel):
    assistant_message: str
    next_step: Literal["intensity", "colour", "symptoms", "notes", "review"]
    completed: bool = False
    period: PeriodLogPayload
    symptoms: SymptomsLogPayload
