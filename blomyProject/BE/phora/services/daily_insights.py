from __future__ import annotations

import json
from datetime import UTC, date, datetime
from typing import Any

import httpx
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import DailyInsight
from phora.repositories.core import DailyInsightRepository, UserRepository


class DailyInsightService:
    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings
        self.users = UserRepository(db)
        self.insights = DailyInsightRepository(db)

    def get_or_generate(
        self,
        *,
        user_id: str,
        insight_date: date,
        phase: str | None,
        cycle_day: int | None = None,
        force: bool = False,
    ) -> DailyInsight:
        existing = self.insights.by_user_and_date(user_id, insight_date)
        if existing and not force:
            return existing
        return self.generate(
            user_id=user_id,
            insight_date=insight_date,
            phase=phase,
            cycle_day=cycle_day,
            existing=existing,
        )

    def generate(
        self,
        *,
        user_id: str,
        insight_date: date,
        phase: str | None,
        cycle_day: int | None = None,
        existing: DailyInsight | None = None,
    ) -> DailyInsight:
        profile = self.users.ensure_profile(user_id)
        normalized_phase = _normalize_phase(phase)
        deterministic = self._rules_payload(
            phase=normalized_phase,
            cycle_day=cycle_day,
            height_cm=profile.height_cm,
            weight_kg=profile.weight_kg,
            bmi=profile.bmi,
        )
        anonymized_context = self._anonymized_context(
            phase=normalized_phase,
            cycle_day=cycle_day,
            height_cm=profile.height_cm,
            weight_kg=profile.weight_kg,
            bmi=profile.bmi,
        )
        llm_payload = self._llm_payload(anonymized_context)
        payload = {**deterministic, **(llm_payload or {})}
        source = "openai_anonymized" if llm_payload else "rules"

        record = existing or DailyInsight(user_id=user_id, insight_date=insight_date)
        record.phase = normalized_phase
        record.source = source
        record.payload = payload
        record.anonymized_context = anonymized_context
        record.updated_at = datetime.now(UTC)
        self.insights.save(record)
        self.db.commit()
        self.db.refresh(record)
        return record

    def _rules_payload(
        self,
        *,
        phase: str | None,
        cycle_day: int | None,
        height_cm: float | None,
        weight_kg: float | None,
        bmi: float | None,
    ) -> dict[str, Any]:
        phase_payloads: dict[str, dict[str, Any]] = {
            "menstrual": {
                "title": "Recovery support today",
                "message": "Choose gentle movement and iron-rich, warming meals while your body is on your period.",
                "nutrition_recommendation": "Prioritize iron, magnesium, hydration, and warm balanced meals.",
                "activity_recommendation": "Keep movement gentle unless your energy feels strong.",
                "foods_to_eat": ["lentils", "spinach", "eggs", "ginger tea", "dark chocolate"],
                "workout_exercises": ["easy walk", "mobility flow", "restorative yoga", "light stretching"],
                "tags": ["menstrual", "recovery", "nutrition"],
            },
            "follicular": {
                "title": "Build energy today",
                "message": "Follicular days often support progressive workouts and protein-rich meals.",
                "nutrition_recommendation": "Use protein, colorful carbohydrates, and fermented foods to support training output.",
                "activity_recommendation": "A moderate to challenging workout can fit if sleep and symptoms are normal.",
                "foods_to_eat": ["Greek yogurt", "berries", "oats", "chicken", "beans"],
                "workout_exercises": ["strength training", "interval cardio", "Pilates", "brisk walk"],
                "tags": ["follicular", "energy", "strength"],
            },
            "ovulation": {
                "title": "Peak energy window",
                "message": "Ovulation can be a good time for power, strength, and antioxidant-rich meals.",
                "nutrition_recommendation": "Prioritize antioxidants, lean protein, and hydration.",
                "activity_recommendation": "Strength, cardio, or athletic work may fit if joints feel stable.",
                "foods_to_eat": ["salmon", "berries", "avocado", "leafy greens", "pumpkin seeds"],
                "workout_exercises": ["strength training", "dance cardio", "cycling", "moderate HIIT"],
                "tags": ["ovulation", "energy", "fertility"],
            },
            "luteal": {
                "title": "Steady support today",
                "message": "Luteal days often benefit from steady meals, lower stress, and sustainable movement.",
                "nutrition_recommendation": "Choose magnesium-rich foods, complex carbs, and steady protein.",
                "activity_recommendation": "Use moderate strength, walking, or mobility with extra recovery room.",
                "foods_to_eat": ["sweet potato", "banana", "nuts", "eggs", "brown rice"],
                "workout_exercises": ["moderate strength", "incline walk", "yoga", "mobility"],
                "tags": ["luteal", "steady_energy", "recovery"],
            },
        }
        payload = dict(phase_payloads.get(phase or "", phase_payloads["luteal"]))
        basis = ["cycle_phase"]
        if cycle_day is not None:
            basis.append("cycle_day")
        if height_cm and weight_kg and bmi:
            basis.extend(["height", "weight", "bmi"])
            if bmi < 18.5:
                payload["nutrition_recommendation"] += " Add energy-dense snacks if your appetite allows."
                payload["foods_to_eat"] = [*payload["foods_to_eat"], "nut butter", "smoothies"]
                payload["activity_recommendation"] = "Favor strength, mobility, and adequate fueling over aggressive calorie burn."
            elif bmi >= 30:
                payload["activity_recommendation"] = "Favor joint-friendly cardio, strength, and gradual intensity progression."
                payload["workout_exercises"] = [*payload["workout_exercises"], "swimming", "low-impact cycling"]
            elif bmi >= 25:
                payload["activity_recommendation"] = "Combine strength with low-impact cardio and recovery-aware pacing."
        payload["personalization_basis"] = basis
        payload["generated_at"] = datetime.now(UTC).isoformat()
        return payload

    def _anonymized_context(
        self,
        *,
        phase: str | None,
        cycle_day: int | None,
        height_cm: float | None,
        weight_kg: float | None,
        bmi: float | None,
    ) -> dict[str, Any]:
        return {
            "cycle_phase": phase,
            "cycle_day_bucket": _bucket_number(cycle_day, [(5, "1-5"), (14, "6-14"), (21, "15-21")], "22+"),
            "bmi_category": _bmi_category(bmi),
            "height_bucket_cm": _bucket_number(height_cm, [(155, "<=155"), (170, "156-170"), (185, "171-185")], "186+"),
            "weight_bucket_kg": _bucket_number(weight_kg, [(55, "<=55"), (70, "56-70"), (90, "71-90")], "91+"),
        }

    def _llm_payload(self, anonymized_context: dict[str, Any]) -> dict[str, Any] | None:
        if not self.settings.llm_api_key:
            return None
        messages = [
            {
                "role": "system",
                "content": (
                    "You create concise menstrual-cycle wellness suggestions. "
                    "Use only the anonymous context. Do not diagnose, prescribe, or mention weight loss. "
                    "Return strict JSON with keys: nutrition_recommendation, activity_recommendation, "
                    "foods_to_eat, workout_exercises. foods_to_eat and workout_exercises must be arrays of 3-6 short strings."
                ),
            },
            {"role": "user", "content": json.dumps(anonymized_context, sort_keys=True)},
        ]
        try:
            response = httpx.post(
                f"{self.settings.llm_base_url.rstrip('/')}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.settings.llm_api_key}",
                    "Content-Type": "application/json",
                },
                json={"model": self.settings.llm_model, "messages": messages, "temperature": 0.2, "response_format": {"type": "json_object"}},
                timeout=self.settings.llm_timeout_seconds,
            )
            response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]
            parsed = json.loads(content)
        except (httpx.HTTPError, KeyError, IndexError, TypeError, json.JSONDecodeError):
            return None
        return {
            key: parsed[key]
            for key in ("nutrition_recommendation", "activity_recommendation", "foods_to_eat", "workout_exercises")
            if key in parsed
        }


def _normalize_phase(value: str | None) -> str | None:
    if value == "ovulatory":
        return "ovulation"
    return value


def _bmi_category(value: float | None) -> str | None:
    if value is None:
        return None
    if value < 18.5:
        return "below_18_5"
    if value < 25:
        return "18_5_to_24_9"
    if value < 30:
        return "25_to_29_9"
    return "30_plus"


def _bucket_number(value: float | int | None, buckets: list[tuple[float, str]], fallback: str) -> str | None:
    if value is None:
        return None
    for threshold, label in buckets:
        if value <= threshold:
            return label
    return fallback
