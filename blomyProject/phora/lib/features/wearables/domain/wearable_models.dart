import 'package:flutter/material.dart';

enum WearableSource {
  vylaWearable,
  fitbit,
  oura,
  garmin,
  samsungHealth,
  googleHealthConnect,
  whoop,
}

enum WearableSyncHealth { healthy, stale, needsAttention, unavailable }

enum TemperatureReadingType {
  basalBodyTemperature,
  normalBodyTemperature,
  skinTemperatureTrend,
  invalidForBBT,
}

class WearableProviderIds {
  const WearableProviderIds._();

  static const vylaWearable = 'vyla_wearable';
  static const fitbit = 'fitbit';
}

class WearableProviderDescriptor {
  const WearableProviderDescriptor({
    required this.id,
    required this.source,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.capabilities,
    this.permissionRationale,
    this.enabled = true,
  });

  final String id;
  final WearableSource source;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<String> capabilities;
  final String? permissionRationale;
  final bool enabled;
}

class WearableProviderCapabilities {
  const WearableProviderCapabilities({
    required this.supportsBBT,
    required this.supportsSkinTemperature,
    required this.supportsSleep,
    required this.supportsHRV,
    required this.supportsRestingHeartRate,
    required this.supportsSteps,
  });

  final bool supportsBBT;
  final bool supportsSkinTemperature;
  final bool supportsSleep;
  final bool supportsHRV;
  final bool supportsRestingHeartRate;
  final bool supportsSteps;
}

class BBTReading {
  const BBTReading({
    required this.valueCelsius,
    required this.measuredAt,
    required this.source,
    required this.type,
    required this.valid,
    required this.confidence,
    this.invalidReason,
  });

  final double valueCelsius;
  final DateTime measuredAt;
  final WearableSource source;
  final TemperatureReadingType type;
  final bool valid;
  final String confidence;
  final String? invalidReason;
}

class SleepSession {
  const SleepSession({
    required this.startedAt,
    required this.endedAt,
    required this.totalMinutes,
    this.deepSleepMinutes,
    this.lightSleepMinutes,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int totalMinutes;
  final int? deepSleepMinutes;
  final int? lightSleepMinutes;
}

class WearableDailyMetrics {
  const WearableDailyMetrics({
    required this.date,
    required this.source,
    this.bbt,
    this.bodyTemperature,
    this.wristTemperature,
    this.sleepMinutes,
    this.deepSleepMinutes,
    this.lightSleepMinutes,
    this.remSleepMinutes,
    this.awakeSleepMinutes,
    this.steps,
    this.restingHeartRate,
    this.averageHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.hrv,
    this.stress,
  });

  final DateTime date;
  final double? bbt;
  final double? bodyTemperature;
  final double? wristTemperature;
  final int? sleepMinutes;
  final int? deepSleepMinutes;
  final int? lightSleepMinutes;
  final int? remSleepMinutes;
  final int? awakeSleepMinutes;
  final int? steps;
  final double? restingHeartRate;
  final double? averageHeartRate;
  final double? minHeartRate;
  final double? maxHeartRate;
  final double? hrv;
  final double? stress;
  final WearableSource source;

  String get dataSource => switch (source) {
    WearableSource.vylaWearable => 'vyla_wearable',
    _ => 'manual_entry',
  };

  String get sourceLabel => switch (source) {
    WearableSource.vylaWearable => 'Vyla wearable',
    _ => 'Manual entry',
  };

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().substring(0, 10),
      'source': source.name,
      'data_source': dataSource,
      if (bbt != null) 'bbt': bbt,
      if (bodyTemperature != null) 'body_temperature': bodyTemperature,
      if (sleepMinutes != null) 'sleep_minutes': sleepMinutes,
      if (deepSleepMinutes != null) 'deep_sleep_minutes': deepSleepMinutes,
      if (lightSleepMinutes != null) 'light_sleep_minutes': lightSleepMinutes,
      if (remSleepMinutes != null) 'rem_sleep_minutes': remSleepMinutes,
      if (awakeSleepMinutes != null) 'awake_sleep_minutes': awakeSleepMinutes,
      if (steps != null) 'steps': steps,
      if (restingHeartRate != null) 'resting_heart_rate': restingHeartRate,
      if (averageHeartRate != null) 'heart_rate_avg': averageHeartRate,
      if (minHeartRate != null) 'heart_rate_min': minHeartRate,
      if (maxHeartRate != null) 'heart_rate_max': maxHeartRate,
      if (hrv != null) 'hrv': hrv,
      if (stress != null) 'stress': stress,
      if (wristTemperature != null) 'wrist_temperature': wristTemperature,
    };
  }
}

class WearableData {
  const WearableData({
    required this.providerId,
    required this.syncedAt,
    required this.dailyMetrics,
    this.batteryLevel,
    this.isCharging,
  });

  final String providerId;
  final DateTime syncedAt;
  final List<WearableDailyMetrics> dailyMetrics;
  final int? batteryLevel;
  final bool? isCharging;
}

class WearableConnectionStatus {
  const WearableConnectionStatus({
    required this.providerId,
    required this.isConnected,
    required this.syncHealth,
    this.connectedAt,
    this.lastSyncedAt,
    this.batteryLevel,
    this.isCharging,
    this.retryCount = 0,
    this.lastError,
  });

  final String providerId;
  final bool isConnected;
  final WearableSyncHealth syncHealth;
  final DateTime? connectedAt;
  final DateTime? lastSyncedAt;
  final int? batteryLevel;
  final bool? isCharging;
  final int retryCount;
  final String? lastError;

  bool get isStale {
    final lastSync = lastSyncedAt;
    if (!isConnected || lastSync == null) {
      return false;
    }
    return DateTime.now().difference(lastSync) > const Duration(hours: 24);
  }

  WearableConnectionStatus copyWith({
    bool? isConnected,
    WearableSyncHealth? syncHealth,
    DateTime? connectedAt,
    DateTime? lastSyncedAt,
    int? batteryLevel,
    bool? isCharging,
    int? retryCount,
    String? lastError,
  }) {
    return WearableConnectionStatus(
      providerId: providerId,
      isConnected: isConnected ?? this.isConnected,
      syncHealth: syncHealth ?? this.syncHealth,
      connectedAt: connectedAt ?? this.connectedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError,
    );
  }

  factory WearableConnectionStatus.fromJson(
    String providerId,
    Map<String, dynamic> json,
  ) {
    return WearableConnectionStatus(
      providerId: providerId,
      isConnected: json['is_connected'] == true,
      syncHealth: WearableSyncHealth.values.firstWhere(
        (value) => value.name == json['sync_health'],
        orElse: () => WearableSyncHealth.unavailable,
      ),
      connectedAt: _dateFromJson(json['connected_at']),
      lastSyncedAt: _dateFromJson(json['last_synced_at']),
      batteryLevel: (json['battery_level'] as num?)?.toInt(),
      isCharging: json['is_charging'] as bool?,
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_connected': isConnected,
      'sync_health': syncHealth.name,
      if (connectedAt != null) 'connected_at': connectedAt!.toIso8601String(),
      if (lastSyncedAt != null)
        'last_synced_at': lastSyncedAt!.toIso8601String(),
      if (batteryLevel != null) 'battery_level': batteryLevel,
      if (isCharging != null) 'is_charging': isCharging,
      'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
    };
  }
}

DateTime? _dateFromJson(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
