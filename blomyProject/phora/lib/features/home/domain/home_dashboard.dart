class HomeDashboard {
  const HomeDashboard({
    required this.user,
    required this.mainStatus,
    required this.fertility,
    required this.todayFocus,
    required this.fitnessGuidance,
    required this.healthSnapshot,
    required this.deviceCycleInsights,
    required this.deviceTrends,
    required this.cyclePredictionImpact,
    required this.predictionDisclaimer,
    required this.quickActions,
    required this.alerts,
  });

  factory HomeDashboard.fromJson(Map<String, dynamic> json) {
    return HomeDashboard(
      user: HomeUser.fromJson(_mapValue(json['user'])),
      mainStatus: HomeMainStatus.fromJson(_mapValue(json['main_status'])),
      fertility: HomeFertility.fromJson(_mapValue(json['fertility'])),
      todayFocus: HomeTodayFocus.fromJson(_mapValue(json['today_focus'])),
      fitnessGuidance: HomeFitnessGuidance.fromJson(
        _mapValue(json['fitness_guidance']),
      ),
      healthSnapshot: HomeHealthSnapshot.fromJson(
        _mapValue(json['health_snapshot']),
      ),
      deviceCycleInsights:
          _listValue(
            json['device_cycle_insights'],
          ).map((item) => HomeCycleInsight.fromJson(_mapValue(item))).toList(),
      deviceTrends:
          _listValue(
            json['device_trends'],
          ).map((item) => HomeDeviceTrend.fromJson(_mapValue(item))).toList(),
      cyclePredictionImpact: HomeCyclePredictionImpact.fromJson(
        _mapValue(json['cycle_prediction_impact']),
      ),
      predictionDisclaimer:
          _stringValue(json['prediction_disclaimer']) ??
          'Vyla provides wellness and cycle awareness insights only. Predictions are estimates and should not be used for contraception, diagnosis, or treatment.',
      quickActions:
          _listValue(
            json['quick_actions'],
          ).map((item) => HomeQuickAction.fromJson(_mapValue(item))).toList(),
      alerts:
          _listValue(
            json['alerts'],
          ).map((item) => HomeAlert.fromJson(_mapValue(item))).toList(),
    );
  }

  final HomeUser user;
  final HomeMainStatus mainStatus;
  final HomeFertility fertility;
  final HomeTodayFocus todayFocus;
  final HomeFitnessGuidance fitnessGuidance;
  final HomeHealthSnapshot healthSnapshot;
  final List<HomeCycleInsight> deviceCycleInsights;
  final List<HomeDeviceTrend> deviceTrends;
  final HomeCyclePredictionImpact? cyclePredictionImpact;
  final String predictionDisclaimer;
  final List<HomeQuickAction> quickActions;
  final List<HomeAlert> alerts;
}

class HomeUser {
  const HomeUser({required this.id, required this.firstName});

  factory HomeUser.fromJson(Map<String, dynamic> json) {
    return HomeUser(
      id: _stringValue(json['id']) ?? '',
      firstName: _stringValue(json['first_name']),
    );
  }

  final String id;
  final String? firstName;
}

class HomeMainStatus {
  const HomeMainStatus({
    required this.currentCycleDay,
    required this.currentPhase,
    required this.currentPhaseRaw,
    required this.nextPredictedPeriodDate,
    required this.countdownToNextPeriodDays,
    required this.predictionConfidence,
    required this.predictionConfidenceScore,
    required this.cycleLengthDays,
    required this.periodLengthDays,
  });

  factory HomeMainStatus.fromJson(Map<String, dynamic> json) {
    return HomeMainStatus(
      currentCycleDay: _intValue(json['current_cycle_day']),
      currentPhase: _stringValue(json['current_phase']),
      currentPhaseRaw: _stringValue(json['current_phase_raw']),
      nextPredictedPeriodDate: _dateValue(json['next_predicted_period_date']),
      countdownToNextPeriodDays: _intValue(
        json['countdown_to_next_period_days'],
      ),
      predictionConfidence:
          _stringValue(json['prediction_confidence']) ?? 'unknown',
      predictionConfidenceScore:
          _doubleValue(json['prediction_confidence_score']) ?? 0,
      cycleLengthDays: _intValue(json['cycle_length_days']),
      periodLengthDays: _intValue(json['period_length_days']),
    );
  }

