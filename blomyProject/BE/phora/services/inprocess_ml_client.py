from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import uuid4

from phora.schemas.ml import (
    MlEnsembleRequest,
    MlEnsembleResponse,
    MlHealthResponse,
    MlLHStripResponse,
    ModelAudit,
    PredictionAudit,
)
from phora.services.ml_client import MlClient

LOGGER = logging.getLogger(__name__)


class InProcessMlClient(MlClient):
    """Calls bloomy_ml models in-process — no HTTP round-trip."""

    _loaded: bool = False
    _population_models: dict | None = None
    _cusum = None
    _stress_scorer = None
    _shift_predictor = None
    _started_at: datetime | None = None

    @classmethod
    def _ensure_loaded(cls) -> bool:
        if cls._loaded:
            return True
        try:
            from bloomy_ml.config import CONFIG
            from bloomy_ml.models import (
                CUSUMDetector,
                OvulationShiftPredictor,
                PopulationRF,
                StressBurdenScorer,
            )

            models: dict = {}
            if CONFIG.population_rf_fedcycle_production_artifact.exists():
                models["fedcycle"] = PopulationRF.load(CONFIG.population_rf_fedcycle_production_artifact)
            if CONFIG.population_rf_mcphases_production_artifact.exists():
                models["mcphases"] = PopulationRF.load(CONFIG.population_rf_mcphases_production_artifact)
            if not models and CONFIG.population_rf_artifact.exists():
                legacy = PopulationRF.load(CONFIG.population_rf_artifact)
                models["fedcycle"] = legacy
                models["mcphases"] = legacy
            if not models:
                models["fedcycle"] = PopulationRF()
                models["mcphases"] = PopulationRF()
            if "fedcycle" not in models:
                models["fedcycle"] = models["mcphases"]
            if "mcphases" not in models:
                models["mcphases"] = models["fedcycle"]

            cls._population_models = models
            cls._cusum = CUSUMDetector(CONFIG.threshold_config)
            cls._stress_scorer = StressBurdenScorer()
            cls._shift_predictor = OvulationShiftPredictor()
            cls._started_at = datetime.now(timezone.utc)
            cls._loaded = True
            LOGGER.info("bloomy_ml loaded in-process")
            return True
        except Exception as exc:
            LOGGER.warning("bloomy_ml failed to load in-process: %s", exc)
            return False

    def health(self) -> MlHealthResponse:
        loaded = self._ensure_loaded()
        uptime = (
            (datetime.now(timezone.utc) - self._started_at).total_seconds()
            if self._started_at
            else None
        )
        return MlHealthResponse(
            status="ok" if loaded else "degraded",
            models_loaded=loaded,
            uptime=uptime,
        )

    def model_versions(self) -> dict:
        if not self._ensure_loaded():
            return {}
        return {
            "rf_fedcycle_version": self._population_models["fedcycle"].model_version,
            "rf_mcphases_version": self._population_models["mcphases"].model_version,
            "cusum_version": self._cusum.model_version,
        }

    def predict_ensemble(self, payload: MlEnsembleRequest) -> MlEnsembleResponse:
        if not self._ensure_loaded():
            raise RuntimeError("bloomy_ml models are not available in-process")

        from bloomy_ml.config import CONFIG
        from bloomy_ml.dataset_ingestion.schema import CanonicalDailyRecord
        from bloomy_ml.ensemble import fuse_predictions
        from bloomy_ml.models import PersonalLSTM

        has_wearables = bool(
            payload.temp_series
            or payload.delta_temp is not None
            or payload.rhr_dev is not None
            or payload.hrv_dev is not None
            or (payload.wearable_source not in (None, "", "manual_bbt"))
            or (payload.temp_source not in ("manual_bbt", "") if payload.temp_source else False)
        )
        source_domain = "mcphases" if has_wearables else "fedcycle"

        record = CanonicalDailyRecord(
            training_id=payload.user_id,
            source=source_domain,
            cycle_id=payload.cycle_id,
            subject_id=payload.user_id,
            study_interval=None,
            cycle_day=payload.cycle_day,
            cycle_length=int(payload.mu_cycle or max(payload.cycle_day, 1)),
            period_length=payload.menses_length,
            phase="unknown",
            ovulation_day=payload.ovulation_day,
            ovulation_ground_truth_type="runtime_input",
            cycle_day_norm=payload.cycle_day_norm,
            sigma_cycle=payload.sigma_cycle,
            mu_cycle=payload.mu_cycle,
            age=payload.age,
            age_band=payload.age_band or "UNKNOWN",
            age_at_menarche=payload.age_at_menarche,
            bmi=payload.bmi,
            pcos_flag=payload.pcos_flag,
            anovulatory_flag=False,
            lh_proxy=payload.lh_proxy,
            mucus_score=payload.mucus_score,
            sleep_quality=payload.sleep_quality,
            delta_temp=payload.delta_temp,
            rhr_dev=payload.rhr_dev,
            hrv_dev=payload.hrv_dev,
            availability_flags=payload.signal_availability.model_dump(),
            metadata={"runtime_source_domain": source_domain},
        )

        rf_model = self._population_models.get(source_domain, self._population_models["fedcycle"])
        rf_prediction = rf_model.predict(record)

        lstm_path = CONFIG.personal_lstm_production_dir / f"{payload.user_id}.pt"
        personal_lstm = PersonalLSTM.load(lstm_path) if lstm_path.exists() else PersonalLSTM()
        lstm_prediction = personal_lstm.predict(None)

        temp_readings_for_cusum = [
            {
                "date": item.date.isoformat() if item.date else None,
                "delta_temp": item.delta_temp,
                "quality_score": item.quality_score,
                "illness_flag": item.illness_flag,
                "alcohol_flag": item.alcohol_flag,
            }
            for item in payload.temp_series
        ]
        cusum_prediction = self._cusum.predict(
            readings=temp_readings_for_cusum,
            source_type=payload.temp_source,
            age_band=payload.age_band,
            perimenopause_mode_active=payload.perimenopause_mode_active,
            stress_burden_7d=payload.stress_burden_7d or 0.0,
        )

        shift_prediction = self._shift_predictor.predict(
            cycle_length_var_sigma=payload.sigma_cycle or 0.0,
            pcos_flag=payload.pcos_flag,
            mucus_proxy=payload.mucus_score or payload.lh_proxy or 0.0,
            stress_burden_7d=payload.stress_burden_7d,
        )

        fused = fuse_predictions(
            rf_prediction,
            lstm_prediction,
            cusum_prediction,
            shift_prediction=shift_prediction,
            lh_surge_state=payload.lh_surge_state,
            lh_surge_day=payload.lh_surge_day,
            pcos_flag=payload.pcos_flag,
            stress_burden_7d=payload.stress_burden_7d,
            cycle_day=payload.cycle_day,
            mu_cycle=payload.mu_cycle,
            temp_series_length=len(payload.temp_series),
            source_domain=source_domain,
        )

        audit_dict = fused.audit
        prediction_audit = PredictionAudit(
            cusum_triggered=bool(audit_dict.get("cusum_triggered", False)),
            pcos_flag=bool(audit_dict.get("pcos_flag", False)),
            lh_override_applied=bool(audit_dict.get("lh_override_applied", False)),
            ovulation_estimate_source=str(audit_dict.get("ovulation_estimate_source", "calendar_fallback")),
            rf_direct_threshold=audit_dict.get("rf_direct_threshold"),
        )

        audits = [
            ModelAudit(
                model_name=rf_prediction.model_name,
                model_version=rf_prediction.model_version,
                available=rf_prediction.available,
                confidence=rf_prediction.confidence,
                explanation=f"{rf_prediction.explanation} Routed source_domain={source_domain}.",
            ),
            ModelAudit(
                model_name=cusum_prediction.model_name,
                model_version=cusum_prediction.model_version,
                available=cusum_prediction.available,
                confidence=cusum_prediction.confidence,
                explanation=cusum_prediction.explanation,
            ),
            ModelAudit(
                model_name=shift_prediction.model_name,
                model_version=shift_prediction.model_version,
                available=shift_prediction.available,
                confidence=shift_prediction.confidence,
                explanation=shift_prediction.explanation,
            ),
        ]

        return MlEnsembleResponse(
            user_id=payload.user_id,
            prediction_id=str(uuid4()),
            current_phase=fused.current_phase,
            phase_distribution=fused.phase_distribution,
            ovulation_estimate=fused.ovulation_estimate,
            confidence=fused.confidence,
            confidence_explanation=fused.confidence_explanation,
            warning_flags=fused.warning_flags,
            models_used=fused.models_used,
            model_audits=audits,
            audit=prediction_audit,
            generated_at=datetime.now(timezone.utc),
        )

    def analyze_lh_strip(self, image_bytes: bytes, content_type: str) -> MlLHStripResponse:
        if not self._ensure_loaded():
            raise RuntimeError("bloomy_ml models are not available in-process")

        from bloomy_ml.service.lh_strip import analyze_lh_strip

        result = analyze_lh_strip(image_bytes=image_bytes, content_type=content_type)
        return MlLHStripResponse(
            strip_valid=result.strip_valid,
            strip_confidence=result.strip_confidence,
            state=result.state,
            positive=result.positive,
            ratio=result.ratio,
            result_confidence=result.result_confidence,
            explanation=result.explanation,
            analysis_version=result.analysis_version,
        )
