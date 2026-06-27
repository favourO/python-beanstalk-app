import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/features/profile/domain/age_profile.dart';
import 'package:phora/features/profile/domain/notification_models.dart';
import 'package:phora/features/profile/domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(apiClient: ref.watch(apiClientProvider));
});

class ProfileRepository {
  ProfileRepository({required this.apiClient});

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<UserProfile> getUserProfile() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/user/profile'),
      );
      final data = response.data ?? <String, dynamic>{};
      return UserProfile(
        userId: _stringValue(data['user_id']) ?? '',
        email: _stringValue(data['email']) ?? '',
        emailVerified: data['email_verified'] == true,
        accountMode: _stringValue(data['account_mode']) ?? 'registered',
        fullName: _stringValue(data['full_name']) ?? 'Vyla User',
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AgeProfile> getAgeProfile() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/user/age-profile'),
      );
      final data = response.data ?? <String, dynamic>{};
      return AgeProfile(
        dateOfBirth: _dateValue(data['date_of_birth']),
        ageBand: _stringValue(data['age_band']),
        perimenopauseModeActive: data['perimenopause_mode_active'] == true,
        perimenopauseModeSource: _stringValue(
          data['perimenopause_mode_source'],
        ),
        reproductiveStage: _stringValue(data['reproductive_stage']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> updateAgeProfile({
    DateTime? dateOfBirth,
    bool? perimenopauseModeActive,
    String? perimenopauseModeSource,
    String? reproductiveStage,
  }) async {
    try {
      await dio.put<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/user/age-profile'),
        data: {
          if (dateOfBirth != null)
            'date_of_birth':
                '${dateOfBirth.year.toString().padLeft(4, '0')}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}',
          if (perimenopauseModeActive != null)
            'perimenopause_mode_active': perimenopauseModeActive,
          if (perimenopauseModeSource != null &&
              perimenopauseModeSource.isNotEmpty)
            'perimenopause_mode_source': perimenopauseModeSource,
          if (reproductiveStage != null && reproductiveStage.isNotEmpty)
            'reproductive_stage': reproductiveStage,
        },
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> setReproductiveStage({required String stage}) async {
    try {
      await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/user/reproductive-stage'),
        data: {'stage': stage},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<NotificationSettings> getNotificationSettings() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/notifications/settings'),
      );
      return NotificationSettings.fromJson(response.data);
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> updateNotificationSettings({
    required Map<String, dynamic> patch,
  }) async {
    try {
      await dio.put<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/notifications/settings'),
        data: patch,
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<NotificationHistory> getNotificationHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        buildVersionedApiUrl(dio, '/api/v1/notifications'),
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = response.data;
      final unreadCount =
          data is Map<String, dynamic>
              ? _intValue(data['unread_count'] ?? data['unreadCount'])
              : null;
      final totalCount =
          data is Map<String, dynamic>
              ? _intValue(
                data['total_count'] ?? data['totalCount'] ?? data['total'],
              )
              : null;
      final nextOffset =
          data is Map<String, dynamic>
              ? _intValue(data['next_offset'] ?? data['nextOffset'])
              : null;
      final hasMoreValue =
          data is Map<String, dynamic>
              ? data['has_more'] ?? data['hasMore'] ?? data['more']
              : null;
      final items =
          data is List
              ? data
              : data is Map<String, dynamic>
              ? (data['items'] ??
                      data['notifications'] ??
                      data['results'] ??
                      data['data'])
                  as List<dynamic>?
              : null;
      if (items == null) {
        return const NotificationHistory.empty();
      }
      final notifications =
          items
              .whereType<Map>()
              .map(
                (item) =>
                    AppNotification.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
      return NotificationHistory(
        items: notifications,
        unreadCount:
            unreadCount ?? notifications.where((item) => !item.isRead).length,
        hasMore:
            hasMoreValue is bool
                ? hasMoreValue
                : nextOffset != null
                ? true
                : totalCount != null
                ? offset + notifications.length < totalCount
                : notifications.length >= limit,
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<List<AppNotification>> getNotifications({int limit = 20}) async {
    final history = await getNotificationHistory(limit: limit);
    return history.items;
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/notifications/read-all'),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/notifications/$notificationId/read'),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await dio.delete<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/notifications/$notificationId'),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      await dio.delete<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/notifications'),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
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

  DateTime? _dateValue(dynamic value) {
    final string = _stringValue(value);
    if (string == null) {
      return null;
    }
    return DateTime.tryParse(string)?.toLocal();
  }

  int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
