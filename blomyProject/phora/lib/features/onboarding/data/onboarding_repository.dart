import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/features/onboarding/domain/onboarding_status.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(apiClient: ref.watch(apiClientProvider));
});

class OnboardingRepository {
  OnboardingRepository({required this.apiClient});

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<OnboardingProgress?> fetchProgress() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/onboarding/progress'),
      );
      final payload = response.data;
      if (payload == null || payload.isEmpty) {
        return null;
      }
      return OnboardingProgress.fromJson(payload);
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 404) {
        return null;
      }
      throw mapDioError(exception);
    }
  }

  Future<OnboardingProgress> saveProgress({
    required int currentStep,
    int? periodLength,
    DateTime? lastPeriodStart,
    DateTime? lastPeriodEnd,
    String? goal,
    List<String>? healthConditions,
  }) async {
    try {
      final response = await dio.patch<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/onboarding/progress'),
        data: {
          'current_step': currentStep,
          if (periodLength != null) 'period_length': periodLength,
          if (lastPeriodStart != null)
            'last_period_start': _dateOnly(lastPeriodStart),
          if (lastPeriodEnd != null) 'last_period_end': _dateOnly(lastPeriodEnd),
          if (goal != null && goal.isNotEmpty) 'goal': goal,
          if (healthConditions != null) 'health_conditions': healthConditions,
        },
      );
      final payload = response.data;
      if (payload == null || payload.isEmpty) {
        return OnboardingProgress(
          currentStep: currentStep,
          periodLength: periodLength,
          lastPeriodStart: lastPeriodStart,
          lastPeriodEnd: lastPeriodEnd,
          goal: goal,
          healthConditions: healthConditions ?? const [],
        );
      }
      return OnboardingProgress.fromJson(payload);
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 404) {
        return OnboardingProgress(
          currentStep: currentStep,
          periodLength: periodLength,
          lastPeriodStart: lastPeriodStart,
          lastPeriodEnd: lastPeriodEnd,
          goal: goal,
          healthConditions: healthConditions ?? const [],
        );
      }
      throw mapDioError(exception);
    }
  }

  Future<void> submitProfile({
    String? fullName,
    String? email,
    DateTime? dateOfBirth,
    String? country,
    String? timezone,
  }) async {
    await _post(
      '/api/v1/onboarding/profile',
      {
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (dateOfBirth != null) 'date_of_birth': _dateOnly(dateOfBirth),
        if (country != null && country.isNotEmpty) 'country': country,
        if (timezone != null && timezone.isNotEmpty) 'timezone': timezone,
      },
    );
  }

  Future<void> submitCycleHistory({
    int? averageCycleLength,
    int? averagePeriodLength,
    DateTime? lastPeriodStart,
    int? yearsMenstruating,
  }) async {
    await _post(
      '/api/v1/onboarding/cycle-history',
      {
        if (averageCycleLength != null)
          'average_cycle_length': averageCycleLength,
        if (averagePeriodLength != null)
          'average_period_length': averagePeriodLength,
        if (lastPeriodStart != null) 'last_period_start': _dateOnly(lastPeriodStart),
        if (yearsMenstruating != null) 'years_menstruating': yearsMenstruating,
      },
    );
  }

  Future<void> submitGoal({required String goal}) async {
    await _post('/api/v1/onboarding/goal', {'goal': goal});
  }

  Future<void> submitWearable({
    required String wearableType,
    Map<String, dynamic>? metadata,
  }) async {
    await _post(
      '/api/v1/onboarding/wearable',
      {
        'wearable_type': wearableType,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
    );
  }

  Future<void> submitHealthConditions({
    required List<String> conditions,
  }) async {
    await _post(
      '/api/v1/onboarding/health-conditions',
      {'conditions': conditions},
    );
  }

  Future<void> completeOnboarding({
    required DateTime lastPeriodStart,
    required DateTime lastPeriodEnd,
    required int averagePeriodLength,
    required int averageCycleLength,
    required String goal,
    required List<String> healthConditions,
  }) async {
    await _post(
      '/api/v1/onboarding/complete',
      {
        'cycle_history': {
          'last_period_start': _dateOnly(lastPeriodStart),
          'last_period_end': _dateOnly(lastPeriodEnd),
          'average_period_length': averagePeriodLength,
          'average_cycle_length': averageCycleLength,
        },
        'goal': goal,
        'health_conditions': healthConditions,
      },
    );
  }

  Future<void> submitPrivacyPreferences({
    required bool researchDataSharing,
    required bool healthAnalytics,
    required bool personalizedRecommendations,
    required bool productMessagingOptimization,
  }) async {
    await _post(
      '/api/v1/onboarding/privacy-preferences',
      {
        'research_data_sharing': researchDataSharing,
        'health_analytics': healthAnalytics,
        'personalized_recommendations': personalizedRecommendations,
        'product_messaging_optimization': productMessagingOptimization,
      },
    );
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

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
