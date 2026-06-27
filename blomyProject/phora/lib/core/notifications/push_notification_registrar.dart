import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/app/env.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/locale_controller.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pushNotificationRegistrarProvider = Provider<PushNotificationRegistrar>(
  (ref) => PushNotificationRegistrar(
    apiClient: ref.watch(apiClientProvider),
    ref: ref,
  ),
);

class PushNotificationRegistrar {
  PushNotificationRegistrar({required this.apiClient, required this.ref});

  static const _deviceIdKey = 'phora.notification_device_id';

  final ApiClient apiClient;
  final Ref ref;
  bool _tokenRefreshListenerAttached = false;
  String? _lastRegisteredToken;
  String? _lastRegisteredUserId;

  Future<void> registerCurrentDevice() async {
    if (!_isSupportedPlatform) {
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        logInfo('Push notification permission denied.');
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        logInfo('No FCM token returned for this device.');
        return;
      }

      await _registerToken(token);
      _attachTokenRefreshListener(messaging);
    } catch (error) {
      logInfo('Push notification registration skipped: $error');
    }
  }

  void clearRegisteredUser() {
    _lastRegisteredUserId = null;
  }

  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  void _attachTokenRefreshListener(FirebaseMessaging messaging) {
    if (_tokenRefreshListenerAttached) {
      return;
    }
    _tokenRefreshListenerAttached = true;
    messaging.onTokenRefresh.listen((token) async {
      if (token.isEmpty) {
        return;
      }
      await _registerToken(token);
    });
  }

  Future<void> _registerToken(String token) async {
    final session = ref.read(authSessionProvider).valueOrNull;
    final userId = session?.isAuthenticated == true ? session!.userId : null;
    if (userId == null || userId.isEmpty) {
      logInfo('Push notification registration skipped: no authenticated user.');
      return;
    }

    if (_lastRegisteredToken == token && _lastRegisteredUserId == userId) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final deviceId = await _deviceId(preferences);
    final platform = Platform.isIOS ? 'ios' : 'android';
    final locale =
        ref.read(localeControllerProvider).valueOrNull?.activeLocale.tag ??
        PlatformDispatcher.instance.locale.toLanguageTag();

    await apiClient.dio.post<Map<String, dynamic>>(
      buildVersionedApiUrl(apiClient.dio, '/api/v1/notifications/devices'),
      data: {
        'platform': platform,
        'device_id': deviceId,
        'fcm_token': token,
        'app_version': kAppVersion,
        'device_name': Platform.isIOS ? 'iOS device' : 'Android device',
        'locale': locale,
        'notifications_enabled': true,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    _lastRegisteredToken = token;
    _lastRegisteredUserId = userId;
  }

  Future<String> _deviceId(SharedPreferences preferences) async {
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await preferences.setString(_deviceIdKey, id);
    return id;
  }
}
