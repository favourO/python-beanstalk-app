from __future__ import annotations

import json
import re
from typing import Any

from phora.core.config import Settings
from phora.schemas.daily_log import PeriodLogPayload, SymptomsLogPayload
from phora.services.ai_gateway import AIGateway


class PeriodLogAssistantService:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.ai_gateway = AIGateway(settings)

    def assist(
        self,
        *,
        message: str,
        current_period: PeriodLogPayload,
        current_symptoms: SymptomsLogPayload,
    ):
        heuristic = self._heuristic_extract(message)
        llm = self._llm_extract(message=message, current_period=current_period, current_symptoms=current_symptoms) or {}
        extracted = self._merge_dicts(heuristic, llm)

        period_data = current_period.model_dump(mode="json", exclude_none=True)
        symptoms_data = current_symptoms.model_dump(mode="json", exclude_none=True)

        intensity = self._normalize_intensity(extracted.get("intensity"))
        colour = self._normalize_colour(extracted.get("colour"))
        symptoms = [self._normalize_symptom(item) for item in extracted.get("symptoms", [])]
        symptoms = [item for item in symptoms if item is not None]
        notes = self._normalize_notes(extracted.get("notes"))

        if intensity:
            period_data["intensity"] = intensity
        if colour:
            period_data["colour"] = colour
        if symptoms:
            period_data["symptoms"] = self._dedupe([*period_data.get("symptoms", []), *symptoms])
            symptoms_data["physical"] = self._dedupe([*symptoms_data.get("physical", []), *symptoms])
        if notes:
            existing = (symptoms_data.get("notes") or "").strip()
            symptoms_data["notes"] = (existing + "\n" + notes).strip() if existing and notes.lower() not in existing.lower() else (existing or notes)

        period = PeriodLogPayload.model_validate(period_data)
        symptoms_payload = SymptomsLogPayload.model_validate(symptoms_data)
        next_step = self._next_step(period=period, symptoms=symptoms_payload)
        completed = next_step == "review"
        return {
            "assistant_message": self._assistant_message(period=period, symptoms=symptoms_payload, next_step=next_step),
            "next_step": next_step,
            "completed": completed,
            "period": period,
            "symptoms": symptoms_payload,
        }

    def _llm_extract(
        self,
        *,
        message: str,
        current_period: PeriodLogPayload,
        current_symptoms: SymptomsLogPayload,
    ) -> dict[str, Any] | None:
        if not self.ai_gateway.enabled:
            return None
        body = {
            "model": self.settings.llm_model,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "Extract menstrual period logging details from the user message. "
                        "Normalize intensity and colour to the allowed values. "
                        "Only include symptoms from the allowed set. "
                        "Use an empty string when a scalar field is not mentioned."
                    ),
                },
                {
                    "role": "user",
                    "content": json.dumps(
                        {
                            "message": message,
                            "current": {
                                "period": current_period.model_dump(mode="json", exclude_none=True),
                                "symptoms": current_symptoms.model_dump(mode="json", exclude_none=True),
                            },
                        }
                    ),
                },
            ],
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": "period_log_extract",
                    "strict": True,
                    "schema": {
                        "type": "object",
                        "properties": {
                            "intensity": {
                                "type": "string",
                                "enum": ["", "Spotting", "Light", "Medium", "Heavy"],
                            },
                            "colour": {
                                "type": "string",
                                "enum": ["", "Brown", "Red", "Dark", "Pink"],
                            },
                            "symptoms": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "enum": [
                                        "Cramps",
                                        "Bloating",
                                        "Headache",
                                        "Fatigue",
                                        "Back Pain",
                                        "Nausea",
                                        "Mood Swings",
                                        "Acne",
                                    ],
                                },
                            },
                            "notes": {"type": "string"},
                        },
                        "required": ["intensity", "colour", "symptoms", "notes"],
                        "additionalProperties": False,
                    },
                },
            },
            "temperature": 0,
        }
        try:
            data = self.ai_gateway.chat_completion(body)
            if not data:
                return None
            message_data = data["choices"][0]["message"]
            refusal = message_data.get("refusal")
            if refusal:
                return None
            content = message_data.get("content")
            if not isinstance(content, str) or not content.strip():
                return None
            parsed = json.loads(content)
            return parsed if isinstance(parsed, dict) else None
        except (KeyError, IndexError, TypeError, ValueError, json.JSONDecodeError):
            return None

    def _heuristic_extract(self, message: str) -> dict[str, Any]:
        text = message.lower().strip()
        symptoms: list[str] = []
        symptom_map = {
            "Cramps": ["cramp", "cramps", "cramping"],
            "Bloating": ["bloat", "bloated", "bloating"],
            "Headache": ["headache", "migraine"],
            "Fatigue": ["fatigue", "tired", "exhausted", "drained"],
            "Back Pain": ["back pain", "lower back"],
            "Nausea": ["nausea", "nauseous"],
            "Mood Swings": ["mood swing", "irritable", "moody"],
            "Acne": ["acne", "breakout", "pimple"],
        }
        for label, terms in symptom_map.items():
            if any(term in text for term in terms):
                symptoms.append(label)
        return {
            "intensity": self._first_match(
                text,
                {
                    "Spotting": ["spotting", "very light"],
                    "Light": ["light flow", "light bleeding", "light period", "light"],
                    "Medium": ["medium flow", "moderate flow", "normal flow", "medium"],
                    "Heavy": ["heavy flow", "heavy bleeding", "heavy", "flooding"],
                },
            ),
            "colour": self._first_match(
                text,
                {
                    "Brown": ["brown"],
                    "Dark": ["dark red", "blackish", "dark"],
                    "Red": ["bright red", "red"],
                    "Pink": ["pink"],
                },
            ),
            "symptoms": symptoms,
            "notes": self._maybe_note(message),
        }

    def _next_step(self, *, period: PeriodLogPayload, symptoms: SymptomsLogPayload) -> str:
        if not period.intensity:
            return "intensity"
        if not period.colour:
            return "colour"
        if not period.symptoms and not symptoms.physical:
            return "symptoms"
        if not (symptoms.notes or "").strip():
            return "notes"
        return "review"

    def _assistant_message(self, *, period: PeriodLogPayload, symptoms: SymptomsLogPayload, next_step: str) -> str:
        if next_step == "intensity":
            return "Let’s start with your period.\n\nWhat is your flow intensity today?"
        if next_step == "colour":
            return f"Got it. {(period.intensity or 'that').lower()} flow.\n\nWhat’s the flow colour?"
        if next_step == "symptoms":
            return "Thanks. Now, let’s log any period symptoms you’re experiencing.\n\nSelect all that apply."
        if next_step == "notes":
            if period.symptoms or symptoms.physical:
                joined = self._join_phrases(self._dedupe([*period.symptoms, *symptoms.physical]))
                return f"{joined}.\n\nAnything else you’d like to add about your period today?"
            return "Anything else you’d like to add about your period today?"
        return "Thanks! I’ve captured all the period details."

    def _first_match(self, text: str, options: dict[str, list[str]]) -> str:
        for label, phrases in options.items():
            if any(phrase in text for phrase in phrases):
                return label
        return ""

    def _merge_dicts(self, left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
        merged = dict(left)
        for key, value in right.items():
            if key == "symptoms":
                merged[key] = self._dedupe([*(left.get(key) or []), *(value or [])])
            elif isinstance(value, str) and value.strip():
                merged[key] = value.strip()
            elif value:
                merged[key] = value
        return merged

    def _normalize_intensity(self, value: Any) -> str | None:
        if not isinstance(value, str):
            return None
        normalized = value.strip().lower()
        return {
            "spotting": "Spotting",
            "light": "Light",
            "medium": "Medium",
            "moderate": "Medium",
            "heavy": "Heavy",
        }.get(normalized)

    def _normalize_colour(self, value: Any) -> str | None:
        if not isinstance(value, str):
            return None
        normalized = value.strip().lower()
        return {
            "brown": "Brown",
            "red": "Red",
            "dark": "Dark",
            "dark red": "Dark",
            "pink": "Pink",
        }.get(normalized)

    def _normalize_symptom(self, value: Any) -> str | None:
        if not isinstance(value, str):
            return None
        normalized = re.sub(r"\s+", " ", value.strip().lower())
        return {
            "cramps": "Cramps",
            "bloating": "Bloating",
            "headache": "Headache",
            "fatigue": "Fatigue",
            "back pain": "Back Pain",
            "nausea": "Nausea",
            "mood swings": "Mood Swings",
            "acne": "Acne",
        }.get(normalized)

    def _normalize_notes(self, value: Any) -> str | None:
        if not isinstance(value, str):
            return None
        note = value.strip()
        return note if note else None

    def _maybe_note(self, message: str) -> str:
        trimmed = " ".join(message.strip().split())
        if len(trimmed.split()) < 4:
            return ""
        return trimmed

    def _dedupe(self, values: list[str]) -> list[str]:
        seen: set[str] = set()
        deduped: list[str] = []
        for value in values:
            if value and value not in seen:
                seen.add(value)
                deduped.append(value)
        return deduped

    def _join_phrases(self, values: list[str]) -> str:
        if not values:
            return ""
        if len(values) == 1:
            return values[0]
        if len(values) == 2:
            return f"{values[0]} and {values[1]}"
        return f"{', '.join(values[:-1])}, and {values[-1]}"
