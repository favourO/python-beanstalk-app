import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/app_supported_locale.dart';
import 'package:phora/core/i18n/locale_preferences.dart';
import 'package:phora/core/i18n/locale_resolution.dart';

enum LocaleSource { device, user, backend, fallback }

class LocaleState {
  const LocaleState({
    required this.activeLocale,
    required this.source,
    required this.hasCompletedLanguageSelection,
    required this.useDeviceLocale,
    this.backendLocaleTag,
  });

  final AppSupportedLocale activeLocale;
  final LocaleSource source;
  final bool hasCompletedLanguageSelection;
  final bool useDeviceLocale;
  final String? backendLocaleTag;

  LocaleState copyWith({
    AppSupportedLocale? activeLocale,
    LocaleSource? source,
    bool? hasCompletedLanguageSelection,
    bool? useDeviceLocale,
    String? backendLocaleTag,
  }) {
    return LocaleState(
      activeLocale: activeLocale ?? this.activeLocale,
      source: source ?? this.source,
      hasCompletedLanguageSelection:
          hasCompletedLanguageSelection ?? this.hasCompletedLanguageSelection,
      useDeviceLocale: useDeviceLocale ?? this.useDeviceLocale,
      backendLocaleTag: backendLocaleTag ?? this.backendLocaleTag,
    );
  }
}

final localePreferencesProvider = Provider<LocalePreferences>((ref) {
  return LocalePreferences(ref.watch(appPreferencesProvider));
});

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, LocaleState>(LocaleController.new);

class LocaleController extends AsyncNotifier<LocaleState> {
  @override
  Future<LocaleState> build() async {
    final preferences = ref.read(localePreferencesProvider);
    final useDeviceLocale = await preferences.getUseDeviceLocale();
    final preferredLocaleTag = await preferences.getPreferredLocaleTag();
    final selectionCompleted =
        await preferences.getLanguageSelectionCompleted();
    final deviceLocale = PlatformDispatcher.instance.locale;

    final activeLocale =
        useDeviceLocale
            ? LocaleResolution.resolveDeviceLocale(deviceLocale)
            : LocaleResolution.resolveBest(
              userPreferenceTag: preferredLocaleTag,
              deviceLocale: deviceLocale,
            );

    return LocaleState(
      activeLocale: activeLocale,
      source: useDeviceLocale ? LocaleSource.device : LocaleSource.user,
      hasCompletedLanguageSelection: selectionCompleted,
      useDeviceLocale: useDeviceLocale,
    );
  }

  Future<void> setExplicitLocale(AppSupportedLocale locale) async {
    final preferences = ref.read(localePreferencesProvider);
    await preferences.setPreferredLocaleTag(locale.tag);
    await preferences.setUseDeviceLocale(false);
    final current = state.valueOrNull ?? await future;
    state = AsyncData(
      current.copyWith(
        activeLocale: locale,
        source: LocaleSource.user,
        useDeviceLocale: false,
      ),
    );
  }

  Future<void> useDeviceLocale() async {
    final preferences = ref.read(localePreferencesProvider);
    await preferences.setUseDeviceLocale(true);
    final current = state.valueOrNull ?? await future;
    state = AsyncData(
      current.copyWith(
        activeLocale: LocaleResolution.resolveDeviceLocale(
          PlatformDispatcher.instance.locale,
        ),
        source: LocaleSource.device,
        useDeviceLocale: true,
      ),
    );
  }

  Future<void> markLanguageSelectionCompleted() async {
    final preferences = ref.read(localePreferencesProvider);
    await preferences.setLanguageSelectionCompleted(true);
    final current = state.valueOrNull ?? await future;
    state = AsyncData(current.copyWith(hasCompletedLanguageSelection: true));
  }

  void syncFromBackend(String? preferredLocaleTag) {
    final current = state.valueOrNull;
    if (current == null || current.useDeviceLocale) {
      return;
    }
    final backendLocale = AppSupportedLocale.fromTag(preferredLocaleTag);
    if (backendLocale == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        activeLocale: backendLocale,
        source: LocaleSource.backend,
        backendLocaleTag: backendLocale.tag,
      ),
    );
  }
}
