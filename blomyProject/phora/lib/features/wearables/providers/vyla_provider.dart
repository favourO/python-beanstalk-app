import 'package:flutter/material.dart';
import 'package:phora/features/wearables/data/gtl1_watch_sync_repository.dart';
import 'package:phora/features/wearables/domain/bbt_classifier.dart';
import 'package:phora/features/wearables/domain/wearable_models.dart';
import 'package:phora/features/wearables/domain/wearable_provider.dart';
import 'package:phora_gtl1_watch/phora_gtl1_watch.dart';

class VylaWearableProvider implements WearableProvider {
  VylaWearableProvider({required Gtl1WatchSyncRepository repository})
    : _repository = repository;

  final Gtl1WatchSyncRepository _repository;
  bool _connected = false;

  @override
  WearableProviderDescriptor get descriptor => const WearableProviderDescriptor(
    id: WearableProviderIds.vylaWearable,
    source: WearableSource.vylaWearable,
    name: 'Vyla Wearable',
    subtitle: 'Pair Vyla Wear with BLE, battery-aware sync, and offline cache.',
    icon: Icons.watch_rounded,
    accentColor: Color(0xFFFF7C68),
    capabilities: [
      'BLE pairing',
      'Background sync',
      'Scheduled sync',
      'Offline cache',
      'Battery-aware sync',
      'Firmware-ready architecture',
    ],
  );

  @override
  WearableProviderCapabilities get capabilities =>
      const WearableProviderCapabilities(
        supportsBBT: true,
        supportsSkinTemperature: true,
        supportsSleep: true,
        supportsHRV: false,
        supportsRestingHeartRate: true,
        supportsSteps: true,
      );

  @override
  Future<void> connect() async {
    final pairing = await _repository.getPairedPhoraWear();
    if (pairing == null) {
      await _repository.scanAndPairNearestPhoraWear();
      _connected = true;
      return;
    }
    await _repository.connectPairedPhoraWear(pairing);
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    await _repository.disconnect();
    await _repository.clearPairing();
    _connected = false;
  }

  @override
  Future<WearableData> sync() async {
    final payload = await _repository.syncPairedTodayAndUpload();
    _connected = true;
    return WearableData(
      providerId: WearableProviderIds.vylaWearable,
      syncedAt: DateTime.now(),
      dailyMetrics: [payload.toWearableDailyMetrics()],
    );
  }

  @override
  Future<WearableConnectionStatus> getConnectionStatus() async {
    final pairing = await _repository.getPairedPhoraWear();
    return WearableConnectionStatus(
      providerId: WearableProviderIds.vylaWearable,
      isConnected: pairing != null,
      syncHealth:
          pairing == null
              ? WearableSyncHealth.unavailable
              : pairing.lastSyncedAt == null
              ? WearableSyncHealth.stale
              : WearableSyncHealth.healthy,
      connectedAt: pairing?.pairedAt,
      lastSyncedAt: pairing?.lastSyncedAt,
    );
  }

  @override
  Future<DateTime?> getLastSuccessfulSync() async {
    return (await _repository.getPairedPhoraWear())?.lastSyncedAt;
  }

  @override
  Future<BBTReading?> getLatestValidBBT() async {
    return null;
  }

  @override
  bool get isConnected => _connected;
}

extension Gtl1WearableNormalization on Gtl1DailyHealthData {
  WearableDailyMetrics toWearableDailyMetrics() {
    final parsedDate = DateTime.tryParse(date) ?? DateTime.now();
    final temperatureReading = _temperatureReading(parsedDate);
    final classification =
        temperatureReading == null
            ? null
            : const BbtClassifier().classify(temperatureReading);

    return WearableDailyMetrics(
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      source: WearableSource.vylaWearable,
      bbt:
          classification?.isBbt == true
              ? classification!.reading.valueCelsius
              : null,
      bodyTemperature:
          classification?.isBbt == false
              ? classification!.reading.valueCelsius
              : null,
      sleepMinutes: sleep.totalMinutes > 0 ? sleep.totalMinutes : null,
      deepSleepMinutes: sleep.deepMinutes > 0 ? sleep.deepMinutes : null,
      lightSleepMinutes: sleep.lightMinutes > 0 ? sleep.lightMinutes : null,
      steps: steps > 0 ? steps : null,
      restingHeartRate:
          heartRate.resting > 0 ? heartRate.resting.toDouble() : null,
    );
  }

  TemperatureReading? _temperatureReading(DateTime parsedDate) {
    if (temperature.avg <= 0) {
      return null;
    }
    final recordedAt =
        DateTime.tryParse(raw['temperatureRecordedAt'] as String? ?? '') ??
        parsedDate;
    final duringSleep = raw['temperatureDuringSleep'] == true;
    final afterWaking = raw['temperatureAfterWaking'] == true;
    final movement = raw['excessiveMovementBeforeTemperature'] == true;
    return TemperatureReading(
      valueCelsius: temperature.avg,
      recordedAt: recordedAt,
      source: WearableSource.vylaWearable,
      trustedSource: true,
      collectedDuringSleep: duringSleep,
      collectedAfterWaking: afterWaking,
      priorContinuousSleepMinutes:
          sleep.totalMinutes > 0 ? sleep.totalMinutes : null,
      excessiveMovementBeforeReading: movement,
    );
  }
}
