import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/features/predictions/domain/prediction_models.dart';

final predictionsRepositoryProvider = Provider<PredictionsRepository>((ref) {
  return PredictionsRepository(apiClient: ref.watch(apiClientProvider));
});

class PredictionsRepository {
  PredictionsRepository({required this.apiClient});

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<CurrentPrediction> getCurrentPrediction() async {
    try {
      final responses = await Future.wait([
        dio.get<Map<String, dynamic>>(
          buildVersionedApiUrl(dio, '/api/v1/predictions/current'),
        ),
        dio.get<Map<String, dynamic>>(
          buildVersionedApiUrl(dio, '/api/v1/predictions/fertile-window'),
        ),
        dio.get<Map<String, dynamic>>(
          buildVersionedApiUrl(dio, '/api/v1/predictions/ovulation'),
        ),
        dio.get<Map<String, dynamic>>(
          buildVersionedApiUrl(dio, '/api/v1/predictions/next-period'),
        ),
        dio.get<Map<String, dynamic>>(
          buildVersionedApiUrl(dio, '/api/v1/predictions/age-context'),
        ),
      ]);

      final current = _payloadFromMap(responses[0].data);
      final fertileWindow = _payloadFromMap(responses[1].data);
      final ovulation = _payloadFromMap(responses[2].data);
      final nextPeriod = _payloadFromMap(responses[3].data);
      final ageContext = _payloadFromMap(responses[4].data);
      final explanations = await _getOptional(
        '/api/v1/predictions/explanations',
      );
      final phaseConfidence = await _getOptional(
        '/api/v1/predictions/phase-confidence',
      );
      final alerts = await _getOptional('/api/v1/predictions/alerts');

      final distribution =
          _phaseDistribution(phaseConfidence).isNotEmpty
              ? _phaseDistribution(phaseConfidence)
              : _phaseDistribution(current);
      final phase =
          _parsePhase(
            _stringValue(current['current_phase']) ??
                _stringValue(current['phase']),
          ) ??
          _phaseFromDistribution(distribution);

      return CurrentPrediction(
        phase: phase,
        confidence:
            _doubleValue(phaseConfidence['confidence']) ??
            _doubleValue(current['confidence']) ??
            0,
        confidenceExplanation:
            _stringValue(explanations['confidence_explanation']) ??
            _stringValue(current['confidence_explanation']) ??
            _stringValue(current['summary']) ??
            'Prediction data is available for this cycle.',
        phaseDistribution: distribution,
        warningFlags:
            _stringList(alerts['warning_flags']).isNotEmpty
                ? _stringList(alerts['warning_flags'])
                : _stringList(current['warning_flags']),
        cycleDay:
            _intValue(current['cycle_day']) ??
            _intValue(current['current_day']),
        cycleLength:
            _intValue(current['cycle_length']) ??
            _intValue(current['cycle_length_days']) ??
            _intValue(current['predicted_cycle_length']) ??
            _intValue(nextPeriod['cycle_length']),
        cycleStartDate: _dateValue(
          current['cycle_start_date'] ??
              current['period_start_date'] ??
              current['current_cycle_start_date'],
        ),
        periodLength:
            _intValue(current['period_length_days']) ??
            _intValue(current['menses_length']) ??
            _intValue(current['period_length']),
        fertileWindowStart: _dateValue(
          fertileWindow['start_date'] ??
              fertileWindow['start'] ??
              current['fertile_window']?['start_date'] ??
              current['fertile_window']?['start'],
        ),
        fertileWindowEnd: _dateValue(
          fertileWindow['end_date'] ??
              fertileWindow['end'] ??
              current['fertile_window']?['end_date'] ??
              current['fertile_window']?['end'],
        ),
        ovulationDate: _dateValue(
          ovulation['predicted_date'] ??
              ovulation['date'] ??
              ovulation['ovulation_date'] ??
              current['ovulation_estimate']?['predicted_date'] ??
              current['ovulation_estimate']?['date'] ??
              current['ovulation_estimate']?['ovulation_date'],
        ),
        nextPeriodDate: _dateValue(
          nextPeriod['predicted_date'] ??
              nextPeriod['date'] ??
              nextPeriod['start_date'] ??
              current['next_period_estimate']?['predicted_date'] ??
              current['next_period_estimate']?['date'] ??
              current['next_period_estimate']?['start_date'],
        ),
        ageContextSummary:
            _stringValue(ageContext['summary']) ??
            _stringValue(ageContext['age_context']) ??
            _stringValue(ageContext['message']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<List<PredictionCalendarDay>> getPredictionCalendar() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/predictions/calendar'),
      );
      final payload = response.data ?? <String, dynamic>{};
      final rawItems = _listValue(
        payload['days'] ??
            payload['calendar'] ??
            payload['data'] ??
            payload['items'],
      );

      return rawItems
          .map((item) => Map<String, dynamic>.from(item))
          .map((item) {
            final date = _dateValue(
              item['date'] ?? item['day'] ?? item['calendar_date'],
            );
            if (date == null) {
              return null;
            }
            final phase =
                _parsePhase(
                  _stringValue(item['phase']) ??
                      _stringValue(item['phase_name']) ??
                      _stringValue(item['current_phase']),
                ) ??
                PredictionPhase.unknown;
            final hasDot =
                item['has_dot'] == true ||
                item['is_fertile'] == true ||
                item['is_ovulation'] == true ||
                item['is_ovulation_est'] == true;
            return PredictionCalendarDay(
              date: DateTime(date.year, date.month, date.day),
              phase: phase,
              hasDot: hasDot,
              isOvulation:
                  item['is_ovulation'] == true ||
                  item['is_ovulation_est'] == true,
              isFertile: item['is_fertile'] == true,
              isPeriod: item['is_period'] == true,
            );
          })
          .whereType<PredictionCalendarDay>()
          .toList();
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<List<CycleForecastSuggestion>> getPendingForecastSuggestions() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/predictions/forecast-suggestions'),
        queryParameters: const {'status': 'pending'},
      );
      final payload = response.data ?? <String, dynamic>{};
      final rawItems = _listValue(
        payload['suggestions'] ?? payload['data'] ?? payload['items'],
      );
      return rawItems
          .map(_forecastSuggestionFromJson)
          .whereType<CycleForecastSuggestion>()
          .toList();
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<CycleForecastSuggestion> acceptForecastSuggestion(String id) async {
    return _decideForecastSuggestion(id: id, action: 'accept');
  }

  Future<CycleForecastSuggestion> rejectForecastSuggestion(String id) async {
    return _decideForecastSuggestion(id: id, action: 'reject');
  }

  Future<CycleForecastSuggestion> _decideForecastSuggestion({
    required String id,
    required String action,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(
          dio,
          '/api/v1/predictions/forecast-suggestions/$id/$action',
        ),
      );
      final payload = _payloadFromMap(response.data);
      final suggestion = _forecastSuggestionFromJson(payload);
      if (suggestion == null) {
        throw const MessageApiFailure(
          'Could not read forecast suggestion response.',
        );
      }
      return suggestion;
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<Map<String, dynamic>> _getOptional(String path) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, path),
      );
      return _payloadFromMap(response.data);
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 404) {
        return const {};
      }
      throw mapDioError(exception);
    }
  }

  Map<String, dynamic> _payloadFromMap(Map<String, dynamic>? response) {
    final map = response ?? <String, dynamic>{};
    final data = map['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return map;
  }

  List<Map<String, dynamic>> _listValue(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return const [];
  }

  Map<PredictionPhase, double> _phaseDistribution(
    Map<String, dynamic> current,
  ) {
    final distribution =
        current['phase_distribution'] ?? current['distribution'] ?? const {};
    if (distribution is! Map) {
      return const {};
    }
    final result = <PredictionPhase, double>{};
    for (final entry in distribution.entries) {
      final phase = _parsePhase(entry.key.toString());
      final value = _doubleValue(entry.value);
      if (phase != null && value != null) {
        result[phase] = value;
      }
    }
    return result;
  }

  CycleForecastSuggestion? _forecastSuggestionFromJson(
    Map<String, dynamic> item,
  ) {
    final id = _stringValue(item['id']);
    if (id == null) return null;
    return CycleForecastSuggestion(
      id: id,
      type: _parseSuggestionType(
        _stringValue(item['suggestion_type']) ?? _stringValue(item['type']),
      ),
      status: _parseSuggestionStatus(_stringValue(item['status'])),
      cycleId: _stringValue(item['cycle_id']),
      currentValue: _dateValue(item['current_value']),
      suggestedValue: _dateValue(item['suggested_value']),
      evidence: _evidenceList(item['evidence']),
      createdAt: _dateTimeValue(item['created_at']),
      decidedAt: _dateTimeValue(item['decided_at']),
    );
  }

  List<CycleForecastEvidence> _evidenceList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .map((item) {
          return CycleForecastEvidence(
            label: _stringValue(item['label']) ?? 'Evidence',
            summary: _stringValue(item['summary']) ?? '',
            sourceType: _stringValue(item['source_type']),
            confidence: _doubleValue(item['confidence']),
          );
        })
        .where((item) => item.summary.isNotEmpty)
        .toList();
  }

  PredictionPhase _phaseFromDistribution(
    Map<PredictionPhase, double> distribution,
  ) {
    if (distribution.isEmpty) {
      return PredictionPhase.unknown;
    }
    return distribution.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  PredictionPhase? _parsePhase(String? raw) {
    if (raw == null) return null;
    switch (raw.trim().toLowerCase()) {
      case 'menstrual':
      case 'period':
        return PredictionPhase.menstrual;
      case 'follicular':
        return PredictionPhase.follicular;
      case 'ovulatory':
      case 'ovulation':
        return PredictionPhase.ovulatory;
      case 'luteal':
        return PredictionPhase.luteal;
      default:
        return PredictionPhase.unknown;
    }
  }

  CycleForecastSuggestionType _parseSuggestionType(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'ovulation_shift':
      case 'ovulation':
        return CycleForecastSuggestionType.ovulationShift;
      case 'period_shift':
      case 'period':
        return CycleForecastSuggestionType.periodShift;
      default:
        return CycleForecastSuggestionType.unknown;
    }
  }

  CycleForecastSuggestionStatus _parseSuggestionStatus(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'pending':
        return CycleForecastSuggestionStatus.pending;
      case 'accepted':
        return CycleForecastSuggestionStatus.accepted;
      case 'rejected':
        return CycleForecastSuggestionStatus.rejected;
      case 'expired':
        return CycleForecastSuggestionStatus.expired;
      default:
        return CycleForecastSuggestionStatus.unknown;
    }
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

  DateTime? _dateValue(dynamic value) {
    final string = _stringValue(value);
    if (string == null) return null;
    return DateTime.tryParse(string)?.toLocal();
  }

  DateTime? _dateTimeValue(dynamic value) => _dateValue(value);

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map(_stringValue)
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
