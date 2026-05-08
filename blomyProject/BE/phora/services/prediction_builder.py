from dataclasses import dataclass
from datetime import UTC, datetime
from statistics import median

from phora.models import (
    CycleRecord,
    DailyLog,
    SensorReading,
    StressScore,
    UserProfile,
    WearableMetric,
)
from phora.models.enums import WearableType
from phora.schemas.ml import MlEnsembleRequest, SignalAvailability, TemperatureSeriesPoint
from phora.services.age import age_on_day, derive_age_band, should_activate_perimenopause_mode


@dataclass
class PredictionInputBundle:
    profile: UserProfile
    cycle: CycleRecord
    logs: list[DailyLog]
    wearable_metrics: list[WearableMetric]
    temp_readings: list[SensorReading]
    rhr_readings: list[SensorReading]
    hrv_readings: list[SensorReading]
    sleep_readings: list[SensorReading]
    stress_scores: list[StressScore]


def _latest_payload(logs: list[DailyLog], log_type: str) -> dict | None:
    matches = [log for log in logs if log.log_type.value == log_type]
    return matches[-1].payload if matches else None


def _latest_per_day(readings: list[SensorReading]) -> list[SensorReading]:
    daily: dict[object, SensorReading] = {}
    for reading in sorted(readings, key=lambda item: item.recorded_at):
        daily[reading.recorded_at.date()] = reading
    return list(daily.values())


def _is_manual_bbt(reading: SensorReading) -> bool:
    return (reading.source or "").lower() in {"manual_bbt", "manual"}


def _temperature_readings_for_cusum(readings: list[SensorReading]) -> tuple[list[SensorReading], str | None]:
    daily = _latest_per_day(readings)
    manual = [reading for reading in daily if _is_manual_bbt(reading)]
    if manual:
        return manual[-30:], WearableType.MANUAL_BBT.value
    return [], None


def _temperature_metrics_for_prediction(
    metrics: list[WearableMetric],
) -> tuple[list[WearableMetric], str | None]:
    eligible = [
        metric
        for metric in metrics
        if not metric.excluded_from_ovulation_prediction
        and metric.is_morning_bbt_window
        and metric.metric_type in {"basal_body_temperature", "body_temperature"}
    ]
    daily: dict[object, WearableMetric] = {}
    for metric in sorted(eligible, key=lambda item: item.measured_at):
        daily[metric.measured_at.date()] = metric
    selected = list(daily.values())[-30:]
    source = selected[-1].source if selected else None
    return selected, source


def _baseline_delta_series(
    readings: list[SensorReading],
    *,
    absolute_threshold: float,
    existing_delta_limit: float,
) -> list[tuple[SensorReading, float]]:
    if not readings:
        return []
    values = [float(reading.value) for reading in readings]
    absolute_values = [value for value in values if abs(value) >= absolute_threshold]
    baseline = median(absolute_values[: min(6, len(absolute_values))]) if absolute_values else 0.0
    series: list[tuple[SensorReading, float]] = []
    for reading in readings:
        raw_delta = reading.delta
        value = float(reading.value)
        if raw_delta is not None and abs(float(raw_delta)) <= existing_delta_limit:
            delta = float(raw_delta)
        elif abs(value) >= absolute_threshold:
            delta = value - baseline
        else:
            delta = value
        series.append((reading, round(delta, 4)))
    return series


def _latest_delta(
    readings: list[SensorReading],
    *,
    absolute_threshold: float,
    existing_delta_limit: float,
) -> float | None:
    series = _baseline_delta_series(
        readings,
        absolute_threshold=absolute_threshold,
        existing_delta_limit=existing_delta_limit,
    )
    return series[-1][1] if series else None


def _metric_quality_score(metric: WearableMetric) -> float:
    if metric.confidence == "high":
        return 1.0
    if metric.confidence == "medium":
        return 0.75
    return 0.45


