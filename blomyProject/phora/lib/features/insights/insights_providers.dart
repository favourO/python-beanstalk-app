import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/features/insights/data/cycle_stats_repository.dart';
import 'package:phora/features/insights/domain/cycle_stats.dart';

final cycleStatsProvider =
    AsyncNotifierProvider<CycleStatsController, CycleStats>(
      CycleStatsController.new,
    );

class CycleStatsController extends AsyncNotifier<CycleStats> {
  @override
  Future<CycleStats> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      return const CycleStats(
        trackedCycles: 0,
        firstPeriodStartDate: null,
        averageCycleLengthDays: 0,
        averagePeriodLengthDays: 0,
        regularityScore: 0,
        temperatureTrend: [],
        hrvTrend: [],
        symptomPatterns: SymptomPatterns(),
        periodRanges: [],
      );
    }
    return ref.watch(cycleStatsRepositoryProvider).getCycleStats();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cycleStatsRepositoryProvider).getCycleStats(),
    );
  }
}
