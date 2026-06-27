import 'dart:ui';

import 'package:phora/app/env.dart';
import 'package:phora/core/api/api_interceptors.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/locale_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(tokenStoreProvider).readAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final localeState = ref.read(localeControllerProvider).valueOrNull;
        final localeTag =
            localeState?.activeLocale.tag ??
            PlatformDispatcher.instance.locale.toLanguageTag();
        options.headers['Accept-Language'] = localeTag;
        options.headers['X-User-Locale'] = localeTag;
        handler.next(options);
      },
    ),
  );

  dio.interceptors.add(
    ApiErrorInterceptor(
      onUnauthorized: (error) async {
        final request = error.requestOptions;
        if (_isTokenRevokedError(error)) {
          await _clearLocalAuthSession(ref);
          return null;
        }
        if (request.extra[kSkipAuthRefreshKey] == true ||
            request.extra[kRetriedAfterAuthRefreshKey] == true) {
          return null;
        }

        final refreshToken =
            await ref.read(tokenStoreProvider).readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          return null;
        }

        late final Response<Map<String, dynamic>> refreshResponse;
        try {
          refreshResponse = await dio.post<Map<String, dynamic>>(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
            options: Options(
              extra: const {
                kSkipAuthRefreshKey: true,
                kSkipUnauthorizedLogoutKey: true,
              },
            ),
          );
        } on DioException catch (refreshError) {
          if (_isTokenRevokedError(refreshError)) {
            await _clearLocalAuthSession(ref);
          }
          return null;
        }
        final payload = refreshResponse.data ?? <String, dynamic>{};
        final accessToken = _stringValue(payload['access_token']);
        final nextRefreshToken = _stringValue(payload['refresh_token']);
        if (accessToken == null || nextRefreshToken == null) {
          return null;
        }

        final tokenStore = ref.read(tokenStoreProvider);
        await tokenStore.writeAccessToken(accessToken);
        await tokenStore.writeRefreshToken(nextRefreshToken);

        final session = ref.read(authSessionProvider).valueOrNull;
        if (session != null) {
          ref
              .read(authSessionProvider.notifier)
              .setSession(
                session.copyWith(
                  accessToken: accessToken,
                  refreshToken: nextRefreshToken,
                ),
              );
        }

        final retryHeaders = Map<String, dynamic>.from(request.headers);
        retryHeaders['Authorization'] = 'Bearer $accessToken';
        return dio.request<dynamic>(
          request.path,
          data: request.data,
          queryParameters: request.queryParameters,
          cancelToken: request.cancelToken,
          onReceiveProgress: request.onReceiveProgress,
          onSendProgress: request.onSendProgress,
          options: Options(
            method: request.method,
            headers: retryHeaders,
            responseType: request.responseType,
            contentType: request.contentType,
            followRedirects: request.followRedirects,
            receiveDataWhenStatusError: request.receiveDataWhenStatusError,
            extra: {...request.extra, kRetriedAfterAuthRefreshKey: true},
          ),
        );
      },
      onPaywalled: (failure) async {
        ref.read(lastPaywallFailureProvider.notifier).state = failure;
      },
    ),
  );

  return dio;
});

Future<void> _clearLocalAuthSession(Ref ref) async {
  await ref.read(sessionCleanupProvider).clearLocalSession();
  ref.read(authSessionProvider.notifier).setSession(null);
}

bool _isTokenRevokedError(DioException error) {
  if (error.response?.statusCode != 401) return false;
  final message = _errorMessage(error.response?.data).toLowerCase();
  return message.contains('token revoked') ||
      message.contains('revoked token') ||
      (message.contains('revoked') && message.contains('token'));
}

String _errorMessage(dynamic data) {
  if (data is String) return data;
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is Map) {
      final message = detail['message'];
      if (message is String) return message;
      final error = detail['error'];
      if (error is String) return error;
    }
    final message = data['message'];
    if (message is String) return message;
    final error = data['error'];
    if (error is String) return error;
  }
  return '';
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await dio.get<Map<String, dynamic>>(path);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(path, data: data);
    return response.data ?? <String, dynamic>{};
  }
}

String? _stringValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
