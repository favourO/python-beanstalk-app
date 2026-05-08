from datetime import UTC, date, datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id
from phora.db.session import get_db
from phora.models import CycleRecord, DailyLog, SensorReading, WearableMetric
from phora.models.enums import LogType
from phora.repositories.core import AuditRepository, CycleRepository, UserRepository
from phora.schemas.daily_log import (
    CervicalMucusLogPayload,
    DailyLogEnvelope,
    DailyLogResponse,
    IntimacyLogPayload,
    LhTestLogPayload,
    PeriodLogPayload,
    SaveStatusResponse,
    SymptomsLogPayload,
    TemperatureLogPayload,
)
from phora.services.wearable_metrics import (
    build_manual_bbt_metric,
    combine_local_day_and_time,
)

router = APIRouter(prefix="/log/daily", tags=["log"])


@router.get("", response_model=DailyLogResponse)
def get_daily_log(
    day: date | None = Query(default=None, alias="date"),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> DailyLogResponse:
    target = day or datetime.now(UTC).date()
    logs = _logs_for_day(db=db, user_id=user_id, day=target)
    return DailyLogResponse(
        user_id=user_id,
        date=target,
        period=_payload_for(logs, LogType.PERIOD, PeriodLogPayload),
        symptoms=_payload_for(logs, LogType.SYMPTOM, SymptomsLogPayload),
        temperature=_payload_for(logs, LogType.BBT, TemperatureLogPayload),
        lh_test=_payload_for(logs, LogType.LH, LhTestLogPayload),
        cervical_mucus=_payload_for(logs, LogType.MUCUS, CervicalMucusLogPayload),
        intimacy=_payload_for(logs, LogType.INTERCOURSE, IntimacyLogPayload),
    )


@router.post("", response_model=SaveStatusResponse)
def save_daily_log(
    payload: DailyLogEnvelope,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SaveStatusResponse:
    _save_sections(db=db, user_id=user_id, payload=payload)
    db.commit()
    return SaveStatusResponse()


@router.post("/period", response_model=SaveStatusResponse)
def save_period_log(
    payload: DailyLogEnvelope,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SaveStatusResponse:
    if payload.period is None:
      return SaveStatusResponse()
    _save_period(db=db, user_id=user_id, day=payload.date, section=payload.period)
    db.commit()
    return SaveStatusResponse()


@router.post("/symptoms", response_model=SaveStatusResponse)
def save_symptoms_log(
    payload: DailyLogEnvelope,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SaveStatusResponse:
    if payload.symptoms is None:
        return SaveStatusResponse()
    _upsert_log(
        db=db,
        user_id=user_id,
        day=payload.date,
        log_type=LogType.SYMPTOM,
        data=payload.symptoms.model_dump(mode="json", exclude_none=True),
    )
    db.commit()
    return SaveStatusResponse()


@router.post("/temperature", response_model=SaveStatusResponse)
def save_temperature_log(
    payload: DailyLogEnvelope,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SaveStatusResponse:
    if payload.temperature is None:
        return SaveStatusResponse()
    _save_temperature_section(
        db=db,
        user_id=user_id,
        day=payload.date,
        section=payload.temperature,
    )
    db.commit()
    return SaveStatusResponse()


@router.post("/lh-test", response_model=SaveStatusResponse)
def save_lh_test_log(
    payload: DailyLogEnvelope,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SaveStatusResponse:
    if payload.lh_test is None:
        return SaveStatusResponse()
    section = payload.lh_test
    data = section.model_dump(mode="json", exclude_none=True)
    result = (section.result or "").strip().lower()
    if result:
        data["state"] = result
        data["positive"] = result in {"high", "peak"}
    _upsert_log(
        db=db,
        user_id=user_id,
        day=payload.date,
        log_type=LogType.LH,
        data=data,
    )
    db.commit()
    return SaveStatusResponse()


@router.post("/cervical-mucus", response_model=SaveStatusResponse)
def save_cervical_mucus_log(
    payload: DailyLogEnvelope,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SaveStatusResponse:
    if payload.cervical_mucus is None:
        return SaveStatusResponse()
    _upsert_log(
        db=db,
        user_id=user_id,
        day=payload.date,
        log_type=LogType.MUCUS,
        data=payload.cervical_mucus.model_dump(mode="json", exclude_none=True),
    )
    db.commit()
    return SaveStatusResponse()


@router.post("/intimacy", response_model=SaveStatusResponse)
def save_intimacy_log(
    payload: DailyLogEnvelope,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> SaveStatusResponse:
    if payload.intimacy is None:
        return SaveStatusResponse()
    _upsert_log(
        db=db,
        user_id=user_id,
        day=payload.date,
        log_type=LogType.INTERCOURSE,
        data=payload.intimacy.model_dump(mode="json", exclude_none=True),
    )
    db.commit()
    return SaveStatusResponse()


def _save_sections(*, db: Session, user_id: str, payload: DailyLogEnvelope) -> None:
    if payload.period is not None:
        _save_period(db=db, user_id=user_id, day=payload.date, section=payload.period)
    if payload.symptoms is not None:
        _upsert_log(
            db=db,
            user_id=user_id,
            day=payload.date,
            log_type=LogType.SYMPTOM,
            data=payload.symptoms.model_dump(mode="json", exclude_none=True),
        )
    if payload.temperature is not None:
        _save_temperature_section(
            db=db,
            user_id=user_id,
            day=payload.date,
            section=payload.temperature,
        )
    if payload.lh_test is not None:
        data = payload.lh_test.model_dump(mode="json", exclude_none=True)
        result = (payload.lh_test.result or "").strip().lower()
        if result:
            data["state"] = result
            data["positive"] = result in {"high", "peak"}
        _upsert_log(db=db, user_id=user_id, day=payload.date, log_type=LogType.LH, data=data)
    if payload.cervical_mucus is not None:
        _upsert_log(
            db=db,
            user_id=user_id,
            day=payload.date,
            log_type=LogType.MUCUS,
            data=payload.cervical_mucus.model_dump(mode="json", exclude_none=True),
        )
    if payload.intimacy is not None:
        _upsert_log(
            db=db,
            user_id=user_id,
            day=payload.date,
            log_type=LogType.INTERCOURSE,
            data=payload.intimacy.model_dump(mode="json", exclude_none=True),
        )


def _save_period(*, db: Session, user_id: str, day: date, section: PeriodLogPayload) -> None:
    cycles = CycleRepository(db)
    active = cycles.active_for_user(user_id)
    if active is None:
        active = CycleRecord(
            user_id=user_id,
            period_start_date=day,
            period_end_date=day,
            menses_length=1,
            is_active=True,
        )
        db.add(active)
        db.flush()
    elif day < active.period_start_date:
        active.period_start_date = day
        active.period_end_date = max(active.period_end_date or day, day)
        active.menses_length = (active.period_end_date - active.period_start_date).days + 1
    elif _is_same_period_window(active, day):
        active.period_end_date = max(active.period_end_date or active.period_start_date, day)
        active.menses_length = (active.period_end_date - active.period_start_date).days + 1
    else:
        active.is_active = False
        if active.period_end_date is None:
            active.period_end_date = active.period_start_date
            active.menses_length = 1
        active = CycleRecord(
            user_id=user_id,
            period_start_date=day,
            period_end_date=day,
            menses_length=1,
            is_active=True,
        )
        db.add(active)
        db.flush()
    _upsert_log(
        db=db,
        user_id=user_id,
        day=day,
        log_type=LogType.PERIOD,
        data=section.model_dump(mode="json", exclude_none=True),
        cycle_id=active.id,
    )
    AuditRepository(db).log(user_id, "cycle.period_logged", {"date": day.isoformat()})


def _save_temperature_section(
    *,
    db: Session,
    user_id: str,
    day: date,
    section: TemperatureLogPayload,
) -> None:
    profile = UserRepository(db).ensure_profile(user_id)
    _upsert_log(
        db=db,
        user_id=user_id,
        day=day,
        log_type=LogType.BBT,
        data=section.model_dump(mode="json", exclude_none=True),
    )
    if section.temperature_celsius is None:
        return
    stamp = _combine_day_and_optional_time(day, section.measured_at)
    existing = db.scalar(
        select(SensorReading)
        .where(
            SensorReading.user_id == user_id,
            SensorReading.metric == "wrist_temp",
            SensorReading.recorded_at == stamp,
            SensorReading.source == "manual_bbt",
        )
    )
    if existing is None:
        db.add(
            SensorReading(
                user_id=user_id,
                metric="wrist_temp",
                value=section.temperature_celsius,
                delta=section.temperature_celsius,
                quality_score=1.0,
                source="manual_bbt",
                recorded_at=stamp,
            )
        )
    else:
        existing.value = section.temperature_celsius
        existing.delta = section.temperature_celsius
    wearable_stamp = combine_local_day_and_time(
        day=day,
        measured_at=section.measured_at,
        timezone_name=profile.timezone,
    )
    wearable_existing = db.scalar(
        select(WearableMetric).where(
            WearableMetric.user_id == user_id,
            WearableMetric.source == "manual",
            WearableMetric.metric_type == "basal_body_temperature",
            WearableMetric.measured_at == wearable_stamp,
        )
    )
    normalized = build_manual_bbt_metric(
        user_id=user_id,
        temperature_celsius=section.temperature_celsius,
        measured_at=wearable_stamp,
        timezone_name=profile.timezone,
        same_time_as_yesterday=section.same_time_as_yesterday,
        uninterrupted_sleep=section.uninterrupted_sleep,
        measured_before_getting_up=section.measured_before_getting_up,
        method=section.method,
        illness_flag=section.illness_flag,
        alcohol_flag=section.alcohol_flag,
        stress_flag=section.stress_flag,
        travel_flag=section.travel_flag,
    )
    if wearable_existing is None:
        db.add(normalized)
        return
    wearable_existing.value = normalized.value
    wearable_existing.unit = normalized.unit
    wearable_existing.collected_at = normalized.collected_at
    wearable_existing.is_morning_bbt_window = normalized.is_morning_bbt_window
    wearable_existing.is_user_entered = normalized.is_user_entered
    wearable_existing.confidence = normalized.confidence
    wearable_existing.excluded_from_ovulation_prediction = (
        normalized.excluded_from_ovulation_prediction
    )
    wearable_existing.exclusion_reason = normalized.exclusion_reason
    wearable_existing.raw_payload = normalized.raw_payload


def _is_same_period_window(cycle: CycleRecord, day: date) -> bool:
    if day < cycle.period_start_date:
        return False
    if cycle.period_end_date is not None:
        return day <= cycle.period_end_date + timedelta(days=2)
    expected_length = cycle.menses_length or 7
    max_window = max(7, min(expected_length, 10))
    return day <= cycle.period_start_date + timedelta(days=max_window - 1)


def _logs_for_day(*, db: Session, user_id: str, day: date) -> dict[LogType, DailyLog]:
    stmt = (
        select(DailyLog)
        .where(DailyLog.user_id == user_id, DailyLog.log_date == day)
        .order_by(desc(DailyLog.logged_at))
    )
    result: dict[LogType, DailyLog] = {}
    for row in db.scalars(stmt):
        result.setdefault(row.log_type, row)
    return result


def _payload_for(logs: dict[LogType, DailyLog], log_type: LogType, model_cls):
    row = logs.get(log_type)
    if row is None:
        return None
    return model_cls.model_validate(row.payload or {})


def _upsert_log(
    *,
    db: Session,
    user_id: str,
    day: date,
    log_type: LogType,
    data: dict,
    cycle_id: str | None = None,
) -> DailyLog:
    existing = db.scalar(
        select(DailyLog).where(
            DailyLog.user_id == user_id,
            DailyLog.log_date == day,
            DailyLog.log_type == log_type,
        )
    )
    if existing is None:
        existing = DailyLog(
            user_id=user_id,
            cycle_id=cycle_id or _active_cycle_id(db, user_id),
            log_date=day,
            log_type=log_type,
            payload=data,
        )
        db.add(existing)
        return existing
    existing.payload = {**(existing.payload or {}), **data}
    if cycle_id and not existing.cycle_id:
        existing.cycle_id = cycle_id
    return existing


def _active_cycle_id(db: Session, user_id: str) -> str | None:
    active = CycleRepository(db).active_for_user(user_id)
    return active.id if active else None


def _combine_day_and_optional_time(day: date, value) -> datetime:
    if value is None:
        return datetime(day.year, day.month, day.day, tzinfo=UTC)
    return datetime(day.year, day.month, day.day, value.hour, value.minute, tzinfo=UTC)
