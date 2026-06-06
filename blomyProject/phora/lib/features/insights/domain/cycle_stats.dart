class CycleStats {
  const CycleStats({
    required this.trackedCycles,
    this.firstPeriodStartDate,
    required this.averageCycleLengthDays,
    required this.averagePeriodLengthDays,
    required this.regularityScore,
    required this.temperatureTrend,
    required this.hrvTrend,
    required this.symptomPatterns,
    this.periodRanges = const [],
  });

  final int trackedCycles;
  final DateTime? firstPeriodStartDate;
  final double averageCycleLengthDays;
  final double averagePeriodLengthDays;
  final double regularityScore;
  final List<CycleStatsPoint> temperatureTrend;
  final List<CycleStatsPoint> hrvTrend;
  final SymptomPatterns symptomPatterns;
  final List<CyclePeriodRange> periodRanges;

  String get regularityPercentLabel =>
      (regularityScore * 100).round().toString();
}

class CyclePeriodRange {
  const CyclePeriodRange({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;

  bool contains(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !key.isBefore(start) && !key.isAfter(end);
  }
}

class CycleStatsPoint {
  const CycleStatsPoint({required this.recordedAt, required this.value});

  final DateTime recordedAt;
  final double value;
}

class SymptomPatterns {
  const SymptomPatterns({this.mostCommon, this.energyDips});

  final String? mostCommon;
  final String? energyDips;
}
