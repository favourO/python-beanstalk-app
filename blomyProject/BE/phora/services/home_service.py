from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy.orm import Session

from phora.services.home_i18n import translate as _t

from phora.core.config import Settings
from phora.models import CycleRecord, DailyLog, StressScore, User, WearableMetric
from phora.models.enums import CyclePhase, LogType, WearableType
from phora.repositories.core import CycleRepository, PredictionRepository, SensorRepository, UserRepository
from phora.schemas.home import (
    HomeAlertResponse,
    HomeCycleInsightResponse,
    HomeCyclePredictionImpactResponse,
    HomeDeviceTrendPointResponse,
    HomeDeviceTrendResponse,
    HomeFertilityResponse,
    HomeFitnessGuidanceResponse,
    HomeHealthSnapshotResponse,
    HomeMainStatusResponse,
    HomeQuickActionResponse,
    HomeResponse,
    HomeTodayFocusResponse,
    HomeUserResponse,
)
from phora.schemas.prediction import PredictionSnapshotResponse
from phora.services.ml_client import MlClient
from phora.services.daily_insights import DailyInsightService
from phora.services.prediction_service import PREDICTION_INPUT_PIPELINE_VERSION, PredictionService


CYCLE_AWARENESS_DISCLAIMER = _t("en", "cycle_awareness_disclaimer")
SIGNAL_CHECK_DISCLAIMER = _t("en", "signal_check_disclaimer")


