import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/features/log/daily_log_models.dart';

final dailyLogRepositoryProvider = Provider<DailyLogRepository>((ref) {
  return DailyLogRepository(apiClient: ref.watch(apiClientProvider));
});

class DailyLogRepository {
  DailyLogRepository({required this.apiClient});

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<DailyLogDraft> getDailyLog({
    required String userId,
    required DateTime date,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/log/daily'),
        queryParameters: {'date': _dateOnly(date)},
      );
      final data = response.data ?? const <String, dynamic>{};
      return DailyLogDraft(
        userId: _stringValue(data['user_id']) ?? userId,
        date: DateTime.tryParse(_stringValue(data['date']) ?? '') ?? date,
        period:
            data['period'] is Map<String, dynamic>
                ? PeriodLogDraft.fromJson(data['period'] as Map<String, dynamic>)
                : data['period'] is Map
                ? PeriodLogDraft.fromJson(Map<String, dynamic>.from(data['period'] as Map))
                : null,
        symptoms:
            data['symptoms'] is Map<String, dynamic>
                ? SymptomsLogDraft.fromJson(data['symptoms'] as Map<String, dynamic>)
                : data['symptoms'] is Map
                ? SymptomsLogDraft.fromJson(Map<String, dynamic>.from(data['symptoms'] as Map))
                : null,
        temperature:
            data['temperature'] is Map<String, dynamic>
                ? TemperatureLogDraft.fromJson(data['temperature'] as Map<String, dynamic>)
                : data['temperature'] is Map
                ? TemperatureLogDraft.fromJson(Map<String, dynamic>.from(data['temperature'] as Map))
                : null,
        lhTest:
            data['lh_test'] is Map<String, dynamic>
                ? LhTestLogDraft.fromJson(data['lh_test'] as Map<String, dynamic>)
                : data['lh_test'] is Map
                ? LhTestLogDraft.fromJson(Map<String, dynamic>.from(data['lh_test'] as Map))
                : null,
        cervicalMucus:
            data['cervical_mucus'] is Map<String, dynamic>
                ? CervicalMucusLogDraft.fromJson(data['cervical_mucus'] as Map<String, dynamic>)
                : data['cervical_mucus'] is Map
                ? CervicalMucusLogDraft.fromJson(
                  Map<String, dynamic>.from(data['cervical_mucus'] as Map),
                )
                : null,
        intimacy:
            data['intimacy'] is Map<String, dynamic>
                ? IntimacyLogDraft.fromJson(data['intimacy'] as Map<String, dynamic>)
                : data['intimacy'] is Map
                ? IntimacyLogDraft.fromJson(Map<String, dynamic>.from(data['intimacy'] as Map))
                : null,
        notes: _stringValue(data['notes']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> saveSection({
    required DailyLogDraft draft,
    required LogSection section,
  }) async {
    final body = _payloadForSection(draft: draft, section: section);
    await _post(_pathForSection(section), body);
  }

  Future<void> saveSections({
    required DailyLogDraft draft,
    required Set<LogSection> sections,
  }) async {
    final data = <String, dynamic>{
      'user_id': draft.userId,
      'date': _dateOnly(draft.date),
    };
    for (final section in sections) {
      data.addAll(_sectionBody(draft: draft, section: section));
    }
    await _post('/api/v1/log/daily', data);
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

  Map<String, dynamic> _payloadForSection({
    required DailyLogDraft draft,
    required LogSection section,
  }) {
    return {
      'user_id': draft.userId,
      'date': _dateOnly(draft.date),
      ..._sectionBody(draft: draft, section: section),
    };
  }

  Map<String, dynamic> _sectionBody({
    required DailyLogDraft draft,
    required LogSection section,
  }) {
    return switch (section) {
      LogSection.period => {
        if (draft.period != null && draft.period!.hasData) 'period': draft.period!.toJson(),
      },
      LogSection.symptoms => {
        if (draft.symptoms != null && draft.symptoms!.hasData) 'symptoms': draft.symptoms!.toJson(),
      },
      LogSection.temperature => {
        if (draft.temperature != null && draft.temperature!.hasData)
          'temperature': draft.temperature!.toJson(),
      },
      LogSection.lhTest => {
        if (draft.lhTest != null && draft.lhTest!.hasData) 'lh_test': draft.lhTest!.toJson(),
      },
      LogSection.cervicalMucus => {
        if (draft.cervicalMucus != null && draft.cervicalMucus!.hasData)
          'cervical_mucus': draft.cervicalMucus!.toJson(),
      },
      LogSection.intimacy => {
        if (draft.intimacy != null && draft.intimacy!.hasData) 'intimacy': draft.intimacy!.toJson(),
      },
    };
  }

  String _pathForSection(LogSection section) {
    return switch (section) {
      LogSection.period => '/api/v1/log/daily/period',
      LogSection.symptoms => '/api/v1/log/daily/symptoms',
      LogSection.temperature => '/api/v1/log/daily/temperature',
      LogSection.lhTest => '/api/v1/log/daily/lh-test',
      LogSection.cervicalMucus => '/api/v1/log/daily/cervical-mucus',
      LogSection.intimacy => '/api/v1/log/daily/intimacy',
    };
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
