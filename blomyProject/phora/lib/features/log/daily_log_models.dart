import 'package:flutter/material.dart';

enum LogSection {
  period,
  symptoms,
  temperature,
  lhTest,
  cervicalMucus,
  intimacy,
}

class DailyLogDraft {
  const DailyLogDraft({
    required this.userId,
    required this.date,
    this.period,
    this.symptoms,
    this.temperature,
    this.lhTest,
    this.cervicalMucus,
    this.intimacy,
    this.notes,
  });

  DailyLogDraft copyWith({
    String? userId,
    DateTime? date,
    PeriodLogDraft? period,
    SymptomsLogDraft? symptoms,
    TemperatureLogDraft? temperature,
    LhTestLogDraft? lhTest,
    CervicalMucusLogDraft? cervicalMucus,
    IntimacyLogDraft? intimacy,
    String? notes,
  }) {
    return DailyLogDraft(
      userId: userId ?? this.userId,
      date: date ?? this.date,
      period: period ?? this.period,
      symptoms: symptoms ?? this.symptoms,
      temperature: temperature ?? this.temperature,
      lhTest: lhTest ?? this.lhTest,
      cervicalMucus: cervicalMucus ?? this.cervicalMucus,
      intimacy: intimacy ?? this.intimacy,
      notes: notes ?? this.notes,
    );
  }

  final String userId;
  final DateTime date;
  final PeriodLogDraft? period;
  final SymptomsLogDraft? symptoms;
  final TemperatureLogDraft? temperature;
  final LhTestLogDraft? lhTest;
  final CervicalMucusLogDraft? cervicalMucus;
  final IntimacyLogDraft? intimacy;
  final String? notes;
}

class PeriodLogDraft {
  const PeriodLogDraft({
    this.startDate,
    this.endDate,
    this.intensity,
    this.colour,
    this.symptoms = const [],
  });

  factory PeriodLogDraft.fromJson(Map<String, dynamic> json) {
    return PeriodLogDraft(
      startDate: _dateValue(json['start_date'] ?? json['period_start_date']),
      endDate: _dateValue(json['end_date'] ?? json['period_end_date']),
      intensity: _stringValue(json['intensity']),
      colour: _stringValue(json['colour']),
      symptoms: _stringList(json['symptoms']),
    );
  }

  PeriodLogDraft copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? intensity,
    String? colour,
    List<String>? symptoms,
  }) {
    return PeriodLogDraft(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      intensity: intensity ?? this.intensity,
      colour: colour ?? this.colour,
      symptoms: symptoms ?? this.symptoms,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (startDate != null) 'start_date': _dateOnly(startDate!),
      if (endDate != null) 'end_date': _dateOnly(endDate!),
      if (intensity != null) 'intensity': intensity,
      if (colour != null) 'colour': colour,
      if (symptoms.isNotEmpty) 'symptoms': symptoms,
    };
  }

  bool get hasData =>
      startDate != null ||
      endDate != null ||
      intensity != null ||
      colour != null ||
      symptoms.isNotEmpty;

  final DateTime? startDate;
  final DateTime? endDate;
  final String? intensity;
  final String? colour;
  final List<String> symptoms;
}

class SymptomsLogDraft {
  const SymptomsLogDraft({
    this.mood,
    this.energyLevel,
    this.physical = const [],
    this.painLevel,
    this.sleepQuality,
    this.notes,
  });

  factory SymptomsLogDraft.fromJson(Map<String, dynamic> json) {
    return SymptomsLogDraft(
      mood: _stringValue(json['mood']),
      energyLevel: _intValue(json['energy_level']),
      physical: _stringList(json['physical']),
      painLevel: _intValue(json['pain_level']),
      sleepQuality: _stringValue(json['sleep_quality']),
      notes: _stringValue(json['notes']),
    );
  }

