from datetime import UTC, datetime, time as dt_time
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from phora.models import WearableMetric

_MORNING_BBT_START_HOUR = 3
_MORNING_BBT_END_HOUR = 7


def timezone_or_utc(timezone_name: str | None) -> ZoneInfo:
    if timezone_name:
        try:
            return ZoneInfo(timezone_name)
        except ZoneInfoNotFoundError:
            pass
    return ZoneInfo("UTC")


def is_morning_bbt_window(measured_at: datetime, timezone_name: str | None) -> bool:
    local_time = measured_at.astimezone(timezone_or_utc(timezone_name))
    return _MORNING_BBT_START_HOUR <= local_time.hour < _MORNING_BBT_END_HOUR


def combine_local_day_and_time(
    *,
    day,
    measured_at: dt_time | None,
    timezone_name: str | None,
) -> datetime:
    if measured_at is None:
        return datetime(day.year, day.month, day.day, tzinfo=UTC)
    local_zone = timezone_or_utc(timezone_name)
    local_value = datetime.combine(day, measured_at, tzinfo=local_zone)
    return local_value.astimezone(UTC)


def normalize_metric_source(source: str) -> str:
    normalized = (source or "").strip().lower()
    if normalized in {"gtl1", "phora_wear"}:
        return "phora_wear"
    if normalized in {"healthkit", "apple_watch"}:
        return "healthkit"
    if normalized in {"health_connect", "android_health"}:
        return "health_connect"
    if normalized in {"fitbit", "oura", "manual"}:
        return normalized
    if normalized == "manual_bbt":
        return "manual"
    return normalized or "manual"


def classify_data_source(source: str) -> str:
    """Map any source string to a canonical data_source value."""
    normalized = (source or "").strip().lower()
    if normalized in {"gtl1", "phora_wear", "vyla_wearable"}:
        return "vyla_wearable"
    if normalized in {"healthkit", "apple_watch", "apple_health"}:
        return "apple_health"
    if normalized in {"manual", "manual_bbt", "manual_entry"}:
        return "manual_entry"
    return "manual_entry"


def build_manual_bbt_metric(
    *,
    user_id: str,
    temperature_celsius: float,
    measured_at: datetime,
    timezone_name: str | None,
    same_time_as_yesterday: bool,
    uninterrupted_sleep: bool,
    measured_before_getting_up: bool,
    method: str | None,
    illness_flag: bool = False,
    alcohol_flag: bool = False,
    stress_flag: bool = False,
    travel_flag: bool = False,
) -> WearableMetric:
    in_window = is_morning_bbt_window(measured_at, timezone_name)
    exclusion_reason = None
    excluded = False

    if not in_window:
        excluded = True
        exclusion_reason = (
            "Temperature was not collected during the early-morning BBT window."
        )
    elif not uninterrupted_sleep:
        excluded = True
        exclusion_reason = "Temperature followed disrupted sleep."
    elif not measured_before_getting_up:
        excluded = True
        exclusion_reason = "Temperature was not taken before getting up."
    elif illness_flag:
        excluded = True
        exclusion_reason = "Illness may distort resting temperature."
    elif alcohol_flag:
        excluded = True
        exclusion_reason = "Alcohol may distort resting temperature."
    elif travel_flag:
        excluded = True
        exclusion_reason = "Travel may distort resting temperature."

    confidence = "high"
    if not same_time_as_yesterday or stress_flag:
        confidence = "medium"
    if excluded:
        confidence = "low"

    raw_payload = {
        "method": method or "unknown",
        "same_time_as_yesterday": same_time_as_yesterday,
        "uninterrupted_sleep": uninterrupted_sleep,
        "measured_before_getting_up": measured_before_getting_up,
        "illness_flag": illness_flag,
        "alcohol_flag": alcohol_flag,
        "stress_flag": stress_flag,
        "travel_flag": travel_flag,
    }

    return WearableMetric(
        user_id=user_id,
        source="manual",
        data_source="manual_entry",
        metric_type="basal_body_temperature",
        value=temperature_celsius,
        unit="celsius",
        measured_at=measured_at,
        collected_at=datetime.now(UTC),
        is_morning_bbt_window=in_window,
        is_user_entered=True,
        confidence=confidence,
        excluded_from_ovulation_prediction=excluded,
        exclusion_reason=exclusion_reason,
        raw_payload=raw_payload,
    )


def build_trend_metric(
    *,
    user_id: str,
    source: str,
    metric_type: str,
    value: float,
    unit: str,
    measured_at: datetime,
    collected_at: datetime | None = None,
    timezone_name: str | None = None,
    is_user_entered: bool = False,
    confidence: str = "medium",
    excluded_from_ovulation_prediction: bool = False,
    exclusion_reason: str | None = None,
    raw_payload: dict | None = None,
    data_source: str | None = None,
    external_id: str | None = None,
) -> WearableMetric:
    return WearableMetric(
        user_id=user_id,
        source=normalize_metric_source(source),
        data_source=data_source or classify_data_source(source),
        metric_type=metric_type,
        value=value,
        unit=unit,
        measured_at=measured_at,
        collected_at=collected_at or datetime.now(UTC),
        is_morning_bbt_window=is_morning_bbt_window(measured_at, timezone_name),
        is_user_entered=is_user_entered,
        confidence=confidence,
        excluded_from_ovulation_prediction=excluded_from_ovulation_prediction,
        exclusion_reason=exclusion_reason,
        raw_payload=raw_payload,
        external_id=external_id,
    )