  final int? currentCycleDay;
  final String? currentPhase;
  final String? currentPhaseRaw;
  final DateTime? nextPredictedPeriodDate;
  final int? countdownToNextPeriodDays;
  final String predictionConfidence;
  final double predictionConfidenceScore;
  final int? cycleLengthDays;
  final int? periodLengthDays;
}

class HomeFertility {
  const HomeFertility({
    required this.fertileToday,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.predictedOvulationDate,
    required this.predictionMethod,
  });

  factory HomeFertility.fromJson(Map<String, dynamic> json) {
    return HomeFertility(
      fertileToday: json['fertile_today'] == true,
      fertileWindowStart: _dateValue(json['fertile_window_start']),
      fertileWindowEnd: _dateValue(json['fertile_window_end']),
      predictedOvulationDate: _dateValue(json['predicted_ovulation_date']),
      predictionMethod: _stringValue(json['prediction_method']),
    );
  }

  final bool fertileToday;
  final DateTime? fertileWindowStart;
  final DateTime? fertileWindowEnd;
  final DateTime? predictedOvulationDate;
  final String? predictionMethod;
}

class HomeTodayFocus {
  const HomeTodayFocus({
    required this.title,
    required this.message,
    required this.tags,
    required this.nutritionRecommendation,
    required this.activityRecommendation,
    required this.foodsToEat,
    required this.workoutExercises,
    required this.personalizationBasis,
    required this.generatedAt,
  });

  factory HomeTodayFocus.fromJson(Map<String, dynamic> json) {
    return HomeTodayFocus(
      title: _stringValue(json['title']) ?? '',
      message: _stringValue(json['message']) ?? '',
      tags:
          _listValue(json['tags'])
              .map((item) => _stringValue(item) ?? '')
              .where((item) => item.isNotEmpty)
              .toList(),
      nutritionRecommendation: _stringValue(json['nutrition_recommendation']),
      activityRecommendation: _stringValue(json['activity_recommendation']),
      foodsToEat:
          _listValue(json['foods_to_eat'])
              .map((item) => _stringValue(item) ?? '')
              .where((item) => item.isNotEmpty)
              .toList(),
      workoutExercises:
          _listValue(json['workout_exercises'])
              .map((item) => _stringValue(item) ?? '')
              .where((item) => item.isNotEmpty)
              .toList(),
      personalizationBasis:
          _listValue(json['personalization_basis'])
              .map((item) => _stringValue(item) ?? '')
              .where((item) => item.isNotEmpty)
              .toList(),
      generatedAt: _dateTimeValue(json['generated_at']),
    );
  }

  final String title;
  final String message;
  final List<String> tags;
  final String? nutritionRecommendation;
  final String? activityRecommendation;
  final List<String> foodsToEat;
  final List<String> workoutExercises;
  final List<String> personalizationBasis;
  final DateTime? generatedAt;
}

class HomeFitnessGuidance {
  const HomeFitnessGuidance({
    required this.recommendedIntensity,
    required this.recommendedFocus,
    required this.recoveryPriority,
    required this.message,
    required this.reason,
  });

  factory HomeFitnessGuidance.fromJson(Map<String, dynamic> json) {
    return HomeFitnessGuidance(
      recommendedIntensity:
          _stringValue(json['recommended_intensity']) ?? 'unknown',
      recommendedFocus:
          _listValue(json['recommended_focus'])
              .map((item) => _stringValue(item) ?? '')
              .where((item) => item.isNotEmpty)
              .toList(),
      recoveryPriority: _stringValue(json['recovery_priority']) ?? 'unknown',
      message: _stringValue(json['message']) ?? '',
      reason: _stringValue(json['reason']) ?? '',
    );
  }

  final String recommendedIntensity;
  final List<String> recommendedFocus;
  final String recoveryPriority;
  final String message;
  final String reason;
}

class HomeHealthSnapshot {
  const HomeHealthSnapshot({
    required this.wearableConnected,
    required this.wearableType,
    required this.bodySignalState,
    required this.bodySignalTitle,
    required this.bodySignalMessage,
    required this.bodySignalActionLabel,
    required this.sleepHours,
    required this.sleepDeepMinutes,
    required this.sleepLightMinutes,
    required this.sleepAwakeMinutes,
    required this.steps,
    required this.restingHeartRate,
    required this.bloodOxygenAvg,
    required this.bloodOxygenMin,
    required this.stressAvg,
    required this.hrv,
    required this.temperatureDeltaC,
    required this.latestRecordedAt,
    required this.latestSyncedAt,
    required this.cycleSupportSignals,
  });

