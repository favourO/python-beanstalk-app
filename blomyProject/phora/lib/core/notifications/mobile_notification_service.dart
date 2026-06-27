import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/app/router.dart';
import 'package:phora/core/utils/logger.dart';
import 'package:phora/features/profile/profile_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;

final mobileNotificationServiceProvider = Provider<MobileNotificationService>((
  ref,
) {
  return MobileNotificationService(ref: ref, router: ref.watch(routerProvider));
});

const phoraAndroidNotificationChannel = AndroidNotificationChannel(
  'phora_notifications',
  'Vyla notifications',
  description: 'Cycle predictions, health insights, and app reminders.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
void localNotificationTapBackground(NotificationResponse response) {}

@pragma('vm:entry-point')
Future<void> showRemoteMessageAsLocalNotification(
  RemoteMessage message, {
  bool includeNotificationPayload = true,
}) async {
  final localNotifications = FlutterLocalNotificationsPlugin();
  await _showRemoteMessageAsLocalNotificationWithPlugin(
    message,
    localNotifications,
    includeNotificationPayload: includeNotificationPayload,
    initializePlugin: true,
  );
}

Future<void> _showRemoteMessageAsLocalNotificationWithPlugin(
  RemoteMessage message,
  FlutterLocalNotificationsPlugin localNotifications, {
  required bool includeNotificationPayload,
  required bool initializePlugin,
}) async {
  final notification = message.notification;
  if (!includeNotificationPayload && notification != null) {
    return;
  }

  final title = notification?.title ?? message.data['title']?.toString();
  final body = notification?.body ?? message.data['body']?.toString();
  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return;
  }

  if (initializePlugin) {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(
      settings: settings,
      onDidReceiveBackgroundNotificationResponse:
          localNotificationTapBackground,
    );
  }

  if (!kIsWeb && Platform.isAndroid) {
    final androidPlugin =
        localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(
      phoraAndroidNotificationChannel,
    );
  }

  final id =
      (message.messageId ?? message.sentTime?.millisecondsSinceEpoch).hashCode
          .abs();
  final payloadData =
      message.data.isEmpty
          ? <String, dynamic>{'notification_type': 'update'}
          : message.data;
  await localNotifications.show(
    id: id,
    title: title ?? 'Vyla',
    body: body ?? '',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        phoraAndroidNotificationChannel.id,
        phoraAndroidNotificationChannel.name,
        channelDescription: phoraAndroidNotificationChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: jsonEncode(payloadData),
  );
}

class MobileNotificationService {
  MobileNotificationService({required this.ref, required this.router});

  final Ref ref;
  final GoRouter router;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void>? _initializeFuture;

  Future<void> initialize() async {
    if (!_isSupportedPlatform) {
      return;
    }
    if (_initialized) {
      await _initializeFuture;
      return;
    }

    _initialized = true;
    _initializeFuture = _initializeSafely();
    await _initializeFuture;
  }

  Future<void> _initializeSafely() async {
    try {
      await _initializeLocalNotifications();
      tzdata.initializeTimeZones();
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }
    } catch (error) {
      logInfo('Mobile notification initialization skipped: $error');
    }
  }

  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          localNotificationTapBackground,
    );

    if (Platform.isAndroid) {
      final androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidPlugin?.createNotificationChannel(
        phoraAndroidNotificationChannel,
      );
      await androidPlugin?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    await cancelLegacyScheduledReminders();

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true && response != null) {
      _handleLocalNotificationTap(response);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _refreshNotificationHistory();
    await _showLocalNotification(message);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    _refreshNotificationHistory();
    router.go('/notifications');
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    _refreshNotificationHistory();
    router.go('/notifications');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    await _showRemoteMessageAsLocalNotificationWithPlugin(
      message,
      _localNotifications,
      includeNotificationPayload: true,
      initializePlugin: false,
    );
  }

  Future<void> cancelLegacyScheduledReminders() async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _localNotifications.cancel(id: 9301);
    await _localNotifications.cancel(id: 9302);
    for (var id = 9400; id <= 9410; id += 1) {
      await _localNotifications.cancel(id: id);
    }
    for (var id = 9500; id <= 9530; id += 1) {
      await _localNotifications.cancel(id: id);
    }
  }

  void _refreshNotificationHistory() {
    ref.invalidate(notificationHistoryProvider);
  }
}
