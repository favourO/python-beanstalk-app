class Gtl1WatchDevice {
  const Gtl1WatchDevice({
    required this.id,
    required this.name,
    this.rssi,
    this.metadata = const <String, dynamic>{},
  });

  factory Gtl1WatchDevice.fromMap(Map<dynamic, dynamic> map) {
    return Gtl1WatchDevice(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      rssi: (map['rssi'] as num?)?.toInt(),
      metadata: Map<String, dynamic>.from(
        (map['metadata'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  final String id;
  final String name;
  final int? rssi;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (rssi != null) 'rssi': rssi,
      'metadata': metadata,
    };
  }
}

class Gtl1BatteryStatus {
  const Gtl1BatteryStatus({required this.level, required this.isCharging});

  factory Gtl1BatteryStatus.fromMap(Map<dynamic, dynamic> map) {
    return Gtl1BatteryStatus(
      level: (map['level'] as num?)?.toInt() ?? 0,
      isCharging: map['isCharging'] == true,
    );
  }

  final int level;
  final bool isCharging;

  Map<String, dynamic> toMap() {
    return {'level': level, 'isCharging': isCharging};
  }
}

class Gtl1FemaleHealthSettings {
  const Gtl1FemaleHealthSettings({
    required this.periodDays,
    required this.cycleDays,
    required this.lastPeriodDate,
  });

  factory Gtl1FemaleHealthSettings.fromMap(Map<dynamic, dynamic> map) {
    return Gtl1FemaleHealthSettings(
      periodDays: (map['periodDays'] as num?)?.toInt() ?? 0,
      cycleDays: (map['cycleDays'] as num?)?.toInt() ?? 0,
      lastPeriodDate:
          DateTime.tryParse(map['lastPeriodDate'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final int periodDays;
  final int cycleDays;
  final DateTime lastPeriodDate;

  Map<String, dynamic> toMap() {
    return {
      'periodDays': periodDays,
      'cycleDays': cycleDays,
      'lastPeriodDate': _yyyyMmDd(lastPeriodDate),
    };
  }
}

class Gtl1DailyHealthData {
  const Gtl1DailyHealthData({
    required this.date,
    required this.steps,
    this.caloriesKcal = 0,
    this.distanceMeters = 0,
    required this.heartRate,
    required this.sleep,
    required this.bloodOxygen,
    required this.temperature,
    required this.stress,
    this.sourceDevice,
    this.syncTimestamp,
    this.raw = const <String, dynamic>{},
  });

  factory Gtl1DailyHealthData.fromMap(Map<dynamic, dynamic> map) {
    return Gtl1DailyHealthData(
      date: map['date'] as String? ?? '',
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      caloriesKcal: (map['caloriesKcal'] as num?)?.toDouble() ?? 0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
      heartRate: Gtl1HeartRateSummary.fromMap(
        Map<dynamic, dynamic>.from((map['heartRate'] as Map?) ?? const {}),
      ),
      sleep: Gtl1SleepSummary.fromMap(
        Map<dynamic, dynamic>.from((map['sleep'] as Map?) ?? const {}),
      ),
      bloodOxygen: Gtl1BloodOxygenSummary.fromMap(
        Map<dynamic, dynamic>.from((map['bloodOxygen'] as Map?) ?? const {}),
      ),
      temperature: Gtl1TemperatureSummary.fromMap(
        Map<dynamic, dynamic>.from((map['temperature'] as Map?) ?? const {}),
      ),
      stress: Gtl1StressSummary.fromMap(
        Map<dynamic, dynamic>.from((map['stress'] as Map?) ?? const {}),
      ),
      sourceDevice: map['sourceDevice'] as String?,
      syncTimestamp: map['syncTimestamp'] as String?,
      raw: Map<String, dynamic>.from(
        (map['raw'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  final String date;
  final int steps;
  final double caloriesKcal;
  final double distanceMeters;
  final Gtl1HeartRateSummary heartRate;
  final Gtl1SleepSummary sleep;
  final Gtl1BloodOxygenSummary bloodOxygen;
  final Gtl1TemperatureSummary temperature;
  final Gtl1StressSummary stress;
  final String? sourceDevice;
  final String? syncTimestamp;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'steps': steps,
      'caloriesKcal': caloriesKcal,
      'distanceMeters': distanceMeters,
      'heartRate': heartRate.toMap(),
      'sleep': sleep.toMap(),
      'bloodOxygen': bloodOxygen.toMap(),
      'temperature': temperature.toMap(),
      'stress': stress.toMap(),
      if (sourceDevice != null) 'sourceDevice': sourceDevice,
      if (syncTimestamp != null) 'syncTimestamp': syncTimestamp,
      'raw': raw,
    };
  }
}

class Gtl1HeartRateSummary {
  const Gtl1HeartRateSummary({
    this.resting = 0,
    this.avg = 0,
    this.min = 0,
    this.max = 0,
  });

  factory Gtl1HeartRateSummary.fromMap(Map<dynamic, dynamic> map) {
    return Gtl1HeartRateSummary(
      resting: (map['resting'] as num?)?.toInt() ?? 0,
      avg: (map['avg'] as num?)?.toInt() ?? 0,
      min: (map['min'] as num?)?.toInt() ?? 0,
      max: (map['max'] as num?)?.toInt() ?? 0,
    );
  }

  final int resting;
  final int avg;
  final int min;
  final int max;

  Map<String, dynamic> toMap() {
    return {'resting': resting, 'avg': avg, 'min': min, 'max': max};
  }
}

class Gtl1SleepSummary {
  const Gtl1SleepSummary({
    this.totalMinutes = 0,
    this.deepMinutes = 0,
    this.lightMinutes = 0,
    this.awakeMinutes = 0,
  });

  factory Gtl1SleepSummary.fromMap(Map<dynamic, dynamic> map) {
    return Gtl1SleepSummary(
      totalMinutes: (map['totalMinutes'] as num?)?.toInt() ?? 0,
      deepMinutes: (map['deepMinutes'] as num?)?.toInt() ?? 0,
      lightMinutes: (map['lightMinutes'] as num?)?.toInt() ?? 0,
      awakeMinutes: (map['awakeMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  final int totalMinutes;
  final int deepMinutes;
  final int lightMinutes;
  final int awakeMinutes;

  Map<String, dynamic> toMap() {
    return {
      'totalMinutes': totalMinutes,
      'deepMinutes': deepMinutes,
      'lightMinutes': lightMinutes,
      'awakeMinutes': awakeMinutes,
    };
  }
}

class Gtl1BloodOxygenSummary {
  const Gtl1BloodOxygenSummary({this.avg = 0, this.min = 0});

  factory Gtl1BloodOxygenSummary.fromMap(Map<dynamic, dynamic> map) {
    return Gtl1BloodOxygenSummary(
      avg: (map['avg'] as num?)?.toInt() ?? 0,
      min: (map['min'] as num?)?.toInt() ?? 0,
    );
  }

  final int avg;
  final int min;

  Map<String, dynamic> toMap() {
    return {'avg': avg, 'min': min};
  }
}

class Gtl1TemperatureSummary {
  const Gtl1TemperatureSummary({this.avg = 0});

  factory Gtl1TemperatureSummary.fromMap(Map<dynamic, dynamic> map) {
    return Gtl1TemperatureSummary(avg: (map['avg'] as num?)?.toDouble() ?? 0);
  }

  final double avg;

  Map<String, dynamic> toMap() {
    return {'avg': avg};
  }
}

class Gtl1StressSummary {
  const Gtl1StressSummary({this.avg = 0});

  factory Gtl1StressSummary.fromMap(Map<dynamic, dynamic> map) {
    return Gtl1StressSummary(avg: (map['avg'] as num?)?.toInt() ?? 0);
  }

  final int avg;

  Map<String, dynamic> toMap() {
    return {'avg': avg};
  }
}

String _yyyyMmDd(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
