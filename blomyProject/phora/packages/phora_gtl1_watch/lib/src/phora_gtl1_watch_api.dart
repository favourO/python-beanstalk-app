import 'dart:async';

import 'package:flutter/services.dart';

import 'phora_gtl1_watch_models.dart';

class PhoraGtl1Watch {
  PhoraGtl1Watch._();

  static const MethodChannel _channel = MethodChannel('phora/gtl1_watch');
  static const EventChannel _events = EventChannel('phora/gtl1_watch/events');

  static Stream<Map<String, dynamic>> get realtimeStream {
    return _events.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
  }

  static Future<List<Gtl1WatchDevice>> scanDevices() async {
    final result = await _channel.invokeListMethod<dynamic>('scanDevices');
    return (result ?? const <dynamic>[])
        .map(
          (item) =>
              Gtl1WatchDevice.fromMap(Map<dynamic, dynamic>.from(item as Map)),
        )
        .toList();
  }

  static Future<void> connect(String deviceId) {
    return _channel.invokeMethod<void>('connect', {'deviceId': deviceId});
  }

  static Future<void> disconnect() {
    return _channel.invokeMethod<void>('disconnect');
  }

  static Future<void> syncDeviceTime() {
    return _channel.invokeMethod<void>('syncDeviceTime');
  }

  static Future<Gtl1BatteryStatus> getBattery() async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getBattery',
    );
    return Gtl1BatteryStatus.fromMap(result ?? const <dynamic, dynamic>{});
  }

  static Future<Gtl1DailyHealthData> syncToday() async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'syncToday',
    );
    return Gtl1DailyHealthData.fromMap(result ?? const <dynamic, dynamic>{});
  }

  static Future<Gtl1DailyHealthData> getCurrentHealth() async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getCurrentHealth',
    );
    return Gtl1DailyHealthData.fromMap(result ?? const <dynamic, dynamic>{});
  }

  static Future<Gtl1DailyHealthData> syncDate(DateTime date) async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'syncDate',
      {'date': _yyyyMmDd(date)},
    );
    return Gtl1DailyHealthData.fromMap(result ?? const <dynamic, dynamic>{});
  }

  static Future<List<Gtl1DailyHealthData>> syncRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = await _channel.invokeListMethod<dynamic>('syncRange', {
      'start': _yyyyMmDd(start),
      'end': _yyyyMmDd(end),
    });
    return (result ?? const <dynamic>[])
        .map(
          (item) => Gtl1DailyHealthData.fromMap(
            Map<dynamic, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static Future<Gtl1FemaleHealthSettings> getFemaleHealth() async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getFemaleHealth',
    );
    return Gtl1FemaleHealthSettings.fromMap(
      result ?? const <dynamic, dynamic>{},
    );
  }

  static Future<void> setFemaleHealth(Gtl1FemaleHealthSettings settings) {
    return _channel.invokeMethod<void>('setFemaleHealth', settings.toMap());
  }

  static Future<bool> getPhoneNotificationsEnabled() async {
    final result = await _channel.invokeMethod<bool>(
      'getPhoneNotificationsEnabled',
    );
    return result ?? true;
  }

  static Future<void> setPhoneNotificationsEnabled(bool enabled) {
    return _channel.invokeMethod<void>('setPhoneNotificationsEnabled', {
      'enabled': enabled,
    });
  }
}

String _yyyyMmDd(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
