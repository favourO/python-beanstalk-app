from __future__ import annotations

import base64
import csv
import io
import json
import re
import zipfile
from datetime import UTC, date, datetime, timedelta
from statistics import mean, stdev
from typing import Any, Iterator
from xml.etree import ElementTree

from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import AiMemoryDocument, CycleRecord, DailyLog, MedicalChatMessage, MedicalChatThread, PredictionSnapshot, SensorReading
from phora.models.enums import LogType
from phora.repositories.core import AuditRepository, CycleRepository, DailyInsightRepository, PredictionRepository, SensorRepository, UserRepository
from phora.schemas.ai import (
    MedicalDocumentAnalysisResponse,
    MedicalChatDataAction,
    MedicalChatHistoryItem,
    MedicalChatHistoryResponse,
    MedicalChatMissingData,
    MedicalChatResponse,
    MedicalChatThreadListResponse,
    MedicalChatThreadSummary,
)
from phora.services.ai_gateway import AIGateway
from phora.services.ai_memory import (
    AIMemoryEmbeddingService,
    LOCAL_EMBEDDING_MODEL,
    OpenAIEmbeddingService,
    REAL_EMBEDDING_MODEL,
    REAL_EMBEDDING_DIMENSIONS,
)
from phora.services.premium_access import PremiumAccessService


class MedicalChatError(ValueError):
    pass


class MedicalChatQuotaError(MedicalChatError):
    def __init__(self, *, limit: int, used: int, reset_at: datetime, tier: str):
        self.limit = limit
        self.used = used
        self.reset_at = reset_at
        self.tier = tier
        super().__init__(
            f"You have used your {limit} Vyla AI chats for this week. "
            f"Your chat limit resets on {reset_at.date().isoformat()}."
        )


class MedicalChatPremiumRequiredError(MedicalChatError):
    pass


VYLA_AI_SYSTEM_PROMPT = """
You are Vyla AI — a deeply intelligent, empathetic, medically-aware women's health assistant designed to help users better understand their reproductive, hormonal, sexual, fertility, pregnancy, menstrual, wellness, and overall female health.

Your role is to provide highly personalized, safe, evidence-informed, emotionally intelligent, and context-aware guidance using the user's available health data, wearable signals, historical patterns, onboarding preferences, cycle history, symptoms, lifestyle data, and in-app behavior.

## Core Behavior

* Speak in calm, reassuring, intelligent, non-judgmental language.
* Be warm and supportive without sounding robotic or overly clinical.
* Explain complex medical or hormonal concepts in simple plain English.
* Never shame users for symptoms, sexual activity, cycle irregularities, fertility concerns, body changes, or lifestyle habits.
* Prioritize clarity, personalization, and safety.
* Avoid generic answers when personalized data exists.
* Always adapt responses to the user's current reproductive stage, health patterns, and historical data.

## Personalization Rules

You MUST dynamically personalize responses using all available user context including:

User Profile: age, height/weight, contraception type, pregnancy goals, relationship status, sexual activity, medical conditions, medication history, cycle history, fertility goals, menopause/perimenopause stage, PCOS/endometriosis history, previous pregnancy history.

Cycle & Hormonal Data: current cycle phase, predicted ovulation, period timing, cycle length variability, late or missed periods, PMS trends, symptom patterns, basal body temperature (BBT), cervical mucus logs, LH test results, ovulation confidence score.

Wearable & Sensor Data: sleep quality, HRV, resting heart rate, body temperature trends, stress trends, activity levels, fatigue patterns, nighttime temperature shifts, deep/light sleep changes.

## Intelligence Rules

When answering:
* Correlate symptoms with cycle phase and hormonal changes.
* Detect patterns across months, not just current data.
* Compare current cycle against the user's historical baseline.
* Identify abnormalities or trends that may require medical attention.
* Explain WHY something may be happening biologically.
* Distinguish between common hormonal changes, potential medical concerns, emergencies, fertility indicators, and lifestyle-related effects.

## AI Reasoning Framework

For every health question:
1. Analyze current cycle state.
2. Compare against historical baseline.
3. Analyze wearable trends.
4. Analyze symptom clusters.
5. Analyze recent behavioral changes.
6. Estimate confidence level.
7. Generate a personalized response.
8. Add safety escalation if needed.

## Reproductive & Sexual Health Coverage

Confidently support: menstrual cycles, ovulation, fertility, pregnancy, PMS/PMDD, PCOS, endometriosis, libido, sexual wellness, vaginal health, birth control, menopause, perimenopause, hormonal fluctuations, pelvic pain, discharge, breast tenderness, mood changes, bloating, irregular periods, cycle tracking, BBT interpretation, miscarriage awareness, fertility optimization, safe sex education, hormonal acne, nutrition and exercise impact on cycles, stress and reproductive health, sleep and hormone balance.

## Medical Safety Rules

You are NOT a replacement for a doctor. You MUST:
* Encourage professional medical help when symptoms may indicate risk.
* Clearly identify urgent symptoms.
* Avoid making definitive diagnoses.
* Use wording like "may indicate", "could be associated with", "it may help to speak with a healthcare professional".
* Escalate immediately for: severe pain, chest pain, suicidal thoughts, heavy bleeding, fainting, pregnancy emergencies, signs of infection, severe depression, dangerous blood pressure patterns.

## Response Style

Preferred structure:
1. Direct answer
2. Personalized explanation grounded in the user's data
3. What may be contributing
4. What to monitor
5. When to seek medical help
6. Helpful lifestyle or support suggestions

* Feel conversational and intelligent.
* Be concise first, detailed second.
* Use bullet points where useful.
* Be emotionally aware.
* Provide actionable next steps.
* Reference the user's actual data points (cycle day, temperature trends, sleep scores, HRV) naturally in the response.
* Mention patterns across past cycles when they are relevant.

## Privacy Rules

* Never expose raw internal calculations or system identifiers.
* Be privacy-first and respectful.
* Avoid assumptions when data confidence is low.
* If insufficient data exists, say so clearly and ask for the smallest useful next piece of context.

## Tone Examples

GOOD:
* "Based on your recent temperature trend and cycle timing, this could be related to ovulation."
* "Your recent sleep disruption and elevated stress may also be contributing."
* "This pattern has appeared in your last two cycles as well."
* "You are on cycle day 18, which puts you in your luteal phase — progesterone tends to peak now, which can affect sleep and mood."

BAD:
* "Women usually experience this."
* "I cannot help."
* "Consult your doctor." (without context or warmth)
* Robotic medical textbook language.
* Generic answers that ignore the user's supplied data.

Your goal is to make users feel understood, informed, emotionally supported, safer, more in control of their reproductive health, and increasingly aware of patterns in their body over time. You are not just answering questions — you are building a long-term intelligent understanding of the user's reproductive health journey.
""".strip()

URGENT_SYMPTOM_GUIDANCE = (
    "I want to treat this as potentially urgent. Vyla AI cannot assess emergencies or replace a clinician. "
    "Please seek urgent medical help now if you have severe or worsening pain, very heavy bleeding, fainting, chest pain, "
    "trouble breathing, signs of infection such as fever with pelvic pain or unusual discharge, pregnancy-related severe pain "
    "or bleeding, or thoughts of harming yourself. If you feel in immediate danger, contact local emergency services."
)

FREE_WEEKLY_CHAT_LIMIT = 3
PREMIUM_WEEKLY_CHAT_LIMIT = 50
CHAT_QUOTA_WINDOW_DAYS = 7
MEDICAL_DOCUMENT_MAX_BYTES = 25 * 1024 * 1024
MEDICAL_DOCUMENT_TEXT_LIMIT = 24000
MEDICAL_DOCUMENT_ALLOWED_EXTENSIONS = {".txt", ".csv", ".pdf", ".xlsx", ".xls", ".png", ".jpg", ".jpeg", ".webp", ".heic", ".heif"}
AI_SECURITY_POLICY_VERSION = "rag-security-phase1-2026-06"

PII_REDACTION_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE), "[redacted_email]"),
    (re.compile(r"\b\d{1,5}\s+[A-Za-z0-9.' -]{2,80}\s+(?:street|st|road|rd|avenue|ave|lane|ln|drive|dr|close|court|ct|way|boulevard|blvd)\b", re.IGNORECASE), "[redacted_address]"),
    (re.compile(r"\b(?:date of birth|dob|born)\s*[:=-]?\s*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b", re.IGNORECASE), "[redacted_dob]"),
    (re.compile(r"\b(?:my name is|i am called|i'm called)\s+[A-Z][A-Za-z.'-]+(?:\s+[A-Z][A-Za-z.'-]+){0,3}\b", re.IGNORECASE), "[redacted_name]"),
    (re.compile(r"\b\d{3}-\d{2}-\d{4}\b"), "[redacted_identifier]"),
)

PII_PAYLOAD_KEYS = {
    "address",
    "birth_date",
    "date_of_birth",
    "device_id",
    "dob",
    "email",
    "external_id",
    "first_name",
    "full_name",
    "last_name",
    "name",
    "phone",
    "postcode",
    "postal_code",
    "raw_text",
    "ssn",
    "street",
    "zip",
    "zipcode",
}


