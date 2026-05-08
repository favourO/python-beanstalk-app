from collections import Counter
from datetime import UTC, date, time
from statistics import mean, pstdev

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_ml_client
from phora.db.session import get_db
from phora.models import CycleRecord, DailyLog, SensorReading
from phora.models.enums import LogType
from phora.repositories.core import AuditRepository, CycleRepository
from phora.services.ml_client import MlClient
from phora.schemas.cycle import (
    CycleStatsResponse,
    CycleTrendPoint,
    IntimacyLogRequest,
    LHLogHistoryItemResponse,
    LHLogHistoryResponse,
    LHLogRequest,
    MucusLogRequest,
    PeriodStartRequest,
    SymptomLogRequest,
    SymptomPatternsResponse,
)

router = APIRouter(prefix="/cycle", tags=["cycle"])


def _iso_utc(value) -> str:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC).isoformat()
    return value.astimezone(UTC).isoformat()


def _serialize_time(value: time | None) -> str | None:
    if value is None:
        return None
    return value.isoformat(timespec="minutes")


def _persist_lh_log(
    *,
    db: Session,
    user_id: str,
    cycle: CycleRecord,
    log_date: date,
    test_time: time | None,
    state: str | None,
    raw_value: float | None,
    ratio: float | None,
    positive: bool,
    extra_payload: dict | None = None,
) -> DailyLog:
    day = (log_date - cycle.period_start_date).days + 1
    payload = {
        "state": state,
        "raw_value": raw_value,
        "ratio": ratio,
        "positive": positive,
        "cycle_day": day,
    }
    if test_time is not None:
        payload["test_time"] = _serialize_time(test_time)
    if extra_payload:
        payload.update(extra_payload)
    log = DailyLog(
        user_id=user_id,
        cycle_id=cycle.id,
        log_date=log_date,
        log_type=LogType.LH,
        payload=payload,
    )
    db.add(log)
    if positive:
        cycle.lh_surge_detected_date = log_date
    return log


def _lh_log_history_item(log: DailyLog) -> LHLogHistoryItemResponse:
    payload = log.payload or {}
    return LHLogHistoryItemResponse(
        id=log.id,
        log_date=log.log_date,
        test_time=payload.get("test_time"),
        state=payload.get("state"),
        raw_value=payload.get("raw_value"),
        ratio=payload.get("ratio"),
        positive=bool(payload.get("positive", False)),
        cycle_day=payload.get("cycle_day"),
        source="image_analysis" if payload.get("strip_valid") else "manual",
        strip_valid=payload.get("strip_valid"),
        confidence=payload.get("result_confidence"),
        explanation=payload.get("explanation"),
        analysis_version=payload.get("analysis_version"),
        logged_at=_iso_utc(log.logged_at),
    )


