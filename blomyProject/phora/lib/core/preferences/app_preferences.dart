import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._(this._prefs);

  static Future<AppPreferences> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    return AppPreferences._(prefs);
  }

  /// Creates preferences with a warm cache, falling back to empty defaults
  /// if the cache cannot be loaded (prevents a black-screen crash on start).
  static Future<AppPreferences> createOrFallback() async {
    try {
      return await create();
    } catch (error) {
      debugPrint('SharedPreferences cache init failed: $error');
      // Fallback: empty allow-list means the cache is blank (all reads return
      // null / defaults). Writes still persist to disk so the next cold start
      // with a healthy cache picks them up.
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: <String>{},
        ),
      );
      return AppPreferences._(prefs);
    }
  }

  static const _hasSeenIntroKey = 'has_seen_intro_flow';
  static const _allowPhoraAiChatKey = 'allow_phora_ai_chat';
  static const _postSignupSetupPendingKey = 'post_signup_setup_pending';
  static const _lastCycleLogPendingKey = 'last_cycle_log_pending';
  static const _billingCountryKey = 'billing_country';
  static const _freePlanSelectedKey = 'free_plan_selected';
  static const _preferredLocaleTagKey = 'preferred_locale_tag';
  static const _useDeviceLocaleKey = 'use_device_locale';
  static const _languageSelectionCompletedKey = 'language_selection_completed';
  static const _themeModeKey = 'theme_mode';
  static const _pairedPhoraWearKey = 'paired_phora_wear';
  static const _wearableConnectionsKey = 'wearable_connections';
  static const _bbtWearableReminderTimeKey = 'bbt_wearable_reminder_time';
  static const _bbtManualReminderTimeKey = 'bbt_manual_reminder_time';
  static const _bbtReminderDismissedUntilKey = 'bbt_reminder_dismissed_until';
  static const _phoraWearPhoneNotificationsEnabledKey =
      'phora_wear_phone_notifications_enabled';
  static const _cachedHomeDashboardJsonKey = 'cached_home_dashboard_json';
  static const _cachedHomeDashboardAtKey = 'cached_home_dashboard_at';
  static const _pendingReferralCodeKey = 'pending_referral_code';
  static const _pendingReferralSourceKey = 'pending_referral_source';
  static const _pendingReferralDeepLinkIdKey = 'pending_referral_deep_link_id';
  static const _allowedKeys = {
    _hasSeenIntroKey,
    _allowPhoraAiChatKey,
    _postSignupSetupPendingKey,
    _lastCycleLogPendingKey,
    _billingCountryKey,
    _freePlanSelectedKey,
    _preferredLocaleTagKey,
    _useDeviceLocaleKey,
    _languageSelectionCompletedKey,
    _themeModeKey,
    _pairedPhoraWearKey,
    _wearableConnectionsKey,
    _bbtWearableReminderTimeKey,
    _bbtManualReminderTimeKey,
    _bbtReminderDismissedUntilKey,
    _phoraWearPhoneNotificationsEnabledKey,
    _cachedHomeDashboardJsonKey,
    _cachedHomeDashboardAtKey,
    _pendingReferralCodeKey,
    _pendingReferralSourceKey,
    _pendingReferralDeepLinkIdKey,
  };

  final SharedPreferencesWithCache _prefs;

  Future<bool> getHasSeenIntroFlow() async {
    try {
      return _prefs.getBool(_hasSeenIntroKey) ?? false;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> setHasSeenIntroFlow(bool value) async {
    try {
      await _prefs.setBool(_hasSeenIntroKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<void> clearIntroFlowFlag() async {
    try {
      for (final key in _allowedKeys) {
        await _prefs.remove(key);
      }
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<bool> getAllowPhoraAiChat() async {
    try {
      return _prefs.getBool(_allowPhoraAiChatKey) ?? false;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> setAllowPhoraAiChat(bool value) async {
    try {
      await _prefs.setBool(_allowPhoraAiChatKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<bool> getPostSignupSetupPending() async {
    try {
      return _prefs.getBool(_postSignupSetupPendingKey) ?? false;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> setPostSignupSetupPending(bool value) async {
    try {
      await _prefs.setBool(_postSignupSetupPendingKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<bool> getLastCycleLogPending() async {
    try {
      return _prefs.getBool(_lastCycleLogPendingKey) ?? false;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> setLastCycleLogPending(bool value) async {
    try {
      await _prefs.setBool(_lastCycleLogPendingKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<String?> getBillingCountry() async {
    try {
      final value = _prefs.getString(_billingCountryKey);
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> setBillingCountry(String value) async {
    try {
      await _prefs.setString(_billingCountryKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<bool> getFreePlanSelected() async {
    try {
      return _prefs.getBool(_freePlanSelectedKey) ?? false;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> setFreePlanSelected(bool value) async {
    try {
      await _prefs.setBool(_freePlanSelectedKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<String?> getPreferredLocaleTag() async {
    try {
      final value = _prefs.getString(_preferredLocaleTagKey);
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> setPreferredLocaleTag(String value) async {
    try {
      await _prefs.setString(_preferredLocaleTagKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<bool> getUseDeviceLocale() async {
    try {
      return _prefs.getBool(_useDeviceLocaleKey) ?? true;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return true;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return true;
    }
  }

  Future<void> setUseDeviceLocale(bool value) async {
    try {
      await _prefs.setBool(_useDeviceLocaleKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<bool> getLanguageSelectionCompleted() async {
    try {
      return _prefs.getBool(_languageSelectionCompletedKey) ?? false;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> setLanguageSelectionCompleted(bool value) async {
    try {
      await _prefs.setBool(_languageSelectionCompletedKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<String?> getThemeMode() async {
    try {
      final value = _prefs.getString(_themeModeKey);
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> setThemeMode(String value) async {
    try {
      await _prefs.setString(_themeModeKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<PhoraWearPairing?> getPairedPhoraWear() async {
    try {
      final value = _prefs.getString(_pairedPhoraWearKey);
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return PhoraWearPairing.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } on FormatException catch (error, stackTrace) {
      debugPrint('Stored Vyla Wear pairing is invalid: $error\n$stackTrace');
      await clearPairedPhoraWear();
      return null;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> setPairedPhoraWear(PhoraWearPairing pairing) async {
    try {
      await _prefs.setString(_pairedPhoraWearKey, jsonEncode(pairing.toJson()));
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<void> clearPairedPhoraWear() async {
    try {
      await _prefs.remove(_pairedPhoraWearKey);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<Map<String, Map<String, dynamic>>>
  getWearableConnectionRecords() async {
    try {
      final value = _prefs.getString(_wearableConnectionsKey);
      if (value == null || value.trim().isEmpty) {
        return const {};
      }
      final decoded = Map<String, dynamic>.from(jsonDecode(value) as Map);
      return decoded.map(
        (key, record) => MapEntry(
          key,
          Map<String, dynamic>.from((record as Map?) ?? const {}),
        ),
      );
    } on FormatException catch (error, stackTrace) {
      debugPrint(
        'Stored wearable connections are invalid: $error\n$stackTrace',
      );
      await clearWearableConnectionRecords();
      return const {};
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return const {};
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return const {};
    }
  }

  Future<void> setWearableConnectionRecord(
    String providerId,
    Map<String, dynamic> record,
  ) async {
    try {
      final records = await getWearableConnectionRecords();
      final updated = Map<String, Map<String, dynamic>>.from(records)
        ..[providerId] = record;
      await _prefs.setString(_wearableConnectionsKey, jsonEncode(updated));
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<void> removeWearableConnectionRecord(String providerId) async {
    try {
      final records = await getWearableConnectionRecords();
      final updated = Map<String, Map<String, dynamic>>.from(records)
        ..remove(providerId);
      await _prefs.setString(_wearableConnectionsKey, jsonEncode(updated));
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<void> clearWearableConnectionRecords() async {
    try {
      await _prefs.remove(_wearableConnectionsKey);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<ReminderTime> getBbtWearableReminderTime() async {
    return _getReminderTime(
      key: _bbtWearableReminderTimeKey,
      fallback: const ReminderTime(hour: 20, minute: 30),
    );
  }

  Future<void> setBbtWearableReminderTime(ReminderTime value) {
    return _setReminderTime(_bbtWearableReminderTimeKey, value);
  }

  Future<ReminderTime> getBbtManualReminderTime() async {
    return _getReminderTime(
      key: _bbtManualReminderTimeKey,
      fallback: const ReminderTime(hour: 6, minute: 30),
    );
  }

  Future<void> setBbtManualReminderTime(ReminderTime value) {
    return _setReminderTime(_bbtManualReminderTimeKey, value);
  }

  Future<DateTime?> getBbtReminderDismissedUntil() async {
    try {
      final value = _prefs.getString(_bbtReminderDismissedUntilKey);
      if (value == null || value.isEmpty) {
        return null;
      }
      return DateTime.tryParse(value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> setBbtReminderDismissedUntil(DateTime value) async {
    try {
      await _prefs.setString(
        _bbtReminderDismissedUntilKey,
        value.toIso8601String(),
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<void> clearBbtReminderDismissal() async {
    try {
      await _prefs.remove(_bbtReminderDismissedUntilKey);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<ReminderTime> _getReminderTime({
    required String key,
    required ReminderTime fallback,
  }) async {
    try {
      final value = _prefs.getString(key);
      if (value == null || value.trim().isEmpty) {
        return fallback;
      }
      return ReminderTime.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Stored reminder time is invalid: $error\n$stackTrace');
      return fallback;
    }
  }

  Future<void> _setReminderTime(String key, ReminderTime value) async {
    try {
      await _prefs.setString(key, jsonEncode(value.toJson()));
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<bool> getPhoraWearPhoneNotificationsEnabled() async {
    try {
      return _prefs.getBool(_phoraWearPhoneNotificationsEnabledKey) ?? false;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> setPhoraWearPhoneNotificationsEnabled(bool value) async {
    try {
      await _prefs.setBool(_phoraWearPhoneNotificationsEnabledKey, value);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<Map<String, dynamic>?> getCachedHomeDashboardJson() async {
    try {
      final raw = _prefs.getString(_cachedHomeDashboardJsonKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } on FormatException catch (error, stackTrace) {
      debugPrint('Cached home dashboard JSON invalid: $error\n$stackTrace');
      return null;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<DateTime?> getCachedHomeDashboardAt() async {
    try {
      final raw = _prefs.getString(_cachedHomeDashboardAtKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> setCachedHomeDashboardJson(Map<String, dynamic> value) async {
    try {
      await _prefs.setString(_cachedHomeDashboardJsonKey, jsonEncode(value));
      await _prefs.setString(
        _cachedHomeDashboardAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<String?> getPendingReferralCode() async {
    try {
      final value = _prefs.getString(_pendingReferralCodeKey);
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<String?> getPendingReferralSource() async {
    try {
      final value = _prefs.getString(_pendingReferralSourceKey);
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<String?> getPendingReferralDeepLinkId() async {
    try {
      final value = _prefs.getString(_pendingReferralDeepLinkIdKey);
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      return value.trim();
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
      return null;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> setPendingReferral({
    required String code,
    String? source,
    String? deepLinkId,
  }) async {
    try {
      await _prefs.setString(_pendingReferralCodeKey, code);
      if (source != null && source.trim().isNotEmpty) {
        await _prefs.setString(_pendingReferralSourceKey, source.trim());
      }
      if (deepLinkId != null && deepLinkId.trim().isNotEmpty) {
        await _prefs.setString(
          _pendingReferralDeepLinkIdKey,
          deepLinkId.trim(),
        );
      }
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }

  Future<void> clearPendingReferral() async {
    try {
      await _prefs.remove(_pendingReferralCodeKey);
      await _prefs.remove(_pendingReferralSourceKey);
      await _prefs.remove(_pendingReferralDeepLinkIdKey);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('SharedPreferences unavailable: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('SharedPreferences missing plugin: $error\n$stackTrace');
    }
  }
}

@immutable
class PhoraWearPairing {
  const PhoraWearPairing({
    required this.deviceId,
    required this.stableIdentifier,
    required this.internalDeviceType,
    required this.displayName,
    required this.pairedAt,
    this.deviceName,
    this.manufacturerMac,
    this.manufacturerPrefix,
    this.lastSyncedAt,
  });

  factory PhoraWearPairing.fromJson(Map<String, dynamic> json) {
    return PhoraWearPairing(
      deviceId: _stringValue(json['device_id']) ?? '',
      stableIdentifier: _stringValue(json['stable_identifier']) ?? '',
      internalDeviceType: _stringValue(json['internal_device_type']) ?? 'gtl1',
      displayName: _stringValue(json['display_name']) ?? 'Vyla Wear',
      deviceName: _stringValue(json['device_name']),
      manufacturerMac: _stringValue(json['manufacturer_mac']),
      manufacturerPrefix: _stringValue(json['manufacturer_prefix']),
      pairedAt:
          DateTime.tryParse(_stringValue(json['paired_at']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastSyncedAt: DateTime.tryParse(
        _stringValue(json['last_synced_at']) ?? '',
      ),
    );
  }

  final String deviceId;
  final String stableIdentifier;
  final String internalDeviceType;
  final String displayName;
  final String? deviceName;
  final String? manufacturerMac;
  final String? manufacturerPrefix;
  final DateTime pairedAt;
  final DateTime? lastSyncedAt;

  PhoraWearPairing copyWith({
    String? deviceId,
    String? stableIdentifier,
    String? internalDeviceType,
    String? displayName,
    String? deviceName,
    String? manufacturerMac,
    String? manufacturerPrefix,
    DateTime? pairedAt,
    DateTime? lastSyncedAt,
  }) {
    return PhoraWearPairing(
      deviceId: deviceId ?? this.deviceId,
      stableIdentifier: stableIdentifier ?? this.stableIdentifier,
      internalDeviceType: internalDeviceType ?? this.internalDeviceType,
      displayName: displayName ?? this.displayName,
      deviceName: deviceName ?? this.deviceName,
      manufacturerMac: manufacturerMac ?? this.manufacturerMac,
      manufacturerPrefix: manufacturerPrefix ?? this.manufacturerPrefix,
      pairedAt: pairedAt ?? this.pairedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'stable_identifier': stableIdentifier,
      'internal_device_type': internalDeviceType,
      'display_name': displayName,
      if (deviceName != null) 'device_name': deviceName,
      if (manufacturerMac != null) 'manufacturer_mac': manufacturerMac,
      if (manufacturerPrefix != null) 'manufacturer_prefix': manufacturerPrefix,
      'paired_at': pairedAt.toUtc().toIso8601String(),
      if (lastSyncedAt != null)
        'last_synced_at': lastSyncedAt!.toUtc().toIso8601String(),
    };
  }
}

class ReminderTime {
  const ReminderTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  factory ReminderTime.fromJson(Map<String, dynamic> json) {
    return ReminderTime(
      hour: ((json['hour'] as num?)?.toInt() ?? 20).clamp(0, 23),
      minute: ((json['minute'] as num?)?.toInt() ?? 0).clamp(0, 59),
    );
  }

  Map<String, dynamic> toJson() {
    return {'hour': hour, 'minute': minute};
  }
}

String? _stringValue(Object? value) {
  if (value == null) return null;
  final string = value.toString().trim();
  return string.isEmpty ? null : string;
}
