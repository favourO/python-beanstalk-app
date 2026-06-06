import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/features/wearables/domain/health_data_source.dart';

final healthDataRepositoryProvider = Provider<HealthDataRepository>((ref) {
  return HealthDataRepository(apiClient: ref.watch(apiClientProvider));
});

class HealthDataRepository {
  HealthDataRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<HealthMetric>> fetchMetrics({
    HealthDataSource? source,
    String? metricType,
    int days = 30,
    int limit = 100,
  }) async {
    final queryParams = <String, String>{
      'days': days.toString(),
      'limit': limit.toString(),
      if (source != null) 'source': source.apiValue,
      if (metricType != null) 'metric_type': metricType,
    };
    final query = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final path = '/wearables/health-metrics?$query';
    final response = await _apiClient.getJson(path);
    final list = response['metrics'] as List<dynamic>? ?? const [];
    return list
        .map((item) => HealthMetric.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<HealthMetric>> fetchVylaWearableMetrics({
    String? metricType,
    int days = 30,
  }) => fetchMetrics(
    source: HealthDataSource.vylaWearable,
    metricType: metricType,
    days: days,
  );
}