@router.get("/stats", response_model=CycleStatsResponse)
def cycle_stats(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> CycleStatsResponse:
    cycles = (
        db.query(CycleRecord)
        .filter(CycleRecord.user_id == user_id)
        .order_by(CycleRecord.period_start_date.asc())
        .all()
    )
    logs = (
        db.query(DailyLog)
        .filter(DailyLog.user_id == user_id)
        .order_by(DailyLog.log_date.asc())
        .all()
    )
    temp_readings = (
        db.query(SensorReading)
        .filter(SensorReading.user_id == user_id, SensorReading.metric == "wrist_temp")
        .order_by(SensorReading.recorded_at.asc())
        .all()
    )
    hrv_readings = (
        db.query(SensorReading)
        .filter(SensorReading.user_id == user_id, SensorReading.metric == "hrv")
        .order_by(SensorReading.recorded_at.asc())
        .all()
    )

    cycle_lengths: list[int] = []
    for cycle in cycles:
        if cycle.cycle_length_days:
            cycle_lengths.append(cycle.cycle_length_days)
    for current, nxt in zip(cycles, cycles[1:]):
        if current.cycle_length_days:
            continue
        derived = (nxt.period_start_date - current.period_start_date).days
        if derived > 0:
            cycle_lengths.append(derived)

    period_lengths: list[int] = []
    for cycle in cycles:
        if cycle.menses_length:
            period_lengths.append(cycle.menses_length)
        elif cycle.period_end_date and cycle.period_end_date >= cycle.period_start_date:
            period_lengths.append((cycle.period_end_date - cycle.period_start_date).days + 1)

    regularity_score: float | None = None
    if cycle_lengths:
        if len(cycle_lengths) == 1:
            regularity_score = 1.0
        else:
            variability = pstdev(cycle_lengths)
            regularity_score = round(max(0.0, 1.0 - min(variability / 7.0, 1.0)), 2)

    symptom_logs = [log for log in logs if log.log_type == LogType.SYMPTOM]
    symptom_counts: Counter[str] = Counter()
    low_energy_days: list[int] = []
    for log in symptom_logs:
        payload = log.payload or {}
        symptom_counts.update(str(item) for item in payload.get("symptoms", []))
        if payload.get("energy_level") == "low" and payload.get("cycle_day") is not None:
            low_energy_days.append(int(payload["cycle_day"]))

    energy_dips = None
    if low_energy_days:
        start_day = min(low_energy_days)
        end_day = max(low_energy_days)
        energy_dips = f"Day {start_day}" if start_day == end_day else f"Day {start_day}-{end_day}"

    return CycleStatsResponse(
        tracked_cycles=len(cycles),
        first_period_start_date=cycles[0].period_start_date if cycles else None,
        average_cycle_length_days=round(mean(cycle_lengths), 1) if cycle_lengths else None,
        average_period_length_days=round(mean(period_lengths), 1) if period_lengths else None,
        regularity_score=regularity_score,
        temperature_trend=[
            CycleTrendPoint(
                recorded_at=_iso_utc(reading.recorded_at),
                value=round(float(reading.delta if reading.delta is not None else reading.value), 2),
            )
            for reading in temp_readings[-12:]
        ],
        hrv_trend=[
            CycleTrendPoint(recorded_at=_iso_utc(reading.recorded_at), value=round(float(reading.value), 2))
            for reading in hrv_readings[-12:]
        ],
        symptom_patterns=SymptomPatternsResponse(
            most_common=symptom_counts.most_common(1)[0][0] if symptom_counts else None,
            energy_dips=energy_dips,
        ),
    )


@router.post("/period/start")
def period_start(
    payload: PeriodStartRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    cycles = CycleRepository(db)
    active = cycles.active_for_user(user_id)
    if active:
        active.is_active = False
        if active.period_end_date is None:
            active.period_end_date = active.period_start_date
            active.menses_length = 1
    new_cycle = CycleRecord(user_id=user_id, period_start_date=payload.start_date, is_active=True)
    db.add(new_cycle)
    AuditRepository(db).log(user_id, "cycle.period_start", payload.model_dump(mode="json"))
    db.commit()
    return {"status": "ok", "cycle_id": new_cycle.id}


@router.post("/log/lh")
def log_lh(
    payload: LHLogRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    cycle = CycleRepository(db).active_for_user(user_id)
    if not cycle:
        raise HTTPException(status_code=400, detail="Active cycle required")
    log = _persist_lh_log(
        db=db,
        user_id=user_id,
        cycle=cycle,
        log_date=payload.log_date,
        test_time=payload.test_time,
        state=payload.state,
        raw_value=payload.raw_value,
        ratio=payload.ratio,
        positive=payload.positive,
    )
    AuditRepository(db).log(user_id, "cycle.lh_logged", payload.model_dump(mode="json"))
    db.commit()
    return {"status": "ok", "log_id": log.id}


@router.get("/log/lh/history", response_model=LHLogHistoryResponse)
def lh_history(
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> LHLogHistoryResponse:
    query = db.query(DailyLog).filter(DailyLog.user_id == user_id, DailyLog.log_type == LogType.LH)
    total = query.count()
    logs = query.order_by(DailyLog.log_date.desc(), DailyLog.logged_at.desc()).offset(offset).limit(limit).all()
    return LHLogHistoryResponse(
        items=[_lh_log_history_item(log) for log in logs],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.post("/log/lh/image")
async def log_lh_image(
    log_date: date = Form(...),
    test_time: time | None = Form(default=None),
    image: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    ml_client: MlClient = Depends(get_ml_client),
) -> dict:
    cycle = CycleRepository(db).active_for_user(user_id)
    if not cycle:
        raise HTTPException(status_code=400, detail="Active cycle required")

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Image is required")

    try:
        analysis = ml_client.analyze_lh_strip(image_bytes=image_bytes, content_type=image.content_type or "application/octet-stream")
    except RuntimeError as exc:
        AuditRepository(db).log(
            user_id,
            "cycle.lh_image_analysis_unavailable",
            {
                "log_date": log_date.isoformat(),
                "test_time": _serialize_time(test_time),
                "detail": str(exc),
            },
        )
        db.commit()
        return {
            "status": "manual_only",
            "strip_valid": None,
            "state": None,
            "positive": None,
            "ratio": None,
            "confidence": None,
            "explanation": "LH strip image analysis is unavailable in this deployment. Please log the result manually.",
            "analysis_version": None,
            "test_time": _serialize_time(test_time),
            "manual_entry_required": True,
        }

    if not analysis.strip_valid:
        AuditRepository(db).log(
            user_id,
            "cycle.lh_rejected_from_image",
            {
                "log_date": log_date.isoformat(),
                "test_time": _serialize_time(test_time),
                "state": analysis.state,
                "strip_valid": analysis.strip_valid,
                "strip_confidence": analysis.strip_confidence,
                "result_confidence": analysis.result_confidence,
                "explanation": analysis.explanation,
                "analysis_version": analysis.analysis_version,
            },
        )
        db.commit()
        return {
            "status": "rejected",
            "strip_valid": False,
            "state": analysis.state,
            "confidence": analysis.strip_confidence,
            "explanation": analysis.explanation,
            "analysis_version": analysis.analysis_version,
            "test_time": _serialize_time(test_time),
        }

    log = _persist_lh_log(
        db=db,
        user_id=user_id,
        cycle=cycle,
        log_date=log_date,
        test_time=test_time,
        state=analysis.state,
        raw_value=None,
        ratio=analysis.ratio,
        positive=analysis.positive,
        extra_payload={
            "strip_valid": analysis.strip_valid,
            "strip_confidence": analysis.strip_confidence,
            "result_confidence": analysis.result_confidence,
            "explanation": analysis.explanation,
            "analysis_version": analysis.analysis_version,
        },
    )
    AuditRepository(db).log(
        user_id,
        "cycle.lh_logged_from_image",
        {
            "log_date": log_date.isoformat(),
            "test_time": _serialize_time(test_time),
            "state": analysis.state,
            "ratio": analysis.ratio,
            "positive": analysis.positive,
            "strip_valid": analysis.strip_valid,
            "strip_confidence": analysis.strip_confidence,
            "result_confidence": analysis.result_confidence,
            "analysis_version": analysis.analysis_version,
        },
    )
    db.commit()
    return {
        "status": "ok",
        "log_id": log.id,
        "strip_valid": True,
        "state": analysis.state,
        "positive": analysis.positive,
        "ratio": analysis.ratio,
        "confidence": analysis.result_confidence,
        "explanation": analysis.explanation,
        "analysis_version": analysis.analysis_version,
        "test_time": _serialize_time(test_time),
    }


@router.post("/log/mucus")
def log_mucus(
    payload: MucusLogRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    cycle = CycleRepository(db).active_for_user(user_id)
    if not cycle:
        raise HTTPException(status_code=400, detail="Active cycle required")
    log = DailyLog(
        user_id=user_id,
        cycle_id=cycle.id,
        log_date=payload.log_date,
        log_type=LogType.MUCUS,
        payload={"score": payload.score},
    )
    db.add(log)
    db.commit()
    return {"status": "ok", "log_id": log.id}


@router.post("/symptom-log")
def log_symptoms(
    payload: SymptomLogRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    cycle = CycleRepository(db).active_for_user(user_id)
    if not cycle:
        raise HTTPException(status_code=400, detail="Active cycle required")
    day = (payload.log_date - cycle.period_start_date).days + 1
    log = DailyLog(
        user_id=user_id,
        cycle_id=cycle.id,
        log_date=payload.log_date,
        log_type=LogType.SYMPTOM,
        payload={
            "symptoms": payload.symptoms,
            "severity": payload.severity,
            "notes": payload.notes,
            "cycle_day": day,
            **payload.metadata,
        },
    )
    db.add(log)
    AuditRepository(db).log(user_id, "cycle.symptoms_logged", payload.model_dump(mode="json"))
    db.commit()
    return {"status": "ok", "log_id": log.id, "symptoms": payload.symptoms}


@router.post("/intimacy-log")
def log_intimacy(
    payload: IntimacyLogRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> dict:
    cycle = CycleRepository(db).active_for_user(user_id)
    if not cycle:
        raise HTTPException(status_code=400, detail="Active cycle required")
    day = (payload.log_date - cycle.period_start_date).days + 1
    log = DailyLog(
        user_id=user_id,
        cycle_id=cycle.id,
        log_date=payload.log_date,
        log_type=LogType.INTERCOURSE,
        payload={
            "had_intimacy": payload.had_intimacy,
            "protection_used": payload.protection_used,
            "ejaculation": payload.ejaculation,
            "partner_gender": payload.partner_gender,
            "notes": payload.notes,
            "cycle_day": day,
            **payload.metadata,
        },
    )
    db.add(log)
    AuditRepository(db).log(user_id, "cycle.intimacy_logged", payload.model_dump(mode="json"))
    db.commit()
    return {"status": "ok", "log_id": log.id}
