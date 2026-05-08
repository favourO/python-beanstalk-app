from __future__ import annotations

import json
import re
from datetime import UTC, date, datetime, timedelta
from statistics import mean
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import CycleRecord, DailyLog, MedicalChatMessage, MedicalChatThread, PredictionSnapshot, SensorReading
from phora.models.enums import LogType
from phora.repositories.core import AuditRepository, CycleRepository, PredictionRepository, SensorRepository, UserRepository
from phora.schemas.ai import (
    MedicalChatDataAction,
    MedicalChatHistoryItem,
    MedicalChatHistoryResponse,
    MedicalChatMissingData,
    MedicalChatResponse,
    MedicalChatThreadListResponse,
    MedicalChatThreadSummary,
)


class MedicalChatError(ValueError):
    pass


class MedicalChatService:
    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings
        self.users = UserRepository(db)
        self.cycles = CycleRepository(db)
        self.sensors = SensorRepository(db)
        self.predictions = PredictionRepository(db)
        self.audit = AuditRepository(db)

    def chat(
        self,
        *,
        user_id: str,
        message: str,
        thread_id: str | None = None,
        data_action: MedicalChatDataAction | None = None,
    ) -> MedicalChatResponse:
        normalized_message = message.strip()
        thread = self._get_or_create_thread(user_id=user_id, thread_id=thread_id, message=normalized_message)
        self._append_message(thread_id=thread.id, user_id=user_id, role="user", content=normalized_message)
        if not self._is_medical_question(normalized_message):
            answer = (
                "Vyla AI only answers reproductive and health-related questions. "
                "Ask about your cycle, symptoms, fertility, temperature, ovulation, or logged health data."
            )
            self._append_message(thread_id=thread.id, user_id=user_id, role="assistant", content=answer)
            self.db.commit()
            return MedicalChatResponse(thread_id=thread.id, answer=answer, sufficient_data=False, disclaimer=self.settings.medical_disclaimer)

        saved_records: list[str] = []
        extracted_actions = self._extract_actions_from_message(normalized_message)
        if data_action is not None:
            extracted_actions = [item for item in extracted_actions if item.action != data_action.action]
        for extracted_action in extracted_actions:
            saved_records.extend(self._apply_data_action(user_id=user_id, data_action=extracted_action))
        if data_action is not None:
            saved_records.extend(self._apply_data_action(user_id=user_id, data_action=data_action))

        context = self._build_context(user_id)
        missing = self._identify_missing_data(message=normalized_message, context=context)
        used_user_data = self._used_user_data(context)
        if missing:
            answer = self._build_missing_data_answer(message=normalized_message, context=context, missing=missing, saved_records=saved_records)
        else:
            answer = self._generate_answer(message=normalized_message, context=context, thread_id=thread.id)

        self._append_message(thread_id=thread.id, user_id=user_id, role="assistant", content=answer)

        response = MedicalChatResponse(
            thread_id=thread.id,
            answer=answer,
            sufficient_data=not missing,
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
                "message": normalized_message,
                "sufficient_data": response.sufficient_data,
                "saved_records": saved_records,
                "missing_actions": [item.action for item in missing],
            },
        )
        self.db.commit()
        return response

    def latest_thread_history(self, *, user_id: str) -> MedicalChatHistoryResponse:
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
        messages = self._recent_thread_messages(thread_id=thread.id, limit=100)
        return MedicalChatHistoryResponse(
            thread_id=thread.id,
            messages=[
                MedicalChatHistoryItem(
                    role=item.role,
                    content=item.content,
                    created_at=item.created_at.isoformat() if item.created_at else None,
                )
                for item in messages
            ],
        )

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
        limit: int = 100,
    ) -> MedicalChatHistoryResponse:
        thread = self.db.scalar(
            select(MedicalChatThread).where(
                MedicalChatThread.id == thread_id,
                MedicalChatThread.user_id == user_id,
            )
        )
        if not thread:
            raise MedicalChatError("Medical chat thread not found")
        messages = self._recent_thread_messages(thread_id=thread.id, limit=limit)
        return MedicalChatHistoryResponse(
            thread_id=thread.id,
            messages=[
                MedicalChatHistoryItem(
                    role=item.role,
                    content=item.content,
                    created_at=item.created_at.isoformat() if item.created_at else None,
                )
                for item in messages
            ],
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

    def _recent_thread_messages(self, *, thread_id: str, limit: int = 8) -> list[MedicalChatMessage]:
        stmt = (
            select(MedicalChatMessage)
            .where(MedicalChatMessage.thread_id == thread_id)
            .order_by(MedicalChatMessage.created_at.desc())
            .limit(limit)
        )
        return list(reversed(list(self.db.scalars(stmt))))

    def _is_medical_question(self, message: str) -> bool:
        text = message.lower()
        keywords = {
            "cycle",
            "period",
            "ovulation",
            "ovulat",
            "fertility",
            "fertile",
            "menstrual",
            "symptom",
            "cramp",
            "bloating",
            "temperature",
            "lh",
            "mucus",
            "pregnancy",
            "bleeding",
            "spotting",
            "pcos",
            "endometriosis",
            "perimenopause",
            "intimacy",
            "sex",
            "intercourse",
            "pain",
            "discharge",
            "sleep",
            "stress",
            "health",
            "medical",
            "hormone",
        }
        return any(keyword in text for keyword in keywords)

    def _build_context(self, user_id: str) -> dict[str, Any]:
        user = self.users.by_id(user_id)
        profile = self.users.ensure_profile(user_id)
        active_cycle = self.cycles.active_for_user(user_id)
        recent_logs = self.cycles.recent_logs(user_id, days=60)
        recent_sleep = self.sensors.recent(user_id, "sleep_minutes", days=30)
        recent_steps = self.sensors.recent(user_id, "steps", days=30)
        recent_temps = self.sensors.recent(user_id, "wrist_temp", days=60)
        recent_rhr = self.sensors.recent(user_id, "rhr", days=30)
        recent_blood_oxygen_avg = self.sensors.recent(user_id, "blood_oxygen_avg", days=30)
        recent_blood_oxygen_min = self.sensors.recent(user_id, "blood_oxygen_min", days=30)
        recent_hrv = self.sensors.recent(user_id, "hrv", days=30)
        recent_stress = self.sensors.recent_stress(user_id, days=14)
        latest_prediction = self.predictions.latest_for_user(user_id)
        return {
            "user": user,
            "profile": profile,
            "active_cycle": active_cycle,
            "recent_logs": recent_logs,
            "recent_sleep": recent_sleep,
            "recent_steps": recent_steps,
            "recent_temps": recent_temps,
            "recent_rhr": recent_rhr,
            "recent_blood_oxygen_avg": recent_blood_oxygen_avg,
            "recent_blood_oxygen_min": recent_blood_oxygen_min,
            "recent_hrv": recent_hrv,
            "recent_stress": recent_stress,
            "latest_prediction": latest_prediction,
        }

    def _used_user_data(self, context: dict[str, Any]) -> list[str]:
        used: list[str] = []
        profile = context["profile"]
        if profile.date_of_birth or profile.age_band:
            used.append("profile.age")
        if profile.conditions:
            used.append("profile.conditions")
        if context["active_cycle"]:
            used.append("cycle.active")
        if context["recent_logs"]:
            used.append("cycle.logs")
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
        return used

    def _identify_missing_data(self, *, message: str, context: dict[str, Any]) -> list[MedicalChatMissingData]:
        text = message.lower()
        missing: list[MedicalChatMissingData] = []
        profile = context["profile"]
        active_cycle = context["active_cycle"]
        latest_prediction = context["latest_prediction"]
        symptom_logs = [log for log in context["recent_logs"] if log.log_type == LogType.SYMPTOM]
        intimacy_logs = [log for log in context["recent_logs"] if log.log_type == LogType.INTERCOURSE]

        if any(term in text for term in {"ovulation", "ovulat", "fertility", "fertile", "phase", "next period"}):
            if not active_cycle:
                missing.append(
                    MedicalChatMissingData(
                        action="save_period_start",
                        endpoint="POST /api/v1/cycle/period/start",
                        reason="Your current cycle has not been started yet.",
                        prompt="When did your last period start?",
                        payload_template={"start_date": "2026-04-06"},
                    )
                )
            if not context["recent_temps"] and "temperature" in text:
                missing.append(
                    MedicalChatMissingData(
                        action="save_temperature",
                        endpoint="POST /api/v1/sensor/ingest/temperature",
                        reason="There are no recent temperature logs to ground the answer.",
                        prompt="Please log at least one basal or wrist temperature reading.",
                        payload_template={"records": [{"timestamp": "2026-04-06T07:30:00Z", "delta_c": 0.14}]},
                    )
                )
            if active_cycle and not latest_prediction:
                # We can still answer from cycle day, so this is informational rather than blocking.
                pass

        if any(term in text for term in {"perimenopause", "age", "menopause"}):
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

        if any(term in text for term in {"symptom", "cramp", "bloating", "pain", "spotting", "bleeding"}):
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
        prefix = "I saved the information you just provided. " if saved_records else ""
        missing_prompts = " ".join(item.prompt for item in missing)
        return (
            f"{prefix}I can answer questions about your reproductive health using your logged Vyla data, "
            f"but I still need a bit more context before I can answer this safely. "
            f"{known_bits} {missing_prompts}"
        ).strip()

    def _generate_answer(self, *, message: str, context: dict[str, Any], thread_id: str) -> str:
        openai_answer = self._openai_answer(message=message, context=context, thread_id=thread_id)
        if openai_answer:
            return openai_answer
        return self._deterministic_answer(message=message, context=context)

    def _openai_answer(self, *, message: str, context: dict[str, Any], thread_id: str) -> str | None:
        if not self.settings.llm_api_key:
            return None
        prompt_context = self._serialize_context_for_model(context)
        history = self._recent_thread_messages(thread_id=thread_id)
        input_messages: list[dict[str, str]] = [
            {
                "role": "developer",
                "content": (
                    "You are Vyla AI, a medical-only reproductive health assistant. "
                    "Answer only reproductive or health questions. Use only the supplied user data context as your knowledge base. "
                    "Do not invent facts beyond the supplied context. If the user data is sparse, say so plainly. "
                    "Do not diagnose, prescribe, or claim certainty. "
                    "Ground every answer in the user's own records, cycle data, predictions, and wearable signals when available. "
                    "Keep the answer concise, supportive, and specific to the user."
                ),
            },
            {
                "role": "developer",
                "content": f"Grounding user data knowledge base:\n{prompt_context}",
            },
        ]
        for item in history:
            input_messages.append({"role": item.role, "content": item.content})
        body = {
            "model": self.settings.llm_model,
            "input": input_messages,
            "instructions": (
                "Base your answer on the supplied user data knowledge base and the conversation history. "
                "If the user's data does not support a firm answer, state the limitation clearly."
            ),
            "temperature": 0.2,
            "text": {"format": {"type": "text"}},
        }
        try:
            response = httpx.post(
                f"{self.settings.llm_base_url.rstrip('/')}/responses",
                headers={
                    "Authorization": f"Bearer {self.settings.llm_api_key}",
                    "Content-Type": "application/json",
                },
                json=body,
                timeout=self.settings.llm_timeout_seconds,
            )
            response.raise_for_status()
        except httpx.HTTPError:
            return None
        data = response.json()
        try:
            output = data["output"]
            for item in output:
                if item.get("type") != "message" or item.get("role") != "assistant":
                    continue
                for content_item in item.get("content", []):
                    if content_item.get("type") == "output_text":
                        text = (content_item.get("text") or "").strip()
                        if text:
                            return text
        except (KeyError, IndexError, TypeError, AttributeError):
            return None
        return None

    def _serialize_context_for_model(self, context: dict[str, Any]) -> str:
        profile = context["profile"]
        active_cycle = context["active_cycle"]
        latest_prediction = context["latest_prediction"]
        recent_logs: list[DailyLog] = context["recent_logs"]
        knowledge_base = {
            "profile": {
                "date_of_birth": profile.date_of_birth.isoformat() if profile.date_of_birth else None,
                "age_band": profile.age_band,
                "conditions": profile.conditions or {},
            },
            "active_cycle": None
            if not active_cycle
            else {
                "period_start_date": active_cycle.period_start_date.isoformat(),
                "cycle_length_days": active_cycle.cycle_length_days,
                "period_length_days": active_cycle.menses_length,
                "is_active": active_cycle.is_active,
            },
            "latest_prediction": None
            if not latest_prediction
            else {
                "generated_at": latest_prediction.generated_at.isoformat() if latest_prediction.generated_at else None,
                "current_phase": latest_prediction.current_phase,
                "confidence": latest_prediction.confidence,
                "fertile_window": latest_prediction.fertile_window or {},
                "ovulation_estimate": latest_prediction.ovulation_estimate or {},
                "next_period_estimate": latest_prediction.next_period_estimate or {},
                "audit": latest_prediction.audit or {},
            },
            "recent_logs": [self._serialize_log_entry(item) for item in recent_logs[-12:]],
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
        }
        return json.dumps(knowledge_base, default=str, ensure_ascii=True, indent=2)

    def _serialize_log_entry(self, log: DailyLog) -> dict[str, Any]:
        return {
            "date": log.log_date.isoformat() if log.log_date else None,
            "type": log.log_type.value if hasattr(log.log_type, "value") else str(log.log_type),
            "payload": log.payload or {},
        }

    def _sensor_summary(self, readings: list[SensorReading], *, value_label: str) -> dict[str, Any]:
        latest = readings[-1] if readings else None
        values = [float(item.value) for item in readings if item.value is not None]
        deltas = [float(item.delta) for item in readings if item.delta is not None]
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
            "average": round(mean(values), 2) if values else None,
            "average_delta": round(mean(deltas), 2) if deltas else None,
            "last_7": [
                {
                    "recorded_at": item.recorded_at.isoformat() if item.recorded_at else None,
                    value_label: item.value,
                    "delta": item.delta,
                }
                for item in readings[-7:]
            ],
        }

    def _stress_summary(self, readings) -> dict[str, Any]:
        values = [float(item.score) for item in readings if item.score is not None]
        latest = readings[-1] if readings else None
        return {
            "count": len(readings),
            "latest": None
            if not latest
            else {
                "recorded_at": latest.recorded_at.isoformat() if latest.recorded_at else None,
                "score": latest.score,
            },
            "average": round(mean(values), 2) if values else None,
            "last_7": [
                {
                    "recorded_at": item.recorded_at.isoformat() if item.recorded_at else None,
                    "score": item.score,
                }
                for item in readings[-7:]
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
            "nausea": {"nausea", "nauseous"},
            "fatigue": {"fatigue", "tired", "exhausted"},
            "spotting": {"spotting"},
            "bleeding": {"bleeding", "heavy bleeding"},
        }
        symptoms: list[str] = []
        for canonical, variants in symptom_map.items():
            if any(variant in text for variant in variants):
                symptoms.append(canonical)
        return symptoms

    def _extract_severity(self, text: str) -> str | None:
        if any(term in text for term in {"severe", "very bad", "intense"}):
            return "severe"
        if any(term in text for term in {"mild", "light"}):
            return "mild"
        if any(term in text for term in {"moderate", "medium"}):
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
        logs: list[DailyLog] = context["recent_logs"]
        profile = context["profile"]

        if any(term in text for term in {"phase", "ovulation", "fertility", "fertile", "next period"}):
            if prediction:
                return (
                    f"Based on your latest Vyla prediction, your current phase is {prediction.current_phase}. "
                    f"Model confidence is {round(prediction.confidence * 100)}%. "
                    f"The fertile window is {prediction.fertile_window.get('start')} to {prediction.fertile_window.get('end')}, "
                    f"and the next period estimate is {prediction.next_period_estimate.get('date')}."
                )
            if active_cycle:
                cycle_day = (datetime.now(UTC).date() - active_cycle.period_start_date).days + 1
                return (
                    f"You have an active cycle that started on {active_cycle.period_start_date.isoformat()}, "
                    f"which puts you around cycle day {cycle_day}. "
                    f"I do not have a saved prediction snapshot yet, so any phase estimate would be lower confidence."
                )

        if any(term in text for term in {"temperature", "bbt"}):
            if temp_readings:
                latest = temp_readings[-1]
                avg = mean((item.delta or item.value) for item in temp_readings[-min(len(temp_readings), 7):])
                return (
                    f"You have {len(temp_readings)} recent temperature readings. "
                    f"Your latest logged temperature delta is {round(latest.delta or latest.value, 2)}°C on "
                    f"{latest.recorded_at.date().isoformat()}, and your recent 7-reading average delta is {round(avg, 2)}°C."
                )

        if any(term in text for term in {"symptom", "cramp", "bloating", "pain", "bleeding", "spotting"}):
            symptom_logs = [log for log in logs if log.log_type == LogType.SYMPTOM]
            if symptom_logs:
                latest = symptom_logs[-1].payload
                return (
                    f"Your latest logged symptoms are {', '.join(latest.get('symptoms', [])) or 'unspecified symptoms'} "
                    f"on {symptom_logs[-1].log_date.isoformat()}. "
                    f"Severity was recorded as {latest.get('severity') or 'not specified'}."
                )

        conditions = profile.conditions or {}
        if conditions:
            return (
                f"Based on your saved profile, I can ground this in your logged health context: {conditions}. "
                f"I do not have enough structured cycle evidence to answer more specifically yet."
            )

        return (
            "I can answer reproductive and health questions using your Vyla logs, but your current account has limited structured data. "
            "Please log the relevant period, symptom, temperature, or profile information first."
        )

    def _deterministic_context_summary(self, context: dict[str, Any]) -> str:
        parts: list[str] = []
        prediction: PredictionSnapshot | None = context["latest_prediction"]
        if prediction:
            parts.append(f"Your latest saved phase is {prediction.current_phase} at {round(prediction.confidence * 100)}% confidence.")
        if context["active_cycle"]:
            parts.append(f"Your active cycle started on {context['active_cycle'].period_start_date.isoformat()}.")
        if context["recent_temps"]:
            parts.append(f"You have {len(context['recent_temps'])} recent temperature readings.")
        return " ".join(parts)

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
