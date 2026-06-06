import 'package:intl/intl.dart';

class AppFormatters {
  const AppFormatters._();

  static String formatDateShort(DateTime value, {required String localeTag}) {
    return DateFormat.yMd(_intlLocale(localeTag)).format(value);
  }

  static String formatDateLong(DateTime value, {required String localeTag}) {
    return DateFormat.yMMMMd(_intlLocale(localeTag)).format(value);
  }

  static String formatDateMedium(DateTime value, {required String localeTag}) {
    return DateFormat.yMMMd(_intlLocale(localeTag)).format(value);
  }

  static String formatMonthYear(DateTime value, {required String localeTag}) {
    return DateFormat.yMMMM(_intlLocale(localeTag)).format(value);
  }

  static String formatTime(DateTime value, {required String localeTag}) {
    return DateFormat.jm(_intlLocale(localeTag)).format(value);
  }

  static String formatDecimal(num value, {required String localeTag}) {
    return NumberFormat.decimalPattern(_intlLocale(localeTag)).format(value);
  }

  static String formatCurrency(
    num value, {
    required String localeTag,
    String? currency,
  }) {
    return NumberFormat.simpleCurrency(
      locale: _intlLocale(localeTag),
      name: currency,
    ).format(value);
  }

  static String _intlLocale(String localeTag) {
    return localeTag.replaceAll('-', '_');
  }
}
