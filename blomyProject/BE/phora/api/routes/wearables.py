from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_settings_dep
from phora.core.config import Settings
from phora.db.session import get_db
from phora.models import SensorReading, WearableMetric
from phora.models.enums import WearableType
from phora.repositories.core import AuditRepository, UserRepository
from phora.schemas.watch import (
    AppleHealthStatusResponse,
    AppleHealthSyncRequest,
    AppleHealthSyncResponse,
    GoogleHealthAuthUrlResponse,
    GoogleHealthStatusResponse,
    GoogleHealthSyncResponse,
    HealthMetricRecord,
    HealthMetricsResponse,
)
from phora.services.google_health import GoogleHealthError, GoogleHealthService
from phora.services.wearable_metrics import build_trend_metric

router = APIRouter(prefix="/wearables", tags=["wearables"])

_SOURCE_LABELS: dict[str, str] = {
    "vyla_wearable": "Vyla wearable",
    "apple_health": "Apple Health",
    "manual_entry": "Manual entry",
}


def _is_connected_wearable(wearable_type: WearableType | None) -> bool:
    return wearable_type not in {None, WearableType.NONE, WearableType.MANUAL_BBT}


def _assert_single_wearable_connection(
    *,
    current: WearableType | None,
    requested: WearableType,
) -> None:
    if not _is_connected_wearable(current):
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


def _get_apple_health_connection(profile_conditions: dict) -> dict:
    return dict((profile_conditions.get("apple_health") or {}))


def _apple_health_connected(profile_conditions: dict) -> bool:
    return _get_apple_health_connection(profile_conditions).get("connected", False) is True


