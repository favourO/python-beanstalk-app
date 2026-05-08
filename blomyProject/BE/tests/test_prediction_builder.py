from datetime import UTC, date, datetime

from phora.models import CycleRecord, SensorReading, StressScore, UserProfile, WearableMetric
from phora.models.enums import Goal, WearableType
from phora.services.prediction_builder import PredictionInputBundle, build_ensemble_request


def test_build_ensemble_request_populates_expected_fields():
    profile = UserProfile(
        user_id="user-1",
        date_of_birth=date(1995, 1, 1),
        age_at_menarche=12,
        bmi=24.1,
        goal=Goal.TRACK,
        conditions={"pcos": False},
        wearable_type=WearableType.FITBIT,
        age_band="B",
        perimenopause_mode_active=False,
    )
    cycle = CycleRecord(
        id="cycle-1",
        user_id="user-1",
        period_start_date=date(2026, 4, 1),
        mu_cycle=28.0,
        sigma_cycle=2.5,
        menses_length=5,
        is_active=True,
    )
    temp_reading = SensorReading(
        user_id="user-1",
        metric="wrist_temp",
        value=0.14,
        delta=0.14,
        quality_score=1.0,
        source="fitbit",
        recorded_at=datetime(2026, 4, 4, tzinfo=UTC),
    )
    rhr = SensorReading(
        user_id="user-1",
        metric="rhr",
        value=0.2,
        delta=0.2,
        quality_score=1.0,
        source="fitbit",
        recorded_at=datetime(2026, 4, 4, tzinfo=UTC),
    )
    hrv = SensorReading(
        user_id="user-1",
        metric="hrv",
        value=-0.1,
        delta=-0.1,
        quality_score=1.0,
        source="fitbit",
        recorded_at=datetime(2026, 4, 4, tzinfo=UTC),
    )
    sleep = SensorReading(
        user_id="user-1",
        metric="sleep_minutes",
        value=450,
        delta=450,
        quality_score=1.0,
        source="fitbit",
        recorded_at=datetime(2026, 4, 4, tzinfo=UTC),
    )
    stress = StressScore(user_id="user-1", score=0.2, recorded_at=datetime(2026, 4, 4, tzinfo=UTC))
    bundle = PredictionInputBundle(
        profile,
        cycle,
        [],
        [],
        [temp_reading],
        [rhr],
        [hrv],
        [sleep],
        [stress],
    )

    payload = build_ensemble_request("user-1", bundle, prediction_date=datetime(2026, 4, 4, tzinfo=UTC))

    assert payload.cycle_day == 4
    assert payload.cycle_day_norm == round(4 / 28.0, 4)
    assert payload.age_band == "B"
    assert payload.stress_burden_7d == 0.2
    assert payload.signal_availability.temp is False
    assert payload.delta_temp is None
    assert payload.rhr_dev == 0.2
    assert payload.hrv_dev == -0.1
    assert payload.sleep_quality == round(450 / 480, 4)


def test_build_ensemble_request_ignores_wrist_temperature_for_ovulation_prediction():
    profile = UserProfile(
        user_id="user-1",
        wearable_type=WearableType.GTL1,
        conditions={},
        age_band="B",
    )
    cycle = CycleRecord(
        id="cycle-1",
        user_id="user-1",
        period_start_date=date(2026, 4, 1),
        mu_cycle=28.0,
        sigma_cycle=2.5,
        menses_length=5,
        is_active=True,
    )
    temps = [
        SensorReading(
            user_id="user-1",
            metric="wrist_temp",
            value=value,
            delta=value,
            source="gtl1",
            recorded_at=datetime(2026, 4, day, tzinfo=UTC),
        )
        for day, value in [(1, 36.1), (2, 36.0), (3, 36.2), (4, 36.3), (5, 36.2), (6, 36.5)]
    ]
    bundle = PredictionInputBundle(profile, cycle, [], [], temps, [], [], [], [])

    payload = build_ensemble_request("user-1", bundle, prediction_date=datetime(2026, 4, 6, tzinfo=UTC))

    assert payload.temp_source is None
    assert payload.temp_series == []
    assert payload.delta_temp is None
    assert payload.signal_availability.temp is False


