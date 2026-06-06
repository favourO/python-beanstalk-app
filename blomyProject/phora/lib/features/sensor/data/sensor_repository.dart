import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';

final sensorRepositoryProvider = Provider<SensorRepository>((ref) {
  return SensorRepository(apiClient: ref.watch(apiClientProvider));
});

class SensorRepository {
  SensorRepository({required this.apiClient});

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<void> ingestTemperature({
    required DateTime measuredAt,
    required double temperatureCelsius,
    String source = 'manual_bbt',
    String unit = 'celsius',
    String metricType = 'basal_body_temperature',
    String method = 'unknown',
    Map<String, dynamic>? quality,
  }) async {
    final sleepMinutes = _intValue(quality?['sleep_minutes']);
    final sleepQualityScore = _doubleValue(quality?['sleep_quality_score']);
    final illnessFlag = _boolValue(quality?['illness_flag']);
    final alcoholFlag = _boolValue(quality?['alcohol_flag']);
    final stressFlag = _boolValue(quality?['stress_flag']);
    final travelFlag = _boolValue(quality?['travel_flag']);
    final sameTimeAsYesterday = _boolValue(quality?['same_time_as_yesterday']);
    final uninterruptedSleep = _boolValue(quality?['uninterrupted_sleep']);
    final measuredBeforeGettingUp = _boolValue(
      quality?['measured_before_getting_up'],
    );
    final excluded = _boolValue(quality?['excluded_from_ovulation_prediction']);
    final exclusionReason = _stringValue(quality?['exclusion_reason']);
    final collectedAt = DateTime.now().toUtc();
    await _post('/api/v1/sensor/ingest/temperature', {
      'records': [
        {
          'timestamp': measuredAt.toUtc().toIso8601String(),
          'measured_at': measuredAt.toUtc().toIso8601String(),
          'collected_at': collectedAt.toIso8601String(),
          'temperature_celsius': temperatureCelsius,
          'delta_c': 0.0,
          'unit': unit,
          'metric_type': metricType,
          'is_user_entered': true,
          if (sleepMinutes != null) 'sleep_minutes': sleepMinutes,
          if (sleepQualityScore != null)
            'sleep_quality_score': sleepQualityScore,
          if (illnessFlag != null) 'illness_flag': illnessFlag,
          if (alcoholFlag != null) 'alcohol_flag': alcoholFlag,
          if (stressFlag != null) 'stress_flag': stressFlag,
          if (travelFlag != null) 'travel_flag': travelFlag,
          if (excluded != null)
            'excluded_from_ovulation_prediction': excluded,
          if (exclusionReason != null) 'exclusion_reason': exclusionReason,
          'raw_payload': {
            'method': method,
            if (sameTimeAsYesterday != null)
              'same_time_as_yesterday': sameTimeAsYesterday,
            if (uninterruptedSleep != null)
              'uninterrupted_sleep': uninterruptedSleep,
            if (measuredBeforeGettingUp != null)
              'measured_before_getting_up': measuredBeforeGettingUp,
          },
          'source': source,
        },
      ],
    });
  }

  Future<void> ingestHeartRate({
    required DateTime recordedAt,
    required double bpm,
    Map<String, dynamic>? metadata,
  }) async {
    await _post('/api/v1/sensor/ingest/heart-rate', {
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'bpm': bpm,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
  }

  Future<void> ingestSleep({
    required DateTime startedAt,
    required DateTime endedAt,
    double? durationHours,
    Map<String, dynamic>? metadata,
  }) async {
    await _post('/api/v1/sensor/ingest/sleep', {
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
      if (durationHours != null) 'duration_hours': durationHours,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
  }

  Future<void> _post(String path, Map<String, dynamic> data) async {
    try {
      await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, path),
        data: data,
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _doubleValue(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }

  String? _stringValue(dynamic value) {
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }
}
