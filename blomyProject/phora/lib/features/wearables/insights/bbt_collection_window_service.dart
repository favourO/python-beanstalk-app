import 'package:phora/features/home/domain/home_dashboard.dart';

class BBTCollectionWindow {
  const BBTCollectionWindow({
    required this.nextPeriodDate,
    required this.expectedOvulationDay,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.collectionWindowStart,
    required this.collectionWindowEnd,
    required this.isTodayInCollectionWindow,
    required this.source,
  });

  final DateTime nextPeriodDate;
  final DateTime expectedOvulationDay;
  final DateTime fertileWindowStart;
  final DateTime fertileWindowEnd;
  final DateTime collectionWindowStart;
  final DateTime collectionWindowEnd;
  final bool isTodayInCollectionWindow;
  final String source;
}

class BBTCollectionWindowService {
  const BBTCollectionWindowService();

  BBTCollectionWindow? fromHomeDashboard(
    HomeDashboard dashboard, {
    DateTime? today,
  }) {
    final ovulationDate = dashboard.fertility.predictedOvulationDate;
    final nextPeriodDate = dashboard.mainStatus.nextPredictedPeriodDate;
    if (ovulationDate != null && nextPeriodDate != null) {
      return _fromOvulationAndPeriod(
        expectedOvulationDay: ovulationDate,
        nextPeriodDate: nextPeriodDate,
        fertileWindowStart:
            dashboard.fertility.fertileWindowStart ??
            ovulationDate.subtract(const Duration(days: 5)),
        fertileWindowEnd:
            dashboard.fertility.fertileWindowEnd ??
            ovulationDate.add(const Duration(days: 1)),
        today: today,
        source: dashboard.fertility.predictionMethod ?? 'home_prediction',
      );
    }

    final cycleDay = dashboard.mainStatus.currentCycleDay;
    final cycleLength = dashboard.mainStatus.cycleLengthDays;
    if (cycleDay == null || cycleLength == null) {
      return null;
    }
    final localToday = _dateOnly(today ?? DateTime.now());
    final periodStart = localToday.subtract(Duration(days: cycleDay - 1));
    return fromRegistrationCycleData(
      lastPeriodStart: periodStart,
      averageCycleLength: cycleLength,
      today: localToday,
      source: 'home_cycle_day_fallback',
    );
  }

  BBTCollectionWindow fromRegistrationCycleData({
    required DateTime lastPeriodStart,
    required int averageCycleLength,
    DateTime? today,
    String source = 'registration_cycle_data',
  }) {
    final normalizedToday = _dateOnly(today ?? DateTime.now());
    final nextPeriodDate = _dateOnly(
      lastPeriodStart.add(Duration(days: averageCycleLength)),
    );
    final expectedOvulationDay = nextPeriodDate.subtract(
      const Duration(days: 14),
    );
    return _fromOvulationAndPeriod(
      expectedOvulationDay: expectedOvulationDay,
      nextPeriodDate: nextPeriodDate,
      fertileWindowStart: expectedOvulationDay.subtract(
        const Duration(days: 5),
      ),
      fertileWindowEnd: expectedOvulationDay.add(const Duration(days: 1)),
      today: normalizedToday,
      source: source,
    );
  }

  BBTCollectionWindow _fromOvulationAndPeriod({
    required DateTime expectedOvulationDay,
    required DateTime nextPeriodDate,
    required DateTime fertileWindowStart,
    required DateTime fertileWindowEnd,
    required DateTime? today,
    required String source,
  }) {
    final normalizedToday = _dateOnly(today ?? DateTime.now());
    final ovulation = _dateOnly(expectedOvulationDay);
    final collectionWindowStart = ovulation.subtract(const Duration(days: 7));
    final collectionWindowEnd = ovulation.add(const Duration(days: 5));
    return BBTCollectionWindow(
      nextPeriodDate: _dateOnly(nextPeriodDate),
      expectedOvulationDay: ovulation,
      fertileWindowStart: _dateOnly(fertileWindowStart),
      fertileWindowEnd: _dateOnly(fertileWindowEnd),
      collectionWindowStart: collectionWindowStart,
      collectionWindowEnd: collectionWindowEnd,
      isTodayInCollectionWindow:
          !normalizedToday.isBefore(collectionWindowStart) &&
          !normalizedToday.isAfter(collectionWindowEnd),
      source: source,
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