  factory HomeHealthSnapshot.fromJson(Map<String, dynamic> json) {
    return HomeHealthSnapshot(
      wearableConnected: json['wearable_connected'] == true,
      wearableType: _stringValue(json['wearable_type']),
      bodySignalState:
          _stringValue(json['body_signal_state']) ?? 'connect_wearable',
      bodySignalTitle:
          _stringValue(json['body_signal_title']) ?? 'Connect wearable',
      bodySignalMessage:
          _stringValue(json['body_signal_message']) ??
          'Connect a wearable to show live body signals here.',
      bodySignalActionLabel: _stringValue(json['body_signal_action_label']),
      sleepHours: _doubleValue(json['sleep_hours']),
      sleepDeepMinutes: _intValue(json['sleep_deep_minutes']),
      sleepLightMinutes: _intValue(json['sleep_light_minutes']),
      sleepAwakeMinutes: _intValue(json['sleep_awake_minutes']),
      steps: _intValue(json['steps']),
      restingHeartRate: _doubleValue(json['resting_heart_rate']),
      bloodOxygenAvg: _doubleValue(json['blood_oxygen_avg']),
      bloodOxygenMin: _doubleValue(json['blood_oxygen_min']),
      stressAvg: _doubleValue(json['stress_avg']),
      hrv: _doubleValue(json['hrv']),
      temperatureDeltaC: _doubleValue(json['temperature_delta_c']),
      latestRecordedAt: _dateTimeValue(json['latest_recorded_at']),
      latestSyncedAt: _dateTimeValue(json['latest_synced_at']),
      cycleSupportSignals:
          _listValue(json['cycle_support_signals'])
              .map((item) => _stringValue(item) ?? '')
              .where((item) => item.isNotEmpty)
              .toList(),
    );
  }

  final bool wearableConnected;
  final String? wearableType;
  final String bodySignalState;
  final String bodySignalTitle;
  final String bodySignalMessage;
  final String? bodySignalActionLabel;
  final double? sleepHours;
  final int? sleepDeepMinutes;
  final int? sleepLightMinutes;
  final int? sleepAwakeMinutes;
  final int? steps;
  final double? restingHeartRate;
  final double? bloodOxygenAvg;
  final double? bloodOxygenMin;
  final double? stressAvg;
  final double? hrv;
  final double? temperatureDeltaC;
  final DateTime? latestRecordedAt;
  final DateTime? latestSyncedAt;
  final List<String> cycleSupportSignals;
}

class HomeQuickAction {
  const HomeQuickAction({required this.type, required this.label});

  factory HomeQuickAction.fromJson(Map<String, dynamic> json) {
    return HomeQuickAction(
      type: _stringValue(json['type']) ?? '',
      label: _stringValue(json['label']) ?? '',
    );
  }

  final String type;
  final String label;
}

class HomeCycleInsight {
  const HomeCycleInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.advice,
    required this.cycleImpact,
    required this.confidence,
    required this.severity,
    required this.sourceSignals,
    required this.showMedicalDisclaimer,
    required this.ctaLabel,
    required this.ctaRoute,
  });

  factory HomeCycleInsight.fromJson(Map<String, dynamic> json) {
    return HomeCycleInsight(
      id: _stringValue(json['id']) ?? '',
      type: _stringValue(json['type']) ?? 'data_quality',
      title: _stringValue(json['title']) ?? '',
      summary: _stringValue(json['summary']) ?? '',
      advice: _stringValue(json['advice']) ?? '',
      cycleImpact: _stringValue(json['cycle_impact']) ?? '',
      confidence: _stringValue(json['confidence']) ?? 'low',
      severity: _stringValue(json['severity']) ?? 'neutral',
      sourceSignals:
          _listValue(json['source_signals'])
              .map((item) => _stringValue(item) ?? '')
              .where((item) => item.isNotEmpty)
              .toList(),
      showMedicalDisclaimer: json['show_medical_disclaimer'] == true,
      ctaLabel: _stringValue(json['cta_label']),
      ctaRoute: _stringValue(json['cta_route']),
    );
  }

  final String id;
  final String type;
  final String title;
  final String summary;
  final String advice;
  final String cycleImpact;
  final String confidence;
  final String severity;
  final List<String> sourceSignals;
  final bool showMedicalDisclaimer;
  final String? ctaLabel;
  final String? ctaRoute;
}

