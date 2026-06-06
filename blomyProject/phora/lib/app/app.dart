import 'dart:async';

import 'package:phora/app/router.dart';
import 'package:phora/app/theme_controller.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/app_supported_locale.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/i18n/locale_controller.dart';
import 'package:phora/core/i18n/locale_resolution.dart';
import 'package:phora/features/auth/domain/app_session.dart';
import 'package:phora/core/notifications/mobile_notification_service.dart';
import 'package:phora/core/notifications/push_notification_registrar.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/growth/growth_providers.dart';
import 'package:phora/features/wearables/providers/phora_wear_sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:phora/l10n/app_localizations.dart';

class PhoraApp extends ConsumerStatefulWidget {
  const PhoraApp({super.key});

  @override
  ConsumerState<PhoraApp> createState() => _PhoraAppState();
}

class _PhoraAppState extends ConsumerState<PhoraApp> {
  late final ProviderSubscription<AsyncValue<AppSession?>>
  _authSessionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(mobileNotificationServiceProvider).initialize());
    });
    _authSessionSubscription = ref.listenManual<AsyncValue<AppSession?>>(
      authSessionProvider,
      (_, next) {
        final session = next.valueOrNull;
        if (session?.isAuthenticated != true) {
          ref.read(phoraWearSyncControllerProvider.notifier).stop();
          return;
        }
        unawaited(
          ref.read(pushNotificationRegistrarProvider).registerCurrentDevice(),
        );
        unawaited(
          ref
              .read(pendingReferralClaimControllerProvider.notifier)
              .claimIfNeeded(session),
        );
        unawaited(ref.read(phoraWearSyncControllerProvider.notifier).start());
      },
    );
  }

  @override
  void dispose() {
    _authSessionSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final localeState = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: localeState.valueOrNull?.activeLocale.flutterLocale,
      supportedLocales: AppSupportedLocale.supportedFlutterLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback:
          (locale, supportedLocales) =>
              LocaleResolution.resolveSupportedLocale(locale, supportedLocales),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