class HomeService:
    def __init__(self, db: Session, settings: Settings, ml_client: MlClient):
        self.db = db
        self.settings = settings
        self.ml_client = ml_client
        self.users = UserRepository(db)
        self.cycles = CycleRepository(db)
        self.sensors = SensorRepository(db)
        self.predictions = PredictionRepository(db)

    @staticmethod
    def _now_utc() -> datetime:
        return datetime.now(UTC)

    def get_home_payload(self, user_id: str, locale: str = "en") -> HomeResponse:
        user = self.db.query(User).filter(User.id == user_id).one()
        profile = self.users.ensure_profile(user_id)
        cycle = self.cycles.active_for_user(user_id)
        if not cycle:
            raise ValueError("Active cycle not found")

        prediction = self._current_prediction(user_id, profile.timezone)
        local_today = self._local_today(profile.timezone)
        cycle_day = max(1, (local_today - cycle.period_start_date).days + 1)
        next_period_date = self._parse_date(prediction.next_period_estimate.get("date"))
        fertile_start = self._parse_date(prediction.fertile_window.get("start"))
        fertile_end = self._parse_date(prediction.fertile_window.get("end"))
        ovulation_date = self._parse_date(prediction.ovulation_estimate.get("date"))
        tracked_cycles = self._tracked_cycles(user_id)

        source_filter = self._wearable_source_filter(profile.wearable_type)
        sleep = self._latest_sensor(user_id, "sleep_minutes", source=source_filter)
        steps = self._latest_sensor(user_id, "steps", source=source_filter)
        sleep_deep = self._latest_sensor(user_id, "sleep_deep_minutes", source=source_filter)
        sleep_light = self._latest_sensor(user_id, "sleep_light_minutes", source=source_filter)
        sleep_awake = self._latest_sensor(user_id, "sleep_awake_minutes", source=source_filter)
        rhr = self._latest_sensor(user_id, "rhr", source=source_filter)
        blood_oxygen_avg = self._latest_sensor(user_id, "blood_oxygen_avg", source=source_filter)
        blood_oxygen_min = self._latest_sensor(user_id, "blood_oxygen_min", source=source_filter)
        stress = self._latest_stress(user_id)
        hrv = self._latest_sensor(user_id, "hrv", source=source_filter)
        temp = self._latest_sensor(user_id, "wrist_temp", source=source_filter)
        recent_logs = self.cycles.recent_logs(user_id, days=7)

        health_snapshot = self._build_health_snapshot(
            user_id,
            profile.wearable_type,
            sleep,
            sleep_deep,
            sleep_light,
            sleep_awake,
            steps,
            rhr,
            blood_oxygen_avg,
            blood_oxygen_min,
            stress,
            hrv,
            temp,
            locale=locale,
        )
        device_trends = self._build_device_trends(user_id, source=source_filter)
        cycle_prediction_impact = self._build_cycle_prediction_impact(
            cycle=cycle,
            prediction=prediction,
            health_snapshot=health_snapshot,
        )
        device_cycle_insights = self._build_device_cycle_insights(
            prediction=prediction,
            health_snapshot=health_snapshot,
            device_trends=device_trends,
            cycle_prediction_impact=cycle_prediction_impact,
            fertile_start=fertile_start,
            fertile_end=fertile_end,
            ovulation_date=ovulation_date,
            next_period_date=next_period_date,
            local_today=local_today,
        )
        today_focus = self._build_today_focus(
            prediction=prediction,
            cycle_day=cycle_day,
            local_today=local_today,
            fertile_start=fertile_start,
            fertile_end=fertile_end,
            next_period_date=next_period_date,
            recent_logs=recent_logs,
            health_snapshot=health_snapshot,
        )
        daily_insight = DailyInsightService(self.db, self.settings).get_or_generate(
            user_id=user_id,
            insight_date=local_today,
            phase=prediction.current_phase,
            cycle_day=cycle_day,
        )
        today_focus = self._merge_daily_insight(today_focus, daily_insight)
        fitness = self._build_fitness_guidance(prediction.current_phase, recent_logs, health_snapshot)
        alerts = self._build_alerts(
            tracked_cycles=tracked_cycles,
            wearable_type=profile.wearable_type,
            health_snapshot=health_snapshot,
            locale=locale,
        )

        return HomeResponse(
            user=HomeUserResponse(
                id=user_id,
                first_name=self._resolve_first_name(profile),
            ),
            main_status=HomeMainStatusResponse(
                current_cycle_day=cycle_day,
                current_phase=self._normalize_phase(prediction.current_phase),
                current_phase_raw=prediction.current_phase,
                next_predicted_period_date=next_period_date,
                countdown_to_next_period_days=max(0, (next_period_date - local_today).days) if next_period_date else None,
                prediction_confidence=self._confidence_label(prediction.confidence, tracked_cycles, health_snapshot),
                prediction_confidence_score=round(prediction.confidence, 2),
                cycle_length_days=self._resolve_cycle_length(cycle),
                period_length_days=cycle.menses_length,
            ),
            fertility=HomeFertilityResponse(
                fertile_today=bool(
                    fertile_start and fertile_end and fertile_start <= local_today <= fertile_end
                ),
                fertile_window_start=fertile_start,
                fertile_window_end=fertile_end,
                predicted_ovulation_date=ovulation_date,
                prediction_method=prediction.audit.get("ovulation_estimate_source"),
            ),
            today_focus=today_focus,
            fitness_guidance=fitness,
            health_snapshot=health_snapshot,
            device_cycle_insights=device_cycle_insights,
            device_trends=device_trends,
            cycle_prediction_impact=cycle_prediction_impact,
            prediction_disclaimer=_t(locale, "cycle_awareness_disclaimer"),
            quick_actions=[
                HomeQuickActionResponse(type="log_period", label=_t(locale, "qa_log_period")),
                HomeQuickActionResponse(type="log_cramps", label=_t(locale, "qa_log_cramps")),
                HomeQuickActionResponse(type="log_mood", label=_t(locale, "qa_log_mood")),
                HomeQuickActionResponse(type="log_discharge", label=_t(locale, "qa_log_discharge")),
                HomeQuickActionResponse(type="log_sleep", label=_t(locale, "qa_log_sleep")),
                HomeQuickActionResponse(type="log_workout", label=_t(locale, "qa_log_workout")),
            ],
            alerts=alerts,
        )

    def _build_cycle_prediction_impact(
        self,
        *,
        cycle,
        prediction: PredictionSnapshotResponse,
        health_snapshot: HomeHealthSnapshotResponse,
    ) -> HomeCyclePredictionImpactResponse:
        cycle_length = self._resolve_cycle_length(cycle) or int(round(cycle.mu_cycle or 28))
        before_ovulation_day = max(1, cycle_length - 14)
        before_ovulation_date = cycle.period_start_date + timedelta(days=before_ovulation_day - 1)
        before_period_date = cycle.period_start_date + timedelta(days=cycle_length)
        after_ovulation_date = self._parse_date(prediction.ovulation_estimate.get("date"))
        after_period_date = self._parse_date(prediction.next_period_estimate.get("date"))
        signals: list[str] = []
        if health_snapshot.sleep_hours is not None:
            signals.append("sleep")
        if health_snapshot.resting_heart_rate is not None:
            signals.append("resting_heart_rate")
        if health_snapshot.hrv is not None:
            signals.append("hrv")
        if health_snapshot.blood_oxygen_avg is not None:
            signals.append("blood_oxygen")
        if health_snapshot.stress_avg is not None:
            signals.append("stress")
        confidence_before = 0.35
        confidence_after = round(prediction.confidence, 2)
        method = prediction.audit.get("ovulation_estimate_source")
        if signals:
            explanation = "Sleep, heart rate, and related wearable signals are included in the current prediction alongside cycle history."
        elif "temperature" in health_snapshot.cycle_support_signals:
            explanation = "Temperature is shown as a recovery signal and does not shift ovulation timing on its own."
        else:
            explanation = "Current prediction is still mostly calendar-based until wearable body signals are available."
        return HomeCyclePredictionImpactResponse(
            before_ovulation_date=before_ovulation_date,
            before_period_date=before_period_date,
            after_ovulation_date=after_ovulation_date,
            after_period_date=after_period_date,
            confidence_before=confidence_before,
            confidence_after=confidence_after,
            confidence_delta=round(confidence_after - confidence_before, 2),
            method=method,
            contributing_signals=signals,
            explanation=explanation,
        )

    def _build_device_cycle_insights(
        self,
        *,
        prediction: PredictionSnapshotResponse,
        health_snapshot: HomeHealthSnapshotResponse,
        device_trends: list[HomeDeviceTrendResponse],
        cycle_prediction_impact: HomeCyclePredictionImpactResponse,
        fertile_start: date | None,
        fertile_end: date | None,
        ovulation_date: date | None,
        next_period_date: date | None,
        local_today: date,
    ) -> list[HomeCycleInsightResponse]:
        insights: list[HomeCycleInsightResponse] = []
        confidence = self._calculate_cycle_signal_confidence(health_snapshot, device_trends)
        sleep_hours = health_snapshot.sleep_hours
        deep_sleep = health_snapshot.sleep_deep_minutes
        temp_delta = health_snapshot.temperature_delta_c
        spo2 = health_snapshot.blood_oxygen_avg
        stress_avg = health_snapshot.stress_avg

        rhr_latest, rhr_baseline = self._trend_latest_and_baseline(device_trends, "rhr")
        steps_latest, steps_baseline = self._trend_latest_and_baseline(device_trends, "steps")
        rhr_elevated = (
            rhr_latest is not None
            and rhr_baseline is not None
            and rhr_latest >= rhr_baseline + 5
        )
        resting_hr_stable = (
            rhr_latest is not None
            and rhr_baseline is not None
            and rhr_latest <= rhr_baseline + 2
        )
        steps_healthy = (
            steps_latest is not None
            and ((steps_baseline is not None and steps_latest >= max(steps_baseline * 0.8, 5000)) or steps_latest >= 7000)
        )
        temperature_outlier = temp_delta is not None and abs(temp_delta) >= 0.4
        low_sleep = sleep_hours is not None and sleep_hours < 6.0
        strong_sleep = sleep_hours is not None and sleep_hours >= 7.0
        strong_deep_sleep = deep_sleep is not None and deep_sleep >= 90
        low_deep_sleep = deep_sleep is not None and 0 < deep_sleep < 60

        if fertile_start and fertile_end and fertile_start <= local_today <= fertile_end:
            insights.append(
                self._insight(
                    id="ovulation_window",
                    type="ovulation_window",
                    title="Fertile window estimate is active",
                    summary="Your cycle timing suggests you may be in your fertile window today.",
                    advice="Use this as a cycle-awareness estimate only and keep tracking for a clearer pattern.",
                    cycle_impact="Vyla may update this window as more cycle and wearable data arrives.",
                    confidence=confidence,
                    severity="positive" if confidence != "low" else "neutral",
                    source_signals=["ovulation_window", "combined_cycle"],
                )
            )
        elif ovulation_date is not None:
            insights.append(
                self._insight(
                    id="ovulation_window",
                    type="ovulation_window",
                    title="Ovulation estimate is still a forecast",
                    summary=f"Vyla currently estimates your next ovulation window around {ovulation_date.isoformat()}.",
                    advice="Continue logging symptoms and overnight wearable data to improve this estimate.",
                    cycle_impact="This estimate may shift as new body-signal patterns appear.",
                    confidence=confidence,
                    severity="neutral",
                    source_signals=["ovulation_window"],
                )
            )

        if (
            cycle_prediction_impact.before_period_date
            and cycle_prediction_impact.after_period_date
            and cycle_prediction_impact.before_period_date != cycle_prediction_impact.after_period_date
        ):
            insights.append(
                self._insight(
                    id="period_shift",
                    type="period_shift",
                    title="Your period estimate has been updated",
                    summary="New cycle and wearable context suggests your next period estimate has shifted.",
                    advice="Keep logging your cycle so Vyla can stabilise this estimate over time.",
                    cycle_impact=(
                        f"Your period estimate moved from {cycle_prediction_impact.before_period_date.isoformat()} "
                        f"to {cycle_prediction_impact.after_period_date.isoformat()}."
                    ),
                    confidence=confidence,
                    severity="neutral",
                    source_signals=["period_shift", "combined_cycle"],
                )
            )
        elif next_period_date is not None:
            insights.append(
                self._insight(
                    id="period_shift",
                    type="period_shift",
                    title="Your next period estimate is holding steady",
                    summary="There is no strong signal-driven change to your next period estimate right now.",
                    advice="Continue wearing your device and logging cycle events for stronger trend quality.",
                    cycle_impact=f"Vyla still estimates your next period around {next_period_date.isoformat()}.",
                    confidence=confidence,
                    severity="neutral",
                    source_signals=["period_shift"],
                )
            )

        if temp_delta is None:
            insights.append(
                self._insight(
                    id="temperature_baseline",
                    type="data_quality",
                    title="Temperature baseline is still building",
                    summary="We need more overnight temperature readings before using temperature strongly in your cycle context.",
                    advice="Wear your device overnight consistently so Vyla can compare readings with your personal baseline.",
                    cycle_impact="Your cycle estimates currently lean more on cycle history and non-temperature signals.",
                    confidence="low",
                    severity="neutral",
                    source_signals=["temperature", "data_quality"],
                )
            )
        elif temperature_outlier:
            insights.append(
                self._insight(
                    id="temperature_outlier",
                    type="temperature",
                    title="Temperature reading looks unusual",
                    summary="Your temperature is higher than your usual recent pattern and may reflect strain rather than cycle timing.",
                    advice="Illness, poor sleep, alcohol, stress, travel, or device fit can distort one night of temperature data.",
                    cycle_impact="Vyla will treat this reading cautiously and will not use it alone to shift ovulation timing.",
                    confidence="low",
                    severity="caution",
                    source_signals=["temperature"],
                )
            )
        elif temp_delta >= 0.15 and strong_sleep and not rhr_elevated:
            insights.append(
                self._insight(
                    id="temperature_rise",
                    type="temperature",
                    title="Temperature trend may reflect a post-ovulation pattern",
                    summary="Your overnight temperature is slightly above baseline and your recovery signals look steadier today.",
                    advice="A single rise does not confirm ovulation. Keep tracking for a pattern over several days.",
                    cycle_impact="Vyla uses this as cycle context only and not as stand-alone ovulation confirmation.",
                    confidence="medium" if confidence == "high" else confidence,
                    severity="positive",
                    source_signals=["temperature", "sleep", "resting_hr"],
                )
            )
        else:
            insights.append(
                self._insight(
                    id="temperature_stable",
                    type="temperature",
                    title="Temperature is close to your baseline",
                    summary="Your overnight temperature looks relatively steady compared with your recent pattern.",
                    advice="Keep collecting overnight readings so Vyla can detect more meaningful changes over time.",
                    cycle_impact="No strong temperature-driven cycle update is suggested from this reading alone.",
                    confidence="medium" if confidence == "high" else confidence,
                    severity="neutral",
                    source_signals=["temperature"],
                )
            )

        if strong_sleep:
            insights.append(
                self._insight(
                    id="sleep_support",
                    type="sleep",
                    title="Good sleep is supporting your cycle awareness",
                    summary="Your sleep duration looks strong enough to support recovery and more reliable wearable context.",
                    advice="Consistent sleep can support recovery, energy, and steadier cycle-signal interpretation.",
                    cycle_impact="This supports higher confidence in today’s body-signal insights.",
                    confidence="medium" if confidence == "low" else confidence,
                    severity="positive",
                    source_signals=["sleep"],
                )
            )

        if stress_avg is not None and stress_avg > 0:
            if stress_avg >= 65:
                title = "Stress may be adding cycle noise"
                summary = "Your stress signal is elevated today, which can make ovulation and period timing harder to interpret."
                advice = "Prioritise rest, hydration, lighter movement, and consistent sleep where possible."
                cycle_impact = "Higher stress can affect sleep and recovery patterns, so Vyla treats today’s ovulation and period estimates with more caution."
                severity = "caution"
                stress_confidence = "medium"
            elif stress_avg >= 35:
                title = "Stress may influence today’s cycle context"
                summary = "Your stress signal is present today and may shape how reliable some body signals look."
                advice = "Keep wearing your device and use gentle recovery habits to help Vyla separate stress from cycle patterns."
                cycle_impact = "Stress can contribute to noisier temperature, heart-rate, and sleep signals, which may affect ovulation and period confidence."
                severity = "neutral"
                stress_confidence = "medium"
            else:
                title = "Stress is part of today’s body context"
                summary = "Your stress signal is low, but Vyla still includes it when interpreting cycle-related body signals."
                advice = "Maintain steady sleep, meals, hydration, and movement to keep cycle signals easier to read."
                cycle_impact = "Lower stress is generally more supportive for stable cycle interpretation, but it does not confirm ovulation or period timing."
                severity = "positive"
                stress_confidence = "low" if confidence == "low" else "medium"
            insights.append(
                self._insight(
                    id="stress_cycle_context",
                    type="stress",
                    title=title,
                    summary=summary,
                    advice=advice,
                    cycle_impact=cycle_impact,
                    confidence=stress_confidence,
                    severity=severity,
                    source_signals=["stress"],
                )
            )
        if low_sleep:
            insights.append(
                self._insight(
                    id="sleep_low",
                    type="sleep",
                    title="Sleep was lower than usual",
                    summary="Short sleep can make temperature and heart-rate signals harder to interpret cleanly.",
                    advice="Prioritise recovery today and avoid overinterpreting one night of wearable data.",
                    cycle_impact="Vyla may lower confidence in today’s cycle-signal interpretation.",
                    confidence="medium",
                    severity="caution",
                    source_signals=["sleep"],
                )
            )

        if strong_deep_sleep:
            insights.append(
                self._insight(
                    id="deep_sleep_good",
                    type="deep_sleep",
                    title="Deep sleep suggests better recovery",
                    summary="Your deep sleep looks strong enough to support overnight recovery today.",
                    advice="Good overnight recovery can make temperature and resting heart-rate context easier to trust.",
                    cycle_impact="This can support steadier interpretation of your other wearable signals.",
                    confidence="medium",
                    severity="positive",
                    source_signals=["deep_sleep", "sleep"],
                )
            )
        elif low_deep_sleep:
            insights.append(
                self._insight(
                    id="deep_sleep_low",
                    type="deep_sleep",
                    title="Recovery may be lighter today",
                    summary="Lower deep sleep can be linked to lighter recovery and more signal noise the next day.",
                    advice="Keep movement gentler today and prioritise rest if energy feels lower.",
                    cycle_impact="Vyla will treat today’s temperature and resting-HR context more cautiously.",
                    confidence="medium",
                    severity="caution",
                    source_signals=["deep_sleep", "sleep"],
                )
            )

        if rhr_elevated:
            insights.append(
                self._insight(
                    id="resting_hr_high",
                    type="resting_hr",
                    title="Resting heart rate looks elevated",
                    summary="Your resting heart rate is above its recent pattern, which can happen when your body is under strain.",
                    advice="Stress, poor sleep, illness, dehydration, alcohol, or hard training can all push resting HR up.",
                    cycle_impact="Vyla will reduce confidence in temperature-based cycle interpretation today.",
                    confidence="low",
                    severity="caution",
                    source_signals=["resting_hr"],
                )
            )
        elif resting_hr_stable:
            insights.append(
                self._insight(
                    id="resting_hr_steady",
                    type="resting_hr",
                    title="Resting heart rate looks steady",
                    summary="Your resting heart rate is close to its recent pattern, which suggests more stable recovery context.",
                    advice="A steadier resting HR can support confidence in your wearable-based wellness insights.",
                    cycle_impact="This supports more stable interpretation of today’s body signals.",
                    confidence="medium",
                    severity="positive",
                    source_signals=["resting_hr"],
                )
            )
        elif health_snapshot.resting_heart_rate is not None:
            insights.append(
                self._insight(
                    id="resting_hr_baseline",
                    type="resting_hr",
                    title="Resting heart-rate baseline is still building",
                    summary="Vyla has a resting heart-rate reading for today, but it needs more days before comparing a strong pattern.",
                    advice="Keep wearing your device consistently so Vyla can compare resting-HR changes more confidently.",
                    cycle_impact="For now, resting heart rate adds context but not a strong trend signal.",
                    confidence="low",
                    severity="neutral",
                    source_signals=["resting_hr", "data_quality"],
                )
            )

        if steps_latest is not None:
            if steps_healthy:
                insights.append(
                    self._insight(
                        id="steps_balanced",
                        type="steps",
                        title="Movement is supporting your cycle wellbeing",
                        summary="Your activity level looks consistent with a more balanced movement day.",
                        advice="Moderate movement can support mood, circulation, and period comfort.",
                        cycle_impact="Movement supports overall wellbeing, but it does not directly confirm ovulation.",
                        confidence="medium",
                        severity="positive",
                        source_signals=["steps"],
                    )
                )
            elif steps_latest < 3000:
                insights.append(
                    self._insight(
                        id="steps_light",
                        type="steps",
                        title="This looks like a lighter movement day",
                        summary="Your step count is lower than your recent activity pattern.",
                        advice="A short walk or gentle stretching may help energy and comfort today.",
                        cycle_impact="Low movement does not shift ovulation estimates directly, but it may shape energy and PMS context.",
                        confidence="medium",
                        severity="neutral",
                        source_signals=["steps"],
                    )
                )

        if spo2 is not None and spo2 < 95:
            insights.append(
                self._insight(
                    id="spo2_low",
                    type="spo2",
                    title="Blood oxygen looks lower than expected",
                    summary="This reading looks lower than the range Vyla usually expects for a reassuring wellness signal.",
                    advice="Retest when calm and check that the device fit is good before drawing conclusions.",
                    cycle_impact="Vyla does not use this reading directly for ovulation timing, but it may lower confidence in broader recovery context.",
                    confidence="low",
                    severity="caution",
                    source_signals=["spo2"],
                )
            )

        if strong_sleep and not rhr_elevated and not temperature_outlier and (steps_healthy or steps_latest is None):
            insights.append(
                self._insight(
                    id="combined_cycle_support",
                    type="combined_cycle",
                    title="Your body signals are supporting today’s cycle insight",
                    summary="Sleep, recovery, and activity look balanced enough to support more useful body-signal context.",
                    advice="Keep wearing your device overnight to improve the quality of future estimates.",
                    cycle_impact="Vyla can use today’s readings to support cycle-awareness insights with better confidence.",
                    confidence=confidence,
                    severity="positive",
                    source_signals=["combined_cycle", "sleep", "resting_hr", "steps"],
                )
            )
        elif low_sleep or rhr_elevated or temperature_outlier:
            insights.append(
                self._insight(
                    id="combined_cycle_caution",
                    type="recovery",
                    title="Today’s body signals need more context",
                    summary="Some signals suggest strain or noisier recovery, so cycle interpretation should stay cautious today.",
                    advice="Poor sleep, elevated resting HR, or unusual temperature patterns can all lower insight quality.",
                    cycle_impact="Vyla will avoid making a strong cycle update from noisy readings alone.",
                    confidence="low",
                    severity="caution",
                    source_signals=["combined_cycle", "sleep", "resting_hr", "temperature"],
                )
            )

        return insights

    @staticmethod
    def _insight(
        *,
        id: str,
        type: str,
        title: str,
        summary: str,
        advice: str,
        cycle_impact: str,
        confidence: str,
        severity: str,
        source_signals: list[str],
    ) -> HomeCycleInsightResponse:
        return HomeCycleInsightResponse(
            id=id,
            type=type,
            title=title,
            summary=summary,
            advice=advice,
            cycle_impact=cycle_impact,
            confidence=confidence,
            severity=severity,
            source_signals=source_signals,
            show_medical_disclaimer=True,
        )

    @staticmethod
    def _trend_latest_and_baseline(
        device_trends: list[HomeDeviceTrendResponse],
        metric: str,
    ) -> tuple[float | None, float | None]:
        trend = next((item for item in device_trends if item.metric == metric), None)
        if not trend or not trend.points:
            return None, None
        latest = trend.points[-1].value
        baseline_points = trend.points[:-1]
        baseline = (
            sum(point.value for point in baseline_points) / len(baseline_points)
            if baseline_points
            else None
        )
        return latest, round(baseline, 2) if baseline is not None else None

    @staticmethod
    def _calculate_cycle_signal_confidence(
        health_snapshot: HomeHealthSnapshotResponse,
        device_trends: list[HomeDeviceTrendResponse],
    ) -> str:
        score = 50
        sleep_hours = health_snapshot.sleep_hours or 0
        deep_sleep = health_snapshot.sleep_deep_minutes or 0
        temp = health_snapshot.temperature_delta_c
        spo2 = health_snapshot.blood_oxygen_avg
        rhr_latest, rhr_baseline = HomeService._trend_latest_and_baseline(device_trends, "rhr")
        steps_latest, steps_baseline = HomeService._trend_latest_and_baseline(device_trends, "steps")

        if temp is not None:
            score += 12
        if sleep_hours >= 6:
            score += 8
        if deep_sleep >= 90:
            score += 6
        if rhr_latest is not None and rhr_baseline is not None and rhr_latest <= rhr_baseline + 2:
            score += 6
        if steps_latest is not None and ((steps_baseline is not None and steps_latest >= steps_baseline * 0.8) or steps_latest >= 6000):
            score += 4
        if sleep_hours < 5:
            score -= 10
        if rhr_latest is not None and rhr_baseline is not None and rhr_latest >= rhr_baseline + 5:
            score -= 12
        if temp is not None and abs(temp) >= 0.4:
            score -= 20
        if spo2 is not None and spo2 < 95:
            score -= 10

        if score >= 75:
            return "high"
        if score >= 55:
            return "medium"
        return "low"

    def _build_device_trends(self, user_id: str, source: str | None = None) -> list[HomeDeviceTrendResponse]:
        configs = [
            ("rhr", "Resting HR", "bpm"),
            ("hrv", "HRV", "ms"),
            ("sleep_minutes", "Sleep", "min"),
            ("stress", "Stress", None),
            ("steps", "Steps", None),
            ("calories_kcal", "Energy", "kcal"),
            ("distance_meters", "Distance", "m"),
        ]
        trends: list[HomeDeviceTrendResponse] = []
        for metric, label, unit in configs:
            readings = (
                self.sensors.recent_stress(user_id, days=30)
                if metric == "stress"
                else self.sensors.recent(user_id, metric, days=30, source=source)
            )
            latest_by_day = {}
            for item in readings:
                latest_by_day[item.recorded_at.date()] = item
            readings = list(latest_by_day.values())
            points = [
                HomeDeviceTrendPointResponse(
                    recorded_at=item.recorded_at,
                    value=round(
                        float(item.score if metric == "stress" else item.value),
                        2,
                    ),
                )
                for item in readings[-14:]
            ]
            if not points:
                continue
            latest = points[-1].value
            baseline_points = points[:-1]
            baseline = (
                sum(item.value for item in baseline_points) / len(baseline_points)
                if baseline_points
                else None
            )
            delta_percent = None
            if baseline and baseline != 0:
                delta_percent = round(((latest - baseline) / baseline) * 100, 1)
            trends.append(
                HomeDeviceTrendResponse(
                    metric=metric,
                    label=label,
                    unit=unit,
                    latest_value=latest,
                    delta_percent=delta_percent,
                    points=points,
                )
            )
        return trends

    def _current_prediction(self, user_id: str, timezone_name: str | None) -> PredictionSnapshotResponse:
        service = PredictionService(self.db, self.settings, self.ml_client)
        snapshot = self.predictions.latest_for_user(user_id)
        if not snapshot:
            return service.run_prediction(user_id)

        user_today = self._local_today(timezone_name)
        generated_day = snapshot.generated_at.astimezone(self._timezone(timezone_name)).date()
        if generated_day < user_today or self._should_refresh_prediction_snapshot(snapshot):
            return service.run_prediction(user_id)
        return service.to_response(snapshot)

    @staticmethod
    def _should_refresh_prediction_snapshot(snapshot) -> bool:
        audit = snapshot.audit or {}
        ml_payload = snapshot.ml_payload or {}
        temp_series = ml_payload.get("temp_series") or []
        has_absolute_temp_delta = any(
            abs(float(point.get("delta_temp", 0))) > 5
            for point in temp_series
            if isinstance(point, dict)
        )
        is_old_pipeline = audit.get("input_pipeline_version") != PREDICTION_INPUT_PIPELINE_VERSION
        return audit.get("ovulation_estimate_source") == "cusum_fallback" and (
            is_old_pipeline or has_absolute_temp_delta
        )

    def _local_today(self, timezone_name: str | None) -> date:
        return self._now_utc().astimezone(self._timezone(timezone_name)).date()

    def _timezone(self, timezone_name: str | None) -> ZoneInfo:
        if not timezone_name:
            return ZoneInfo("UTC")
        try:
            return ZoneInfo(timezone_name)
        except ZoneInfoNotFoundError:
            return ZoneInfo("UTC")

    @staticmethod
    def _parse_date(value: str | None) -> date | None:
        return date.fromisoformat(value) if value else None

    def _tracked_cycles(self, user_id: str) -> int:
        return self.db.query(CycleRecord).filter(CycleRecord.user_id == user_id).count()

    @staticmethod
    def _resolve_cycle_length(cycle) -> int | None:
        if cycle.cycle_length_days:
            return cycle.cycle_length_days
        if cycle.mu_cycle:
            return int(round(cycle.mu_cycle))
        return None

    @staticmethod
    def _wearable_source_filter(wearable_type) -> str | None:
        from phora.models.enums import WearableType
        if wearable_type == WearableType.APPLE_WATCH:
            return "healthkit"
        return None

    def _latest_sensor(self, user_id: str, metric: str, source: str | None = None):
        readings = self.sensors.recent(user_id, metric, days=60, source=source)
        return readings[-1] if readings else None

    def _latest_stress(self, user_id: str):
        return (
            self.db.query(StressScore)
            .filter(StressScore.user_id == user_id)
            .order_by(StressScore.recorded_at.desc())
            .first()
        )

    def _latest_wearable_sync_time(self, user_id: str) -> datetime | None:
        metric = (
            self.db.query(WearableMetric)
            .filter(WearableMetric.user_id == user_id)
            .order_by(WearableMetric.collected_at.desc())
            .first()
        )
        return metric.collected_at if metric else None

    def _build_health_snapshot(
        self,
        user_id: str,
        wearable_type,
        sleep,
        sleep_deep,
        sleep_light,
        sleep_awake,
        steps,
        rhr,
        blood_oxygen_avg,
        blood_oxygen_min,
        stress,
        hrv,
        temp,
        locale: str = "en",
    ) -> HomeHealthSnapshotResponse:
        latest_times = [
            item.recorded_at
            for item in (
                sleep,
                sleep_deep,
                sleep_light,
                sleep_awake,
                steps,
                rhr,
                blood_oxygen_avg,
                blood_oxygen_min,
                stress,
                hrv,
                temp,
            )
            if item
        ]
        latest_synced_at = self._latest_wearable_sync_time(user_id)
        connected = wearable_type not in (None, WearableType.NONE, WearableType.MANUAL_BBT)
        signals: list[str] = []
        if temp:
            signals.append("temperature")
        if steps:
            signals.append("steps")
        if rhr:
            signals.append("resting_heart_rate")
        if blood_oxygen_avg:
            signals.append("blood_oxygen")
        if stress:
            signals.append("stress")
        if hrv:
            signals.append("hrv")
        if sleep:
            signals.append("sleep")
        if not connected:
            state = "connect_wearable"
            title = _t(locale, "bss_connect_title")
            message = _t(locale, "bss_connect_message")
            action_label = _t(locale, "bss_connect_action")
        elif signals:
            state = "readings_available"
            title = _t(locale, "bss_readings_title")
            message = _t(locale, "bss_readings_message")
            action_label = None
        else:
            state = "awaiting_readings"
            title = _t(locale, "bss_awaiting_title")
            message = _t(locale, "bss_awaiting_message")
            action_label = None
        return HomeHealthSnapshotResponse(
            wearable_connected=connected,
            wearable_type=wearable_type.value if connected else None,
            body_signal_state=state,
            body_signal_title=title,
            body_signal_message=message,
            body_signal_action_label=action_label,
            sleep_hours=round(sleep.value / 60, 1) if sleep else None,
            sleep_deep_minutes=round(sleep_deep.value) if sleep_deep else None,
            sleep_light_minutes=round(sleep_light.value) if sleep_light else None,
            sleep_awake_minutes=round(sleep_awake.value) if sleep_awake else None,
            steps=round(steps.value) if steps else None,
            resting_heart_rate=round(rhr.value, 1) if rhr else None,
            blood_oxygen_avg=round(blood_oxygen_avg.value, 1) if blood_oxygen_avg else None,
            blood_oxygen_min=round(blood_oxygen_min.value, 1) if blood_oxygen_min else None,
            stress_avg=round(stress.score, 1) if stress else None,
            hrv=round(hrv.value, 1) if hrv else None,
            temperature_delta_c=round(temp.delta if temp and temp.delta is not None else temp.value, 2) if temp else None,
            latest_recorded_at=max(latest_times) if latest_times else None,
            latest_synced_at=latest_synced_at,
            cycle_support_signals=signals,
        )

    def _build_today_focus(
        self,
        *,
        prediction: PredictionSnapshotResponse,
        cycle_day: int,
        local_today: date,
        fertile_start: date | None,
        fertile_end: date | None,
        next_period_date: date | None,
        recent_logs: list[DailyLog],
        health_snapshot: HomeHealthSnapshotResponse,
    ) -> HomeTodayFocusResponse:
        symptom_log = self._latest_log(recent_logs, LogType.SYMPTOM)
        symptom_payload = symptom_log.payload if symptom_log else {}
        normalized_phase = self._normalize_phase(prediction.current_phase)

        if fertile_start and fertile_end and fertile_start <= local_today <= fertile_end:
            return HomeTodayFocusResponse(
                title="Fertile window active",
                message="Your fertile window is open today based on your current cycle prediction.",
                tags=["fertile_window", normalized_phase],
            )

        if next_period_date is not None:
            days_to_period = (next_period_date - local_today).days
            if 0 <= days_to_period <= 3:
                return HomeTodayFocusResponse(
                    title="Possible PMS approaching",
                    message=f"Your next period is predicted in {days_to_period} day{'s' if days_to_period != 1 else ''}. Prioritize recovery and hydration if energy dips.",
                    tags=["pms", "recovery", normalized_phase],
                )

        if symptom_payload.get("energy_level") == "low" or (health_snapshot.sleep_hours is not None and health_snapshot.sleep_hours < 6.5):
            return HomeTodayFocusResponse(
                title="Recovery recommended today",
                message="Recent low energy or poor sleep suggests taking a lighter approach today.",
                tags=["recovery", "sleep", normalized_phase],
            )

        if normalized_phase in {"follicular", "ovulation"}:
            return HomeTodayFocusResponse(
                title="High energy day",
                message=f"Cycle day {cycle_day} often supports stronger training output in the {normalized_phase} phase.",
                tags=["energy", normalized_phase],
            )

        return HomeTodayFocusResponse(
            title="Recovery and consistency",
            message="A steadier pace may suit today best. Keep movement consistent and monitor symptoms.",
            tags=["consistency", normalized_phase],
        )

    @staticmethod
    def _merge_daily_insight(today_focus: HomeTodayFocusResponse, daily_insight) -> HomeTodayFocusResponse:
        payload = dict(daily_insight.payload or {})
        generated_at = payload.get("generated_at")
        parsed_generated_at = None
        if isinstance(generated_at, str):
            try:
                parsed_generated_at = datetime.fromisoformat(generated_at)
            except ValueError:
                parsed_generated_at = daily_insight.updated_at
        return HomeTodayFocusResponse(
            title=today_focus.title,
            message=today_focus.message,
            tags=today_focus.tags,
            nutrition_recommendation=payload.get("nutrition_recommendation"),
            activity_recommendation=payload.get("activity_recommendation"),
            foods_to_eat=list(payload.get("foods_to_eat") or []),
            workout_exercises=list(payload.get("workout_exercises") or []),
            personalization_basis=list(payload.get("personalization_basis") or []),
            generated_at=parsed_generated_at or daily_insight.updated_at,
        )

    def _build_fitness_guidance(
        self,
        current_phase: str,
        recent_logs: list[DailyLog],
        health_snapshot: HomeHealthSnapshotResponse,
    ) -> HomeFitnessGuidanceResponse:
        normalized_phase = self._normalize_phase(current_phase)
        symptom_log = self._latest_log(recent_logs, LogType.SYMPTOM)
        symptom_payload = symptom_log.payload if symptom_log else {}
        low_energy = symptom_payload.get("energy_level") == "low" or (health_snapshot.sleep_hours is not None and health_snapshot.sleep_hours < 6.5)

        if normalized_phase == "menstrual":
            return HomeFitnessGuidanceResponse(
                recommended_intensity="low_moderate",
                recommended_focus=["walking", "mobility", "light_strength"],
                recovery_priority="high",
                message="Lean toward easier movement today.",
                reason="Menstrual days often benefit from lower intensity and more recovery room.",
            )

        if normalized_phase in {"follicular", "ovulation"} and not low_energy:
            return HomeFitnessGuidanceResponse(
                recommended_intensity="moderate_high",
                recommended_focus=["cardio", "strength"],
                recovery_priority="normal",
                message="This is a good day for moderate to intense work if you feel good.",
                reason="Follicular and ovulation phases are commonly associated with higher perceived energy.",
            )

        if low_energy:
            return HomeFitnessGuidanceResponse(
                recommended_intensity="low",
                recommended_focus=["walking", "mobility", "recovery"],
                recovery_priority="high",
                message="Use a recovery-focused training day.",
                reason="Recent low-energy or low-sleep signals reduce confidence in pushing intensity today.",
            )

        return HomeFitnessGuidanceResponse(
            recommended_intensity="moderate",
            recommended_focus=["strength", "walking", "mobility"],
            recovery_priority="normal_high",
            message="Moderate effort with extra recovery support fits today.",
            reason="Luteal days can feel heavier, so balanced training tends to be more sustainable.",
        )

    def _build_alerts(
        self,
        *,
        tracked_cycles: int,
        wearable_type,
        health_snapshot: HomeHealthSnapshotResponse,
        locale: str = "en",
    ) -> list[HomeAlertResponse]:
        alerts: list[HomeAlertResponse] = []
        if tracked_cycles < 3:
            alerts.append(
                HomeAlertResponse(
                    type="prediction_improves_with_data",
                    message=_t(locale, "alert_prediction_improves"),
                )
            )
        if wearable_type in (None, WearableType.NONE, WearableType.MANUAL_BBT):
            alerts.append(
                HomeAlertResponse(
                    type="connect_wearable",
                    message=_t(locale, "alert_connect_wearable"),
                )
            )
        elif not health_snapshot.cycle_support_signals:
            alerts.append(
                HomeAlertResponse(
                    type="sync_health_data",
                    message=_t(locale, "alert_sync_health_data"),
                )
            )
        return alerts

    @staticmethod
    def _latest_log(logs: list[DailyLog], log_type: LogType) -> DailyLog | None:
        matches = [log for log in logs if log.log_type == log_type]
        return matches[-1] if matches else None

    @staticmethod
    def _normalize_phase(value: str | None) -> str | None:
        if value == CyclePhase.OVULATORY.value:
            return "ovulation"
        return value

    @staticmethod
    def _resolve_first_name(profile) -> str | None:
        conditions = dict(profile.conditions or {})
        if conditions.get("first_name"):
            return conditions["first_name"]
        if profile.full_name:
            return profile.full_name.split()[0]
        return None

    def _confidence_label(
        self,
        score: float,
        tracked_cycles: int,
        health_snapshot: HomeHealthSnapshotResponse,
    ) -> str:
        if score >= 0.75 and tracked_cycles >= 3 and health_snapshot.cycle_support_signals:
            return "high"
        if score >= 0.45 and tracked_cycles >= 2:
            return "medium"
        return "low"
