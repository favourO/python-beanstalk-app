import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/app/router.dart';
import 'package:phora/core/notifications/notification_destination.dart';
import 'package:phora/core/preferences/app_preferences.dart';
import 'package:phora/core/utils/logger.dart';
import 'package:phora/features/profile/profile_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final mobileNotificationServiceProvider = Provider<MobileNotificationService>((
  ref,
) {
  return MobileNotificationService(ref: ref, router: ref.watch(routerProvider));
});

@pragma('vm:entry-point')
void localNotificationTapBackground(NotificationResponse response) {}

class MobileNotificationService {
  MobileNotificationService({required this.ref, required this.router});

  static const _androidChannel = AndroidNotificationChannel(
    'phora_notifications',
    'Vyla notifications',
    description: 'Cycle predictions, health insights, and app reminders.',
    importance: Importance.high,
  );

  final Ref ref;
  final GoRouter router;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) {
      return;
    }
    _initialized = true;

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
      await androidPlugin?.createNotificationChannel(_androidChannel);
      await androidPlugin?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

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
    _openNotificationDestination(message.data);
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    _refreshNotificationHistory();
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      router.go('/notifications');
      return;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _openNotificationDestination(decoded);
        return;
      }
    } catch (_) {
      // Fall through to the notification center.
    }
    router.go('/notifications');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final id =
        (message.messageId ?? message.sentTime?.millisecondsSinceEpoch).hashCode
            .abs();
    final payload = jsonEncode(message.data);
    await _localNotifications.show(
      id: id,
      title: title ?? 'Vyla',
      body: body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> scheduleDailyBbtReminder({
    required ReminderTime time,
    required String title,
    required String body,
    required String route,
    required bool wearableReminder,
  }) async {
    if (!_initialized || !_isSupportedPlatform) {
      return;
    }
    final id = wearableReminder ? 9301 : 9302;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode({'action_url': route, 'type': 'bbt_collection'}),
    );
  }

  Future<void> cancelBbtReminders() async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _localNotifications.cancel(id: 9301);
    await _localNotifications.cancel(id: 9302);
  }

  void _openNotificationDestination(Map<String, dynamic> data) {
    router.go(notificationDestinationFromData(data));
  }

  void _refreshNotificationHistory() {
    ref.invalidate(notificationHistoryProvider);
  }
}
