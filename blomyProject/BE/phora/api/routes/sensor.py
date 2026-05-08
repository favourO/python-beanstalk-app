from datetime import datetime, UTC

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id
from phora.db.session import get_db
from phora.models import SensorReading
from phora.repositories.core import AuditRepository, UserRepository
from phora.schemas.sensor import HeartRateIngestRequest, SleepIngestRequest, TemperatureIngestRequest
from phora.services.wearable_metrics import build_trend_metric

router = APIRouter(prefix="/sensor", tags=["sensor"])


@router.post("/ingest/temperature")
def ingest_temperature(
    payload: TemperatureIngestRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    profile = UserRepository(db).ensure_profile(user_id)
    for record in payload.records:
        source = "manual_bbt" if record.source in {"manual", "manual_bbt"} else record.source
        db.add(
            SensorReading(
                user_id=user_id,
                metric="wrist_temp",
                value=record.delta_c,
                delta=record.delta_c,
                quality_score=record.sleep_quality_score,
                source=source,
                recorded_at=record.timestamp,
            )
        )
        if record.temperature_celsius is not None:
            measured_at = record.measured_at or record.timestamp
            db.add(
                build_trend_metric(
                    user_id=user_id,
                    source=source,
                    metric_type=record.metric_type,
                    value=record.temperature_celsius,
                    unit=record.unit,
                    measured_at=measured_at,
                    collected_at=record.collected_at or record.timestamp,
                    timezone_name=profile.timezone,
                    is_user_entered=record.is_user_entered,
                    confidence=(
                        "low"
                        if record.excluded_from_ovulation_prediction
                        else "medium"
                    ),
                    excluded_from_ovulation_prediction=(
                        record.excluded_from_ovulation_prediction
                        if record.excluded_from_ovulation_prediction is not None
                        else True
                    ),
                    exclusion_reason=record.exclusion_reason
                    or (
                        None
                        if record.metric_type == "basal_body_temperature"
                        else "This temperature is logged as a supporting trend signal."
                    ),
                    raw_payload={
                        "profile_timezone": profile.timezone,
                        "delta_c": record.delta_c,
                        "sleep_minutes": record.sleep_minutes,
                        "sleep_quality_score": record.sleep_quality_score,
                        "illness_flag": record.illness_flag,
                        "alcohol_flag": record.alcohol_flag,
                        "stress_flag": record.stress_flag,
                        "travel_flag": record.travel_flag,
                        **(record.raw_payload or {}),
                    },
                )
            )
    AuditRepository(db).log(user_id, "sensor.temperature_ingested", {"count": len(payload.records)})
    db.commit()
    return {"status": "ok", "count": len(payload.records)}


@router.post("/ingest/heart-rate")
def ingest_heart_rate(
    payload: HeartRateIngestRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    stamp = datetime.combine(payload.date, datetime.min.time(), tzinfo=UTC)
    db.add(SensorReading(user_id=user_id, metric="rhr", value=payload.rhr_bpm, delta=payload.rhr_bpm, source=payload.source, recorded_at=stamp))
    if payload.hrv_sdnn_ms is not None:
        db.add(SensorReading(user_id=user_id, metric="hrv", value=payload.hrv_sdnn_ms, delta=payload.hrv_sdnn_ms, source=payload.source, recorded_at=stamp))
    db.commit()
    return {"status": "ok"}


@router.post("/ingest/sleep")
def ingest_sleep(
    payload: SleepIngestRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    stamp = datetime.combine(payload.date, datetime.min.time(), tzinfo=UTC)
    db.add(
        SensorReading(
            user_id=user_id,
            metric="sleep_minutes",
            value=float(payload.total_minutes),
            delta=float(payload.total_minutes),
            quality_score=payload.sleep_quality_score,
            source="derived",
            recorded_at=stamp,
        )
    )
    db.commit()
    return {"status": "ok"}