def build_ensemble_request(user_id: str, bundle: PredictionInputBundle, prediction_date: datetime | None = None) -> MlEnsembleRequest:
    prediction_dt = prediction_date or datetime.now(UTC)
    prediction_day = prediction_dt.date()
    cycle_day = (prediction_day - bundle.cycle.period_start_date).days + 1
    mu_cycle = bundle.cycle.mu_cycle or 28.0
    sigma_cycle = bundle.cycle.sigma_cycle or 2.5
    age = age_on_day(bundle.profile.date_of_birth, prediction_day)
    age_band = bundle.profile.age_band or derive_age_band(age)
    peri_active, peri_source = should_activate_perimenopause_mode(
        age_band,
        sigma_cycle,
        perimenopause_self_reported=bool(bundle.profile.conditions.get("perimenopause_self_reported")),
        conditions=bundle.profile.conditions,
    )
    if bundle.profile.perimenopause_mode_active:
        peri_active = True
        peri_source = bundle.profile.perimenopause_mode_source or peri_source

    temp_metrics, temp_metric_source = _temperature_metrics_for_prediction(
        bundle.wearable_metrics
    )
    temp_readings, legacy_temp_source = _temperature_readings_for_cusum(
        bundle.temp_readings
    )
    temp_source = temp_metric_source or legacy_temp_source
    rhr_readings = _latest_per_day(bundle.rhr_readings)
    hrv_readings = _latest_per_day(bundle.hrv_readings)
    sleep_readings = _latest_per_day(bundle.sleep_readings)

    if temp_metrics:
        values = [float(metric.value) for metric in temp_metrics]
        baseline = median(values[: min(6, len(values))]) if values else 0.0
        temp_delta_series = [
            (metric.measured_at.date(), round(float(metric.value) - baseline, 4), metric)
            for metric in temp_metrics
        ]
    else:
        legacy_delta_series = _baseline_delta_series(
            temp_readings,
            absolute_threshold=20.0,
            existing_delta_limit=5.0,
        )
        temp_delta_series = [
            (reading.recorded_at.date(), delta, reading)
            for reading, delta in legacy_delta_series
        ]
    temp_series = [
        TemperatureSeriesPoint(
            date=day,
            delta_temp=delta,
            quality_score=(
                _metric_quality_score(reading)
                if isinstance(reading, WearableMetric)
                else (
                    reading.quality_score
                    if reading.quality_score is not None
                    else 1.0
                )
            ),
            illness_flag=bool(
                isinstance(reading, WearableMetric)
                and (reading.raw_payload or {}).get("illness_flag")
            ),
            alcohol_flag=bool(
                isinstance(reading, WearableMetric)
                and (reading.raw_payload or {}).get("alcohol_flag")
            ),
        )
        for day, delta, reading in temp_delta_series
    ]

    lh_payload = _latest_payload(bundle.logs, "lh") or {}
    mucus_payload = _latest_payload(bundle.logs, "mucus") or {}
    avg_stress = round(sum(score.score for score in bundle.stress_scores) / len(bundle.stress_scores), 4) if bundle.stress_scores else None

    latest_temp = temp_metrics[-1] if temp_metrics else (temp_readings[-1] if temp_readings else None)
    latest_sleep = sleep_readings[-1] if sleep_readings else None
    sleep_quality = None
    if latest_sleep:
        sleep_quality = round(min(max(latest_sleep.value / 480.0, 0.0), 1.25), 4)

    return MlEnsembleRequest(
        user_id=user_id,
        cycle_id=bundle.cycle.id,
        prediction_date=prediction_day,
        cycle_day=cycle_day,
        cycle_day_norm=round(cycle_day / mu_cycle, 4),
        sigma_cycle=sigma_cycle,
        mu_cycle=mu_cycle,
        age=age,
        age_band=age_band,
        age_at_menarche=bundle.profile.age_at_menarche,
        bmi=bundle.profile.bmi,
        temp_source=temp_source,
        wearable_source=WearableType(bundle.profile.wearable_type).value if bundle.profile.wearable_type else None,
        temp_series=temp_series,
        stress_burden_7d=avg_stress,
        lh_surge_state=lh_payload.get("state"),
        lh_surge_day=lh_payload.get("cycle_day"),
        pcos_flag=bool(bundle.profile.conditions.get("pcos")),
        perimenopause_mode_active=peri_active,
        menses_length=bundle.cycle.menses_length,
        mucus_score=mucus_payload.get("score"),
        lh_proxy=lh_payload.get("ratio") or lh_payload.get("raw_value"),
        sleep_quality=sleep_quality
        if sleep_quality is not None
        else (
            1.0
            if isinstance(latest_temp, WearableMetric) and latest_temp.confidence == "high"
            else (
                latest_temp.quality_score
                if latest_temp is not None and not isinstance(latest_temp, WearableMetric)
                else None
            )
        ),
        delta_temp=temp_series[-1].delta_temp if temp_series else None,
        rhr_dev=_latest_delta(rhr_readings, absolute_threshold=25.0, existing_delta_limit=20.0),
        hrv_dev=_latest_delta(hrv_readings, absolute_threshold=10.0, existing_delta_limit=20.0),
        signal_availability=SignalAvailability(
            temp=bool(temp_metrics or temp_readings),
            rhr=bool(rhr_readings),
            hrv=bool(hrv_readings),
            lh=bool(lh_payload),
        ),
    )
