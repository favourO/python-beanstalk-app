import 'dart:io';

import 'package:phora/app/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/notifications/mobile_notification_service.dart';
import 'package:phora/core/payments/apple_iap_service.dart';
import 'package:phora/core/preferences/app_preferences.dart';
import 'package:phora/core/utils/logger.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebase();
  await showRemoteMessageAsLocalNotification(
    message,
    includeNotificationPayload: false,
  );
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appPreferences = await AppPreferences.createOrFallback();
  await _initializeFirebase();
  await AppleIAPService.instance.initialize();
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(
    ProviderScope(
      overrides: [appPreferencesProvider.overrideWithValue(appPreferences)],
      child: const PhoraApp(),
    ),
  );
}

Future<void> _initializeFirebase() async {
  if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) {
    return;
  }

  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp();
  } catch (error) {
    logInfo('Firebase initialization skipped: $error');
  }
}