def test_build_ensemble_request_converts_normalized_wearable_metrics_to_deviations():
    profile = UserProfile(
        user_id="user-1",
        wearable_type=WearableType.GTL1,
        conditions={},
        age_band="B",
    )
    cycle = CycleRecord(
        id="cycle-1",
        user_id="user-1",
        period_start_date=date(2026, 4, 1),
        mu_cycle=28.0,
        sigma_cycle=2.5,
        menses_length=5,
        is_active=True,
    )
    temps = [
        WearableMetric(
            user_id="user-1",
            source="healthkit",
            metric_type="body_temperature",
            value=value,
            unit="celsius",
            measured_at=datetime(2026, 4, day, 6, tzinfo=UTC),
            is_morning_bbt_window=True,
            confidence="high",
        )
        for day, value in [(1, 36.1), (2, 36.0), (3, 36.2), (4, 36.3), (5, 36.2), (6, 36.5)]
    ]
    rhr = [
        SensorReading(user_id="user-1", metric="rhr", value=value, delta=value, recorded_at=datetime(2026, 4, day, tzinfo=UTC))
        for day, value in [(1, 64), (2, 65), (3, 66)]
    ]
    hrv = [
        SensorReading(user_id="user-1", metric="hrv", value=value, delta=value, recorded_at=datetime(2026, 4, day, tzinfo=UTC))
        for day, value in [(1, 45), (2, 44), (3, 40)]
    ]
    bundle = PredictionInputBundle(profile, cycle, [], temps, [], rhr, hrv, [], [])

    payload = build_ensemble_request("user-1", bundle, prediction_date=datetime(2026, 4, 6, tzinfo=UTC))

    assert payload.temp_series[-1].delta_temp == 0.3
    assert payload.delta_temp == 0.3
    assert payload.rhr_dev == 1
    assert payload.hrv_dev == -4


def test_build_ensemble_request_requires_enough_wearable_temperature_days_for_cusum_series():
    profile = UserProfile(
        user_id="user-1",
        wearable_type=WearableType.GTL1,
        conditions={},
        age_band="B",
    )
    cycle = CycleRecord(
        id="cycle-1",
        user_id="user-1",
        period_start_date=date(2026, 4, 16),
        mu_cycle=28.0,
        sigma_cycle=2.5,
        menses_length=5,
        is_active=True,
    )
    temps = [
        SensorReading(user_id="user-1", metric="wrist_temp", value=36.3, delta=36.3, recorded_at=datetime(2026, 4, 27, 0, minute, tzinfo=UTC))
        for minute in [0, 1, 2, 3]
    ]
    bundle = PredictionInputBundle(profile, cycle, [], [], temps, [], [], [], [])

    payload = build_ensemble_request("user-1", bundle, prediction_date=datetime(2026, 4, 27, tzinfo=UTC))

    assert payload.temp_series == []
    assert payload.delta_temp is None
    assert payload.signal_availability.temp is False


def test_build_ensemble_request_uses_manual_bbt_before_wearable_temperature():
    profile = UserProfile(
        user_id="user-1",
        wearable_type=WearableType.GTL1,
        conditions={},
        age_band="B",
    )
    cycle = CycleRecord(
        id="cycle-1",
        user_id="user-1",
        period_start_date=date(2026, 4, 16),
        mu_cycle=28.0,
        sigma_cycle=2.5,
        menses_length=5,
        is_active=True,
    )
    temps = [
        SensorReading(user_id="user-1", metric="wrist_temp", value=36.3, delta=36.3, source="gtl1", recorded_at=datetime(2026, 4, 26, tzinfo=UTC)),
        SensorReading(user_id="user-1", metric="wrist_temp", value=36.7, delta=36.7, source="manual_bbt", recorded_at=datetime(2026, 4, 27, 6, 30, tzinfo=UTC)),
    ]
    bundle = PredictionInputBundle(profile, cycle, [], [], temps, [], [], [], [])

    payload = build_ensemble_request("user-1", bundle, prediction_date=datetime(2026, 4, 27, tzinfo=UTC))

    assert payload.temp_source == "manual_bbt"
    assert len(payload.temp_series) == 1
    assert payload.delta_temp == 0
    assert payload.signal_availability.temp is True
