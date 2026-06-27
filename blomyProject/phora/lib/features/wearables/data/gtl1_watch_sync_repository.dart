import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/preferences/app_preferences.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora_gtl1_watch/phora_gtl1_watch.dart';

final gtl1WatchSyncRepositoryProvider = Provider<Gtl1WatchSyncRepository>((
  ref,
) {
  return Gtl1WatchSyncRepository(
    apiClient: ref.watch(apiClientProvider),
    preferences: ref.watch(appPreferencesProvider),
  );
});

class Gtl1WatchSyncRepository {
  Gtl1WatchSyncRepository({required this.apiClient, required this.preferences});

  final ApiClient apiClient;
  final AppPreferences preferences;

  Future<List<Gtl1WatchDevice>> scanDevices() {
    return PhoraGtl1Watch.scanDevices();
  }

  Future<void> connect(String deviceId) {
    return PhoraGtl1Watch.connect(deviceId);
  }

  Future<void> disconnect() {
    return PhoraGtl1Watch.disconnect();
  }

  Future<void> syncDeviceTime() {
    return PhoraGtl1Watch.syncDeviceTime();
  }

  Future<Gtl1BatteryStatus> getBattery() {
    return PhoraGtl1Watch.getBattery().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw TimeoutException('Timed out reading GTL1 battery.');
      },
    );
  }

  Future<Gtl1BatteryStatus> getPairedBattery() async {
    final pairing = await getPairedPhoraWear();
    if (pairing == null) {
      throw StateError('No Vyla Wear paired.');
    }
    await connectPairedPhoraWear(pairing);
    return getBattery();
  }

  Future<void> syncPairedDeviceTime() async {
    final pairing = await getPairedPhoraWear();
    if (pairing == null) {
      throw StateError('No Vyla Wear paired.');
    }
    await connectPairedPhoraWear(pairing);
    await syncDeviceTime();
  }

  Future<PhoraWearPairing?> getPairedPhoraWear() {
    return preferences.getPairedPhoraWear();
  }

  Future<PhoraWearPairing> savePairing(Gtl1WatchDevice device) async {
    final existing = await getPairedPhoraWear();
    final next = _pairingFromDevice(device);
    final pairing = _mergePairingHistory(existing, next);
    await preferences.setPairedPhoraWear(pairing);
    await _applySavedWatchSettings();
    return pairing;
  }

  Future<PhoraWearPairing> scanAndPairNearestPhoraWear() async {
    final devices = await scanDevices();
    final gtl1Devices =
        devices.where(_isGtl1Device).toList()
          ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    if (gtl1Devices.isEmpty) {
      throw StateError(
        devices.isEmpty
            ? 'No Vyla Wear found nearby.'
            : 'No supported Vyla Wear device identified nearby.',
      );
    }

    final device = gtl1Devices.first;
    await connect(device.id);
    final pairing = await savePairing(device);
    try {
      await syncDeviceTime();
    } catch (_) {
      // Time sync is useful after pairing, but a failed time write should not
      // make the connection look failed when BLE pairing succeeded.
    }
    return pairing;
  }

  Future<void> clearPairing() {
    return preferences.clearPairedPhoraWear();
  }

  Future<Gtl1WatchDevice> connectPairedPhoraWear(
    PhoraWearPairing pairing,
  ) async {
    try {
      await connect(pairing.deviceId);
      await _applySavedWatchSettings();
      return _deviceFromPairing(pairing);
    } catch (_) {
      final devices = await scanDevices();
      final matched = _findPairedDevice(devices, pairing);
      if (matched == null) {
        throw StateError('Paired Vyla Wear is not available.');
      }
      await connect(matched.id);
      await _applySavedWatchSettings();
      await preferences.setPairedPhoraWear(
        _mergePairingHistory(pairing, _pairingFromDevice(matched)),
      );
      return matched;
    }
  }

  Future<Gtl1DailyHealthData> syncPairedTodayAndUpload() async {
    final pairing = await getPairedPhoraWear();
    if (pairing == null) {
      throw StateError('No Vyla Wear paired.');
    }
    try {
      final payload = await collectPairedToday();
      await uploadPairedDailyData(payload);
      return payload;
    } catch (_) {
      // If the existing session is gone, reconnect to the stored device and
      // retry once. The periodic controller will handle later availability.
    }
    final connectedDevice = await connectPairedPhoraWear(pairing);
    final latestPairing = _mergePairingHistory(
      pairing,
      _pairingFromDevice(connectedDevice),
    );
    await preferences.setPairedPhoraWear(latestPairing);
    final payload = await collectPairedToday();
    await uploadPairedDailyData(payload);
    return payload;
  }

  Future<Gtl1DailyHealthData> collectPairedToday() async {
    final pairing = await getPairedPhoraWear();
    if (pairing == null) {
      throw StateError('No Vyla Wear paired.');
    }
    await connectPairedPhoraWear(pairing);
    try {
      final history = await _collectRecentWithTimeout();
      if (_hasAnyHealthData(history)) {
        final merged = await _fillMissingTodayValuesFromCurrentHealth(history);
        return _fillMissingSleepFromRecentHistory(merged);
      }
    } catch (_) {
      // Fall back to the watch's current health screen values when history is
      // unavailable or times out.
    }
    final current = await _collectCurrentHealthWithTimeout();
    return _fillMissingSleepFromRecentHistory(current);
  }

  Future<void> uploadPairedDailyData(Gtl1DailyHealthData payload) async {
    final pairing = await getPairedPhoraWear();
    await _upload([payload], pairing: pairing);
    if (pairing != null) {
      await preferences.setPairedPhoraWear(
        pairing.copyWith(lastSyncedAt: DateTime.now().toUtc()),
      );
    }
  }

  Future<Gtl1DailyHealthData> syncTodayAndUpload({
    PhoraWearPairing? pairing,
  }) async {
    final payload = await PhoraGtl1Watch.syncToday();
    await _upload([payload], pairing: pairing);
    if (pairing != null) {
      await preferences.setPairedPhoraWear(
        pairing.copyWith(lastSyncedAt: DateTime.now().toUtc()),
      );
    }
    return payload;
  }

  Future<Gtl1DailyHealthData> syncDateAndUpload(
    DateTime date, {
    PhoraWearPairing? pairing,
  }) async {
    final payload = await PhoraGtl1Watch.syncDate(date);
    await _upload([payload], pairing: pairing);
    if (pairing != null) {
      await preferences.setPairedPhoraWear(
        pairing.copyWith(lastSyncedAt: DateTime.now().toUtc()),
      );
    }
    return payload;
  }

  Future<List<Gtl1DailyHealthData>> syncRangeAndUpload(
    DateTime start,
    DateTime end, {
    PhoraWearPairing? pairing,
  }) async {
    final payload = await PhoraGtl1Watch.syncRange(start, end);
    await _upload(payload, pairing: pairing);
    if (pairing != null) {
      await preferences.setPairedPhoraWear(
        pairing.copyWith(lastSyncedAt: DateTime.now().toUtc()),
      );
    }
    return payload;
  }

  Future<Gtl1FemaleHealthSettings> getFemaleHealth() {
    return PhoraGtl1Watch.getFemaleHealth();
  }

  Future<void> setFemaleHealth(Gtl1FemaleHealthSettings settings) {
    return PhoraGtl1Watch.setFemaleHealth(settings);
  }

  Future<bool> getPhoneNotificationsEnabled() async {
    final stored = await preferences.getPhoraWearPhoneNotificationsEnabled();
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return stored;
    }
    try {
      final enabled = await PhoraGtl1Watch.getPhoneNotificationsEnabled();
      await preferences.setPhoraWearPhoneNotificationsEnabled(enabled);
      return enabled;
    } catch (_) {
      return stored;
    }
  }

  Future<void> setPhoneNotificationsEnabled(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      await preferences.setPhoraWearPhoneNotificationsEnabled(enabled);
      return;
    }
    await PhoraGtl1Watch.setPhoneNotificationsEnabled(enabled);
    await preferences.setPhoraWearPhoneNotificationsEnabled(enabled);
  }

  Future<void> _applySavedWatchSettings() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final enabled = await preferences.getPhoraWearPhoneNotificationsEnabled();
    try {
      await PhoraGtl1Watch.setPhoneNotificationsEnabled(enabled);
    } catch (_) {
      // Keep the connection alive even if the watch rejects a settings write.
    }
  }

  Future<Gtl1DailyHealthData> _collectTodayWithTimeout() {
    return PhoraGtl1Watch.syncToday().timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw TimeoutException('Timed out collecting GTL1 readings.');
      },
    );
  }

  Future<Gtl1DailyHealthData> _collectCurrentHealthWithTimeout() {
    return PhoraGtl1Watch.getCurrentHealth().timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        throw TimeoutException('Timed out reading GTL1 current health.');
      },
    );
  }

  Future<Gtl1DailyHealthData> _collectDateWithTimeout(DateTime date) {
    return PhoraGtl1Watch.syncDate(date).timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw TimeoutException('Timed out collecting GTL1 readings.');
      },
    );
  }

  Future<Gtl1DailyHealthData> _collectRecentWithTimeout() async {
    final today = await _collectTodayWithTimeout();
    if (_hasAnyHealthData(today)) {
      return today;
    }

    final now = DateTime.now();
    for (var daysAgo = 1; daysAgo <= 6; daysAgo += 1) {
      final candidate = await _collectDateWithTimeout(
        now.subtract(Duration(days: daysAgo)),
      );
      if (_hasAnyHealthData(candidate)) {
        return candidate;
      }
    }
    return today;
  }

  Future<Gtl1DailyHealthData> _fillMissingTodayValuesFromCurrentHealth(
    Gtl1DailyHealthData history,
  ) async {
    if (!_isTodayPayload(history)) {
      return history;
    }

    try {
      final current = await _collectCurrentHealthWithTimeout();
      if (!_isTodayPayload(current)) {
        return history;
      }
      if (_hasMissingCurrentValues(history) ||
          _hasLiveDayDiscrepancy(history, current)) {
        return _mergeCurrentDayValues(history, current);
      }
      return history;
    } catch (_) {
      return history;
    }
  }

  Future<Gtl1DailyHealthData> _fillMissingSleepFromRecentHistory(
    Gtl1DailyHealthData payload,
  ) async {
    if (!_isTodayPayload(payload) || payload.sleep.totalMinutes > 0) {
      return payload;
    }

    final now = DateTime.now();
    for (var daysAgo = 1; daysAgo <= 6; daysAgo += 1) {
      try {
        final candidate = await _collectDateWithTimeout(
          now.subtract(Duration(days: daysAgo)),
        );
        if (candidate.sleep.totalMinutes <= 0) {
          continue;
        }
        return _mergeMissingValues(
          payload,
          Gtl1DailyHealthData(
            date: payload.date,
            steps: 0,
            heartRate: const Gtl1HeartRateSummary(),
            sleep: candidate.sleep,
            bloodOxygen: const Gtl1BloodOxygenSummary(),
            temperature: const Gtl1TemperatureSummary(),
            stress: const Gtl1StressSummary(),
            sourceDevice: candidate.sourceDevice,
            syncTimestamp: candidate.syncTimestamp,
            raw: {'sleepHistoryFallbackDate': candidate.date, ...candidate.raw},
          ),
        );
      } catch (_) {
        // Keep trying older dates; sleep can be stored under the wake date or
        // previous date depending on firmware.
      }
    }
    return payload;
  }

  Future<void> _upload(
    List<Gtl1DailyHealthData> payload, {
    PhoraWearPairing? pairing,
  }) {
    return apiClient.postJson(
      buildVersionedApiUrl(apiClient.dio, '/api/v1/watch/sync'),
      data: {
        'device_type': 'gtl1',
        'display_device_type': 'phora_wear',
        if (pairing != null) ...{
          'device_id': pairing.stableIdentifier,
          'ble_device_id': pairing.deviceId,
          'device_name': pairing.deviceName,
          'manufacturer_mac': pairing.manufacturerMac,
          'manufacturer_prefix': pairing.manufacturerPrefix,
        },
        'synced_at': DateTime.now().toUtc().toIso8601String(),
        'days': payload.map((item) => item.toMap()).toList(),
      },
    );
  }
}

