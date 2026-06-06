import 'package:phora/core/preferences/app_preferences.dart';

class LocalePreferences {
  LocalePreferences(this._preferences);

  final AppPreferences _preferences;

  Future<String?> getPreferredLocaleTag() {
    return _preferences.getPreferredLocaleTag();
  }

  Future<void> setPreferredLocaleTag(String tag) {
    return _preferences.setPreferredLocaleTag(tag);
  }

  Future<bool> getUseDeviceLocale() {
    return _preferences.getUseDeviceLocale();
  }

  Future<void> setUseDeviceLocale(bool value) {
    return _preferences.setUseDeviceLocale(value);
  }

  Future<bool> getLanguageSelectionCompleted() {
    return _preferences.getLanguageSelectionCompleted();
  }

  Future<void> setLanguageSelectionCompleted(bool value) {
    return _preferences.setLanguageSelectionCompleted(value);
  }
}
