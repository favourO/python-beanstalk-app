import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/features/growth/domain/growth_models.dart';

final growthRepositoryProvider = Provider<GrowthRepository>((ref) {
  return GrowthRepository(ref.watch(apiClientProvider));
});

class GrowthRepository {
  GrowthRepository(this.apiClient);

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<ShareInsightConfigModel> getShareInsightConfig() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/share-insight/config'),
      );
      return ShareInsightConfigModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<ShareInsightConfigModel> getCycleReportConfig() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/cycle-report/config'),
      );
      return ShareInsightConfigModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<ShareInsightModel> getShareInsight() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/share-insight'),
      );
      return ShareInsightModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<ShareGenerateResultModel> generateShareInsight({
    required List<String> sectionIds,
    required String audience,
    required String method,
    required int cycleCount,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/share-insight/generate'),
        data: {
          'section_ids': sectionIds,
          'audience': audience,
          'method': method,
          'cycle_count': cycleCount,
        },
      );
      return ShareGenerateResultModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<ShareGenerateResultModel> generateCycleReport({
    required List<String> sectionIds,
    required String audience,
    required String method,
    required int cycleCount,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/cycle-report/generate'),
        data: {
          'section_ids': sectionIds,
          'audience': audience,
          'method': method,
          'cycle_count': cycleCount,
        },
      );
      return ShareGenerateResultModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> trackShareEvent({
    required String shareId,
    required String event,
    String? channel,
    String? deepLinkId,
  }) async {
    try {
      await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/share-events'),
        data: {
          'share_id': shareId,
          'event': event,
          if (channel != null && channel.isNotEmpty) 'channel': channel,
          if (deepLinkId != null && deepLinkId.isNotEmpty)
            'deep_link_id': deepLinkId,
        },
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<FriendNetworkModel> getFriendNetwork() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/friends'),
      );
      return FriendNetworkModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<FriendConnectionModel> sendFriendRequest(String email) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/friends/requests'),
        data: {'email': email},
      );
      return FriendConnectionModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<FriendConnectionModel> acceptFriendRequest(String connectionId) async {
    return _friendAction(
      '/api/v1/growth/friends/requests/$connectionId/accept',
    );
  }

  Future<FriendConnectionModel> declineFriendRequest(
    String connectionId,
  ) async {
    return _friendAction(
      '/api/v1/growth/friends/requests/$connectionId/decline',
    );
  }

  Future<FriendConnectionModel> updateComparisonPermission({
    required String friendId,
    required bool enabled,
  }) async {
    try {
      final response = await apiClient.dio.put<Map<String, dynamic>>(
        buildVersionedApiUrl(
          dio,
          '/api/v1/growth/friends/$friendId/comparison-permission',
        ),
        data: {'enabled': enabled},
      );
      return FriendConnectionModel.fromJson(response.data ?? const {});
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<ComparisonSummaryModel> getComparisonSummary(String friendId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/compare/$friendId'),
      );
      return ComparisonSummaryModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<ReferralStatusModel> getReferralStatus() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/referral'),
      );
      return ReferralStatusModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> claimReferralCode({
    required String referralCode,
    String? source,
    String? deepLinkId,
  }) async {
    try {
      await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/growth/referral/claim'),
        data: {
          'referral_code': referralCode,
          if (source != null && source.isNotEmpty) 'source': source,
          if (deepLinkId != null && deepLinkId.isNotEmpty)
            'deep_link_id': deepLinkId,
        },
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<FriendConnectionModel> _friendAction(String path) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, path),
      );
      return FriendConnectionModel.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }
}
