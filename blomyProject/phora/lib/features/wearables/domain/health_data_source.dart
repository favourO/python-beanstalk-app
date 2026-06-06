enum HealthDataSource {
  vylaWearable,
  manualEntry;

  String get apiValue => switch (this) {
    HealthDataSource.vylaWearable => 'vyla_wearable',
    HealthDataSource.manualEntry => 'manual_entry',
  };

  String get displayName => switch (this) {
    HealthDataSource.vylaWearable => 'Vyla wearable',
    HealthDataSource.manualEntry => 'Manual entry',
  };

  static HealthDataSource fromApiValue(String value) => switch (value) {
    'vyla_wearable' => HealthDataSource.vylaWearable,
    'manual_entry' => HealthDataSource.manualEntry,
    _ => HealthDataSource.manualEntry,
  };
}

class HealthMetric {
  const HealthMetric({
    required this.id,
    required this.userId,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.recordedAt,
    required this.source,
    this.externalId,
    this.confidence = 'medium',
    this.excludedFromOvulationPrediction = false,
  });

  final String id;
  final String userId;
  final String metricType;
  final double value;
  final String unit;
  final DateTime recordedAt;
  final HealthDataSource source;
  final String? externalId;
  final String confidence;
  final bool excludedFromOvulationPrediction;

  String get sourceLabel => source.displayName;

  factory HealthMetric.fromJson(Map<String, dynamic> json) {
    return HealthMetric(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      metricType: json['metric_type'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      source: HealthDataSource.fromApiValue(
        json['data_source'] as String? ?? 'manual_entry',
      ),
      externalId: json['external_id'] as String?,
      confidence: json['confidence'] as String? ?? 'medium',
      excludedFromOvulationPrediction:
          json['excluded_from_ovulation_prediction'] as bool? ?? false,
    );
  }
}