bool _hasAnyHealthData(Gtl1DailyHealthData payload) {
  return payload.steps > 0 ||
      payload.caloriesKcal > 0 ||
      payload.distanceMeters > 0 ||
      payload.sleep.totalMinutes > 0 ||
      payload.heartRate.resting > 0 ||
      payload.heartRate.avg > 0 ||
      payload.bloodOxygen.avg > 0 ||
      payload.temperature.avg > 0 ||
      payload.stress.avg > 0;
}

bool _hasMissingCurrentValues(Gtl1DailyHealthData payload) {
  return payload.steps <= 0 ||
      payload.caloriesKcal <= 0 ||
      payload.distanceMeters <= 0 ||
      payload.heartRate.resting <= 0 ||
      payload.heartRate.avg <= 0 ||
      payload.bloodOxygen.avg <= 0 ||
      !_isPlausibleBodyTemperature(payload.temperature.avg) ||
      payload.stress.avg <= 0;
}

bool _isTodayPayload(Gtl1DailyHealthData payload) {
  return payload.date == _yyyyMmDd(DateTime.now());
}

Gtl1DailyHealthData _mergeMissingValues(
  Gtl1DailyHealthData history,
  Gtl1DailyHealthData current,
) {
  return Gtl1DailyHealthData(
    date: history.date.isNotEmpty ? history.date : current.date,
    steps: history.steps > 0 ? history.steps : current.steps,
    caloriesKcal:
        history.caloriesKcal > 0 ? history.caloriesKcal : current.caloriesKcal,
    distanceMeters:
        history.distanceMeters > 0
            ? history.distanceMeters
            : current.distanceMeters,
    heartRate: Gtl1HeartRateSummary(
      resting:
          history.heartRate.resting > 0
              ? history.heartRate.resting
              : current.heartRate.resting,
      avg:
          history.heartRate.avg > 0
              ? history.heartRate.avg
              : current.heartRate.avg,
      min:
          history.heartRate.min > 0
              ? history.heartRate.min
              : current.heartRate.min,
      max:
          history.heartRate.max > 0
              ? history.heartRate.max
              : current.heartRate.max,
    ),
    sleep: history.sleep.totalMinutes > 0 ? history.sleep : current.sleep,
    bloodOxygen: Gtl1BloodOxygenSummary(
      avg:
          history.bloodOxygen.avg > 0
              ? history.bloodOxygen.avg
              : current.bloodOxygen.avg,
      min:
          history.bloodOxygen.min > 0
              ? history.bloodOxygen.min
              : current.bloodOxygen.min,
    ),
    temperature:
        _isPlausibleBodyTemperature(history.temperature.avg)
            ? history.temperature
            : current.temperature,
    stress: history.stress.avg > 0 ? history.stress : current.stress,
    sourceDevice: history.sourceDevice ?? current.sourceDevice,
    syncTimestamp: history.syncTimestamp ?? current.syncTimestamp,
    raw: {...history.raw, 'currentHealthFallback': current.toMap()},
  );
}