  SymptomsLogDraft copyWith({
    String? mood,
    int? energyLevel,
    List<String>? physical,
    int? painLevel,
    String? sleepQuality,
    String? notes,
  }) {
    return SymptomsLogDraft(
      mood: mood ?? this.mood,
      energyLevel: energyLevel ?? this.energyLevel,
      physical: physical ?? this.physical,
      painLevel: painLevel ?? this.painLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (mood != null) 'mood': mood,
      if (energyLevel != null) 'energy_level': energyLevel,
      if (physical.isNotEmpty) 'physical': physical,
      if (painLevel != null) 'pain_level': painLevel,
      if (sleepQuality != null) 'sleep_quality': sleepQuality,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }

  bool get hasData =>
      mood != null ||
      energyLevel != null ||
      physical.isNotEmpty ||
      painLevel != null ||
      sleepQuality != null ||
      (notes?.trim().isNotEmpty ?? false);

  final String? mood;
  final int? energyLevel;
  final List<String> physical;
  final int? painLevel;
  final String? sleepQuality;
  final String? notes;
}

class TemperatureLogDraft {
  const TemperatureLogDraft({
    this.temperatureCelsius,
    this.measuredAt,
    this.sameTimeAsYesterday = false,
    this.uninterruptedSleep = false,
    this.measuredBeforeGettingUp = false,
    this.method = 'unknown',
    this.illnessFlag = false,
    this.alcoholFlag = false,
    this.stressFlag = false,
    this.travelFlag = false,
    this.displayUnit = 'C',
  });

  factory TemperatureLogDraft.fromJson(Map<String, dynamic> json) {
    return TemperatureLogDraft(
      temperatureCelsius: _doubleValue(json['temperature_celsius']),
      measuredAt: _timeOfDay(_stringValue(json['measured_at'])),
      sameTimeAsYesterday: json['same_time_as_yesterday'] == true,
      uninterruptedSleep: json['uninterrupted_sleep'] == true,
      measuredBeforeGettingUp: json['measured_before_getting_up'] == true,
      method: _stringValue(json['method']) ?? 'unknown',
      illnessFlag: json['illness_flag'] == true,
      alcoholFlag: json['alcohol_flag'] == true,
      stressFlag: json['stress_flag'] == true,
      travelFlag: json['travel_flag'] == true,
      displayUnit: _stringValue(json['unit']) ?? 'C',
    );
  }

  TemperatureLogDraft copyWith({
    double? temperatureCelsius,
    TimeOfDay? measuredAt,
    bool? sameTimeAsYesterday,
    bool? uninterruptedSleep,
    bool? measuredBeforeGettingUp,
    String? method,
    bool? illnessFlag,
    bool? alcoholFlag,
    bool? stressFlag,
    bool? travelFlag,
    String? displayUnit,
  }) {
    return TemperatureLogDraft(
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      measuredAt: measuredAt ?? this.measuredAt,
      sameTimeAsYesterday: sameTimeAsYesterday ?? this.sameTimeAsYesterday,
      uninterruptedSleep: uninterruptedSleep ?? this.uninterruptedSleep,
      measuredBeforeGettingUp:
          measuredBeforeGettingUp ?? this.measuredBeforeGettingUp,
      method: method ?? this.method,
      illnessFlag: illnessFlag ?? this.illnessFlag,
      alcoholFlag: alcoholFlag ?? this.alcoholFlag,
      stressFlag: stressFlag ?? this.stressFlag,
      travelFlag: travelFlag ?? this.travelFlag,
      displayUnit: displayUnit ?? this.displayUnit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (temperatureCelsius != null)
        'temperature_celsius': double.parse(
          temperatureCelsius!.toStringAsFixed(1),
        ),
      if (measuredAt != null) 'measured_at': _formatTime(measuredAt!),
      'same_time_as_yesterday': sameTimeAsYesterday,
      'uninterrupted_sleep': uninterruptedSleep,
      'measured_before_getting_up': measuredBeforeGettingUp,
      'method': method,
      'illness_flag': illnessFlag,
      'alcohol_flag': alcoholFlag,
      'stress_flag': stressFlag,
      'travel_flag': travelFlag,
      'unit': displayUnit,
    };
  }

  bool get hasData =>
      temperatureCelsius != null ||
      measuredAt != null ||
      sameTimeAsYesterday ||
      uninterruptedSleep ||
      measuredBeforeGettingUp ||
      illnessFlag ||
      alcoholFlag ||
      stressFlag ||
      travelFlag ||
      method != 'unknown';

  final double? temperatureCelsius;
  final TimeOfDay? measuredAt;
  final bool sameTimeAsYesterday;
  final bool uninterruptedSleep;
  final bool measuredBeforeGettingUp;
  final String method;
  final bool illnessFlag;
  final bool alcoholFlag;
  final bool stressFlag;
  final bool travelFlag;
  final String displayUnit;
}

class LhTestLogDraft {
  static const Object _unset = Object();

