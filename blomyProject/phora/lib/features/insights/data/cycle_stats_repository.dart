import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/features/insights/domain/cycle_stats.dart';

final cycleStatsRepositoryProvider = Provider<CycleStatsRepository>((ref) {
  return CycleStatsRepository(apiClient: ref.watch(apiClientProvider));
});

class CycleStatsRepository {
  CycleStatsRepository({required this.apiClient});

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<CycleStats> getCycleStats() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/cycle/stats'),
      );
      final data = response.data ?? const <String, dynamic>{};
      return CycleStats(
        trackedCycles: _asInt(data['tracked_cycles']),
        firstPeriodStartDate: _asDate(data['first_period_start_date']),
        averageCycleLengthDays: _asDouble(data['average_cycle_length_days']),
        averagePeriodLengthDays: _asDouble(data['average_period_length_days']),
        regularityScore: _asDouble(data['regularity_score']).clamp(0.0, 1.0),
        temperatureTrend: _asTemperaturePoints(data),
        hrvTrend: _asPoints(data['hrv_trend']),
        symptomPatterns: SymptomPatterns(
          mostCommon: _asString(
            (data['symptom_patterns'] as Map<String, dynamic>?)?['most_common'],
          ),
          energyDips: _asString(
            (data['symptom_patterns'] as Map<String, dynamic>?)?['energy_dips'],
          ),
        ),
        periodRanges: _asPeriodRanges(data['period_ranges']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  List<CycleStatsPoint> _asPoints(dynamic value) {
    final list = value is List ? value : const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(
          (entry) => CycleStatsPoint(
            recordedAt:
                DateTime.tryParse(_asString(entry['recorded_at']) ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            value: _asDouble(entry['value']),
          ),
        )
        .where((entry) => entry.recordedAt.millisecondsSinceEpoch > 0)
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  List<CyclePeriodRange> _asPeriodRanges(dynamic value) {
    final list = value is List ? value : const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((entry) {
          final start = _asDate(entry['start_date']);
          final end = _asDate(entry['end_date']) ?? start;
          if (start == null || end == null) {
            return null;
          }
          return CyclePeriodRange(startDate: start, endDate: end);
        })
        .whereType<CyclePeriodRange>()
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  List<CycleStatsPoint> _asTemperaturePoints(Map<String, dynamic> data) {
    final raw =
        data['temperature_trend'] ??
        data['body_temperature_trend'] ??
        data['bbt_trend'] ??
        data['wearable_temperature_trend'];
    final list = raw is List ? raw : const [];
    final points =
        list
            .whereType<Map<String, dynamic>>()
            .map(_temperaturePoint)
            .whereType<CycleStatsPoint>()
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return points;
  }

  CycleStatsPoint? _temperaturePoint(Map<String, dynamic> entry) {
    final recordedAt =
        DateTime.tryParse(
          _asString(
                entry['recorded_at'] ??
                    entry['measured_at'] ??
                    entry['date'] ??
                    entry['timestamp'],
              ) ??
              '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (recordedAt.millisecondsSinceEpoch <= 0) {
      return null;
    }

    final value = _firstDouble(entry, const [
      'value',
      'body_temperature',
      'bbt',
      'temperature',
      'temperature_avg',
      'avg',
      'delta',
    ]);
    if (value == null) {
      return null;
    }

    return CycleStatsPoint(recordedAt: recordedAt, value: value);
  }

  double? _firstDouble(Map<String, dynamic> entry, List<String> keys) {
    for (final key in keys) {
      if (!entry.containsKey(key)) {
        continue;
      }
      final parsed = _nullableDouble(entry[key]);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  double? _nullableDouble(dynamic value) {
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

  String? _asString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  DateTime? _asDate(dynamic value) {
    final raw = _asString(value);
    if (raw == null) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
