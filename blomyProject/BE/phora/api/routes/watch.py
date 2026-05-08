from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id
from phora.db.session import get_db
from phora.models import SensorReading, StressScore
from phora.repositories.core import AuditRepository, UserRepository
from phora.models.enums import WearableType
from phora.schemas.watch import WatchSyncRequest
from phora.services.wearable_metrics import build_trend_metric

router = APIRouter(prefix="/watch", tags=["watch"])


def _is_connected_wearable(wearable_type: WearableType | None) -> bool:
    return wearable_type not in {None, WearableType.NONE, WearableType.MANUAL_BBT}


def _assert_single_wearable_connection(
    *,
    current: WearableType | None,
    requested: WearableType,
) -> None:
    if not _is_connected_wearable(current):
        return
    if not _is_connected_wearable(requested):
        return
    if current == requested:
        return
    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=(
            "Only one wearable can be connected at a time. "
            "Disconnect the current wearable before syncing a different one."
        ),
    )


@router.post("/sync")
def sync_watch(
    payload: WatchSyncRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    if payload.device_type != WearableType.GTL1.value:
        raise HTTPException(status_code=400, detail="Unsupported watch device type")

    saved = 0
    source = payload.device_type
    profile = UserRepository(db).ensure_profile(user_id)
    _assert_single_wearable_connection(
        current=profile.wearable_type,
        requested=WearableType.GTL1,
    )
    for day in payload.days:
        stamp = datetime.combine(day.date, datetime.min.time(), tzinfo=UTC)
        if day.steps > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="steps",
                    value=float(day.steps),
                    delta=float(day.steps),
                    source=source,
                    recorded_at=stamp,
                )
            )
            db.add(
                build_trend_metric(
                    user_id=user_id,
                    source=source,
                    metric_type="steps",
                    value=float(day.steps),
                    unit="count",
                    measured_at=stamp,
                    collected_at=datetime.now(UTC),
                    timezone_name=profile.timezone,
                    confidence="medium",
                    raw_payload={"profile_timezone": profile.timezone},
                )
            )
            saved += 1
        if day.caloriesKcal > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="calories_kcal",
                    value=float(day.caloriesKcal),
                    delta=float(day.caloriesKcal),
                    source=source,
                    recorded_at=stamp,
                )
            )
            saved += 1
        if day.distanceMeters > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="distance_meters",
                    value=float(day.distanceMeters),
                    delta=float(day.distanceMeters),
                    source=source,
                    recorded_at=stamp,
                )
            )
            saved += 1
        if day.sleep.totalMinutes > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="sleep_minutes",
                    value=float(day.sleep.totalMinutes),
                    delta=float(day.sleep.totalMinutes),
                    source=source,
                    recorded_at=stamp,
                )
            )
            db.add(
                build_trend_metric(
                    user_id=user_id,
                    source=source,
                    metric_type="sleep",
                    value=float(day.sleep.totalMinutes),
                    unit="minutes",
                    measured_at=stamp,
                    collected_at=datetime.now(UTC),
                    timezone_name=profile.timezone,
                    confidence="medium",
                    raw_payload={
                        "profile_timezone": profile.timezone,
                        "deep_minutes": day.sleep.deepMinutes,
                        "light_minutes": day.sleep.lightMinutes,
                        "awake_minutes": day.sleep.awakeMinutes,
                    },
                )
            )
            saved += 1
        if day.sleep.deepMinutes > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="sleep_deep_minutes",
                    value=float(day.sleep.deepMinutes),
                    delta=float(day.sleep.deepMinutes),
                    source=source,
                    recorded_at=stamp,
                )
            )
            saved += 1
        if day.sleep.lightMinutes > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="sleep_light_minutes",
                    value=float(day.sleep.lightMinutes),
                    delta=float(day.sleep.lightMinutes),
                    source=source,
                    recorded_at=stamp,
                )
            )
            saved += 1
        if day.sleep.awakeMinutes > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="sleep_awake_minutes",
                    value=float(day.sleep.awakeMinutes),
                    delta=float(day.sleep.awakeMinutes),
                    source=source,
                    recorded_at=stamp,
                )
            )
            saved += 1
        heart_rate = day.heartRate.resting if day.heartRate.resting > 0 else day.heartRate.avg
        if heart_rate > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="rhr",
                    value=float(heart_rate),
                    delta=float(heart_rate),
                    source=source,
                    recorded_at=stamp,
                )
            )
            db.add(
                build_trend_metric(
                    user_id=user_id,
                    source=source,
                    metric_type="heart_rate",
                    value=float(heart_rate),
                    unit="bpm",
                    measured_at=stamp,
                    collected_at=datetime.now(UTC),
                    timezone_name=profile.timezone,
                    confidence="medium",
                    raw_payload={
                        "profile_timezone": profile.timezone,
                        "heart_rate_kind": "resting_or_average",
                    },
                )
            )
            saved += 1
        if day.heartRate.avg > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="heart_rate_avg",
                    value=float(day.heartRate.avg),
                    delta=float(day.heartRate.avg),
                    source=source,
                    recorded_at=stamp,
                )
            )
            saved += 1
        if day.temperature.avg:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="wrist_temp",
                    value=float(day.temperature.avg),
                    delta=float(day.temperature.avg),
                    source=source,
                    recorded_at=stamp,
                )
            )
            db.add(
                build_trend_metric(
                    user_id=user_id,
                    source=source,
                    metric_type="skin_temperature",
                    value=float(day.temperature.avg),
                    unit="celsius",
                    measured_at=stamp,
                    collected_at=datetime.now(UTC),
                    timezone_name=profile.timezone,
                    confidence="low",
                    excluded_from_ovulation_prediction=True,
                    exclusion_reason=(
                        "Daily GTL1 summary temperature is logged as a trend and "
                        "not used as a confirmed early-morning BBT reading."
                    ),
                    raw_payload={"profile_timezone": profile.timezone},
                )
            )
            saved += 1
        if day.bloodOxygen.avg > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="blood_oxygen_avg",
                    value=float(day.bloodOxygen.avg),
                    delta=float(day.bloodOxygen.avg),
                    source=source,
                    recorded_at=stamp,
                )
            )
            db.add(
                build_trend_metric(
                    user_id=user_id,
                    source=source,
                    metric_type="spo2",
                    value=float(day.bloodOxygen.avg),
                    unit="percent",
                    measured_at=stamp,
                    collected_at=datetime.now(UTC),
                    timezone_name=profile.timezone,
                    confidence="medium",
                    raw_payload={"profile_timezone": profile.timezone},
                )
            )
            saved += 1
        if day.bloodOxygen.min > 0:
            db.add(
                SensorReading(
                    user_id=user_id,
                    metric="blood_oxygen_min",
                    value=float(day.bloodOxygen.min),
                    delta=float(day.bloodOxygen.min),
                    source=source,
                    recorded_at=stamp,
                )
            )
            saved += 1
        if day.stress.avg:
            db.add(StressScore(user_id=user_id, score=float(day.stress.avg), recorded_at=stamp))
            saved += 1

    profile.wearable_type = WearableType.GTL1
    AuditRepository(db).log(user_id, "watch.gtl1_sync", {"days": len(payload.days), "records": saved})
    db.commit()
    return {"status": "ok", "days": len(payload.days), "records": saved}
