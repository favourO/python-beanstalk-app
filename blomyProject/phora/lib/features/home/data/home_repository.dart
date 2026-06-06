import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/preferences/app_preferences.dart';
import 'package:phora/features/home/domain/home_dashboard.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(
    apiClient: ref.watch(apiClientProvider),
    preferences: ref.watch(appPreferencesProvider),
  );
});

class HomeDashboardFetchResult {
  const HomeDashboardFetchResult({
    required this.dashboard,
    required this.fromCache,
    this.cachedAt,
  });

  final HomeDashboard dashboard;
  final bool fromCache;
  final DateTime? cachedAt;
}

class HomeRepository {
  HomeRepository({required this.apiClient, required this.preferences});

  final ApiClient apiClient;
  final AppPreferences preferences;

  Dio get dio => apiClient.dio;

  Future<HomeDashboardFetchResult> getHomeDashboard() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/home'),
      );
      final data = response.data ?? const <String, dynamic>{};
      await preferences.setCachedHomeDashboardJson(data);
      return HomeDashboardFetchResult(
        dashboard: HomeDashboard.fromJson(data),
        fromCache: false,
      );
    } on DioException catch (exception) {
      if (_isOfflineException(exception)) {
        final cached = await preferences.getCachedHomeDashboardJson();
        if (cached != null) {
          return HomeDashboardFetchResult(
            dashboard: HomeDashboard.fromJson(cached),
            fromCache: true,
            cachedAt: await preferences.getCachedHomeDashboardAt(),
          );
        }
      }
      throw mapDioError(exception);
    }
  }

  bool _isOfflineException(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.unknown => true,
      _ => false,
    };
  }
}
