import 'package:flutter/widgets.dart';
import 'package:phora/core/i18n/app_supported_locale.dart';

class LocaleResolution {
  const LocaleResolution._();

  static AppSupportedLocale resolveFromTag(String? tag) {
    final exact = AppSupportedLocale.fromTag(tag);
    if (exact != null) {
      return exact;
    }

    if (tag == null || tag.trim().isEmpty) {
      return AppSupportedLocale.defaultLocale;
    }

    final normalized = tag.trim().replaceAll('_', '-');
    final parts = normalized.split('-');
    final languageCode = parts.first.toLowerCase();
    final countryCode =
        parts.length > 1 && parts[1].isNotEmpty ? parts[1].toUpperCase() : null;
    return resolveDeviceLocale(
      Locale.fromSubtags(languageCode: languageCode, countryCode: countryCode),
    );
  }

  static AppSupportedLocale resolveDeviceLocale(Locale? locale) {
    if (locale == null) {
      return AppSupportedLocale.defaultLocale;
    }

    final languageCode = locale.languageCode.toLowerCase();
    final countryCode = locale.countryCode?.toUpperCase();

    return switch (languageCode) {
      'en' => switch (countryCode) {
        'GB' => AppSupportedLocale.englishUk,
        'US' => AppSupportedLocale.englishUs,
        'CA' => AppSupportedLocale.englishCanada,
        'AU' => AppSupportedLocale.englishAustralia,
        _ => AppSupportedLocale.english,
      },
      'es' => switch (countryCode) {
        'ES' => AppSupportedLocale.spanishSpain,
        'MX' ||
        'AR' ||
        'CO' ||
        'CL' ||
        'PE' ||
        'VE' ||
        'EC' ||
        'UY' ||
        'PY' ||
        'BO' ||
        'DO' ||
        'CR' ||
        'GT' ||
        'HN' ||
        'NI' ||
        'PA' ||
        'PR' ||
        'SV' => AppSupportedLocale.spanishLatam,
        '419' => AppSupportedLocale.spanishLatam,
        _ => AppSupportedLocale.spanish,
      },
      'fr' => switch (countryCode) {
        'FR' => AppSupportedLocale.frenchFrance,
        'CA' => AppSupportedLocale.frenchCanada,
        _ => AppSupportedLocale.french,
      },
      'de' => switch (countryCode) {
        'DE' => AppSupportedLocale.germanGermany,
        'AT' => AppSupportedLocale.germanAustria,
        'CH' => AppSupportedLocale.germanSwitzerland,
        _ => AppSupportedLocale.german,
      },
      'pt' => switch (countryCode) {
        'BR' => AppSupportedLocale.portugueseBrazil,
        'PT' => AppSupportedLocale.portuguesePortugal,
        _ => AppSupportedLocale.portuguese,
      },
      _ => AppSupportedLocale.defaultLocale,
    };
  }

  static AppSupportedLocale resolveBest({
    String? userPreferenceTag,
    String? backendPreferenceTag,
    Locale? deviceLocale,
  }) {
    final userPreferred = AppSupportedLocale.fromTag(userPreferenceTag);
    if (userPreferred != null) {
      return userPreferred;
    }

    final backendPreferred = AppSupportedLocale.fromTag(backendPreferenceTag);
    if (backendPreferred != null) {
      return backendPreferred;
    }

    return resolveDeviceLocale(deviceLocale);
  }

  static Locale resolveSupportedLocale(
    Locale? locale,
    Iterable<Locale> supportedLocales,
  ) {
    final resolved = resolveDeviceLocale(locale).flutterLocale;
    for (final supported in supportedLocales) {
      if (supported.languageCode == resolved.languageCode &&
          supported.countryCode == resolved.countryCode) {
        return supported;
      }
    }
    for (final supported in supportedLocales) {
      if (supported.languageCode == resolved.languageCode) {
        return supported;
      }
    }
    return supportedLocales.first;
  }
}