@router.get("/google-health/auth-url", response_model=GoogleHealthAuthUrlResponse)
def google_health_auth_url(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> GoogleHealthAuthUrlResponse:
    try:
        service = GoogleHealthService(db, settings)
        return GoogleHealthAuthUrlResponse(authorization_url=service.authorization_url(user_id))
    except GoogleHealthError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("/google-health/callback")
def google_health_callback(
    code: str | None = Query(default=None),
    state: str | None = Query(default=None),
    error: str | None = Query(default=None),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> RedirectResponse:
    if error or not code or not state:
        return RedirectResponse(settings.google_health_oauth_error_redirect)
    try:
        redirect_url = GoogleHealthService(db, settings).complete_callback(code=code, state=state)
    except GoogleHealthError:
        redirect_url = settings.google_health_oauth_error_redirect
    return RedirectResponse(redirect_url)


@router.get("/google-health/status", response_model=GoogleHealthStatusResponse)
def google_health_status(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> dict:
    try:
        return GoogleHealthService(db, settings).status(user_id)
    except GoogleHealthError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/google-health/sync", response_model=GoogleHealthSyncResponse)
def google_health_sync(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> dict:
    try:
        return GoogleHealthService(db, settings).sync(user_id)
    except GoogleHealthError as exc:
        return {
            "synced": False,
            "saved": 0,
            "detail": str(exc),
        }


@router.post("/google-health/disconnect")
def google_health_disconnect(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> dict:
    GoogleHealthService(db, settings).disconnect(user_id)
    return {"disconnected": True}


@router.get("/apple-health/status", response_model=AppleHealthStatusResponse)
def apple_health_status(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> AppleHealthStatusResponse:
    profile = UserRepository(db).ensure_profile(user_id)
    conditions = dict(profile.conditions or {})
    connection = _get_apple_health_connection(conditions)
    last_synced_raw = connection.get("last_synced_at")
    last_synced: datetime | None = None
    if isinstance(last_synced_raw, str):
        try:
            last_synced = datetime.fromisoformat(last_synced_raw)
        except ValueError:
            pass
    return AppleHealthStatusResponse(
        connected=connection.get("connected", False) is True,
        last_synced_at=last_synced,
    )


@router.post("/apple-health/sync", response_model=AppleHealthSyncResponse)
def apple_health_sync(
    payload: AppleHealthSyncRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    now = datetime.now(UTC)
    data_source = "apple_health"
    source = "healthkit"

    profile = UserRepository(db).ensure_profile(user_id)

    # Apple Health is an independent source — it does NOT enforce the single-wearable
    # mutex and must never overwrite or displace the Vyla wearable connection.
    # Track its connection state separately in profile.conditions.
    conditions = dict(profile.conditions or {})
    apple_health_conn = dict(conditions.get("apple_health") or {})
    apple_health_conn["connected"] = True
    apple_health_conn["last_synced_at"] = now.isoformat()
    if not apple_health_conn.get("connected_at"):
        apple_health_conn["connected_at"] = now.isoformat()
    conditions["apple_health"] = apple_health_conn
    profile.conditions = conditions

    saved = 0
    for day in payload.days:
        stamp = datetime.combine(day.date, datetime.min.time(), tzinfo=UTC)
        day_ext = day.external_id

        def _should_skip(metric_type: str, _stamp=stamp) -> bool:
            existing = db.scalar(
                select(WearableMetric).where(
                    WearableMetric.user_id == user_id,
                    WearableMetric.data_source == data_source,
                    WearableMetric.metric_type == metric_type,
                    WearableMetric.measured_at == _stamp,
                )
            )
            return existing is not None

        def _ext(metric_type: str, _day_ext=day_ext, _date=day.date) -> str:
            if _day_ext:
                return f"{_day_ext}:{metric_type}"
            return f"{_date.isoformat()}:{metric_type}"

        if day.sleep_minutes and day.sleep_minutes > 0 and not _should_skip("sleep"):
            db.add(SensorReading(user_id=user_id, metric="sleep_minutes", value=float(day.sleep_minutes), delta=float(day.sleep_minutes), source=source, recorded_at=stamp))
            db.add(build_trend_metric(user_id=user_id, source=source, metric_type="sleep", value=float(day.sleep_minutes), unit="minutes", measured_at=stamp, collected_at=now, confidence="medium", data_source=data_source, external_id=_ext("sleep"), raw_payload={"deep_minutes": day.deep_sleep_minutes, "light_minutes": day.light_sleep_minutes}))
            saved += 1

        if day.deep_sleep_minutes and day.deep_sleep_minutes > 0 and not _should_skip("sleep_deep"):
            db.add(SensorReading(user_id=user_id, metric="sleep_deep_minutes", value=float(day.deep_sleep_minutes), delta=float(day.deep_sleep_minutes), source=source, recorded_at=stamp))
            saved += 1

        if day.light_sleep_minutes and day.light_sleep_minutes > 0 and not _should_skip("sleep_light"):
            db.add(SensorReading(user_id=user_id, metric="sleep_light_minutes", value=float(day.light_sleep_minutes), delta=float(day.light_sleep_minutes), source=source, recorded_at=stamp))
            saved += 1

        if day.steps and day.steps > 0 and not _should_skip("steps"):
            db.add(SensorReading(user_id=user_id, metric="steps", value=float(day.steps), delta=float(day.steps), source=source, recorded_at=stamp))
            db.add(build_trend_metric(user_id=user_id, source=source, metric_type="steps", value=float(day.steps), unit="count", measured_at=stamp, collected_at=now, confidence="medium", data_source=data_source, external_id=_ext("steps")))
            saved += 1

        if day.resting_heart_rate and day.resting_heart_rate > 0 and not _should_skip("heart_rate"):
            db.add(SensorReading(user_id=user_id, metric="rhr", value=float(day.resting_heart_rate), delta=float(day.resting_heart_rate), source=source, recorded_at=stamp))
            db.add(build_trend_metric(user_id=user_id, source=source, metric_type="heart_rate", value=float(day.resting_heart_rate), unit="bpm", measured_at=stamp, collected_at=now, confidence="medium", data_source=data_source, external_id=_ext("heart_rate")))
            saved += 1

        if day.hrv and day.hrv > 0 and not _should_skip("hrv"):
            db.add(SensorReading(user_id=user_id, metric="hrv", value=float(day.hrv), delta=float(day.hrv), source=source, recorded_at=stamp))
            db.add(build_trend_metric(user_id=user_id, source=source, metric_type="hrv", value=float(day.hrv), unit="ms", measured_at=stamp, collected_at=now, confidence="medium", data_source=data_source, external_id=_ext("hrv")))
            saved += 1

        if day.bbt and day.bbt > 0 and not _should_skip("basal_body_temperature"):
            db.add(build_trend_metric(user_id=user_id, source=source, metric_type="basal_body_temperature", value=float(day.bbt), unit="celsius", measured_at=stamp, collected_at=now, confidence="medium", data_source=data_source, external_id=_ext("basal_body_temperature")))
            saved += 1

        if day.body_temperature and day.body_temperature > 0 and not _should_skip("body_temperature"):
            db.add(SensorReading(user_id=user_id, metric="wrist_temp", value=float(day.body_temperature), delta=float(day.body_temperature), source=source, recorded_at=stamp))
            db.add(build_trend_metric(user_id=user_id, source=source, metric_type="body_temperature", value=float(day.body_temperature), unit="celsius", measured_at=stamp, collected_at=now, confidence="medium", data_source=data_source, external_id=_ext("body_temperature")))
            saved += 1

        if day.wrist_temperature and day.wrist_temperature > 0 and not _should_skip("wrist_temperature"):
            db.add(build_trend_metric(user_id=user_id, source=source, metric_type="wrist_temperature", value=float(day.wrist_temperature), unit="celsius", measured_at=stamp, collected_at=now, confidence="medium", data_source=data_source, external_id=_ext("wrist_temperature")))
            saved += 1

    AuditRepository(db).log(user_id, "wearables.apple_health_sync", {"days": len(payload.days), "records": saved})
    db.commit()
    return {"synced": True, "saved": saved, "last_synced_at": now}


@router.post("/apple-health/disconnect")
def apple_health_disconnect(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    profile = UserRepository(db).ensure_profile(user_id)
    conditions = dict(profile.conditions or {})
    apple_health_conn = dict(conditions.get("apple_health") or {})
    if apple_health_conn.get("connected"):
        apple_health_conn["connected"] = False
        apple_health_conn["disconnected_at"] = datetime.now(UTC).isoformat()
        conditions["apple_health"] = apple_health_conn
        profile.conditions = conditions
        AuditRepository(db).log(user_id, "wearables.apple_health_disconnect", {})
        db.commit()
    return {"disconnected": True}


@router.get("/health-metrics", response_model=HealthMetricsResponse)
def list_health_metrics(
    source: str | None = Query(default=None, description="Filter by data_source: apple_health, vyla_wearable, manual_entry"),
    metric_type: str | None = Query(default=None),
    days: int = Query(default=30, ge=1, le=365),
    limit: int = Query(default=100, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> HealthMetricsResponse:
    from datetime import timedelta
    since = datetime.now(UTC) - timedelta(days=days)
    stmt = select(WearableMetric).where(
        WearableMetric.user_id == user_id,
        WearableMetric.measured_at >= since,
    )
    if source:
        stmt = stmt.where(WearableMetric.data_source == source)
    if metric_type:
        stmt = stmt.where(WearableMetric.metric_type == metric_type)
    stmt = stmt.order_by(WearableMetric.measured_at.desc()).limit(limit)
    rows = list(db.scalars(stmt))
    records = [
        HealthMetricRecord(
            id=row.id,
            user_id=row.user_id,
            metric_type=row.metric_type,
            value=row.value,
            unit=row.unit,
            data_source=row.data_source,
            recorded_at=row.measured_at,
            external_id=row.external_id,
            confidence=row.confidence,
            excluded_from_ovulation_prediction=row.excluded_from_ovulation_prediction,
            source_label=_SOURCE_LABELS.get(row.data_source, row.data_source),
        )
        for row in rows
    ]
    return HealthMetricsResponse(metrics=records, total=len(records))
