import 'package:phora/features/wearables/domain/health_data_source.dart';
import 'package:phora/features/wearables/domain/wearable_models.dart';

class HealthDataNormalizer {
  const HealthDataNormalizer();

  List<HealthMetric> fromDailyMetrics(
    List<WearableDailyMetrics> days, {
    required String userId,
  }) {
    final metrics = <HealthMetric>[];
    for (final day in days) {
      final source = _sourceFrom(day.source);
      final dateStr = day.date.toIso8601String().substring(0, 10);

      if (day.bbt != null) {
        metrics.add(
          _build(
            userId: userId,
            date: day.date,
            dateStr: dateStr,
            metricType: 'basal_body_temperature',
            value: day.bbt!,
            unit: 'celsius',
            source: source,
          ),
        );
      }
      if (day.bodyTemperature != null) {
        metrics.add(
          _build(
            userId: userId,
            date: day.date,
            dateStr: dateStr,
            metricType: 'body_temperature',
            value: day.bodyTemperature!,
            unit: 'celsius',
            source: source,
          ),
        );
      }
      if (day.sleepMinutes != null) {
        metrics.add(
          _build(
            userId: userId,
            date: day.date,
            dateStr: dateStr,
            metricType: 'sleep',
            value: day.sleepMinutes!.toDouble(),
            unit: 'minutes',
            source: source,
          ),
        );
      }
      if (day.restingHeartRate != null) {
        metrics.add(
          _build(
            userId: userId,
            date: day.date,
            dateStr: dateStr,
            metricType: 'heart_rate',
            value: day.restingHeartRate!,
            unit: 'bpm',
            source: source,
          ),
        );
      }
      if (day.averageHeartRate != null) {
        metrics.add(
          _build(
            userId: userId,
            date: day.date,
            dateStr: dateStr,
            metricType: 'heart_rate_avg',
            value: day.averageHeartRate!,
            unit: 'bpm',
            source: source,
          ),
        );
      }
      if (day.hrv != null) {
        metrics.add(
          _build(
            userId: userId,
            date: day.date,
            dateStr: dateStr,
            metricType: 'hrv',
            value: day.hrv!,
            unit: 'ms',
            source: source,
          ),
        );
      }
      if (day.stress != null) {
        metrics.add(
          _build(
            userId: userId,
            date: day.date,
            dateStr: dateStr,
            metricType: 'stress',
            value: day.stress!,
            unit: 'score',
            source: source,
          ),
        );
      }
      if (day.steps != null) {
        metrics.add(
          _build(
            userId: userId,
            date: day.date,
            dateStr: dateStr,
            metricType: 'steps',
            value: day.steps!.toDouble(),
            unit: 'count',
            source: source,
          ),
        );
      }
    }
    return metrics;
  }

  HealthMetric _build({
    required String userId,
    required DateTime date,
    required String dateStr,
    required String metricType,
    required double value,
    required String unit,
    required HealthDataSource source,
  }) {
    return HealthMetric(
      id: '',
      userId: userId,
      metricType: metricType,
      value: value,
      unit: unit,
      recordedAt: date,
      source: source,
      externalId: '$dateStr:$metricType',
    );
  }

  HealthDataSource _sourceFrom(WearableSource wearableSource) =>
      switch (wearableSource) {
        WearableSource.vylaWearable => HealthDataSource.vylaWearable,
        _ => HealthDataSource.manualEntry,
      };
}