class MedicalChatService:
    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings
        self.users = UserRepository(db)
        self.cycles = CycleRepository(db)
        self.sensors = SensorRepository(db)
        self.predictions = PredictionRepository(db)
        self.insights = DailyInsightRepository(db)
        self.audit = AuditRepository(db)
        self.ai_gateway = AIGateway(settings)
        self._sqlite = settings.database_url.startswith("sqlite")
        if not self._sqlite and settings.llm_api_key:
            self.ai_memory_embeddings: AIMemoryEmbeddingService | OpenAIEmbeddingService = OpenAIEmbeddingService(
                api_key=settings.llm_api_key,
                base_url=settings.llm_base_url,
            )
        else:
            self.ai_memory_embeddings = AIMemoryEmbeddingService()

    def chat(
        self,
        *,
        user_id: str,
        message: str,
        thread_id: str | None = None,
        data_action: MedicalChatDataAction | None = None,
    ) -> MedicalChatResponse:
        normalized_message = message.strip()
        quota = self._chat_quota(user_id)
        if quota["remaining"] <= 0:
            raise MedicalChatQuotaError(
                limit=int(quota["limit"]),
                used=int(quota["used"]),
                reset_at=quota["reset_at"],
                tier=str(quota["tier"]),
        )
        thread = self._get_or_create_thread(user_id=user_id, thread_id=thread_id, message=normalized_message)
        is_contextual_follow_up = self._is_contextual_follow_up(normalized_message) and self._thread_has_medical_context(
            thread_id=thread.id
        )
        self._append_message(thread_id=thread.id, user_id=user_id, role="user", content=normalized_message)
        quota_after = {**quota, "used": int(quota["used"]) + 1, "remaining": max(0, int(quota["remaining"]) - 1)}
        if not self._is_medical_question(normalized_message) and not is_contextual_follow_up:
            answer = (
                "Vyla AI only answers reproductive and health-related questions. "
                "Ask about your cycle, symptoms, fertility, temperature, ovulation, mood, sleep, or logged health data."
            )
            self._append_message(thread_id=thread.id, user_id=user_id, role="assistant", content=answer)
            self.db.commit()
            return MedicalChatResponse(
                thread_id=thread.id,
                answer=answer,
                sufficient_data=False,
                chat_limit=int(quota_after["limit"]),
                chats_used=int(quota_after["used"]),
                chats_remaining=int(quota_after["remaining"]),
                quota_reset_at=quota_after["reset_at"].isoformat(),
                disclaimer=self.settings.medical_disclaimer,
            )

        urgent_symptoms = self._has_urgent_symptoms(normalized_message)
        saved_records: list[str] = []
        extracted_actions = [] if urgent_symptoms else self._extract_actions_from_message(normalized_message)
        if data_action is not None:
            extracted_actions = [item for item in extracted_actions if item.action != data_action.action]
        for extracted_action in extracted_actions:
            saved_records.extend(self._apply_data_action(user_id=user_id, data_action=extracted_action))
        if data_action is not None:
            saved_records.extend(self._apply_data_action(user_id=user_id, data_action=data_action))

        context = self._build_context(user_id)
        context["retrieved_ai_memory"] = self._retrieve_ai_memory_documents(user_id=user_id, query=normalized_message)
        educational_question = self._is_educational_health_question(normalized_message)
        missing = (
            []
            if urgent_symptoms or educational_question or is_contextual_follow_up
            else self._identify_missing_data(message=normalized_message, context=context)
        )
        used_user_data = self._used_user_data(context)
        if urgent_symptoms:
            answer = self._build_urgent_answer(message=normalized_message, context=context, saved_records=saved_records)
        elif missing:
            answer = self._build_missing_data_answer(message=normalized_message, context=context, missing=missing, saved_records=saved_records)
        else:
            answer = self._generate_answer(
                message=normalized_message,
                context=context,
                thread_id=thread.id,
                educational=educational_question,
                contextual_follow_up=is_contextual_follow_up,
            )

        answer = self._guard_output(answer)
        self._append_message(thread_id=thread.id, user_id=user_id, role="assistant", content=answer)
        memory_document = self._persist_ai_memory_document(
            user_id=user_id,
            thread_id=thread.id,
            message=normalized_message,
            answer=answer,
            context=context,
            sufficient_data=not missing,
        )

        response = MedicalChatResponse(
            thread_id=thread.id,
            answer=answer,
            sufficient_data=not missing,
            chat_limit=int(quota_after["limit"]),
            chats_used=int(quota_after["used"]),
            chats_remaining=int(quota_after["remaining"]),
            quota_reset_at=quota_after["reset_at"].isoformat(),
            used_user_data=used_user_data,
            saved_records=saved_records,
            missing_data=missing,
            disclaimer=self.settings.medical_disclaimer,
        )
        self.audit.log(
            user_id,
            "ai.medical_chat",
            {
                "thread_id": thread.id,
                "message_redacted": self._redact_text(normalized_message),
                "sufficient_data": response.sufficient_data,
                "saved_records": saved_records,
                "missing_actions": [item.action for item in missing],
                "security_policy_version": AI_SECURITY_POLICY_VERSION,
                "consent_accepted": self._ai_chat_consent_accepted(user_id),
                "context_pipeline": "minimise:redact:llm:guard",
                "memory_document_id": memory_document.id if memory_document else None,
            },
        )
        self.db.commit()
        return response

    def analyze_document(
        self,
        *,
        user_id: str,
        filename: str,
        content_type: str | None,
        data: bytes,
        question: str | None = None,
        thread_id: str | None = None,
    ) -> MedicalDocumentAnalysisResponse:
        self.ensure_document_analysis_access(user_id)

        if not data:
            raise MedicalChatError("Please upload a document with readable content.")
        if len(data) > MEDICAL_DOCUMENT_MAX_BYTES:
            raise MedicalChatError("Please upload a medical document smaller than 25 MB.")

        safe_filename = (filename or "uploaded document").strip()[:180]
        extracted_text, document_type = self._extract_document_text(
            filename=safe_filename,
            content_type=content_type,
            data=data,
        )
        extracted_text = self._clean_extracted_document_text(extracted_text)

        quota = self._chat_quota(user_id)
        if quota["remaining"] <= 0:
            raise MedicalChatQuotaError(
                limit=int(quota["limit"]),
                used=int(quota["used"]),
                reset_at=quota["reset_at"],
                tier=str(quota["tier"]),
            )

        prompt = (question or "Please analyse this medical document.").strip()
        user_message = f"Uploaded medical document for analysis: {safe_filename}. Question: {prompt}"
        thread = self._get_or_create_thread(user_id=user_id, thread_id=thread_id, message=user_message)
        self._append_message(thread_id=thread.id, user_id=user_id, role="user", content=user_message)
        quota_after = {**quota, "used": int(quota["used"]) + 1, "remaining": max(0, int(quota["remaining"]) - 1)}

        context = self._build_context(user_id)
        context["retrieved_ai_memory"] = self._retrieve_ai_memory_documents(user_id=user_id, query=prompt)
        if not extracted_text:
            answer = (
                "I could not read enough text from this file to analyse it safely. "
                "Please upload a clearer medical report, lab result, prescription, discharge letter, ultrasound report, "
                "or a well-lit image where the text is visible. I do not store the uploaded document."
            )
            medical_only = True
            sufficient_data = False
        elif not self._looks_like_medical_document(extracted_text):
            answer = (
                "This does not look like a medical document from the readable text I could extract. "
                "For privacy and safety, Vyla only analyses health-related documents such as lab results, prescriptions, "
                "clinical letters, ultrasound reports, scan reports, discharge summaries, or symptom/cycle records. "
                "Please upload a medical document if you want analysis."
            )
            medical_only = False
            sufficient_data = False
        else:
            answer = self._generate_document_analysis(
                question=prompt,
                filename=safe_filename,
                document_type=document_type,
                extracted_text=self._redact_text(extracted_text),
                context=context,
            )
            medical_only = True
            sufficient_data = True

        answer = self._guard_output(answer)
        self._append_message(thread_id=thread.id, user_id=user_id, role="assistant", content=answer)
        memory_document = None
        if medical_only and sufficient_data:
            memory_document = self._persist_ai_memory_document(
                user_id=user_id,
                thread_id=thread.id,
                message=prompt,
                answer=answer,
                context=context,
                sufficient_data=True,
                doc_type="document_analysis_summary",
                data_scope="medical_document",
            )
        response = MedicalDocumentAnalysisResponse(
            thread_id=thread.id,
            answer=answer,
            medical_only=medical_only,
            sufficient_data=sufficient_data,
            chat_limit=int(quota_after["limit"]),
            chats_used=int(quota_after["used"]),
            chats_remaining=int(quota_after["remaining"]),
            quota_reset_at=quota_after["reset_at"].isoformat(),
            used_user_data=self._used_user_data(context),
            disclaimer=self.settings.medical_disclaimer,
            filename=safe_filename,
            extracted_text_chars=len(extracted_text),
            document_type=document_type,
        )
        self.audit.log(
            user_id,
            "ai.medical_document_analysis",
            {
                "thread_id": thread.id,
                "filename": safe_filename,
                "content_type": content_type,
                "document_type": document_type,
                "bytes": len(data),
                "extracted_text_chars": len(extracted_text),
                "medical_only": medical_only,
                "sufficient_data": sufficient_data,
                "security_policy_version": AI_SECURITY_POLICY_VERSION,
                "context_pipeline": "document:redact:minimise:llm:guard",
                "memory_document_id": memory_document.id if memory_document else None,
            },
        )
        self.db.commit()
        return response

    def ensure_document_analysis_access(self, user_id: str) -> None:
        premium = PremiumAccessService(self.db).status(user_id)
        if premium.tier == "free" or not premium.is_active:
            raise MedicalChatPremiumRequiredError("Medical document analysis is available for premium users only.")

    def _extract_document_text(self, *, filename: str, content_type: str | None, data: bytes) -> tuple[str, str]:
        lower_name = filename.lower()
        extension = ""
        if "." in lower_name:
            extension = lower_name[lower_name.rfind(".") :]
        if extension and extension not in MEDICAL_DOCUMENT_ALLOWED_EXTENSIONS:
            raise MedicalChatError("Unsupported file type. Please upload a PDF, image, CSV, Excel, or text medical document.")

        content_type = (content_type or "").lower()
        if extension in {".txt"} or content_type.startswith("text/plain"):
            return self._decode_text_bytes(data), "text"
        if extension == ".csv" or content_type in {"text/csv", "application/csv"}:
            return self._extract_csv_text(data), "csv"
        if extension == ".xlsx" or "spreadsheetml" in content_type:
            return self._extract_xlsx_text(data), "excel"
        if extension == ".xls":
            raise MedicalChatError("Older .xls files are not supported yet. Please export the sheet as .xlsx or CSV and upload it again.")
        if extension == ".pdf" or content_type == "application/pdf":
            return self._extract_pdf_text(data), "pdf"
        if extension in {".png", ".jpg", ".jpeg", ".webp", ".heic", ".heif"} or content_type.startswith("image/"):
            return self._extract_image_text(data=data, content_type=content_type or "image/jpeg"), "image"
        raise MedicalChatError("Unsupported file type. Please upload a PDF, image, CSV, Excel, or text medical document.")

    def _decode_text_bytes(self, data: bytes) -> str:
        for encoding in ("utf-8", "utf-16", "latin-1"):
            try:
                return data.decode(encoding)
            except UnicodeDecodeError:
                continue
        return data.decode("utf-8", errors="ignore")

    def _extract_csv_text(self, data: bytes) -> str:
        raw = self._decode_text_bytes(data)
        rows: list[str] = []
        reader = csv.reader(io.StringIO(raw))
        for index, row in enumerate(reader):
            if index >= 200:
                rows.append("...")
                break
            values = [cell.strip() for cell in row if cell and cell.strip()]
            if values:
                rows.append(" | ".join(values))
        return "\n".join(rows)

    def _extract_xlsx_text(self, data: bytes) -> str:
        try:
            archive = zipfile.ZipFile(io.BytesIO(data))
        except zipfile.BadZipFile as exc:
            raise MedicalChatError("The Excel file could not be read. Please export it as .xlsx or CSV and try again.") from exc

        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            shared_root = ElementTree.fromstring(archive.read("xl/sharedStrings.xml"))
            for item in shared_root.iter():
                if item.tag.endswith("}t") or item.tag == "t":
                    if item.text:
                        shared_strings.append(item.text)

        rows: list[str] = []
        sheet_names = [name for name in archive.namelist() if name.startswith("xl/worksheets/sheet") and name.endswith(".xml")]
        for sheet_name in sheet_names[:5]:
            root = ElementTree.fromstring(archive.read(sheet_name))
            for row_index, row in enumerate([node for node in root.iter() if node.tag.endswith("}row") or node.tag == "row"]):
                if row_index >= 200:
                    rows.append("...")
                    break
                values: list[str] = []
                for cell in row:
                    if not (cell.tag.endswith("}c") or cell.tag == "c"):
                        continue
                    cell_type = cell.attrib.get("t")
                    value_node = next((child for child in cell if child.tag.endswith("}v") or child.tag == "v"), None)
                    inline_text = " ".join(
                        text_node.text or ""
                        for text_node in cell.iter()
                        if text_node is not cell and (text_node.tag.endswith("}t") or text_node.tag == "t")
                    ).strip()
                    value = (value_node.text or "").strip() if value_node is not None and value_node.text else inline_text
                    if cell_type == "s" and value.isdigit():
                        index = int(value)
                        value = shared_strings[index] if 0 <= index < len(shared_strings) else value
                    if value:
                        values.append(value)
                if values:
                    rows.append(" | ".join(values))
        return "\n".join(rows)

    def _extract_pdf_text(self, data: bytes) -> str:
        try:
            from pypdf import PdfReader  # type: ignore
        except ImportError:
            return ""
        try:
            reader = PdfReader(io.BytesIO(data))
            pages = []
            for page in reader.pages[:8]:
                pages.append(page.extract_text() or "")
            return "\n".join(pages)
        except Exception:
            return ""

    def _extract_image_text(self, *, data: bytes, content_type: str) -> str:
        if not self.ai_gateway.enabled:
            return ""
        image_b64 = base64.b64encode(data).decode("ascii")
        body = {
            "model": self.settings.llm_model,
            "input": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "input_text",
                            "text": (
                                "Extract the visible text from this health-related document image. "
                                "Return only the text you can read. If it is not a document or no text is readable, return an empty response."
                            ),
                        },
                        {"type": "input_image", "image_url": f"data:{content_type};base64,{image_b64}"},
                    ],
                }
            ],
            "temperature": 0,
            "text": {"format": {"type": "text"}},
        }
        data = self.ai_gateway.responses(body)
        if not data:
            return ""
        return self._guard_output(self._extract_response_text(data))

    def _clean_extracted_document_text(self, text: str) -> str:
        cleaned = re.sub(r"[ \t]+", " ", text or "")
        cleaned = re.sub(r"\n{3,}", "\n\n", cleaned).strip()
        if len(cleaned) > MEDICAL_DOCUMENT_TEXT_LIMIT:
            return cleaned[:MEDICAL_DOCUMENT_TEXT_LIMIT].rsplit("\n", 1)[0].strip()
        return cleaned

    def _looks_like_medical_document(self, text: str) -> bool:
        lower = text.lower()
        terms = {
            "patient", "doctor", "dr ", "clinic", "hospital", "nhs", "medical", "health", "diagnosis",
            "diagnostic", "laboratory", "lab", "result", "report", "prescription", "medication", "dose",
            "ultrasound", "scan", "radiology", "mri", "ct", "x-ray", "blood", "serum", "plasma",
            "haemoglobin", "hemoglobin", "wbc", "rbc", "platelet", "glucose", "hba1c", "cholesterol",
            "thyroid", "tsh", "lh", "fsh", "oestrogen", "estrogen", "progesterone", "testosterone",
            "pregnancy", "hcg", "ovary", "ovarian", "uterus", "uterine", "cervix", "cervical",
            "fibroid", "pcos", "endometriosis", "cycle", "period", "menstrual", "fertility",
            "reference range", "normal range", "abnormal", "positive", "negative",
        }
        return sum(1 for term in terms if term in lower) >= 2

    def _generate_document_analysis(
        self,
        *,
        question: str,
        filename: str,
        document_type: str,
        extracted_text: str,
        context: dict[str, Any],
    ) -> str:
        openai_answer = self._openai_document_analysis(
            question=question,
            filename=filename,
            document_type=document_type,
            extracted_text=extracted_text,
            context=context,
        )
        if openai_answer:
            return openai_answer
        return self._deterministic_document_analysis(
            question=question,
            filename=filename,
            document_type=document_type,
            extracted_text=extracted_text,
            context=context,
        )

    def _openai_document_analysis(
        self,
        *,
        question: str,
        filename: str,
        document_type: str,
        extracted_text: str,
        context: dict[str, Any],
    ) -> str | None:
        if not self.ai_gateway.enabled:
            return None
        prompt_context = self._serialize_context_for_model(context)
        body = {
            "model": self.settings.llm_model,
            "input": [
                {
                    "role": "developer",
                    "content": VYLA_AI_SYSTEM_PROMPT,
                },
                {
                    "role": "developer",
                    "content": (
                        "The user uploaded a medical document. Analyse only the extracted text below and the Vyla user context. "
                        "Do not claim to see the original file. Do not diagnose. Explain findings in plain English, note any values that look outside reference ranges, "
                        "connect relevant findings to the user's reproductive or general health context, and suggest practical follow-up questions for their clinician. "
                        "If the document is unclear, say what is missing. Do not mention internal extraction details unless readability limits matter.\n\n"
                        f"Filename: {filename}\nDocument type: {document_type}\n\n"
                        f"User health context:\n{prompt_context}\n\n"
                        f"Extracted document text:\n{self._redact_text(extracted_text)}"
                    ),
                },
                {"role": "user", "content": question},
            ],
            "instructions": (
                "Structure the answer as: summary, what the document appears to show, what may matter, what to ask a clinician, and safety notes. "
                "Be comprehensive but not boring. Keep it readable on a phone. Include 3 useful follow-up questions."
            ),
            "temperature": 0.2,
            "text": {"format": {"type": "text"}},
        }
        data = self.ai_gateway.responses(body)
        if not data:
            return None
        return self._guard_output(self._extract_response_text(data))

    def _extract_response_text(self, data: dict[str, Any]) -> str:
        try:
            for item in data.get("output", []):
                if item.get("type") != "message" or item.get("role") != "assistant":
                    continue
                for content_item in item.get("content", []):
                    if content_item.get("type") == "output_text":
                        text = (content_item.get("text") or "").strip()
                        if text:
                            return text
        except AttributeError:
            return ""
        return ""

    def _deterministic_document_analysis(
        self,
        *,
        question: str,
        filename: str,
        document_type: str,
        extracted_text: str,
        context: dict[str, Any],
    ) -> str:
        context_summary = self._deterministic_context_summary(context)
        findings = self._extract_document_findings(extracted_text)
        finding_lines = "\n".join(f"- {item}" for item in findings[:8])
        if not finding_lines:
            meaningful_lines = [
                line.strip()
                for line in extracted_text.splitlines()
                if line.strip() and not set(line.strip()) <= {"=", "-", "_"}
            ]
            finding_lines = "\n".join(f"- {line[:160]}" for line in meaningful_lines[:6])
        cycle_part = f"\n\nFrom your Vyla data, this is also happening around {context_summary}." if context_summary else ""
        question_part = question.strip() or "Analyse this report."
        return (
            f"Here is what {filename} appears to show based on your question: \"{question_part}\"\n\n"
            "The main things I can pick out are:\n"
            f"{finding_lines}\n"
            f"{cycle_part}\n\n"
            "What this may mean:\n"
            "- If values such as ferritin or haemoglobin are low, that can fit with iron deficiency or anaemia, which can contribute to fatigue, dizziness, headaches, shortness of breath on exertion, or feeling weak.\n"
            "- Thyroid, glucose/HbA1c, vitamin D, and reproductive hormones such as LH, FSH, and progesterone can also affect energy, cycle regularity, ovulation, and PCOS assessment.\n"
            "- A lab report needs the full reference ranges, your symptoms, medications, and clinical history before anyone can interpret it confidently.\n\n"
            "Good questions to ask your clinician:\n"
            "- Are any of these results outside the reference range for me?\n"
            "- Could the results explain my symptoms or irregular cycles?\n"
            "- Do I need repeat testing, treatment, supplements, or follow-up for iron, thyroid, hormones, glucose, or vitamin D?\n\n"
            "Vyla can explain the report, but it cannot diagnose from an upload alone."
        )

    def _extract_document_findings(self, extracted_text: str) -> list[str]:
        findings: list[str] = []
        important_terms = (
            "haemoglobin",
            "hemoglobin",
            "ferritin",
            "tsh",
            "thyroid",
            "lh",
            "fsh",
            "progesterone",
            "hba1c",
            "glucose",
            "vitamin d",
            "oestrogen",
            "estrogen",
            "testosterone",
            "amh",
            "prolactin",
            "platelet",
            "wbc",
            "rbc",
        )
        seen: set[str] = set()
        for raw_line in extracted_text.splitlines():
            line = re.sub(r"\s+", " ", raw_line).strip(" -\t")
            if not line or len(line) > 180:
                continue
            lower = line.lower()
            if not any(term in lower for term in important_terms):
                continue
            if not re.search(r"\d", line):
                continue
            key = lower
            if key in seen:
                continue
            seen.add(key)
            findings.append(line)
            if len(findings) >= 12:
                break
        return findings

    def _chat_quota(self, user_id: str) -> dict[str, Any]:
        premium = PremiumAccessService(self.db).status(user_id)
        is_premium = premium.tier != "free" and premium.is_active
        limit = PREMIUM_WEEKLY_CHAT_LIMIT if is_premium else FREE_WEEKLY_CHAT_LIMIT
        now = datetime.now(UTC)
        window_start = now - timedelta(days=CHAT_QUOTA_WINDOW_DAYS)
        used = int(
            self.db.scalar(
                select(func.count(MedicalChatMessage.id)).where(
                    MedicalChatMessage.user_id == user_id,
                    MedicalChatMessage.role == "user",
                    MedicalChatMessage.created_at >= window_start,
                )
            )
            or 0
        )
        oldest_in_window = self.db.scalar(
            select(MedicalChatMessage.created_at)
            .where(
                MedicalChatMessage.user_id == user_id,
                MedicalChatMessage.role == "user",
                MedicalChatMessage.created_at >= window_start,
            )
            .order_by(MedicalChatMessage.created_at.asc())
            .limit(1)
        )
        reset_at = (oldest_in_window + timedelta(days=CHAT_QUOTA_WINDOW_DAYS)) if oldest_in_window else now + timedelta(days=CHAT_QUOTA_WINDOW_DAYS)
        if reset_at.tzinfo is None:
            reset_at = reset_at.replace(tzinfo=UTC)
        return {
            "tier": "premium" if is_premium else "free",
            "limit": limit,
            "used": used,
            "remaining": max(0, limit - used),
            "reset_at": reset_at,
        }

    def latest_thread_history(self, *, user_id: str, limit: int = 24, before: datetime | None = None) -> MedicalChatHistoryResponse:
        thread = (
            self.db.execute(
                select(MedicalChatThread)
                .where(MedicalChatThread.user_id == user_id)
                .order_by(MedicalChatThread.updated_at.desc(), MedicalChatThread.created_at.desc())
                .limit(1)
            )
            .scalars()
            .first()
        )
        if not thread:
            return MedicalChatHistoryResponse(thread_id=None, messages=[])
        return self._thread_history_response(thread_id=thread.id, limit=limit, before=before)

    def list_threads(
        self,
        *,
        user_id: str,
        limit: int = 20,
    ) -> MedicalChatThreadListResponse:
        threads = (
            self.db.execute(
                select(MedicalChatThread)
                .where(MedicalChatThread.user_id == user_id)
                .order_by(
                    MedicalChatThread.updated_at.desc(),
                    MedicalChatThread.created_at.desc(),
                )
                .limit(limit)
            )
            .scalars()
            .all()
        )
        return MedicalChatThreadListResponse(
            threads=[self._thread_summary(thread) for thread in threads],
        )

    def thread_history(
        self,
        *,
        user_id: str,
        thread_id: str,
        limit: int = 24,
        before: datetime | None = None,
    ) -> MedicalChatHistoryResponse:
        thread = self.db.scalar(
            select(MedicalChatThread).where(
                MedicalChatThread.id == thread_id,
                MedicalChatThread.user_id == user_id,
            )
        )
        if not thread:
            raise MedicalChatError("Medical chat thread not found")
        return self._thread_history_response(thread_id=thread.id, limit=limit, before=before)

    def _thread_history_response(
        self,
        *,
        thread_id: str,
        limit: int = 24,
        before: datetime | None = None,
    ) -> MedicalChatHistoryResponse:
        capped_limit = min(max(limit, 1), 50)
        fetched_messages = self._recent_thread_messages(thread_id=thread_id, limit=capped_limit + 1, before=before)
        has_more = len(fetched_messages) > capped_limit
        messages = fetched_messages[-capped_limit:] if has_more else fetched_messages
        next_before = messages[0].created_at.isoformat() if has_more and messages and messages[0].created_at else None
        return MedicalChatHistoryResponse(
            thread_id=thread_id,
            messages=[
                MedicalChatHistoryItem(
                    role=item.role,
                    content=item.content,
                    created_at=item.created_at.isoformat() if item.created_at else None,
                )
                for item in messages
            ],
            has_more=has_more,
            next_before=next_before,
        )

    def _get_or_create_thread(self, *, user_id: str, thread_id: str | None, message: str) -> MedicalChatThread:
        if thread_id:
            thread = self.db.scalar(
                select(MedicalChatThread).where(MedicalChatThread.id == thread_id, MedicalChatThread.user_id == user_id)
            )
            if not thread:
                raise MedicalChatError("Medical chat thread not found")
            return thread
        thread = MedicalChatThread(user_id=user_id, title=" ".join(message.split())[:80])
        self.db.add(thread)
        self.db.flush()
        return thread

    def _append_message(self, *, thread_id: str, user_id: str, role: str, content: str) -> None:
        thread = self.db.get(MedicalChatThread, thread_id)
        if thread:
            thread.updated_at = datetime.now(UTC)
        self.db.add(MedicalChatMessage(thread_id=thread_id, user_id=user_id, role=role, content=content))
        self.db.flush()

    def _thread_summary(self, thread: MedicalChatThread) -> MedicalChatThreadSummary:
        messages = self._recent_thread_messages(thread_id=thread.id, limit=100)
        preview = messages[-1].content if messages else None
        return MedicalChatThreadSummary(
            thread_id=thread.id,
            title=thread.title,
            preview=preview,
            created_at=thread.created_at.isoformat() if thread.created_at else None,
            updated_at=thread.updated_at.isoformat() if thread.updated_at else None,
            message_count=len(messages),
        )

    def _recent_thread_messages(
        self,
        *,
        thread_id: str,
        limit: int = 8,
        before: datetime | None = None,
    ) -> list[MedicalChatMessage]:
        stmt = (
            select(MedicalChatMessage)
            .where(MedicalChatMessage.thread_id == thread_id)
            .order_by(MedicalChatMessage.created_at.desc())
            .limit(limit)
        )
        if before is not None:
            stmt = (
                select(MedicalChatMessage)
                .where(
                    MedicalChatMessage.thread_id == thread_id,
                    MedicalChatMessage.created_at < before,
                )
                .order_by(MedicalChatMessage.created_at.desc())
                .limit(limit)
            )
        return list(reversed(list(self.db.scalars(stmt))))

    def _is_medical_question(self, message: str) -> bool:
        text = message.lower()
        keywords = {
            # Cycle & menstruation
            "cycle", "period", "menstrual", "menstruation", "spotting", "bleeding",
            "irregular", "missed period", "late period", "heavy period",
            "phase", "luteal", "follicular", "menstrual phase",
            # Ovulation & fertility
            "ovulation", "ovulat", "fertility", "fertile", "lh", "lh surge",
            "trying to conceive", "ttc", "conception", "egg", "follicle",
            # Hormones
            "hormone", "hormonal", "estrogen", "progesterone", "testosterone",
            "cortisol", "thyroid", "insulin",
            # Pregnancy
            "pregnancy", "pregnant", "miscarriage", "implantation",
            # Conditions
            "pcos", "endometriosis", "fibroid", "fibroids", "endo", "perimenopause",
            "menopause", "pmdd", "pms", "adenomyosis", "polyp", "cyst", "ovarian cyst",
            "cervical", "uterine", "vulva", "vulvar",
            # Physical symptoms
            "symptom", "cramp", "bloating", "pain", "discharge", "mucus",
            "temperature", "bbt", "breast", "tenderness", "pelvic",
            "nausea", "vomiting", "dizziness", "headache", "migraine",
            "acne", "skin", "hair loss", "hot flash", "night sweat",
            # Sexual & reproductive health
            "sex", "intercourse", "intimacy", "libido", "vaginal", "vagina",
            "birth control", "contraception", "iud", "pill", "condom",
            # Mental & emotional health
            "mood", "anxious", "anxiety", "depressed", "depression",
            "emotional", "irritable", "anger", "sad", "mental health",
            "mental", "stress", "burnout",
            # Sleep & recovery
            "sleep", "insomnia", "tired", "fatigue", "exhausted",
            "low energy", "recovery",
            # Wearable & biometrics
            "hrv", "heart rate", "rhr", "wearable", "oura", "fitbit",
            "apple health", "vyla", "temperature trend",
            # Weight & nutrition
            "weight", "nutrition", "diet", "food", "eating", "appetite",
            # General health
            "health", "medical", "doctor", "supplement",
        }
        return any(keyword in text for keyword in keywords)

    def _is_contextual_follow_up(self, message: str) -> bool:
        text = message.lower().strip()
        if not text:
            return False
        if self._is_affirmative_follow_up(text):
            return True
        follow_up_markers = {
            "that",
            "this",
            "it",
            "them",
            "those",
            "earlier",
            "previous",
            "above",
            "continue",
            "go on",
            "tell me more",
            "explain more",
            "what about",
            "what does that mean",
            "why is that",
            "why would that",
            "how about",
            "how do i",
            "how can i",
            "is that",
            "can you explain",
            "should i",
            "what should i",
            "what treatment",
            "treatment",
            "symptoms",
            "causes",
            "risks",
            "next steps",
        }
        return any(marker in text for marker in follow_up_markers)

    def _is_affirmative_follow_up(self, message: str) -> bool:
        text = re.sub(r"[^a-z\s]", "", message.lower()).strip()
        return text in {
            "yes",
            "yes please",
            "yeah",
            "yeah please",
            "yep",
            "yup",
            "please",
            "ok",
            "okay",
            "sure",
            "go ahead",
            "tell me",
            "tell me more",
        }

    def _thread_has_medical_context(self, thread_id: str) -> bool:
        messages = self._recent_thread_messages(thread_id=thread_id, limit=12)
        for item in messages:
            if item.role == "assistant":
                return True
            if item.role == "user" and self._is_medical_question(item.content):
                return True
        return False

    def _is_educational_health_question(self, message: str) -> bool:
        """True when the user is asking for a definition or explanation of a health concept,
        rather than asking about their own personal data or symptoms."""
        text = message.lower().strip()
        educational_starts = (
            "what is",
            "what's",
            "what are",
            "what causes",
            "what can cause",
            "explain",
            "define",
            "tell me about",
            "how does",
            "how do",
            "why does",
            "why do",
            "what does",
            "describe",
            "can you explain",
        )
        if not text.startswith(educational_starts):
            return False
        # Personal questions ("what is my cycle day", "how is my HRV") are not educational
        personal_markers = ("my ", " my ", "i ", "i've", "i'm", "me ", "mine")
        if any(marker in text for marker in personal_markers):
            return False
        # Must be about a medical/health topic
        return self._is_medical_question(text)

    def _has_urgent_symptoms(self, message: str) -> bool:
        text = message.lower()
        urgent_phrases = {
            "severe pain", "unbearable pain", "worst pain", "excruciating",
            "chest pain", "chest tightness",
            "fainting", "fainted", "passing out", "collapsed",
            "soaking a pad", "soaking through", "heavy bleeding", "very heavy bleeding",
            "positive pregnancy test and bleeding", "pregnant and bleeding",
            "pregnant and severe pain", "ectopic",
            "fever and pelvic pain", "fever and pain",
            "bad smell discharge", "foul discharge", "foul smell",
            "suicidal", "kill myself", "harm myself", "end my life",
            "don't want to live", "want to die",
            "trouble breathing", "can't breathe", "shortness of breath",
            "blood pressure very high", "bp very high",
            "signs of infection", "severe infection",
            "sepsis",
        }
        return any(phrase in text for phrase in urgent_phrases)

    def _build_context(self, user_id: str) -> dict[str, Any]:
        user = self.users.by_id(user_id)
        profile = self.users.ensure_profile(user_id)
        active_cycle = self.cycles.active_for_user(user_id)
        latest_period_log = self._latest_period_log(user_id)
        if active_cycle is None and latest_period_log is not None:
            active_cycle = self._cycle_from_period_log(latest_period_log)
        recent_logs = self.cycles.recent_logs(user_id, days=90)
        latest_lh = self.cycles.latest_lh_log(user_id)
        latest_mucus = self.cycles.latest_mucus_log(user_id)
        recent_sleep = self.sensors.recent(user_id, "sleep_minutes", days=30)
        recent_steps = self.sensors.recent(user_id, "steps", days=30)
        recent_temps = self.sensors.recent(user_id, "wrist_temp", days=60)
        if not recent_temps:
            latest_temp = self._latest_sensor_reading(user_id, "wrist_temp")
            recent_temps = [latest_temp] if latest_temp else []
        recent_rhr = self.sensors.recent(user_id, "rhr", days=30)
        recent_blood_oxygen_avg = self.sensors.recent(user_id, "blood_oxygen_avg", days=30)
        recent_blood_oxygen_min = self.sensors.recent(user_id, "blood_oxygen_min", days=30)
        recent_hrv = self.sensors.recent(user_id, "hrv", days=30)
        recent_stress = self.sensors.recent_stress(user_id, days=30)
        latest_prediction = self.predictions.latest_for_user(user_id)
        recent_predictions = self.predictions.recent_for_user(user_id, limit=5)
        latest_insight = self.insights.latest_for_user(user_id)
        past_cycles = self._fetch_past_cycles(user_id, limit=6)
        return {
            "user": user,
            "profile": profile,
            "active_cycle": active_cycle,
            "latest_period_log": latest_period_log,
            "past_cycles": past_cycles,
            "recent_logs": recent_logs,
            "latest_lh": latest_lh,
            "latest_mucus": latest_mucus,
            "recent_sleep": recent_sleep,
            "recent_steps": recent_steps,
            "recent_temps": recent_temps,
            "recent_rhr": recent_rhr,
            "recent_blood_oxygen_avg": recent_blood_oxygen_avg,
            "recent_blood_oxygen_min": recent_blood_oxygen_min,
            "recent_hrv": recent_hrv,
            "recent_stress": recent_stress,
            "latest_prediction": latest_prediction,
            "recent_predictions": recent_predictions,
            "latest_insight": latest_insight,
        }

    def _fetch_past_cycles(self, user_id: str, limit: int = 6) -> list[CycleRecord]:
        stmt = (
            select(CycleRecord)
            .where(CycleRecord.user_id == user_id, CycleRecord.is_active.is_(False))
            .order_by(CycleRecord.period_start_date.desc())
            .limit(limit)
        )
        return list(self.db.scalars(stmt))

    def _latest_sensor_reading(self, user_id: str, metric: str) -> SensorReading | None:
        return self.db.scalar(
            select(SensorReading)
            .where(SensorReading.user_id == user_id, SensorReading.metric == metric)
            .order_by(desc(SensorReading.recorded_at))
            .limit(1)
        )

    def _latest_period_log(self, user_id: str) -> DailyLog | None:
        stmt = (
            select(DailyLog)
            .where(DailyLog.user_id == user_id, DailyLog.log_type == LogType.PERIOD)
            .order_by(desc(DailyLog.log_date), desc(DailyLog.logged_at))
            .limit(1)
        )
        return self.db.scalar(stmt)

    def _cycle_from_period_log(self, log: DailyLog) -> CycleRecord:
        if log.cycle_id:
            cycle = self.db.get(CycleRecord, log.cycle_id)
            if cycle:
                return cycle
        return CycleRecord(
            user_id=log.user_id,
            period_start_date=log.log_date,
            period_end_date=log.log_date,
            menses_length=1,
            is_active=True,
        )

    def _profile_summary(self, profile) -> dict[str, Any]:
        conditions = dict(profile.conditions or {})
        safe_conditions = self._safe_profile_conditions(conditions)
        return {
            "date_of_birth": profile.date_of_birth.isoformat() if profile.date_of_birth else None,
            "age_band": profile.age_band,
            "height_cm": profile.height_cm,
            "weight_kg": profile.weight_kg,
            "bmi": profile.bmi,
            "goal": profile.goal.value if hasattr(profile.goal, "value") else str(profile.goal) if profile.goal else None,
            "conditions": safe_conditions,
            "wearable_type": profile.wearable_type.value
            if hasattr(profile.wearable_type, "value")
            else str(profile.wearable_type)
            if profile.wearable_type
            else None,
            "perimenopause_mode_active": profile.perimenopause_mode_active,
            "reproductive_context": {
                key: safe_conditions.get(key)
                for key in (
                    "contraception_type",
                    "pregnancy_goals",
                    "fertility_goals",
                    "relationship_status",
                    "sexual_activity",
                    "medications",
                    "medical_conditions",
                    "pcos_history",
                    "endometriosis_history",
                    "previous_pregnancy_history",
                    "menopause_stage",
                    "perimenopause_stage",
                    "health_conditions",
                )
                if safe_conditions.get(key) is not None
            },
        }

    def _safe_profile_conditions(self, conditions: dict[str, Any]) -> dict[str, Any]:
        excluded = {
            "first_name",
            "last_name",
            "full_name",
            "country",
            "account_type",
            "signup_method",
            "consents",
            "registration_context",
            "ai_preferences",
        }
        return {key: value for key, value in conditions.items() if key not in excluded}

    def _human_profile_context(self, profile) -> str:
        conditions = self._safe_profile_conditions(dict(profile.conditions or {}))
        health_conditions = conditions.get("health_conditions") or conditions.get("medical_conditions")
        if isinstance(health_conditions, list):
            health_conditions_text = ", ".join(str(item) for item in health_conditions if str(item).strip())
        elif health_conditions:
            health_conditions_text = str(health_conditions)
        else:
            health_conditions_text = ""

        details: list[str] = []
        if health_conditions_text:
            details.append(f"health profile notes: {health_conditions_text}")
        for key, label in (
            ("pcos_history", "PCOS history"),
            ("endometriosis_history", "endometriosis history"),
            ("contraception_type", "contraception"),
            ("pregnancy_goals", "pregnancy goals"),
            ("fertility_goals", "fertility goals"),
            ("menopause_stage", "menopause stage"),
            ("perimenopause_stage", "perimenopause stage"),
        ):
            value = conditions.get(key)
            if value:
                details.append(f"{label}: {value}")
        return "; ".join(details)

    def _used_user_data(self, context: dict[str, Any]) -> list[str]:
        used: list[str] = []
        profile = context["profile"]
        if profile.date_of_birth or profile.age_band:
            used.append("profile.age")
        if profile.conditions:
            used.append("profile.conditions")
        if context["active_cycle"]:
            used.append("cycle.active")
        if context["latest_period_log"]:
            used.append("cycle.period_log")
        if context["past_cycles"]:
            used.append("cycle.history")
        if context["recent_logs"]:
            used.append("cycle.logs")
        if context["latest_lh"]:
            used.append("cycle.lh")
        if context["latest_mucus"]:
            used.append("cycle.mucus")
        if context["recent_temps"]:
            used.append("sensor.temperature")
        if context["recent_rhr"]:
            used.append("sensor.heart_rate")
        if context["recent_hrv"]:
            used.append("sensor.hrv")
        if context["recent_sleep"]:
            used.append("sensor.sleep")
        if context["recent_steps"]:
            used.append("sensor.steps")
        if context["recent_blood_oxygen_avg"]:
            used.append("sensor.blood_oxygen")
        if context["recent_stress"]:
            used.append("sensor.stress")
        if context["latest_prediction"]:
            used.append("predictions.latest")
        if context["latest_insight"]:
            used.append("insights.latest")
        return used

    def _identify_missing_data(self, *, message: str, context: dict[str, Any]) -> list[MedicalChatMissingData]:
        text = message.lower()
        missing: list[MedicalChatMissingData] = []
        profile = context["profile"]
        active_cycle = context["active_cycle"]
        symptom_logs = [log for log in context["recent_logs"] if log.log_type == LogType.SYMPTOM]
        intimacy_logs = [log for log in context["recent_logs"] if log.log_type == LogType.INTERCOURSE]

        if self._is_cycle_timing_question(text):
            if not active_cycle and not context["latest_prediction"]:
                missing.append(
                    MedicalChatMissingData(
                        action="save_period_start",
                        endpoint="POST /api/v1/cycle/period/start",
                        reason="Your current cycle has not been started yet.",
                        prompt="When did your last period start?",
                        payload_template={"start_date": "2026-04-06"},
                    )
                )
            if not context["recent_temps"] and any(term in text for term in {"temperature", "bbt", "temp"}):
                missing.append(
                    MedicalChatMissingData(
                        action="save_temperature",
                        endpoint="POST /api/v1/sensor/ingest/temperature",
                        reason="There are no recent temperature logs to ground the answer.",
                        prompt="Please log at least one basal or wrist temperature reading.",
                        payload_template={"records": [{"timestamp": "2026-04-06T07:30:00Z", "delta_c": 0.14}]},
                    )
                )

        if any(term in text for term in {"perimenopause", "menopause", "age"}):
            if not profile.date_of_birth:
                missing.append(
                    MedicalChatMissingData(
                        action="save_profile",
                        endpoint="POST /api/v1/onboarding/profile",
                        reason="Date of birth is missing from your profile.",
                        prompt="What is your date of birth?",
                        payload_template={"date_of_birth": "1995-01-01"},
                    )
                )

        if any(term in text for term in {"symptom", "cramp", "bloating", "pain", "spotting", "bleeding", "discharge", "breast", "mood", "anxiety", "acne"}):
            if not symptom_logs:
                missing.append(
                    MedicalChatMissingData(
                        action="save_symptoms",
                        endpoint="POST /api/v1/cycle/symptom-log",
                        reason="You have not logged any recent symptoms.",
                        prompt="Which symptoms are you experiencing today?",
                        payload_template={"log_date": "2026-04-06", "symptoms": ["cramps"]},
                    )
                )

        if any(term in text for term in {"intimacy", "sex", "intercourse"}):
            if not active_cycle:
                missing.append(
                    MedicalChatMissingData(
                        action="save_period_start",
                        endpoint="POST /api/v1/cycle/period/start",
                        reason="An active cycle is required before intimacy can be interpreted in cycle context.",
                        prompt="When did your current period start?",
                        payload_template={"start_date": "2026-04-06"},
                    )
                )
            elif not intimacy_logs:
                missing.append(
                    MedicalChatMissingData(
                        action="save_intimacy",
                        endpoint="POST /api/v1/cycle/intimacy-log",
                        reason="There is no intimacy log in your recent cycle history.",
                        prompt="Would you like to log recent intimacy details?",
                        payload_template={"log_date": "2026-04-06", "had_intimacy": True},
                    )
                )

        if any(term in text for term in {"tired", "fatigue", "exhausted", "low energy", "sleep"}):
            if not context["recent_sleep"] and not context["recent_hrv"]:
                missing.append(
                    MedicalChatMissingData(
                        action="save_profile",
                        endpoint="POST /api/v1/onboarding/profile",
                        reason="No wearable or sleep data is available to personalize fatigue analysis.",
                        prompt="Do you have a wearable or fitness tracker connected? Connecting one would help Vyla give you much more accurate fatigue insights.",
                        payload_template={},
                    )
                )

        deduped: list[MedicalChatMissingData] = []
        seen: set[tuple[str, str]] = set()
        for item in missing:
            key = (item.action, item.reason)
            if key not in seen:
                seen.add(key)
                deduped.append(item)
        return deduped

    def _build_missing_data_answer(
        self,
        *,
        message: str,
        context: dict[str, Any],
        missing: list[MedicalChatMissingData],
        saved_records: list[str],
    ) -> str:
        known_bits = self._deterministic_context_summary(context)
        prefix = "I've saved the information you just shared. " if saved_records else ""
        missing_prompts = " ".join(item.prompt for item in missing)
        known_part = f" Here's what I can see so far: {known_bits}" if known_bits else ""
        general_answer = self._general_health_answer(message=message, context=context)
        if general_answer:
            return (
                f"{prefix}{general_answer}\n\n"
                f"To personalize this more accurately for you, I need a little more context.{known_part} "
                f"{missing_prompts}"
            ).strip()
        return (
            f"{prefix}To give you a personalized and safe answer, I need just a little more context.{known_part} "
            f"{missing_prompts}"
        ).strip()

    def _build_urgent_answer(self, *, message: str, context: dict[str, Any], saved_records: list[str]) -> str:
        known_bits = self._deterministic_context_summary(context)
        prefix = "I've saved the information you just shared. " if saved_records else ""
        context_sentence = f" From your Vyla profile: {known_bits}" if known_bits else ""
        return (
            f"{prefix}{URGENT_SYMPTOM_GUIDANCE}{context_sentence} "
            "Once you are safe and symptoms are stable or mild, you can also log when symptoms started, "
            "bleeding amount, pain location, temperature or fever, pregnancy possibility, and any discharge changes "
            "so Vyla can keep your health record complete."
        ).strip()

    def _generate_answer(
        self,
        *,
        message: str,
        context: dict[str, Any],
        thread_id: str,
        educational: bool = False,
        contextual_follow_up: bool = False,
    ) -> str:
        if educational and self._has_deterministic_education_topic(message):
            return self._deterministic_educational_answer(message=message, context=context)
        openai_answer = self._openai_answer(message=message, context=context, thread_id=thread_id, educational=educational)
        if openai_answer:
            return openai_answer
        if contextual_follow_up:
            return self._deterministic_follow_up_answer(message=message, thread_id=thread_id, context=context)
        if educational:
            return self._deterministic_educational_answer(message=message, context=context)
        return self._deterministic_answer(message=message, context=context)

    def _build_chat_openai_body(
        self, *, message: str, context: dict[str, Any], thread_id: str, educational: bool = False
    ) -> dict[str, Any]:
        prompt_context = self._serialize_context_for_model(context)
        history = self._recent_thread_messages(thread_id=thread_id)
        today = datetime.now(UTC).date().isoformat()
        active_cycle = context["active_cycle"]
        cycle_day_note = ""
        if active_cycle:
            cycle_day = (datetime.now(UTC).date() - active_cycle.period_start_date).days + 1
            phase = self._rough_cycle_phase(cycle_day=cycle_day, cycle_length=active_cycle.cycle_length_days)
            cycle_day_note = f" The user is on cycle day {cycle_day} ({phase} phase)."
        input_messages: list[dict[str, str]] = [
            {"role": "developer", "content": VYLA_AI_SYSTEM_PROMPT},
            {
                "role": "developer",
                "content": (
                    f"Today's date is {today}.{cycle_day_note}\n\n"
                    f"User health knowledge base (all available Vyla data):\n{prompt_context}"
                ),
            },
        ]
        for item in history:
            input_messages.append({"role": item.role, "content": self._redact_text(item.content)})
        if educational:
            instructions = (
                "The user is asking an educational health question — they want to understand a concept or condition. "
                "IMPORTANT: Answer ONLY what was asked. Start immediately with a clear, accurate explanation of the specific concept or condition. "
                "Do NOT lead with cycle analysis, wearable data, or the user's personal metrics unless they are directly and obviously relevant to the question. "
                "Do NOT apply the full AI reasoning framework for educational questions. "
                "Structure: (1) Explain what it is, (2) Key facts or symptoms if relevant, (3) When to seek help if appropriate, "
                "(4) suggest 3-5 helpful follow-up questions the user can ask next. "
                "If the user has a directly relevant condition in their profile (e.g. they asked about fibroids and have fibroids noted), "
                "briefly acknowledge it after the explanation. Otherwise stay focused on the concept. "
                "Be warm, clear, and accessible. Avoid medical jargon. Keep the response focused and complete without being boring."
            )
        else:
            instructions = (
                "Follow the Vyla AI system prompt exactly. "
                "Apply the AI reasoning framework: analyze cycle state, compare against historical baseline, "
                "analyze wearable trends, analyze symptom clusters, estimate confidence, then respond. "
                "Ground the answer in the user's actual data — reference cycle day, phase, temperature trends, "
                "HRV, sleep scores, and past cycle patterns naturally where relevant. "
                "If the user's data does not support a firm answer, state the limitation warmly and give the next useful step. "
                "Never give a generic textbook answer when personalized data is available. "
                "If the user asks a health question but Vyla has limited user data, still answer the general health question first, "
                "then explain what extra data would make it more personalized. End with 2-4 useful follow-up questions."
            )
        return {
            "model": self.settings.llm_model,
            "input": input_messages,
            "instructions": instructions,
            "temperature": 0.2,
            "text": {"format": {"type": "text"}},
        }

    def _openai_answer(self, *, message: str, context: dict[str, Any], thread_id: str, educational: bool = False) -> str | None:
        if not self.ai_gateway.enabled:
            return None
        body = self._build_chat_openai_body(message=message, context=context, thread_id=thread_id, educational=educational)
        data = self.ai_gateway.responses(body)
        if not data:
            return None
        text = self._guard_output(self._extract_response_text(data))
        return text or None

    def _openai_answer_stream(
        self, *, message: str, context: dict[str, Any], thread_id: str, educational: bool = False
    ) -> Iterator[str]:
        if not self.ai_gateway.enabled:
            return
        body = self._build_chat_openai_body(message=message, context=context, thread_id=thread_id, educational=educational)
        for data in self.ai_gateway.stream_responses(body):
            if data.get("type") == "response.output_text.delta":
                delta = data.get("delta", "")
                if delta:
                    yield delta

    def chat_stream(
        self,
        *,
        user_id: str,
        message: str,
        thread_id: str | None = None,
        data_action: MedicalChatDataAction | None = None,
    ) -> Iterator[str]:
        def _sse(payload: dict[str, Any]) -> str:
            return f"data: {json.dumps(payload, separators=(',', ':'))}\n\n"

        normalized_message = message.strip()

        try:
            quota = self._chat_quota(user_id)
        except Exception:
            yield _sse({"event": "error", "message": "Service temporarily unavailable."})
            return

        if quota["remaining"] <= 0:
            yield _sse({
                "event": "error",
                "code": "quota_exceeded",
                "message": "You've reached your weekly chat limit.",
                "chat_limit": int(quota["limit"]),
                "chats_used": int(quota["used"]),
                "chats_remaining": 0,
                "quota_reset_at": quota["reset_at"].isoformat(),
            })
            return

        try:
            thread = self._get_or_create_thread(user_id=user_id, thread_id=thread_id, message=normalized_message)
            is_contextual_follow_up = (
                self._is_contextual_follow_up(normalized_message)
                and self._thread_has_medical_context(thread_id=thread.id)
            )
            self._append_message(thread_id=thread.id, user_id=user_id, role="user", content=normalized_message)
            quota_after = {
                **quota,
                "used": int(quota["used"]) + 1,
                "remaining": max(0, int(quota["remaining"]) - 1),
            }
        except Exception:
            yield _sse({"event": "error", "message": "Service temporarily unavailable."})
            return

        yield _sse({
            "event": "start",
            "thread_id": thread.id,
            "chat_limit": int(quota_after["limit"]),
            "chats_used": int(quota_after["used"]),
            "chats_remaining": int(quota_after["remaining"]),
            "quota_reset_at": quota_after["reset_at"].isoformat(),
        })

        if not self._is_medical_question(normalized_message) and not is_contextual_follow_up:
            answer = (
                "Vyla AI only answers reproductive and health-related questions. "
                "Ask about your cycle, symptoms, fertility, temperature, ovulation, mood, sleep, or logged health data."
            )
            yield _sse({"event": "delta", "text": answer})
            try:
                self._append_message(thread_id=thread.id, user_id=user_id, role="assistant", content=answer)
                self.db.commit()
            except Exception:
                pass
            yield _sse({
                "event": "done",
                "sufficient_data": False,
                "missing_data": [],
                "saved_records": [],
                "disclaimer": self.settings.medical_disclaimer,
            })
            return

        try:
            urgent_symptoms = self._has_urgent_symptoms(normalized_message)
            saved_records: list[str] = []
            extracted_actions = [] if urgent_symptoms else self._extract_actions_from_message(normalized_message)
            if data_action is not None:
                extracted_actions = [item for item in extracted_actions if item.action != data_action.action]
            for extracted_action in extracted_actions:
                saved_records.extend(self._apply_data_action(user_id=user_id, data_action=extracted_action))
            if data_action is not None:
                saved_records.extend(self._apply_data_action(user_id=user_id, data_action=data_action))
            context = self._build_context(user_id)
            context["retrieved_ai_memory"] = self._retrieve_ai_memory_documents(user_id=user_id, query=normalized_message)
            educational_question = self._is_educational_health_question(normalized_message)
            missing = (
                []
                if urgent_symptoms or educational_question or is_contextual_follow_up
                else self._identify_missing_data(message=normalized_message, context=context)
            )
        except Exception:
            yield _sse({"event": "error", "message": "Service temporarily unavailable."})
            return

        answer_parts: list[str] = []

        if urgent_symptoms:
            answer = self._build_urgent_answer(message=normalized_message, context=context, saved_records=saved_records)
            yield _sse({"event": "delta", "text": answer})
            answer_parts.append(answer)
        elif missing:
            answer = self._build_missing_data_answer(message=normalized_message, context=context, missing=missing, saved_records=saved_records)
            yield _sse({"event": "delta", "text": answer})
            answer_parts.append(answer)
        else:
            use_openai = self.settings.llm_api_key and not (
                educational_question and self._has_deterministic_education_topic(normalized_message)
            )
            if use_openai:
                for chunk in self._openai_answer_stream(
                    message=normalized_message,
                    context=context,
                    thread_id=thread.id,
                    educational=educational_question,
                ):
                    chunk = self._redact_text(chunk)
                    yield _sse({"event": "delta", "text": chunk})
                    answer_parts.append(chunk)

            if not answer_parts:
                if is_contextual_follow_up:
                    fallback = self._deterministic_follow_up_answer(message=normalized_message, thread_id=thread.id, context=context)
                elif educational_question:
                    fallback = self._deterministic_educational_answer(message=normalized_message, context=context)
                else:
                    fallback = self._deterministic_answer(message=normalized_message, context=context)
                yield _sse({"event": "delta", "text": fallback})
                answer_parts.append(fallback)

        full_answer = self._guard_output("".join(answer_parts))

        try:
            self._append_message(thread_id=thread.id, user_id=user_id, role="assistant", content=full_answer)
            memory_document = self._persist_ai_memory_document(
                user_id=user_id,
                thread_id=thread.id,
                message=normalized_message,
                answer=full_answer,
                context=context,
                sufficient_data=not missing,
            )
            self.audit.log(
                user_id,
                "ai.medical_chat.stream",
                {
                    "thread_id": thread.id,
                    "message_redacted": self._redact_text(normalized_message),
                    "sufficient_data": not missing,
                    "security_policy_version": AI_SECURITY_POLICY_VERSION,
                    "consent_accepted": self._ai_chat_consent_accepted(user_id),
                    "context_pipeline": "minimise:redact:llm:guard",
                    "memory_document_id": memory_document.id if memory_document else None,
                },
            )
            self.db.commit()
        except Exception:
            pass

        yield _sse({
            "event": "done",
            "sufficient_data": not missing,
            "missing_data": [m.model_dump() for m in missing],
            "saved_records": saved_records,
            "disclaimer": self.settings.medical_disclaimer,
        })

    def _deterministic_follow_up_answer(self, *, message: str, thread_id: str, context: dict[str, Any]) -> str:
        history = self._recent_thread_messages(thread_id=thread_id, limit=10)
        prior_messages = [item for item in history if item.content.strip() != message.strip()]
        if self._is_document_follow_up(message):
            document_answer = self._document_follow_up_answer(prior_messages)
            if document_answer:
                return document_answer

        last_assistant = next((item.content.strip() for item in reversed(prior_messages) if item.role == "assistant"), "")
        last_user = next((item.content.strip() for item in reversed(prior_messages) if item.role == "user"), "")
        if self._is_affirmative_follow_up(message) and last_assistant:
            implied_question = self._last_assistant_question(last_assistant)
            if implied_question:
                return self._deterministic_answer(message=implied_question, context=context)
        context_summary = self._deterministic_context_summary(context)
        if last_assistant:
            excerpt = self._clean_follow_up_excerpt(last_assistant)
            context_part = f" I can also see from your Vyla data that {context_summary}." if context_summary else ""
            return (
                f"{excerpt}{context_part}\n\n"
                "What would you like to go deeper on: causes, symptoms, treatment options, fertility impact, test results, or what to ask a clinician?"
            )
        if last_user:
            return (
                f"You were asking about {last_user}. "
                "Tell me which part you want to go deeper on, and I will connect it with your Vyla health data where relevant."
            )
        return self._deterministic_answer(message=message, context=context)

    def _last_assistant_question(self, text: str) -> str | None:
        matches = re.findall(r"([^?]{8,220}\?)", text)
        for raw in reversed(matches):
            question = re.sub(r"^[\s\-*•0-9.)]+", "", raw).strip()
            if question:
                return question
        return None

    def _is_document_follow_up(self, message: str) -> bool:
        text = message.lower()
        return any(term in text for term in {"file", "document", "report", "uploaded", "upload", "lab result", "scan"})

    def _document_follow_up_answer(self, prior_messages: list[MedicalChatMessage]) -> str | None:
        for item in reversed(prior_messages):
            if item.role != "assistant":
                continue
            content = item.content.strip()
            lower = content.lower()
            if "what i can read:" in lower or "medical document" in lower or "reference range" in lower:
                summary = self._clean_follow_up_excerpt(content, max_chars=700)
                return (
                    "The file looked like a medical document. Here is the useful part from the earlier analysis:\n\n"
                    f"{summary}\n\n"
                    "I do not keep the original uploaded file after processing, so if you want me to check a specific value or page again, upload it once more or paste that result here."
                )
        for item in reversed(prior_messages):
            if item.role == "user" and item.content.lower().startswith("uploaded medical document"):
                return (
                    "I do not keep the original uploaded file after processing. "
                    "I can use the analysis already shown in this chat, but I cannot reopen the original file. "
                    "Upload it again or paste the result you want explained, and I will summarise it clearly."
                )
        return None

    def _clean_follow_up_excerpt(self, text: str, *, max_chars: int = 420) -> str:
        cleaned = re.sub(r"\s+", " ", text).strip()
        low_value_phrases = (
            "I can see this in your saved Vyla health profile:",
            "I do not have enough recent cycle, symptom, or wearable data to connect your question to a specific pattern yet.",
            "Logging your latest period start date, symptoms, temperature, LH tests, cervical mucus, sleep, or recovery data will help Vyla give you much more personalized insights.",
        )
        for phrase in low_value_phrases:
            cleaned = cleaned.replace(phrase, "").strip()
        cleaned = re.sub(r"\s+", " ", cleaned).strip(" .")
        if not cleaned:
            return "I do not have enough useful detail from the earlier answer to summarise it well."
        if len(cleaned) > max_chars:
            cleaned = cleaned[: max_chars - 3].rsplit(" ", 1)[0].rstrip(" ,;:") + "..."
        return cleaned

    def _has_deterministic_education_topic(self, message: str) -> bool:
        text = message.lower()
        topic_terms = {
            "fibroid",
            "fibroids",
            "pcos",
            "polycystic",
            "endometriosis",
            "adenomyosis",
            "perimenopause",
            "menopause",
            "pmdd",
            "premenstrual dysphoric",
            "pms",
            "premenstrual syndrome",
        }
        return any(term in text for term in topic_terms)

    def _ai_chat_consent_accepted(self, user_id: str) -> bool:
        profile = self.users.ensure_profile(user_id)
        conditions = dict(profile.conditions or {})
        ai_preferences = dict(conditions.get("ai_preferences") or {})
        return ai_preferences.get("chat_consent_accepted") is True

    def _redact_text(self, value: str | None) -> str:
        if not value:
            return ""
        redacted = str(value)
        for pattern, replacement in PII_REDACTION_PATTERNS:
            redacted = pattern.sub(replacement, redacted)
        redacted = re.sub(r"(?<![\w.-])\+?\d[\d\s().-]{7,}\d(?!\w)", self._redact_phone_candidate, redacted)
        return redacted

    def _redact_phone_candidate(self, match: re.Match[str]) -> str:
        candidate = match.group(0)
        digits = re.sub(r"\D", "", candidate)
        if len(digits) < 9:
            return candidate
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", candidate.strip()):
            return candidate
        return "[redacted_phone]"

    def _redact_payload_for_model(self, value: Any) -> Any:
        if isinstance(value, dict):
            clean: dict[str, Any] = {}
            for key, item in value.items():
                key_text = str(key)
                if key_text.lower() in PII_PAYLOAD_KEYS:
                    clean[key_text] = "[redacted]"
                    continue
                clean[key_text] = self._redact_payload_for_model(item)
            return clean
        if isinstance(value, list):
            return [self._redact_payload_for_model(item) for item in value[:40]]
        if isinstance(value, str):
            return self._redact_text(value)
        return value

    def _minimise_model_context(self, knowledge_base: dict[str, Any]) -> dict[str, Any]:
        context = self._redact_payload_for_model(knowledge_base)
        profile = dict(context.get("profile") or {})
        profile.pop("date_of_birth", None)
        profile.pop("height_cm", None)
        profile.pop("weight_kg", None)
        context["profile"] = profile

        latest_prediction = context.get("latest_prediction")
        if isinstance(latest_prediction, dict):
            latest_prediction.pop("audit", None)
            latest_prediction["warning_flags"] = latest_prediction.get("warning_flags") or []

        logs = context.get("recent_logs")
        if isinstance(logs, list):
            context["recent_logs"] = logs[-14:]
        patterns = context.get("recent_log_patterns")
        if isinstance(patterns, dict):
            patterns.pop("latest_by_type", None)
        return context

    def _guard_output(self, answer: str) -> str:
        guarded = self._redact_text(answer)
        unsafe_diagnosis = re.search(r"\b(you have|you definitely have|this confirms)\s+(pcos|endometriosis|fibroids|cancer|pregnancy|miscarriage|infection)\b", guarded, re.IGNORECASE)
        if unsafe_diagnosis and "may" not in guarded[max(0, unsafe_diagnosis.start() - 80): unsafe_diagnosis.end() + 80].lower():
            guarded = re.sub(
                r"\bYou have\b",
                "Your data may suggest",
                guarded,
                count=1,
                flags=re.IGNORECASE,
            )
        return guarded

    def _persist_ai_memory_document(
        self,
        *,
        user_id: str,
        thread_id: str,
        message: str,
        answer: str,
        context: dict[str, Any],
        sufficient_data: bool,
        doc_type: str = "chat_summary",
        data_scope: str | None = None,
    ) -> AiMemoryDocument | None:
        if not sufficient_data or not self._ai_chat_consent_accepted(user_id):
            return None
        summary = self._build_ai_memory_summary(message=message, answer=answer, context=context)
        if not summary:
            return None
        scope = data_scope or self._infer_ai_memory_scope(message)
        hash_embedding = AIMemoryEmbeddingService().embed(summary)
        memory = AiMemoryDocument(
            user_id=user_id,
            thread_id=thread_id,
            doc_type=doc_type,
            data_scope=scope,
            sensitivity=self._ai_memory_sensitivity(scope),
            summary_text=summary,
            embedding=hash_embedding,
            embedding_model=LOCAL_EMBEDDING_MODEL,
            source_refs=[f"medical_chat_thread:{thread_id}"],
            memory_metadata={
                "security_policy_version": AI_SECURITY_POLICY_VERSION,
                "context_pipeline": "minimise:redact:summarise",
                "used_user_data": self._used_user_data(context),
            },
            redaction_version=AI_SECURITY_POLICY_VERSION,
        )
        self.db.add(memory)
        self.db.flush()
        if not self._sqlite and isinstance(self.ai_memory_embeddings, OpenAIEmbeddingService):
            self._write_real_embedding(memory.id, summary)
        return memory

    def _write_real_embedding(self, memory_id: str, text: str) -> None:
        """Write a real semantic embedding to embedding_vec on Postgres. Non-fatal on failure."""
        from phora.db.base import HEALTH_SCHEMA
        try:
            vec = self.ai_memory_embeddings.embed(text)
            vec_str = "[" + ",".join(f"{x:.6f}" for x in vec) + "]"
            schema_prefix = f'"{HEALTH_SCHEMA}".' if HEALTH_SCHEMA else ""
            self.db.execute(
                text(
                    f"UPDATE {schema_prefix}ai_memory_documents "
                    f"SET embedding_vec = CAST(:vec AS vector), embedding_model = :model "
                    f"WHERE id = :id"
                ),
                {"vec": vec_str, "model": REAL_EMBEDDING_MODEL, "id": memory_id},
            )
        except Exception:
            pass

    def _build_ai_memory_summary(self, *, message: str, answer: str, context: dict[str, Any]) -> str:
        message_text = self._redact_text(message)
        answer_text = self._redact_text(answer)
        answer_text = re.sub(r"\s+", " ", answer_text).strip()
        if len(answer_text) > 520:
            answer_text = answer_text[:517].rsplit(" ", 1)[0].rstrip(" ,;:") + "..."
        context_bits = self._deterministic_context_summary(context)
        pieces = [
            f"User asked: {message_text}",
            f"Vyla answered: {answer_text}",
        ]
        if context_bits:
            pieces.append(f"Relevant context: {self._redact_text(context_bits)}")
        return self._redact_text(" ".join(pieces)).strip()

    def _retrieve_ai_memory_documents(
        self,
        *,
        user_id: str,
        query: str,
        allowed_scopes: set[str] | None = None,
        limit: int = 4,
    ) -> list[dict[str, Any]]:
        scopes = allowed_scopes or self._allowed_ai_memory_scopes(query)
        if not scopes:
            return []

        if isinstance(self.ai_memory_embeddings, OpenAIEmbeddingService):
            safe_items = self._retrieve_via_vector_sql(
                user_id=user_id, query=query, scopes=scopes, limit=limit
            )
            if safe_items:
                self.audit.log(
                    user_id,
                    "ai.memory.retrieved",
                    {
                        "count": len(safe_items),
                        "allowed_scopes": sorted(scopes),
                        "security_policy_version": AI_SECURITY_POLICY_VERSION,
                        "retriever": "vector_cosine_hnsw",
                        "embedding_model": REAL_EMBEDDING_MODEL,
                    },
                )
                return safe_items
            # Fall through to Python cosine if no real-embedding docs exist yet

        safe_items = self._retrieve_via_python_cosine(
            user_id=user_id, query=query, scopes=scopes, limit=limit
        )
        if safe_items:
            self.audit.log(
                user_id,
                "ai.memory.retrieved",
                {
                    "count": len(safe_items),
                    "allowed_scopes": sorted(scopes),
                    "security_policy_version": AI_SECURITY_POLICY_VERSION,
                    "retriever": "user_scoped_embedding_shadow_rag",
                    "embedding_model": LOCAL_EMBEDDING_MODEL,
                },
            )
        return safe_items

    def _retrieve_via_vector_sql(
        self,
        *,
        user_id: str,
        query: str,
        scopes: set[str],
        limit: int,
    ) -> list[dict[str, Any]]:
        from phora.db.base import HEALTH_SCHEMA

        try:
            vec = self.ai_memory_embeddings.embed(query)
        except Exception:
            return []

        vec_str = "[" + ",".join(f"{x:.6f}" for x in vec) + "]"
        schema_prefix = f'"{HEALTH_SCHEMA}".' if HEALTH_SCHEMA else ""
        scopes_list = sorted(scopes)

        rows = self.db.execute(
            text(
                f"SELECT doc_type, data_scope, sensitivity, summary_text, source_refs, "
                f"embedding_model, created_at "
                f"FROM {schema_prefix}ai_memory_documents "
                f"WHERE user_id = :user_id "
                f"  AND data_scope = ANY(:scopes) "
                f"  AND embedding_vec IS NOT NULL "
                f"ORDER BY embedding_vec <=> CAST(:vec AS vector) "
                f"LIMIT :limit"
            ),
            {"user_id": user_id, "scopes": scopes_list, "vec": vec_str, "limit": limit * 4},
        ).fetchall()

        safe_items: list[dict[str, Any]] = []
        for row in rows:
            summary = self._redact_text(row.summary_text)
            if self._contains_prompt_injection(summary):
                continue
            safe_items.append(
                {
                    "doc_type": row.doc_type,
                    "data_scope": row.data_scope,
                    "sensitivity": row.sensitivity,
                    "summary": summary,
                    "source_refs": row.source_refs or [],
                    "embedding_model": row.embedding_model,
                    "created_at": row.created_at.isoformat() if row.created_at else None,
                }
            )
            if len(safe_items) >= limit:
                break
        return safe_items

    def _retrieve_via_python_cosine(
        self,
        *,
        user_id: str,
        query: str,
        scopes: set[str],
        limit: int,
    ) -> list[dict[str, Any]]:
        candidates = list(
            self.db.scalars(
                select(AiMemoryDocument)
                .where(
                    AiMemoryDocument.user_id == user_id,
                    AiMemoryDocument.data_scope.in_(sorted(scopes)),
                )
                .order_by(desc(AiMemoryDocument.created_at))
                .limit(40)
            )
        )
        query_embedding = AIMemoryEmbeddingService().embed(query)
        ranked = sorted(
            candidates,
            key=lambda item: self._memory_rank_score(
                query=query,
                query_embedding=query_embedding,
                memory=item,
            ),
            reverse=True,
        )
        safe_items: list[dict[str, Any]] = []
        for item in ranked:
            score = self._memory_rank_score(query=query, query_embedding=query_embedding, memory=item)
            if score <= 0 and len(safe_items) >= 1:
                continue
            summary = self._redact_text(item.summary_text)
            if self._contains_prompt_injection(summary):
                continue
            safe_items.append(
                {
                    "doc_type": item.doc_type,
                    "data_scope": item.data_scope,
                    "sensitivity": item.sensitivity,
                    "summary": summary,
                    "source_refs": item.source_refs or [],
                    "embedding_model": item.embedding_model,
                    "created_at": item.created_at.isoformat() if item.created_at else None,
                }
            )
            if len(safe_items) >= limit:
                break
        return safe_items

    def _allowed_ai_memory_scopes(self, query: str) -> set[str]:
        text = query.lower()
        scopes = {"cycle", "symptom", "education"}
        if any(term in text for term in {"temperature", "bbt", "wearable", "sleep", "hrv", "heart rate", "rhr"}):
            scopes.add("wearable")
        if any(term in text for term in {"sex", "intimacy", "intercourse", "pregnancy", "fertility", "ovulation", "lh"}):
            scopes.add("fertility")
        if any(term in text for term in {"document", "file", "report", "lab", "blood", "scan"}):
            scopes.add("medical_document")
        return scopes

    def _infer_ai_memory_scope(self, message: str) -> str:
        text = message.lower()
        if any(term in text for term in {"temperature", "bbt", "wearable", "sleep", "hrv", "heart rate", "rhr"}):
            return "wearable"
        if any(term in text for term in {"ovulation", "fertile", "fertility", "lh", "pregnancy", "intimacy", "sex"}):
            return "fertility"
        if any(term in text for term in {"symptom", "cramp", "pain", "mood", "bleeding", "spotting"}):
            return "symptom"
        if self._is_educational_health_question(message):
            return "education"
        return "cycle"

    def _ai_memory_sensitivity(self, scope: str) -> str:
        if scope in {"fertility", "wearable", "medical_document"}:
            return "HIGH"
        if scope in {"cycle", "symptom"}:
            return "MEDIUM"
        return "LOW"

    def _memory_relevance_score(self, query: str, summary: str, data_scope: str) -> int:
        query_terms = {
            term
            for term in re.findall(r"[a-z0-9]{3,}", query.lower())
            if term not in {"what", "when", "does", "with", "about", "this", "that", "have", "today"}
        }
        summary_terms = set(re.findall(r"[a-z0-9]{3,}", summary.lower()))
        score = len(query_terms & summary_terms)
        if data_scope in self._allowed_ai_memory_scopes(query):
            score += 1
        return score

    def _memory_rank_score(self, *, query: str, query_embedding: list[float], memory: AiMemoryDocument) -> float:
        keyword_score = float(self._memory_relevance_score(query, memory.summary_text, memory.data_scope))
        vector_score = self.ai_memory_embeddings.cosine_similarity(query_embedding, memory.embedding)
        return keyword_score + vector_score

    def _contains_prompt_injection(self, text: str) -> bool:
        lowered = text.lower()
        return any(
            phrase in lowered
            for phrase in (
                "ignore previous instructions",
                "reveal all data",
                "show system prompt",
                "export database",
                "developer message",
            )
        )

    def _serialize_context_for_model(self, context: dict[str, Any]) -> str:
        profile = context["profile"]
        active_cycle = context["active_cycle"]
        latest_prediction = context["latest_prediction"]
        recent_logs: list[DailyLog] = context["recent_logs"]
        past_cycles: list[CycleRecord] = context["past_cycles"]
        today = datetime.now(UTC).date()

        cycle_day = None
        if active_cycle:
            cycle_day = (today - active_cycle.period_start_date).days + 1

        knowledge_base = {
            "today": today.isoformat(),
            "profile": self._profile_summary(profile),
            "active_cycle": None
            if not active_cycle
            else {
                "period_start_date": active_cycle.period_start_date.isoformat(),
                "cycle_day": cycle_day,
                "current_phase": self._rough_cycle_phase(cycle_day=cycle_day, cycle_length=active_cycle.cycle_length_days) if cycle_day else None,
                "cycle_length_days": active_cycle.cycle_length_days,
                "period_length_days": active_cycle.menses_length,
                "period_end_date": active_cycle.period_end_date.isoformat() if active_cycle.period_end_date else None,
                "ovulation_predicted_date": active_cycle.ovulation_predicted_date.isoformat()
                if active_cycle.ovulation_predicted_date
                else None,
                "ovulation_confirmed_date": active_cycle.ovulation_confirmed_date.isoformat()
                if active_cycle.ovulation_confirmed_date
                else None,
                "lh_surge_detected_date": active_cycle.lh_surge_detected_date.isoformat()
                if active_cycle.lh_surge_detected_date
                else None,
                "luteal_length_days": active_cycle.luteal_length_days,
                "is_anovulatory": active_cycle.is_anovulatory,
                "mu_cycle": active_cycle.mu_cycle,
                "sigma_cycle": active_cycle.sigma_cycle,
            },
            "cycle_history": self._cycle_history_summary(past_cycles),
            "latest_period_log": self._serialize_log_entry(context["latest_period_log"])
            if context["latest_period_log"]
            else None,
            "latest_prediction": None
            if not latest_prediction
            else {
                "generated_at": latest_prediction.generated_at.isoformat() if latest_prediction.generated_at else None,
                "current_phase": latest_prediction.current_phase,
                "confidence": latest_prediction.confidence,
                "confidence_explanation": latest_prediction.confidence_explanation,
                "fertile_window": latest_prediction.fertile_window or {},
                "ovulation_estimate": latest_prediction.ovulation_estimate or {},
                "next_period_estimate": latest_prediction.next_period_estimate or {},
                "warning_flags": latest_prediction.warning_flags or [],
                "contributing_signals": latest_prediction.contributing_signals or [],
                "audit": latest_prediction.audit or {},
            },
            "latest_lh_log": self._serialize_log_entry(context["latest_lh"]) if context["latest_lh"] else None,
            "latest_mucus_log": self._serialize_log_entry(context["latest_mucus"]) if context["latest_mucus"] else None,
            "recent_logs": [self._serialize_log_entry(item) for item in recent_logs[-30:]],
            "recent_log_patterns": self._log_patterns(recent_logs),
            "sensors": {
                "temperature": self._sensor_summary(context["recent_temps"], value_label="delta_c"),
                "resting_heart_rate": self._sensor_summary(context["recent_rhr"], value_label="bpm"),
                "hrv": self._sensor_summary(context["recent_hrv"], value_label="ms"),
                "sleep": self._sensor_summary(context["recent_sleep"], value_label="minutes"),
                "steps": self._sensor_summary(context["recent_steps"], value_label="steps"),
                "blood_oxygen_avg": self._sensor_summary(context["recent_blood_oxygen_avg"], value_label="percent"),
                "blood_oxygen_min": self._sensor_summary(context["recent_blood_oxygen_min"], value_label="percent"),
                "stress": self._stress_summary(context["recent_stress"]),
            },
            "retrieved_ai_memory": context.get("retrieved_ai_memory") or [],
            "data_confidence": self._data_confidence_score(context),
        }
        return json.dumps(self._minimise_model_context(knowledge_base), default=str, ensure_ascii=True, indent=2)

    def _cycle_history_summary(self, past_cycles: list[CycleRecord]) -> dict[str, Any]:
        if not past_cycles:
            return {"count": 0, "cycles": [], "variability": None}

        summaries = []
        lengths = []
        for cycle in past_cycles:
            length = cycle.cycle_length_days
            if length:
                lengths.append(length)
            summaries.append({
                "period_start_date": cycle.period_start_date.isoformat(),
                "period_end_date": cycle.period_end_date.isoformat() if cycle.period_end_date else None,
                "cycle_length_days": length,
                "menses_length_days": cycle.menses_length,
                "ovulation_predicted_date": cycle.ovulation_predicted_date.isoformat() if cycle.ovulation_predicted_date else None,
                "ovulation_confirmed_date": cycle.ovulation_confirmed_date.isoformat() if cycle.ovulation_confirmed_date else None,
                "lh_surge_detected_date": cycle.lh_surge_detected_date.isoformat() if cycle.lh_surge_detected_date else None,
                "luteal_length_days": cycle.luteal_length_days,
                "is_anovulatory": cycle.is_anovulatory,
            })

        variability = None
        if len(lengths) >= 2:
            variability = {
                "mean_cycle_length": round(mean(lengths), 1),
                "std_dev_days": round(stdev(lengths), 1),
                "min_length": min(lengths),
                "max_length": max(lengths),
                "irregular": stdev(lengths) > 7 if len(lengths) >= 3 else None,
            }

        return {
            "count": len(past_cycles),
            "cycles": summaries,
            "variability": variability,
        }

    def _data_confidence_score(self, context: dict[str, Any]) -> dict[str, Any]:
        signals = {
            "active_cycle": bool(context["active_cycle"]),
            "past_cycles": len(context["past_cycles"]) >= 2,
            "recent_logs": len(context["recent_logs"]) >= 3,
            "temperature_data": len(context["recent_temps"]) >= 3,
            "hrv_data": len(context["recent_hrv"]) >= 3,
            "sleep_data": len(context["recent_sleep"]) >= 3,
            "lh_data": context["latest_lh"] is not None,
            "mucus_data": context["latest_mucus"] is not None,
            "prediction": context["latest_prediction"] is not None,
            "profile_complete": bool(
                context["profile"].date_of_birth and context["profile"].conditions
            ),
        }
        score = sum(signals.values())
        level = "high" if score >= 7 else "medium" if score >= 4 else "low"
        return {"score": score, "max": len(signals), "level": level, "signals": signals}

    def _serialize_log_entry(self, log: DailyLog) -> dict[str, Any]:
        return {
            "date": log.log_date.isoformat() if log.log_date else None,
            "type": log.log_type.value if hasattr(log.log_type, "value") else str(log.log_type),
            "payload": log.payload or {},
        }

    def _log_patterns(self, logs: list[DailyLog]) -> dict[str, Any]:
        symptom_counts: dict[str, int] = {}
        mood_counts: dict[str, int] = {}
        latest_by_type: dict[str, dict[str, Any]] = {}
        for log in logs:
            log_type = log.log_type.value if hasattr(log.log_type, "value") else str(log.log_type)
            latest_by_type[log_type] = self._serialize_log_entry(log)
            payload = log.payload or {}
            if log.log_type == LogType.SYMPTOM:
                for symptom in payload.get("symptoms") or []:
                    if not symptom:
                        continue
                    key = str(symptom).strip().lower()
                    symptom_counts[key] = symptom_counts.get(key, 0) + 1
                for mood in payload.get("moods") or []:
                    if not mood:
                        continue
                    key = str(mood).strip().lower()
                    mood_counts[key] = mood_counts.get(key, 0) + 1

        frequent_symptoms = [
            {"symptom": symptom, "count": count}
            for symptom, count in sorted(symptom_counts.items(), key=lambda item: item[1], reverse=True)[:10]
        ]
        frequent_moods = [
            {"mood": mood, "count": count}
            for mood, count in sorted(mood_counts.items(), key=lambda item: item[1], reverse=True)[:6]
        ]
        return {
            "log_count": len(logs),
            "frequent_symptoms_90_days": frequent_symptoms,
            "frequent_moods_90_days": frequent_moods,
            "latest_by_type": latest_by_type,
        }

    def _sensor_summary(self, readings: list[SensorReading], *, value_label: str) -> dict[str, Any]:
        latest = readings[-1] if readings else None
        values = [float(item.value) for item in readings if item.value is not None]
        deltas = [float(item.delta) for item in readings if item.delta is not None]
        last_7 = readings[-7:]
        last_7_values = [float(item.value) for item in last_7 if item.value is not None]
        return {
            "count": len(readings),
            "latest": None
            if not latest
            else {
                "recorded_at": latest.recorded_at.isoformat() if latest.recorded_at else None,
                value_label: latest.value,
                "delta": latest.delta,
                "source": latest.source,
            },
            "average_30d": round(mean(values), 2) if values else None,
            "average_7d": round(mean(last_7_values), 2) if last_7_values else None,
            "trend_7d": self._simple_trend(last_7_values),
            "average_delta": round(mean(deltas), 2) if deltas else None,
            "last_7": [
                {
                    "recorded_at": item.recorded_at.isoformat() if item.recorded_at else None,
                    value_label: item.value,
                    "delta": item.delta,
                }
                for item in last_7
            ],
        }

    def _simple_trend(self, values: list[float]) -> str | None:
        if len(values) < 3:
            return None
        first_half = mean(values[: len(values) // 2])
        second_half = mean(values[len(values) // 2 :])
        diff = second_half - first_half
        if diff > 0.05 * abs(first_half + 1):
            return "rising"
        if diff < -0.05 * abs(first_half + 1):
            return "falling"
        return "stable"

    def _stress_summary(self, readings) -> dict[str, Any]:
        values = [float(item.score) for item in readings if item.score is not None]
        latest = readings[-1] if readings else None
        last_7 = readings[-7:]
        last_7_values = [float(item.score) for item in last_7 if item.score is not None]
        return {
            "count": len(readings),
            "latest": None
            if not latest
            else {
                "recorded_at": latest.recorded_at.isoformat() if latest.recorded_at else None,
                "score": latest.score,
            },
            "average_30d": round(mean(values), 2) if values else None,
            "average_7d": round(mean(last_7_values), 2) if last_7_values else None,
            "trend_7d": self._simple_trend(last_7_values),
            "last_7": [
                {
                    "recorded_at": item.recorded_at.isoformat() if item.recorded_at else None,
                    "score": item.score,
                }
                for item in last_7
            ],
        }

    def _extract_actions_from_message(self, message: str) -> list[MedicalChatDataAction]:
        text = message.lower()
        actions: list[MedicalChatDataAction] = []
        inferred_log_date = self._infer_log_date(text)

        period_start_date = self._extract_period_start_date(text)
        if period_start_date:
            actions.append(
                MedicalChatDataAction(
                    action="save_period_start",
                    payload={"start_date": period_start_date.isoformat()},
                )
            )
            inferred_log_date = period_start_date

        symptoms = self._extract_symptoms(text)
        if symptoms:
            payload: dict[str, Any] = {
                "log_date": inferred_log_date.isoformat(),
                "symptoms": symptoms,
            }
            severity = self._extract_severity(text)
            if severity:
                payload["severity"] = severity
            actions.append(MedicalChatDataAction(action="save_symptoms", payload=payload))

        temperature_delta = self._extract_temperature_delta(text)
        if temperature_delta is not None:
            actions.append(
                MedicalChatDataAction(
                    action="save_temperature",
                    payload={
                        "records": [
                            {
                                "timestamp": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
                                "delta_c": temperature_delta,
                                "source": "ai_chat",
                            }
                        ]
                    },
                )
            )

        if any(term in text for term in {"had sex", "had intercourse", "we had sex", "i had sex", "i had intercourse"}):
            actions.append(
                MedicalChatDataAction(
                    action="save_intimacy",
                    payload={"log_date": inferred_log_date.isoformat(), "had_intimacy": True},
                )
            )

        deduped: list[MedicalChatDataAction] = []
        seen: set[tuple[str, str]] = set()
        for action in actions:
            key = (action.action, str(action.payload))
            if key not in seen:
                seen.add(key)
                deduped.append(action)
        return deduped

    def _extract_period_start_date(self, text: str) -> date | None:
        if "period" not in text or not any(term in text for term in {"started", "start", "began", "begin"}):
            return None
        today = datetime.now(UTC).date()
        if "yesterday" in text:
            return today - timedelta(days=1)
        if "today" in text:
            return today
        match = re.search(r"\b(20\d{2}-\d{2}-\d{2})\b", text)
        if match:
            return date.fromisoformat(match.group(1))
        return None

    def _infer_log_date(self, text: str) -> date:
        today = datetime.now(UTC).date()
        if "yesterday" in text:
            return today - timedelta(days=1)
        match = re.search(r"\b(20\d{2}-\d{2}-\d{2})\b", text)
        if match:
            return date.fromisoformat(match.group(1))
        return today

    def _extract_symptoms(self, text: str) -> list[str]:
        symptom_map = {
            "cramps": {"cramp", "cramps"},
            "bloating": {"bloat", "bloated", "bloating"},
            "back pain": {"back pain", "lower back pain"},
            "headache": {"headache", "migraine"},
            "nausea": {"nausea", "nauseous", "feel sick"},
            "fatigue": {"fatigue", "tired", "exhausted", "drained"},
            "spotting": {"spotting"},
            "bleeding": {"bleeding", "heavy bleeding"},
            "breast tenderness": {"breast tender", "sore breast", "breast pain", "breast sore", "chest tender"},
            "discharge": {"discharge", "unusual discharge"},
            "pelvic pain": {"pelvic pain", "pelvic pressure"},
            "hot flashes": {"hot flash", "hot flushes", "flush"},
            "mood swings": {"mood swing", "irritable", "mood change"},
            "anxiety": {"anxious", "anxiety", "nervous"},
            "low mood": {"sad", "depressed", "low mood", "crying"},
            "insomnia": {"insomnia", "can't sleep", "cannot sleep", "not sleeping"},
            "dizziness": {"dizzy", "dizziness", "lightheaded"},
            "acne": {"acne", "breakout", "pimple"},
        }
        symptoms: list[str] = []
        for canonical, variants in symptom_map.items():
            if any(variant in text for variant in variants):
                symptoms.append(canonical)
        return symptoms

    def _extract_severity(self, text: str) -> str | None:
        if any(term in text for term in {"severe", "very bad", "intense", "unbearable", "worst"}):
            return "severe"
        if any(term in text for term in {"mild", "light", "slight"}):
            return "mild"
        if any(term in text for term in {"moderate", "medium", "manageable"}):
            return "moderate"
        return None

    def _extract_temperature_delta(self, text: str) -> float | None:
        if "temperature" not in text and "temp" not in text and "bbt" not in text:
            return None
        match = re.search(r"([+-]?\d+(?:\.\d+)?)\s*(?:°c|c)?", text)
        if not match:
            return None
        value = float(match.group(1))
        if "below baseline" in text or "lower" in text or "down" in text:
            return -abs(value)
        if "above baseline" in text or "higher" in text or "up" in text:
            return abs(value)
        return value

    def _deterministic_answer(self, *, message: str, context: dict[str, Any]) -> str:
        text = message.lower()
        prediction: PredictionSnapshot | None = context["latest_prediction"]
        active_cycle: CycleRecord | None = context["active_cycle"]
        temp_readings: list[SensorReading] = context["recent_temps"]
        sleep_readings: list[SensorReading] = context["recent_sleep"]
        hrv_readings: list[SensorReading] = context["recent_hrv"]
        rhr_readings: list[SensorReading] = context["recent_rhr"]
        stress_readings = context["recent_stress"]
        logs: list[DailyLog] = context["recent_logs"]
        latest_lh: DailyLog | None = context["latest_lh"]
        latest_mucus: DailyLog | None = context["latest_mucus"]
        profile = context["profile"]
        past_cycles: list[CycleRecord] = context["past_cycles"]

        general_answer = self._general_health_answer(message=message, context=context)
        if general_answer:
            return general_answer

        cycle_day = None
        phase = None
        if active_cycle:
            cycle_day = (datetime.now(UTC).date() - active_cycle.period_start_date).days + 1
            phase = self._rough_cycle_phase(cycle_day=cycle_day, cycle_length=active_cycle.cycle_length_days)

        if any(term in text for term in {"luteal", "follicular", "menstrual phase"}):
            phase_context = ""
            if cycle_day and phase:
                phase_context = f" In your current Vyla data, you are around cycle day {cycle_day}, which fits the {phase} phase."
            if "luteal" in text:
                return (
                    "The luteal phase is the part of your cycle after ovulation and before your next period. "
                    "Progesterone usually rises during this phase to prepare the uterine lining. "
                    "Because progesterone affects temperature, digestion, sleep, mood, and fluid balance, some people notice PMS symptoms, breast tenderness, bloating, lower energy, or warmer body temperature here. "
                    f"{phase_context} If symptoms feel severe, very different from your normal pattern, or affect daily life, it may help to speak with a healthcare professional."
                ).strip()
            if "follicular" in text:
                return (
                    "The follicular phase starts on the first day of your period and continues until ovulation. "
                    "Estrogen gradually rises as the ovaries prepare an egg for ovulation, so many people feel energy, mood, and libido improve as this phase progresses. "
                    f"{phase_context} Tracking cervical mucus, LH tests, and temperature can help Vyla estimate when this phase is moving toward ovulation."
                ).strip()
            return (
                "The menstrual phase is the bleeding part of the cycle, starting on day 1 of your period. "
                "Estrogen and progesterone are usually low, which can contribute to cramps, lower energy, headaches, or mood changes for some people. "
                f"{phase_context} Severe pain, very heavy bleeding, fainting, or fever are worth medical attention."
            ).strip()

        if self._is_cycle_timing_question(text):
            if prediction:
                flags = prediction.warning_flags or []
                flag_note = f" Note: {'; '.join(str(f) for f in flags[:2])}." if flags else ""
                signal_note = self._prediction_signal_note(prediction.contributing_signals or [])
                next_period = prediction.next_period_estimate.get("date")
                range_days = prediction.next_period_estimate.get("range_days")
                range_note = f" give or take about {range_days} days" if range_days else ""
                if "next cycle" in text:
                    timing_intro = (
                        "Your next cycle starts when your next period begins. "
                        f"Based on your latest Vyla prediction, that is estimated around {next_period or 'your next predicted period'}{range_note}."
                    )
                else:
                    timing_intro = (
                        f"Based on your latest Vyla prediction, your next period is estimated around {next_period or 'the next predicted date'}{range_note}."
                    )
                return (
                    f"{timing_intro} Your current predicted phase is {prediction.current_phase} "
                    f"at {round(prediction.confidence * 100)}% confidence.{flag_note}{signal_note} "
                    f"Your fertile window is {prediction.fertile_window.get('start')} to {prediction.fertile_window.get('end')}, "
                    "which helps explain how Vyla is timing the estimate.\n\n"
                    "Useful follow-up questions you can ask me:\n"
                    "- Why did my cycle estimate change?\n"
                    "- What phase am I in today?\n"
                    "- How accurate is this prediction?\n"
                    "- What should I log to make the next estimate better?"
                )
            if active_cycle and cycle_day and phase:
                history_note = ""
                if past_cycles:
                    lengths = [c.cycle_length_days for c in past_cycles if c.cycle_length_days]
                    if lengths:
                        avg_len = round(mean(lengths), 1)
                        history_note = f" Based on your last {len(lengths)} cycles, your average cycle is {avg_len} days."
                signal_notes = self._ovulation_signal_notes(
                    latest_lh=latest_lh,
                    latest_mucus=latest_mucus,
                    temp_readings=temp_readings,
                )
                signal_note = f" Your ovulation-related logs show: {'; '.join(signal_notes)}." if signal_notes else ""
                next_start = active_cycle.period_start_date + timedelta(days=active_cycle.cycle_length_days or 28)
                timing_note = ""
                if "next cycle" in text or "next period" in text:
                    timing_note = (
                        f" Using your current cycle start and a {active_cycle.cycle_length_days or 28}-day cycle assumption, "
                        f"your next cycle/period would be around {next_start.isoformat()}."
                    )
                return (
                    f"Your active cycle started on {active_cycle.period_start_date.isoformat()}, "
                    f"putting you at cycle day {cycle_day} — which fits the {phase} phase.{history_note} "
                    f"{timing_note}{signal_note} "
                    f"Logging LH tests, cervical mucus, and temperature trends over a few days helps Vyla give you a more precise estimate."
                )

        if any(term in text for term in {"temperature", "bbt"}):
            if temp_readings:
                latest = temp_readings[-1]
                recent_7 = temp_readings[-min(len(temp_readings), 7):]
                avg = mean((item.delta or item.value) for item in recent_7)
                trend = self._simple_trend([float(item.delta or item.value) for item in recent_7])
                trend_note = f" Your 7-day trend is {trend}." if trend else ""
                phase_note = f" You are in your {phase} phase (day {cycle_day})." if phase else ""
                return (
                    f"You have {len(temp_readings)} recent temperature readings.{phase_note} "
                    f"Your latest delta is {round(latest.delta or latest.value, 2)}°C "
                    f"on {latest.recorded_at.date().isoformat()}, and your 7-reading average is {round(avg, 2)}°C.{trend_note} "
                    f"A temperature rise of 0.2–0.5°C above your baseline typically signals ovulation has occurred."
                )

        if any(term in text for term in {"tired", "fatigue", "exhausted", "low energy", "sleepy"}):
            pieces: list[str] = []
            if cycle_day and phase:
                pieces.append(
                    f"you are on cycle day {cycle_day} ({phase} phase), where energy naturally shifts with hormonal changes"
                )
            if sleep_readings:
                latest_sleep = sleep_readings[-1]
                avg_sleep = mean(item.value for item in sleep_readings[-min(len(sleep_readings), 7):])
                gap = round(latest_sleep.value - avg_sleep)
                direction = "below" if gap < 0 else "above"
                pieces.append(
                    f"your latest sleep was {round(latest_sleep.value)} minutes — {abs(gap)} minutes {direction} your recent average"
                )
            if hrv_readings:
                latest_hrv = hrv_readings[-1]
                avg_hrv = mean(item.value for item in hrv_readings[-min(len(hrv_readings), 7):])
                hrv_note = "lower than usual (may indicate incomplete recovery)" if latest_hrv.value < avg_hrv * 0.9 else "within normal range"
                pieces.append(f"your latest HRV is {round(latest_hrv.value, 1)} ms — {hrv_note}")
            if rhr_readings:
                pieces.append(f"your resting heart rate is {round(rhr_readings[-1].value, 1)} bpm")
            if stress_readings:
                pieces.append(f"your latest stress score is {round(stress_readings[-1].score, 1)}")
            if pieces:
                return (
                    "Your fatigue may be connected to a mix of your cycle phase, sleep quality, and recovery signals. "
                    f"Here is what your Vyla data shows: {'; '.join(pieces)}. "
                    "Prioritizing sleep, staying hydrated, eating balanced meals, and gentle movement often helps during this phase. "
                    "Please speak with a healthcare professional if fatigue is sudden, severe, persistent, or accompanied by fainting, chest pain, fever, or heavy bleeding."
                )

        if any(term in text for term in {"mood", "anxious", "anxiety", "sad", "depressed", "irritable", "emotional"}):
            mood_pieces: list[str] = []
            if cycle_day and phase:
                if phase == "luteal":
                    mood_pieces.append(
                        f"you are in your luteal phase (day {cycle_day}), when progesterone is dominant — this is the most common time for mood changes, low mood, and anxiety"
                    )
                elif phase == "menstrual":
                    mood_pieces.append(
                        f"you are in your menstrual phase (day {cycle_day}), when estrogen and progesterone are at their lowest — this can lower mood and energy"
                    )
                else:
                    mood_pieces.append(f"you are on cycle day {cycle_day} ({phase} phase)")
            if stress_readings:
                mood_pieces.append(f"your recent stress score is {round(stress_readings[-1].score, 1)}")
            if sleep_readings:
                mood_pieces.append(f"your recent sleep was {round(sleep_readings[-1].value)} minutes")
            mood_logs = [log for log in logs if log.log_type == LogType.SYMPTOM and any(
                m in (log.payload or {}).get("symptoms", []) for m in ["mood swings", "anxiety", "low mood"]
            )]
            if mood_logs:
                mood_pieces.append(f"you have logged {len(mood_logs)} mood-related entries recently")
            if mood_pieces:
                return (
                    "Mood changes are very commonly linked to your cycle. "
                    f"From your Vyla data: {'; '.join(mood_pieces)}. "
                    "Tracking your mood alongside your cycle over a few months can reveal clear patterns. "
                    "If mood symptoms are severe, persistent, or affecting daily life, it may really help to speak with a healthcare professional — this is always worth taking seriously."
                )

        if any(term in text for term in {"symptom", "cramp", "bloating", "pain", "bleeding", "spotting", "discharge"}):
            symptom_logs = [log for log in logs if log.log_type == LogType.SYMPTOM]
            if symptom_logs:
                latest = symptom_logs[-1].payload
                phase_note = f" You are in your {phase} phase (day {cycle_day}), which can influence symptom patterns." if phase else ""
                history_note = ""
                if past_cycles:
                    history_note = f" You have {len(past_cycles)} past cycles on record, which helps Vyla understand your baseline."
                return (
                    f"Your most recent logged symptoms are {', '.join(latest.get('symptoms', [])) or 'unspecified'} "
                    f"(recorded {symptom_logs[-1].log_date.isoformat()}, severity: {latest.get('severity') or 'not specified'}).{phase_note}{history_note} "
                    f"If pain is severe, bleeding is heavier than usual, or symptoms feel different from your normal pattern, "
                    f"it is worth speaking with a healthcare professional."
                )

        profile_context = self._human_profile_context(profile)
        if profile_context:
            return (
                f"I can see this in your saved Vyla health profile: {profile_context}. "
                "I do not have enough recent cycle, symptom, or wearable data to connect your question to a specific pattern yet. "
                "Logging your latest period start date, symptoms, temperature, LH tests, cervical mucus, sleep, or recovery data will help Vyla give you much more personalized insights."
            )

        return (
            "I can help with this. Your Vyla account currently has limited logged data for a fully personalized answer. "
            "The most useful next steps would be logging your last period start date, any recent symptoms, "
            "and connecting a wearable for sleep and recovery signals. "
            "Even a few days of data makes a big difference in the quality of insights I can give you.\n\n"
            "Useful follow-up questions you can ask me:\n"
            "- What symptoms should I watch for?\n"
            "- When should I speak to a doctor?\n"
            "- How could this relate to my cycle?\n"
            "- What should I log in Vyla to make this more personalised?"
        )

    def _general_health_answer(self, *, message: str, context: dict[str, Any]) -> str | None:
        text = message.lower()
        if any(term in text for term in {"fibroid", "fibroids"}):
            return self._deterministic_educational_answer(message=message, context=context)
        if "pcos" in text and any(
            term in text
            for term in {
                "fast",
                "fasting",
                "intermittent",
                "once a day",
                "one meal",
                "omad",
                "eat once",
                "eating",
                "diet",
                "food",
                "meal",
            }
        ):
            return self._pcos_fasting_answer(context=context)
        return None

    def _pcos_fasting_answer(self, *, context: dict[str, Any]) -> str:
        profile_note = self._human_profile_context(context["profile"])
        personal_note = f"\n\nFrom your Vyla profile, I can see: {profile_note}." if profile_note else ""
        return (
            "For PCOS, fasting can work for some people, but eating only once a day by 4pm is often too restrictive and may backfire.\n\n"
            "PCOS is commonly linked with insulin resistance, which means the body may struggle to manage blood sugar and insulin smoothly. "
            "Long fasts or one-meal-a-day patterns can sometimes improve calorie control, but they can also trigger cravings, low energy, headaches, binge eating later, poorer sleep, and more stress-hormone output. "
            "Those effects can make PCOS symptoms harder to manage for some people.\n\n"
            "A more PCOS-friendly approach is usually:\n"
            "- Eat enough protein with each meal, such as eggs, fish, chicken, tofu, beans, or Greek yoghurt\n"
            "- Pair carbohydrates with protein, fibre, and healthy fats to reduce glucose spikes\n"
            "- Choose high-fibre carbs like oats, beans, lentils, brown rice, fruit, and vegetables\n"
            "- Avoid very long fasts if they worsen cravings, dizziness, anxiety, sleep, or cycle irregularity\n"
            "- Consider a gentler eating window, such as 12:12 or 14:10, if fasting suits you\n\n"
            "If someone with PCOS wants to fast, I would usually suggest starting gently rather than jumping to one meal a day. "
            "For example, a balanced lunch and dinner within an earlier eating window is often more sustainable than eating once and trying to fit all nutrients into one meal.\n\n"
            "Do not fast without medical guidance if you are pregnant, trying to conceive with irregular cycles, have diabetes, take glucose-lowering medication such as metformin or insulin, have a history of eating disorder, or feel dizzy/faint when fasting.\n"
            f"{personal_note}\n\n"
            "Useful follow-up questions you can ask me:\n"
            "- What should a PCOS-friendly meal look like?\n"
            "- Is intermittent fasting safe with metformin?\n"
            "- What foods help insulin resistance in PCOS?\n"
            "- Can fasting affect ovulation or my period?"
        ).strip()

    def _is_cycle_timing_question(self, text: str) -> bool:
        return any(
            term in text
            for term in {
                "phase",
                "ovulation",
                "ovulat",
                "fertility",
                "fertile",
                "next period",
                "next cycle",
                "cycle start",
                "next bleed",
                "next bleeding",
                "next menstruation",
                "next menstrual",
                "ttc",
                "trying to conceive",
            }
        )

    def _prediction_signal_note(self, signals: list[Any]) -> str:
        available: list[str] = []
        unavailable: list[str] = []
        labels = {
            "temp": "temperature",
            "temperature": "temperature",
            "rhr": "resting heart rate",
            "hrv": "HRV",
            "lh": "LH tests",
            "mucus": "cervical mucus",
            "cycle_history": "cycle history",
            "period": "period logs",
        }
        for item in signals:
            if isinstance(item, dict):
                raw_signal = item.get("signal") or item.get("name") or item.get("type")
                if not raw_signal:
                    continue
                label = labels.get(str(raw_signal).lower(), str(raw_signal).replace("_", " "))
                if item.get("available") is False:
                    unavailable.append(label)
                else:
                    available.append(label)
            elif item:
                available.append(str(item).replace("_", " "))

        if available:
            return f" Vyla used {', '.join(available[:4])} for this estimate."
        if unavailable:
            return f" This estimate is mainly calendar-based because {', '.join(unavailable[:3])} data is not available yet."
        return ""


    def _deterministic_educational_answer(self, *, message: str, context: dict[str, Any]) -> str:
        text = message.lower()
        profile = context["profile"]
        conditions = self._safe_profile_conditions(dict(profile.conditions or {}))
        health_conditions = conditions.get("health_conditions") or conditions.get("medical_conditions") or []
        if isinstance(health_conditions, str):
            health_conditions = [health_conditions]
        health_conditions_lower = [str(c).lower() for c in health_conditions]

        def _user_has_condition(*keywords: str) -> bool:
            return any(any(kw in c for kw in keywords) for c in health_conditions_lower)

        def _personal_note(*keywords: str) -> str:
            if _user_has_condition(*keywords):
                safe_notes = ", ".join(str(item) for item in health_conditions if str(item).strip())
                if safe_notes:
                    return (
                        f" Your Vyla health profile also notes: {safe_notes}. "
                        "Vyla will take this into account when personalising your cycle insights."
                    )
                return " You have this noted in your Vyla health profile — Vyla will take this into account when personalising your cycle insights."
            return ""

        if any(term in text for term in {"fibroid", "fibroids"}):
            note = _personal_note("fibroid")
            return (
                "Fibroids are non-cancerous growths that develop in or around the uterus. "
                "They are made of muscle and fibrous tissue and can range from the size of a pea to a grapefruit — or larger. "
                "Fibroids are very common: up to 70–80% of women develop them by age 50, though many never cause symptoms.\n\n"
                "**Common symptoms** (when present):\n"
                "- Heavy or prolonged periods\n"
                "- Pelvic pressure or pain\n"
                "- Frequent urination or difficulty emptying the bladder\n"
                "- Lower back pain\n"
                "- Pain during sex\n"
                "- Bloating or a visibly enlarged abdomen\n\n"
                "**What causes them?** The exact cause is unknown, but oestrogen and progesterone appear to encourage fibroid growth — which is why they often shrink after menopause.\n\n"
                "Other factors that may increase the chance of fibroids include family history, age, earlier first period, vitamin D deficiency, obesity, and higher lifetime exposure to oestrogen. "
                "Fibroids are also more common and often develop earlier in Black women. Having these risk factors does not mean someone caused their fibroids — they are common and not anyone's fault.\n\n"
                "**Do they affect fertility?** Most fibroids do not affect the ability to get pregnant. However, some types or positions within the uterus may interfere with implantation or increase miscarriage risk.\n\n"
                "**When to speak to a doctor:** If you are experiencing very heavy periods, significant pelvic pain, bladder pressure, or any sudden change in symptoms, it is worth a medical evaluation. "
                "Fibroids can be monitored, managed with medication, or treated with procedures depending on severity and your personal goals.\n\n"
                "**Useful follow-up questions you can ask me:**\n"
                "- What symptoms can fibroids cause?\n"
                "- Can fibroids affect fertility or pregnancy?\n"
                "- How are fibroids diagnosed?\n"
                "- What treatments are available for fibroids?\n"
                "- When should heavy bleeding be checked urgently?"
                f"{note}"
            ).strip()

        if any(term in text for term in {"pcos", "polycystic"}):
            note = _personal_note("pcos", "polycystic")
            return (
                "PCOS (Polycystic Ovary Syndrome) is a hormonal condition that affects how the ovaries work. "
                "It is one of the most common causes of irregular periods and fertility challenges in women of reproductive age.\n\n"
                "**The three main features** (you usually need at least two for a diagnosis):\n"
                "1. Irregular or absent periods — caused by infrequent or absent ovulation\n"
                "2. Elevated androgens (male hormones) — which can cause acne, excess facial or body hair, or hair thinning on the scalp\n"
                "3. Polycystic-appearing ovaries on ultrasound — small fluid-filled follicles that haven't released an egg\n\n"
                "**Other common signs:**\n"
                "- Weight gain or difficulty losing weight\n"
                "- Fatigue and mood changes\n"
                "- Insulin resistance (making blood sugar harder to regulate)\n"
                "- Darker skin patches (acanthosis nigricans)\n\n"
                "**What causes PCOS?** The exact cause is not fully understood, but insulin resistance and genetics are thought to play a significant role.\n\n"
                "**Is it curable?** PCOS cannot be cured, but symptoms are very manageable. Lifestyle changes (diet, exercise, stress management), hormonal contraception, and medications like metformin or letrozole can significantly improve symptoms and fertility outcomes.\n\n"
                "**When to seek help:** If your periods are very irregular (fewer than 8 per year), you are struggling to conceive, or you are experiencing distressing symptoms, speak with a GP or gynaecologist."
                f"{note}"
            ).strip()

        if any(term in text for term in {"endometriosis", "endo "}):
            note = _personal_note("endometriosis", "endo")
            return (
                "Endometriosis is a chronic condition where tissue similar to the lining of the uterus (the endometrium) grows outside the uterus — "
                "commonly on the ovaries, fallopian tubes, or pelvic lining. "
                "Like the uterine lining, this tissue responds to hormonal changes each cycle, thickening and breaking down — but with nowhere to go, it can cause inflammation, scar tissue (adhesions), and cysts.\n\n"
                "**Common symptoms:**\n"
                "- Painful periods, often severe (dysmenorrhea)\n"
                "- Pelvic pain — can be chronic, not just during periods\n"
                "- Pain during or after sex\n"
                "- Pain with bowel movements or urination (especially during a period)\n"
                "- Heavy periods or spotting between periods\n"
                "- Fatigue\n"
                "- Difficulty getting pregnant (affects around 30–50% of those with endometriosis)\n\n"
                "**Why is it often diagnosed late?** Symptoms can be dismissed as 'normal' period pain. "
                "On average, it takes 7–10 years to receive a diagnosis. If your pain is severe or limiting daily life, advocate for specialist evaluation.\n\n"
                "**Management options:** Hormonal treatments (the pill, Mirena IUD, GnRH agonists), pain management, laparoscopic surgery to remove lesions, and lifestyle support. "
                "There is currently no cure, but treatment can significantly improve quality of life.\n\n"
                "**When to seek help:** Severe period pain that is not controlled by over-the-counter medication, worsening pelvic pain, or concerns about fertility warrant a specialist referral."
                f"{note}"
            ).strip()

        if "adenomyosis" in text:
            note = _personal_note("adenomyosis")
            return (
                "Adenomyosis is a condition where the tissue that normally lines the uterus (endometrium) grows into the muscular wall of the uterus (myometrium). "
                "This causes the uterine wall to thicken, which can make periods heavier, longer, and more painful.\n\n"
                "**Common symptoms:**\n"
                "- Heavy, prolonged periods\n"
                "- Severe menstrual cramps that worsen with age\n"
                "- Chronic pelvic pain or pressure\n"
                "- Bloating or a feeling of fullness in the lower abdomen\n"
                "- An enlarged uterus\n"
                "- Pain during sex\n\n"
                "**How is it different from endometriosis?** In endometriosis, tissue grows *outside* the uterus. In adenomyosis, it grows *within* the uterine wall. "
                "Some people have both conditions simultaneously.\n\n"
                "**Who is affected?** Adenomyosis most commonly affects people in their 40s and 50s, though it can occur at any reproductive age. "
                "It often improves after menopause when oestrogen levels drop.\n\n"
                "**Management:** Hormonal treatments (IUD, pill, GnRH agonists) can reduce symptoms significantly. "
                "In severe cases, a hysterectomy is the only definitive cure.\n\n"
                "**When to seek help:** If periods are becoming significantly heavier, more painful, or affecting your quality of life, speak with a gynaecologist."
                f"{note}"
            ).strip()

        if "perimenopause" in text:
            note = _personal_note("perimenopause", "peri")
            active_cycle = context["active_cycle"]
            age_note = ""
            if profile.date_of_birth:
                age = (datetime.now(UTC).date() - profile.date_of_birth).days // 365
                if age:
                    age_note = f" At {age}, you are in an age range where perimenopause is {('possible' if age >= 40 else 'less common but not impossible')}."
            return (
                "Perimenopause is the transitional period leading up to menopause — the time when the ovaries gradually begin producing less oestrogen. "
                "It typically starts in the mid-40s, though it can begin in the late 30s for some people, and usually lasts between 4 and 10 years.\n\n"
                "**Common signs:**\n"
                "- Irregular periods — cycles may become shorter, longer, heavier, lighter, or unpredictable\n"
                "- Hot flushes and night sweats\n"
                "- Sleep disturbances\n"
                "- Mood changes: anxiety, low mood, irritability\n"
                "- Brain fog and difficulty concentrating\n"
                "- Vaginal dryness\n"
                "- Reduced libido\n"
                "- Changes in skin and hair\n"
                "- Joint aches\n\n"
                "**When does it officially end?** Perimenopause ends when you have gone 12 consecutive months without a period — at that point, you have reached menopause.\n\n"
                "**How is it managed?** HRT (hormone replacement therapy), lifestyle changes, and symptom-specific treatments can significantly improve quality of life. "
                "Speak with a GP or menopause specialist for personalised guidance."
                f"{age_note}{note}"
            ).strip()

        if "menopause" in text:
            note = _personal_note("menopause")
            age_note = ""
            if profile.date_of_birth:
                age = (datetime.now(UTC).date() - profile.date_of_birth).days // 365
                if age:
                    age_note = f" At {age}, {'menopause may be approaching or recent' if age >= 45 else 'early menopause is less common but possible — a GP can investigate if you have concerns'}."
            return (
                "Menopause is a natural biological stage in a woman's life when the ovaries stop producing eggs and oestrogen levels decline significantly. "
                "It is confirmed when you have had no menstrual period for 12 consecutive months. "
                "The average age in the UK is 51, though anywhere between 45 and 55 is considered typical.\n\n"
                "**Common symptoms:**\n"
                "- Hot flushes and night sweats\n"
                "- Sleep disruption\n"
                "- Mood changes and anxiety\n"
                "- Brain fog\n"
                "- Vaginal dryness and discomfort\n"
                "- Reduced sex drive\n"
                "- Urinary symptoms (urgency or increased infections)\n"
                "- Joint pain and fatigue\n\n"
                "**Long-term health effects:** Lower oestrogen after menopause can affect bone density (increasing osteoporosis risk) and cardiovascular health. "
                "Regular health checks become especially important.\n\n"
                "**What helps?** HRT is the most effective treatment for menopausal symptoms and also protects bone and heart health for many people. "
                "Lifestyle factors — diet rich in calcium and vitamin D, weight-bearing exercise, not smoking — are also important. "
                "Speak with a GP or menopause specialist to discuss the options best suited to you."
                f"{age_note}{note}"
            ).strip()

        if any(term in text for term in {"pmdd", "premenstrual dysphoric"}):
            note = _personal_note("pmdd", "premenstrual dysphoric")
            return (
                "PMDD (Premenstrual Dysphoric Disorder) is a severe form of PMS that significantly impacts mood, behaviour, and daily functioning in the days leading up to a period.\n\n"
                "Unlike standard PMS, PMDD causes psychiatric and emotional symptoms that are intense enough to disrupt relationships, work, and quality of life. "
                "It is believed to be related to an abnormal sensitivity to normal hormonal fluctuations in the luteal phase of the cycle (after ovulation and before a period).\n\n"
                "**Core symptoms** (usually appearing 1–2 weeks before a period and improving within a few days of it starting):\n"
                "- Severe depression, feelings of hopelessness, or self-critical thoughts\n"
                "- Intense anxiety or tension\n"
                "- Marked irritability or anger\n"
                "- Sudden mood swings\n"
                "- Difficulty concentrating\n"
                "- Withdrawal from relationships and social activities\n"
                "- Fatigue, sleep changes, appetite changes\n"
                "- Physical symptoms (bloating, breast tenderness, headache)\n\n"
                "**How is it diagnosed?** Typically by tracking symptoms across two or more cycles using a diary or app to confirm the cyclical pattern.\n\n"
                "**Treatment options:** SSRIs (antidepressants), hormonal treatments (combined pill, GnRH analogues), CBT (cognitive behavioural therapy), and lifestyle approaches. "
                "PMDD is a recognised medical condition — you do not need to manage it alone.\n\n"
                "**When to seek help:** If symptoms are significantly affecting your ability to function, relationships, or you are having thoughts of self-harm, please speak with a GP or mental health professional promptly."
                f"{note}"
            ).strip()

        if any(term in text for term in {"pms", "premenstrual syndrome"}):
            note = _personal_note("pms", "premenstrual")
            return (
                "PMS (Premenstrual Syndrome) refers to a range of physical and emotional symptoms that occur in the days or weeks before a period, "
                "then typically improve once menstruation begins. "
                "It is very common — up to 3 in 4 women experience some form of PMS during their reproductive years.\n\n"
                "**Common PMS symptoms:**\n"
                "*Emotional & behavioural:* mood swings, irritability, anxiety, low mood, feeling emotional or tearful, difficulty concentrating, fatigue\n"
                "*Physical:* bloating, breast tenderness, headaches, joint or muscle aches, food cravings, acne, sleep changes\n\n"
                "**What causes PMS?** The exact cause is not fully understood, but it is linked to hormonal fluctuations — specifically the drop in oestrogen and progesterone — "
                "in the luteal phase (after ovulation and before menstruation). Serotonin sensitivity may also play a role.\n\n"
                "**Management strategies:**\n"
                "- Regular exercise (reduces mood and physical symptoms)\n"
                "- Reducing salt, caffeine, and alcohol in the second half of your cycle\n"
                "- Consistent sleep\n"
                "- Calcium and vitamin B6 supplements (evidence-supported)\n"
                "- Hormonal contraception (can suppress symptoms for many)\n"
                "- SSRIs (for more severe mood symptoms)\n\n"
                "**When to seek help:** If PMS symptoms are severe, disrupt daily life, relationships, or work, or if you think you may have PMDD, speak with a healthcare professional."
                f"{note}"
            ).strip()

        return self._deterministic_answer(message=message, context=context)

    def _rough_cycle_phase(self, *, cycle_day: int, cycle_length: int | None) -> str:
        length = cycle_length or 28
        ovulation_day = max(10, length - 14)
        if cycle_day <= 5:
            return "menstrual"
        if cycle_day < ovulation_day - 2:
            return "follicular"
        if cycle_day <= ovulation_day + 1:
            return "ovulatory"
        return "luteal"

    def _ovulation_signal_notes(
        self,
        *,
        latest_lh: DailyLog | None,
        latest_mucus: DailyLog | None,
        temp_readings: list[SensorReading],
    ) -> list[str]:
        notes: list[str] = []
        if latest_lh:
            payload = latest_lh.payload or {}
            state = payload.get("state") or payload.get("result")
            positive = payload.get("positive")
            if positive is True or str(state or "").lower() in {"high", "peak", "positive"}:
                notes.append(f"your latest LH test on {latest_lh.log_date.isoformat()} was positive/high")
            elif state:
                notes.append(f"your latest LH test on {latest_lh.log_date.isoformat()} was {state}")
        if latest_mucus:
            payload = latest_mucus.payload or {}
            mucus_type = payload.get("type") or payload.get("state") or payload.get("description")
            score = payload.get("score")
            if mucus_type:
                notes.append(f"your latest cervical mucus on {latest_mucus.log_date.isoformat()} was {mucus_type}")
            elif score is not None:
                notes.append(f"your latest cervical mucus score was {score}")
        if len(temp_readings) >= 3:
            recent = [float(item.delta if item.delta is not None else item.value) for item in temp_readings[-3:]]
            if len(recent) == 3 and recent[-1] > recent[0]:
                notes.append("your recent temperature readings are rising, which can fit a post-ovulation pattern")
        return notes

    def _deterministic_context_summary(self, context: dict[str, Any]) -> str:
        parts: list[str] = []
        prediction: PredictionSnapshot | None = context["latest_prediction"]
        if prediction:
            parts.append(f"your latest phase is {prediction.current_phase} at {round(prediction.confidence * 100)}% confidence")
        if context["active_cycle"]:
            cycle_day = (datetime.now(UTC).date() - context["active_cycle"].period_start_date).days + 1
            phase = self._rough_cycle_phase(cycle_day=cycle_day, cycle_length=context["active_cycle"].cycle_length_days)
            parts.append(f"you are on cycle day {cycle_day} ({phase} phase)")
        if context["recent_temps"]:
            parts.append(f"you have {len(context['recent_temps'])} recent temperature readings")
        if context["recent_sleep"]:
            parts.append(f"you have {len(context['recent_sleep'])} recent sleep readings")
        return "; ".join(parts)

    def _apply_data_action(self, *, user_id: str, data_action: MedicalChatDataAction) -> list[str]:
        action = data_action.action
        payload = data_action.payload
        if action == "save_period_start":
            start_date = payload.get("start_date")
            if not start_date and payload.get("started_at"):
                start_date = datetime.fromisoformat(str(payload["started_at"]).replace("Z", "+00:00")).date().isoformat()
            if not start_date:
                raise MedicalChatError("save_period_start requires start_date or started_at")
            start_dt = date.fromisoformat(str(start_date))
            active = self.cycles.active_for_user(user_id)
            if active:
                active.is_active = False
                if active.period_end_date is None:
                    active.period_end_date = active.period_start_date
                    active.menses_length = 1
            new_cycle = CycleRecord(user_id=user_id, period_start_date=start_dt, is_active=True)
            self.db.add(new_cycle)
            self.db.flush()
            return [f"cycle.period_start:{new_cycle.id}"]

        if action == "save_temperature":
            records = payload.get("records")
            if not isinstance(records, list) or not records:
                raise MedicalChatError("save_temperature requires a records array")
            saved: list[str] = []
            for record in records:
                if "timestamp" not in record or "delta_c" not in record:
                    raise MedicalChatError("temperature records require timestamp and delta_c")
                reading = SensorReading(
                    user_id=user_id,
                    metric="wrist_temp",
                    value=float(record["delta_c"]),
                    delta=float(record["delta_c"]),
                    quality_score=float(record.get("sleep_quality_score", 1.0)),
                    source=str(record.get("source", "manual")),
                    recorded_at=datetime.fromisoformat(str(record["timestamp"]).replace("Z", "+00:00")),
                )
                self.db.add(reading)
                self.db.flush()
                saved.append(f"sensor.temperature:{reading.id}")
            return saved

        cycle = self.cycles.active_for_user(user_id)
        if action in {"save_symptoms", "save_intimacy", "save_lh", "save_mucus"} and not cycle:
            raise MedicalChatError("Active cycle required before saving cycle logs")

        if action == "save_symptoms":
            log_date = date.fromisoformat(str(payload["log_date"]))
            log = DailyLog(
                user_id=user_id,
                cycle_id=cycle.id if cycle else None,
                log_date=log_date,
                log_type=LogType.SYMPTOM,
                payload={
                    "symptoms": payload.get("symptoms", []),
                    "severity": payload.get("severity"),
                    "notes": payload.get("notes"),
                    **dict(payload.get("metadata") or {}),
                },
            )
            self.db.add(log)
            self.db.flush()
            return [f"cycle.symptom:{log.id}"]

        if action == "save_intimacy":
            log_date = date.fromisoformat(str(payload["log_date"]))
            log = DailyLog(
                user_id=user_id,
                cycle_id=cycle.id if cycle else None,
                log_date=log_date,
                log_type=LogType.INTERCOURSE,
                payload={
                    "had_intimacy": bool(payload.get("had_intimacy", True)),
                    "protection_used": payload.get("protection_used"),
                    "ejaculation": payload.get("ejaculation"),
                    "partner_gender": payload.get("partner_gender"),
                    "notes": payload.get("notes"),
                    **dict(payload.get("metadata") or {}),
                },
            )
            self.db.add(log)
            self.db.flush()
            return [f"cycle.intimacy:{log.id}"]

        if action == "save_lh":
            log_date = date.fromisoformat(str(payload["log_date"]))
            log = DailyLog(
                user_id=user_id,
                cycle_id=cycle.id if cycle else None,
                log_date=log_date,
                log_type=LogType.LH,
                payload={
                    "state": payload.get("state"),
                    "raw_value": payload.get("raw_value"),
                    "ratio": payload.get("ratio"),
                    "positive": bool(payload.get("positive", False)),
                },
            )
            self.db.add(log)
            self.db.flush()
            return [f"cycle.lh:{log.id}"]

        if action == "save_mucus":
            log_date = date.fromisoformat(str(payload["log_date"]))
            log = DailyLog(
                user_id=user_id,
                cycle_id=cycle.id if cycle else None,
                log_date=log_date,
                log_type=LogType.MUCUS,
                payload={"score": payload.get("score")},
            )
            self.db.add(log)
            self.db.flush()
            return [f"cycle.mucus:{log.id}"]

        if action == "save_profile":
            profile = self.users.ensure_profile(user_id)
            if payload.get("date_of_birth"):
                profile.date_of_birth = date.fromisoformat(str(payload["date_of_birth"]))
            if payload.get("age_at_menarche") is not None:
                profile.age_at_menarche = int(payload["age_at_menarche"])
            if payload.get("timezone"):
                profile.timezone = str(payload["timezone"])
            if payload.get("conditions"):
                profile.conditions = dict(payload["conditions"])
            self.db.flush()
            return [f"profile:{profile.id}"]

        raise MedicalChatError(f"Unsupported data action: {action}")
