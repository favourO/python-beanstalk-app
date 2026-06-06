from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.core.metrics import PREDICTION_COUNTER
from phora.models import CycleRecord, PredictionSnapshot
from phora.repositories.core import AuditRepository, CycleRepository, PredictionRepository, SensorRepository, UserRepository
from phora.schemas.ml import MlEnsembleResponse, PredictionAudit
from phora.schemas.prediction import PredictionSnapshotResponse
from phora.services.age import POPULATION_PRIORS, age_band_label, build_age_context, derive_age_band
from phora.services.ml_client import MlClient
from phora.services.prediction_builder import PredictionInputBundle, build_ensemble_request

PREDICTION_INPUT_PIPELINE_VERSION = "wearable_daily_dedup_v2"


class PredictionService:
    def __init__(self, db: Session, settings: Settings, ml_client: MlClient):
        self.db = db
        self.settings = settings
        self.ml_client = ml_client
        self.users = UserRepository(db)
        self.cycles = CycleRepository(db)
        self.sensors = SensorRepository(db)
        self.predictions = PredictionRepository(db)
        self.audit = AuditRepository(db)

    @staticmethod
    def _derive_current_phase(
        cycle_day: int,
        *,
        ovulation_day: int | None,
        menses_length: int | None,
    ) -> str:
        bleed_days = max(1, menses_length or 5)
        if cycle_day <= bleed_days:
            return "menstrual"
        if ovulation_day is None:
            return "follicular"
        if abs(cycle_day - ovulation_day) <= 1:
            return "ovulatory"
        if cycle_day < ovulation_day:
            return "follicular"
        return "luteal"

    def _fallback_response(
        self,
        user_id: str,
        cycle_id: str,
        cycle_day: int,
        mu_cycle: float,
        pcos_flag: bool,
        menses_length: int | None,
    ) -> MlEnsembleResponse:
        estimate = max(1, int(round(mu_cycle - 14)))
        return MlEnsembleResponse(
            user_id=user_id,
            prediction_id=str(uuid4()),
            current_phase=self._derive_current_phase(
                cycle_day,
                ovulation_day=estimate,
                menses_length=menses_length,
            ),
            phase_distribution={"menstrual": 0.05, "follicular": 0.65, "ovulatory": 0.15, "luteal": 0.15},
            ovulation_estimate=estimate,
            confidence=0.35,
            confidence_explanation="Fallback generated from cycle priors because the ML service was unavailable.",
            warning_flags=["shadow_mode_fallback"],
            models_used=["calendar_fallback"],
            model_audits=[],
            audit=PredictionAudit(
                pcos_flag=pcos_flag,
                ovulation_estimate_source="calendar_fallback",
                rf_direct_threshold=None,
            ),
            generated_at=self._now_utc(),
        )

    def run_prediction(self, user_id: str) -> PredictionSnapshotResponse:
        profile = self.users.ensure_profile(user_id)
        cycle = self.cycles.active_for_user(user_id)
        if not cycle:
            raise ValueError("Active cycle not found")

        logs = self.cycles.recent_logs(user_id)
        bundle = PredictionInputBundle(
            profile=profile,
            cycle=cycle,
            logs=logs,
            wearable_metrics=self.sensors.recent_wearable_metrics(
                user_id,
                metric_types=[
                    "basal_body_temperature",
                    "body_temperature",
                    "skin_temperature",
                ],
                days=30,
                include_excluded=True,
            ),
            temp_readings=self.sensors.recent(user_id, "wrist_temp"),
            rhr_readings=self.sensors.recent(user_id, "rhr"),
            hrv_readings=self.sensors.recent(user_id, "hrv"),
            sleep_readings=self.sensors.recent(user_id, "sleep_minutes"),
            stress_scores=self.sensors.recent_stress(user_id),
        )

        prediction_moment = self._prediction_moment(profile.timezone)
        request = build_ensemble_request(
            user_id,
            bundle,
            prediction_date=prediction_moment,
        )
        try:
            ml_response = self.ml_client.predict_ensemble(request)
            source = "shadow" if self.settings.ml_shadow_mode else "live"
            PREDICTION_COUNTER.labels(source="ml", status="success").inc()
        except Exception:
            ml_response = self._fallback_response(
                user_id,
                cycle.id,
                request.cycle_day,
                request.mu_cycle or 28.0,
                request.pcos_flag,
                cycle.menses_length,
            )
            source = "fallback"
            PREDICTION_COUNTER.labels(source="ml", status="error").inc()

        ovulation_day = ml_response.ovulation_estimate
        generated_date = ml_response.generated_at.date()
        ovulation_date = (
            cycle.period_start_date + timedelta(days=ovulation_day - 1) if ovulation_day else None
        )
        derived_phase = self._derive_current_phase(
            request.cycle_day,
            ovulation_day=ovulation_day,
            menses_length=cycle.menses_length,
        )
        fertile_window = {
            "start": (ovulation_date - timedelta(days=5)).isoformat() if ovulation_date else None,
            "end": (ovulation_date + timedelta(days=1)).isoformat() if ovulation_date else None,
            "is_open": derived_phase in {"follicular", "ovulatory"},
            "method": ml_response.audit.ovulation_estimate_source,
        }
        next_period_estimate = {
            "date": (cycle.period_start_date + timedelta(days=int(round(request.mu_cycle or 28.0)))).isoformat(),
            "range_days": 2,
        }
        model_version = ",".join(
            filter(None, [audit.model_version for audit in ml_response.model_audits if audit.model_version])
        ) or None
        contributing_signals = [
            {"signal": "temp", "available": request.signal_availability.temp},
            {"signal": "rhr", "available": request.signal_availability.rhr},
            {"signal": "hrv", "available": request.signal_availability.hrv},
            {"signal": "lh", "available": request.signal_availability.lh},
        ]
        prediction_audit = ml_response.audit.model_dump(mode="json")
        prediction_audit["input_pipeline_version"] = PREDICTION_INPUT_PIPELINE_VERSION
        snapshot = PredictionSnapshot(
            prediction_id=ml_response.prediction_id,
            user_id=user_id,
            cycle_id=cycle.id,
            generated_at=ml_response.generated_at,
            current_phase=derived_phase,
            ovulation_estimate={"cycle_day": ovulation_day, "date": ovulation_date.isoformat() if ovulation_date else None},
            confidence=ml_response.confidence,
            confidence_explanation=ml_response.confidence_explanation,
            warning_flags=ml_response.warning_flags,
            models_used=ml_response.models_used,
            model_audits=[item.model_dump(mode="json") for item in ml_response.model_audits],
            audit=prediction_audit,
            fertile_window=fertile_window,
            next_period_estimate=next_period_estimate,
            phase_distribution=ml_response.phase_distribution,
            contributing_signals=contributing_signals,
            model_version=model_version,
            ml_payload=ml_response.model_dump(mode="json"),
            source=source,
        )
        self.predictions.save(snapshot)
        self.audit.log(user_id, "prediction.generated", {"prediction_id": snapshot.prediction_id, "source": source})
        self.db.commit()
        self.db.refresh(snapshot)
        return self.to_response(snapshot)

    def to_response(self, snapshot: PredictionSnapshot) -> PredictionSnapshotResponse:
        cycle = self.db.get(CycleRecord, snapshot.cycle_id) if snapshot.cycle_id else None
        if cycle is None:
            cycle = self.cycles.active_for_user(snapshot.user_id)
        return PredictionSnapshotResponse(
            prediction_id=snapshot.prediction_id,
            user_id=snapshot.user_id,
            cycle_id=snapshot.cycle_id,
            cycle_start_date=cycle.period_start_date if cycle else None,
            cycle_length_days=cycle.cycle_length_days if cycle else None,
            period_length_days=cycle.menses_length if cycle else None,
            generated_at=snapshot.generated_at,
            current_phase=snapshot.current_phase,
            ovulation_estimate=snapshot.ovulation_estimate,
            confidence=snapshot.confidence,
            confidence_explanation=snapshot.confidence_explanation,
            warning_flags=snapshot.warning_flags,
            models_used=snapshot.models_used,
            model_audits=snapshot.model_audits,
            audit=snapshot.audit,
            fertile_window=snapshot.fertile_window,
            next_period_estimate=snapshot.next_period_estimate,
            phase_distribution=snapshot.phase_distribution,
            contributing_signals=snapshot.contributing_signals,
            model_version=snapshot.model_version,
            disclaimer=self.settings.medical_disclaimer,
        )

    def latest_prediction(self, user_id: str) -> PredictionSnapshotResponse:
        snapshot = self.predictions.latest_for_user(user_id)
        active_cycle = self.cycles.active_for_user(user_id)
        profile = self.users.ensure_profile(user_id)
        timezone = self._timezone(profile.timezone)
        local_today = self._now_utc().astimezone(timezone).date()
        snapshot_local_date = snapshot.generated_at.astimezone(timezone).date() if snapshot else None
        if (
            snapshot
            and active_cycle
            and snapshot.cycle_id == active_cycle.id
            and snapshot_local_date == local_today
        ):
            return self.to_response(snapshot)
        return self.run_prediction(user_id)

    def calendar(self, user_id: str) -> list[dict[str, Any]]:
        latest = self.latest_prediction(user_id)
        active_cycle = self.cycles.active_for_user(user_id)
        cycle_start = active_cycle.period_start_date if active_cycle else latest.cycle_start_date
        cycle_length = int(round(active_cycle.mu_cycle or active_cycle.cycle_length_days or 28)) if active_cycle else (latest.cycle_length_days or 28)
        period_length = active_cycle.menses_length if active_cycle else (latest.period_length_days or 5)
        ovulation_date = datetime.fromisoformat(latest.ovulation_estimate["date"]).date() if latest.ovulation_estimate.get("date") else None
        current_date = latest.generated_at.date()
        rows: list[dict[str, Any]] = []
        for offset in range(180):
            day = current_date + timedelta(days=offset)
            cycle_day = ((day - cycle_start).days % cycle_length) + 1 if cycle_start else offset + 1
            is_ovulation_est = ovulation_date == day if ovulation_date else False
            is_fertile = False
            if latest.fertile_window.get("start") and latest.fertile_window.get("end"):
                is_fertile = latest.fertile_window["start"] <= day.isoformat() <= latest.fertile_window["end"]
            phase = self._derive_current_phase(
                cycle_day,
                ovulation_day=(cycle_length - 14),
                menses_length=period_length,
            )
            rows.append(
                {
                    "date": day,
                    "phase": phase,
                    "fertility_score": round(latest.confidence * (0.8 if is_fertile else 0.2), 2),
                    "is_period": cycle_day <= max(1, period_length or 5),
                    "is_fertile": is_fertile,
                    "is_ovulation_est": is_ovulation_est,
                }
            )
        return rows

    def age_context(self, user_id: str) -> dict[str, Any]:
        profile = self.users.ensure_profile(user_id)
        age_band = profile.age_band or derive_age_band(None)
        return {
            "age_band": age_band,
            "age_band_label": age_band_label(age_band),
            "perimenopause_mode_active": profile.perimenopause_mode_active,
            "how_age_affects_predictions": build_age_context(age_band, profile.perimenopause_mode_active),
            "population_priors_for_band": POPULATION_PRIORS.get(age_band or "", {}),
        }
    @staticmethod
    def _now_utc() -> datetime:
        return datetime.now(UTC)

    @staticmethod
    def _timezone(timezone_name: str | None) -> ZoneInfo:
        if timezone_name:
            try:
                return ZoneInfo(timezone_name)
            except ZoneInfoNotFoundError:
                pass
        return ZoneInfo("UTC")

    def _prediction_moment(self, timezone_name: str | None) -> datetime:
        return self._now_utc().astimezone(self._timezone(timezone_name))
