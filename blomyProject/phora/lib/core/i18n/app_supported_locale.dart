import 'package:flutter/widgets.dart';

class AppSupportedLocale {
  const AppSupportedLocale({
    required this.languageCode,
    this.countryCode,
    required this.displayName,
    required this.nativeDisplayName,
  });

  final String languageCode;
  final String? countryCode;
  final String displayName;
  final String nativeDisplayName;

  String get tag =>
      countryCode == null || countryCode!.isEmpty
          ? languageCode
          : '$languageCode-${countryCode!}';

  Locale get flutterLocale =>
      Locale.fromSubtags(languageCode: languageCode, countryCode: countryCode);

  static const english = AppSupportedLocale(
    languageCode: 'en',
    displayName: 'English',
    nativeDisplayName: 'English',
  );
  static const englishUk = AppSupportedLocale(
    languageCode: 'en',
    countryCode: 'GB',
    displayName: 'English (UK)',
    nativeDisplayName: 'English (UK)',
  );
  static const englishUs = AppSupportedLocale(
    languageCode: 'en',
    countryCode: 'US',
    displayName: 'English (US)',
    nativeDisplayName: 'English (US)',
  );
  static const englishCanada = AppSupportedLocale(
    languageCode: 'en',
    countryCode: 'CA',
    displayName: 'English (Canada)',
    nativeDisplayName: 'English (Canada)',
  );
  static const englishAustralia = AppSupportedLocale(
    languageCode: 'en',
    countryCode: 'AU',
    displayName: 'English (Australia)',
    nativeDisplayName: 'English (Australia)',
  );
  static const spanish = AppSupportedLocale(
    languageCode: 'es',
    displayName: 'Spanish',
    nativeDisplayName: 'Espanol',
  );
  static const spanishSpain = AppSupportedLocale(
    languageCode: 'es',
    countryCode: 'ES',
    displayName: 'Spanish (Spain)',
    nativeDisplayName: 'Espanol (Espana)',
  );
  static const spanishLatam = AppSupportedLocale(
    languageCode: 'es',
    countryCode: '419',
    displayName: 'Spanish (Latin America)',
    nativeDisplayName: 'Espanol (Latinoamerica)',
  );
  static const french = AppSupportedLocale(
    languageCode: 'fr',
    displayName: 'French',
    nativeDisplayName: 'Francais',
  );
  static const frenchFrance = AppSupportedLocale(
    languageCode: 'fr',
    countryCode: 'FR',
    displayName: 'French (France)',
    nativeDisplayName: 'Francais (France)',
  );
  static const frenchCanada = AppSupportedLocale(
    languageCode: 'fr',
    countryCode: 'CA',
    displayName: 'French (Canada)',
    nativeDisplayName: 'Francais (Canada)',
  );
  static const german = AppSupportedLocale(
    languageCode: 'de',
    displayName: 'German',
    nativeDisplayName: 'Deutsch',
  );
  static const germanGermany = AppSupportedLocale(
    languageCode: 'de',
    countryCode: 'DE',
    displayName: 'German (Germany)',
    nativeDisplayName: 'Deutsch (Deutschland)',
  );
  static const germanAustria = AppSupportedLocale(
    languageCode: 'de',
    countryCode: 'AT',
    displayName: 'German (Austria)',
    nativeDisplayName: 'Deutsch (Osterreich)',
  );
  static const germanSwitzerland = AppSupportedLocale(
    languageCode: 'de',
    countryCode: 'CH',
    displayName: 'German (Switzerland)',
    nativeDisplayName: 'Deutsch (Schweiz)',
  );
  static const portuguese = AppSupportedLocale(
    languageCode: 'pt',
    displayName: 'Portuguese',
    nativeDisplayName: 'Portugues',
  );
  static const portugueseBrazil = AppSupportedLocale(
    languageCode: 'pt',
    countryCode: 'BR',
    displayName: 'Portuguese (Brazil)',
    nativeDisplayName: 'Portugues (Brasil)',
  );
  static const portuguesePortugal = AppSupportedLocale(
    languageCode: 'pt',
    countryCode: 'PT',
    displayName: 'Portuguese (Portugal)',
    nativeDisplayName: 'Portugues (Portugal)',
  );

  static const all = <AppSupportedLocale>[
    english,
    englishUk,
    englishUs,
    englishCanada,
    englishAustralia,
    spanish,
    spanishSpain,
    spanishLatam,
    french,
    frenchFrance,
    frenchCanada,
    german,
    germanGermany,
    germanAustria,
    germanSwitzerland,
    portuguese,
    portugueseBrazil,
    portuguesePortugal,
  ];

  static const defaultLocale = english;

  static List<Locale> get supportedFlutterLocales =>
      all.map((locale) => locale.flutterLocale).toList(growable: false);

  static AppSupportedLocale? fromTag(String? tag) {
    if (tag == null || tag.trim().isEmpty) {
      return null;
    }
    final normalized = tag.trim().replaceAll('_', '-').toLowerCase();
    for (final locale in all) {
      if (locale.tag.toLowerCase() == normalized) {
        return locale;
      }
    }
    return null;
  }
}