bool _hasLiveDayDiscrepancy(
  Gtl1DailyHealthData history,
  Gtl1DailyHealthData current,
) {
  return current.steps > 0 && current.steps != history.steps;
}

Gtl1DailyHealthData _mergeCurrentDayValues(
  Gtl1DailyHealthData history,
  Gtl1DailyHealthData current,
) {
  return Gtl1DailyHealthData(
    date: history.date.isNotEmpty ? history.date : current.date,
    // For today's live step counts, trust the watch's current screen values.
    steps: current.steps > 0 ? current.steps : history.steps,
    caloriesKcal:
        current.caloriesKcal > 0 ? current.caloriesKcal : history.caloriesKcal,
    distanceMeters:
        current.distanceMeters > 0
            ? current.distanceMeters
            : history.distanceMeters,
    heartRate: Gtl1HeartRateSummary(
      resting:
          history.heartRate.resting > 0
              ? history.heartRate.resting
              : current.heartRate.resting,
      avg:
          history.heartRate.avg > 0
              ? history.heartRate.avg
              : current.heartRate.avg,
      min:
          history.heartRate.min > 0
              ? history.heartRate.min
              : current.heartRate.min,
      max:
          history.heartRate.max > 0
              ? history.heartRate.max
              : current.heartRate.max,
    ),
    sleep: history.sleep.totalMinutes > 0 ? history.sleep : current.sleep,
    bloodOxygen: Gtl1BloodOxygenSummary(
      avg:
          history.bloodOxygen.avg > 0
              ? history.bloodOxygen.avg
              : current.bloodOxygen.avg,
      min:
          history.bloodOxygen.min > 0
              ? history.bloodOxygen.min
              : current.bloodOxygen.min,
    ),
    temperature:
        _isPlausibleBodyTemperature(history.temperature.avg)
            ? history.temperature
            : current.temperature,
    stress: history.stress.avg > 0 ? history.stress : current.stress,
    sourceDevice: history.sourceDevice ?? current.sourceDevice,
    syncTimestamp: history.syncTimestamp ?? current.syncTimestamp,
    raw: {...history.raw, 'currentHealthOverlay': current.toMap()},
  );
}