  const LhTestLogDraft({
    this.result,
    this.method = 'manual',
    this.imageUrl,
    this.analysisStatus,
    this.analysisMessage,
    this.testedAt,
  });

  factory LhTestLogDraft.fromJson(Map<String, dynamic> json) {
    return LhTestLogDraft(
      result: _stringValue(json['result']) ?? _stringValue(json['state']),
      method: _stringValue(json['method']) ?? 'manual',
      imageUrl: _stringValue(json['image_url']),
      analysisStatus: _stringValue(json['analysis_status']),
      analysisMessage: _stringValue(json['analysis_message']),
      testedAt: _timeOfDay(
        _stringValue(json['tested_at']) ?? _stringValue(json['test_time']),
      ),
    );
  }

  LhTestLogDraft copyWith({
    Object? result = _unset,
    String? method,
    Object? imageUrl = _unset,
    Object? analysisStatus = _unset,
    Object? analysisMessage = _unset,
    Object? testedAt = _unset,
  }) {
    return LhTestLogDraft(
      result: identical(result, _unset) ? this.result : result as String?,
      method: method ?? this.method,
      imageUrl:
          identical(imageUrl, _unset) ? this.imageUrl : imageUrl as String?,
      analysisStatus:
          identical(analysisStatus, _unset)
              ? this.analysisStatus
              : analysisStatus as String?,
      analysisMessage:
          identical(analysisMessage, _unset)
              ? this.analysisMessage
              : analysisMessage as String?,
      testedAt:
          identical(testedAt, _unset) ? this.testedAt : testedAt as TimeOfDay?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (result != null) 'result': result,
      'method': method,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
      if (testedAt != null) 'tested_at': _formatTime(testedAt!),
    };
  }

  bool get hasData =>
      result != null || (imageUrl?.isNotEmpty ?? false) || testedAt != null;

  final String? result;
  final String method;
  final String? imageUrl;
  final String? analysisStatus;
  final String? analysisMessage;
  final TimeOfDay? testedAt;
}

class CervicalMucusLogDraft {
  const CervicalMucusLogDraft({this.type, this.amount, this.notes});

  factory CervicalMucusLogDraft.fromJson(Map<String, dynamic> json) {
    return CervicalMucusLogDraft(
      type: _stringValue(json['type']),
      amount: _stringValue(json['amount']),
      notes: _stringValue(json['notes']),
    );
  }

  CervicalMucusLogDraft copyWith({
    String? type,
    String? amount,
    String? notes,
  }) {
    return CervicalMucusLogDraft(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }

  bool get hasData =>
      type != null || amount != null || (notes?.trim().isNotEmpty ?? false);

  final String? type;
  final String? amount;
  final String? notes;
}

class IntimacyLogDraft {
  const IntimacyLogDraft({
    this.activity,
    this.details = const [],
    this.time,
    this.notes,
  });

  factory IntimacyLogDraft.fromJson(Map<String, dynamic> json) {
    return IntimacyLogDraft(
      activity: _stringValue(json['activity']),
      details: _stringList(json['details']),
      time: _timeOfDay(_stringValue(json['time'])),
      notes: _stringValue(json['notes']),
    );
  }

  IntimacyLogDraft copyWith({
    String? activity,
    List<String>? details,
    TimeOfDay? time,
    String? notes,
  }) {
    return IntimacyLogDraft(
      activity: activity ?? this.activity,
      details: details ?? this.details,
      time: time ?? this.time,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (activity != null) 'activity': activity,
      if (details.isNotEmpty) 'details': details,
      if (time != null) 'time': _formatTime(time!),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }

  bool get hasData =>
      activity != null ||
      details.isNotEmpty ||
      time != null ||
      (notes?.trim().isNotEmpty ?? false);

  final String? activity;
  final List<String> details;
  final TimeOfDay? time;
  final String? notes;
}

Map<LogSection, bool> blankSectionMap([bool value = false]) {
  return {for (final section in LogSection.values) section: value};
}

String? _stringValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

DateTime? _dateValue(dynamic value) {
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  return null;
}

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

List<String> _stringList(dynamic value) {
  return value is List
      ? value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList()
      : const <String>[];
}

int? _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _doubleValue(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

TimeOfDay? _timeOfDay(String? value) {
  if (value == null) {
    return null;
  }
  final parts = value.split(':');
  if (parts.length < 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTime(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
