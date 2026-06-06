import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/features/log/daily_log_models.dart';

final aiLogAssistantRepositoryProvider = Provider<AiLogAssistantRepository>((
  ref,
) {
  return AiLogAssistantRepository(apiClient: ref.watch(apiClientProvider));
});

class AiLogAssistantRepository {
  AiLogAssistantRepository({required this.apiClient});

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<AiPeriodAssistResponse> assistPeriodLog({
    required String message,
    required PeriodLogDraft period,
    required SymptomsLogDraft symptoms,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/ai/log/period-assist'),
        data: {
          'message': message,
          'current': {'period': period.toJson(), 'symptoms': symptoms.toJson()},
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      return AiPeriodAssistResponse(
        assistantMessage:
            _stringValue(data['assistant_message']) ??
            'Thanks. I updated your period details.',
        nextStep: _stringValue(data['next_step']) ?? 'review',
        completed: data['completed'] == true,
        period:
            data['period'] is Map<String, dynamic>
                ? PeriodLogDraft.fromJson(
                  data['period'] as Map<String, dynamic>,
                )
                : data['period'] is Map
                ? PeriodLogDraft.fromJson(
                  Map<String, dynamic>.from(data['period'] as Map),
                )
                : period,
        symptoms:
            data['symptoms'] is Map<String, dynamic>
                ? SymptomsLogDraft.fromJson(
                  data['symptoms'] as Map<String, dynamic>,
                )
                : data['symptoms'] is Map
                ? SymptomsLogDraft.fromJson(
                  Map<String, dynamic>.from(data['symptoms'] as Map),
                )
                : symptoms,
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}

class AiPeriodAssistResponse {
  const AiPeriodAssistResponse({
    required this.assistantMessage,
    required this.nextStep,
    required this.completed,
    required this.period,
    required this.symptoms,
  });

  final String assistantMessage;
  final String nextStep;
  final bool completed;
  final PeriodLogDraft period;
  final SymptomsLogDraft symptoms;
}