bool _isPlausibleBodyTemperature(double value) {
  return value >= 30 && value <= 45;
}

String _yyyyMmDd(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

PhoraWearPairing _pairingFromDevice(Gtl1WatchDevice device) {
  final manufacturerMac = _metadataString(device, 'manufacturerMac');
  final manufacturerPrefix = _metadataString(device, 'manufacturerPrefix');
  final stableIdentifier =
      manufacturerMac ??
      _metadataString(device, 'manufacturerId') ??
      device.id.trim();
  return PhoraWearPairing(
    deviceId: device.id,
    stableIdentifier: stableIdentifier,
    internalDeviceType: 'gtl1',
    displayName: 'Vyla Wearable',
    deviceName: _deviceName(device),
    manufacturerMac: manufacturerMac,
    manufacturerPrefix: manufacturerPrefix,
    pairedAt: DateTime.now().toUtc(),
  );
}

PhoraWearPairing _mergePairingHistory(
  PhoraWearPairing? previous,
  PhoraWearPairing next,
) {
  if (previous == null || !_isSamePairing(previous, next)) {
    return next;
  }
  return next.copyWith(
    pairedAt: previous.pairedAt,
    lastSyncedAt: previous.lastSyncedAt,
  );
}

bool _isSamePairing(PhoraWearPairing previous, PhoraWearPairing next) {
  if (previous.stableIdentifier == next.stableIdentifier) {
    return true;
  }
  final previousMac = previous.manufacturerMac;
  final nextMac = next.manufacturerMac;
  if (previousMac != null && nextMac != null && previousMac == nextMac) {
    return true;
  }
  return previous.deviceId == next.deviceId;
}

Gtl1WatchDevice _deviceFromPairing(PhoraWearPairing pairing) {
  return Gtl1WatchDevice(
    id: pairing.deviceId,
    name: pairing.deviceName ?? pairing.displayName,
    metadata: {
      if (pairing.manufacturerMac != null)
        'manufacturerMac': pairing.manufacturerMac,
      if (pairing.manufacturerPrefix != null)
        'manufacturerPrefix': pairing.manufacturerPrefix,
    },
  );
}

Gtl1WatchDevice? _findPairedDevice(
  List<Gtl1WatchDevice> devices,
  PhoraWearPairing pairing,
) {
  for (final device in devices) {
    final candidate = _pairingFromDevice(device);
    if (candidate.stableIdentifier == pairing.stableIdentifier ||
        (candidate.manufacturerMac != null &&
            candidate.manufacturerMac == pairing.manufacturerMac) ||
        device.id == pairing.deviceId) {
      return device;
    }
  }

  final gtl1Devices = devices.where(_isGtl1Device).toList();
  gtl1Devices.sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
  return gtl1Devices.isEmpty ? null : gtl1Devices.first;
}

bool _isGtl1Device(Gtl1WatchDevice device) {
  if (device.metadata['isStarmax'] == true) {
    return true;
  }
  final manufacturerPrefix = _metadataString(device, 'manufacturerPrefix');
  if (manufacturerPrefix?.toUpperCase() == '0001') {
    return true;
  }
  final name = _deviceName(device).toLowerCase();
  return name.contains('gtl1') ||
      name.contains('gtl') ||
      name.contains('runme') ||
      name.contains('starmax') ||
      name.contains('watch');
}

String _deviceName(Gtl1WatchDevice device) {
  final metadataName = _metadataString(device, 'deviceName');
  if (metadataName != null) {
    return metadataName;
  }
  if (device.name.trim().isNotEmpty) {
    return device.name.trim();
  }
  return 'Vyla Wear';
}

String? _metadataString(Gtl1WatchDevice device, String key) {
  final value = device.metadata[key];
  if (value == null) return null;
  final string = value.toString().trim();
  return string.isEmpty ? null : string;
}