class HomeDeviceTrend {
  const HomeDeviceTrend({
    required this.metric,
    required this.label,
    required this.unit,
    required this.latestValue,
    required this.deltaPercent,
    required this.points,
  });

  factory HomeDeviceTrend.fromJson(Map<String, dynamic> json) {
    return HomeDeviceTrend(
      metric: _stringValue(json['metric']) ?? '',
      label: _stringValue(json['label']) ?? '',
      unit: _stringValue(json['unit']),
      latestValue: _doubleValue(json['latest_value']),
      deltaPercent: _doubleValue(json['delta_percent']),
      points:
          _listValue(json['points'])
              .map((item) => HomeDeviceTrendPoint.fromJson(_mapValue(item)))
              .toList(),
    );
  }

  final String metric;
  final String label;
  final String? unit;
  final double? latestValue;
  final double? deltaPercent;
  final List<HomeDeviceTrendPoint> points;
}

class HomeDeviceTrendPoint {
  const HomeDeviceTrendPoint({required this.recordedAt, required this.value});

  factory HomeDeviceTrendPoint.fromJson(Map<String, dynamic> json) {
    return HomeDeviceTrendPoint(
      recordedAt: _dateTimeValue(json['recorded_at']),
      value: _doubleValue(json['value']) ?? 0,
    );
  }

  final DateTime? recordedAt;
  final double value;
}

class HomeCyclePredictionImpact {
  const HomeCyclePredictionImpact({
    required this.beforeOvulationDate,
    required this.beforePeriodDate,
    required this.afterOvulationDate,
    required this.afterPeriodDate,
    required this.confidenceBefore,
    required this.confidenceAfter,
    required this.confidenceDelta,
    required this.method,
    required this.contributingSignals,
    required this.explanation,
  });

  factory HomeCyclePredictionImpact.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return const HomeCyclePredictionImpact.empty();
    }
    return HomeCyclePredictionImpact(
      beforeOvulationDate: _dateValue(json['before_ovulation_date']),
      beforePeriodDate: _dateValue(json['before_period_date']),
      afterOvulationDate: _dateValue(json['after_ovulation_date']),
      afterPeriodDate: _dateValue(json['after_period_date']),
      confidenceBefore: _doubleValue(json['confidence_before']) ?? 0,
      confidenceAfter: _doubleValue(json['confidence_after']) ?? 0,
      confidenceDelta: _doubleValue(json['confidence_delta']) ?? 0,
      method: _stringValue(json['method']),
      contributingSignals:
          _listValue(json['contributing_signals'])
              .map((item) => _stringValue(item) ?? '')
              .where((item) => item.isNotEmpty)
              .toList(),
      explanation: _stringValue(json['explanation']) ?? '',
    );
  }

  const HomeCyclePredictionImpact.empty()
    : beforeOvulationDate = null,
      beforePeriodDate = null,
      afterOvulationDate = null,
      afterPeriodDate = null,
      confidenceBefore = 0,
      confidenceAfter = 0,
      confidenceDelta = 0,
      method = null,
      contributingSignals = const [],
      explanation = '';

  final DateTime? beforeOvulationDate;
  final DateTime? beforePeriodDate;
  final DateTime? afterOvulationDate;
  final DateTime? afterPeriodDate;
  final double confidenceBefore;
  final double confidenceAfter;
  final double confidenceDelta;
  final String? method;
  final List<String> contributingSignals;
  final String explanation;
}

class HomeAlert {
  const HomeAlert({required this.type, required this.message});

  factory HomeAlert.fromJson(Map<String, dynamic> json) {
    return HomeAlert(
      type: _stringValue(json['type']) ?? '',
      message: _stringValue(json['message']) ?? '',
    );
  }

  final String type;
  final String message;
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<dynamic> _listValue(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

String? _stringValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  if (value is num) {
    return value.toString();
  }
  return null;
}

int? _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double? _doubleValue(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? _dateValue(dynamic value) {
  final raw = _stringValue(value);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}

DateTime? _dateTimeValue(dynamic value) {
  final raw = _stringValue(value);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}
