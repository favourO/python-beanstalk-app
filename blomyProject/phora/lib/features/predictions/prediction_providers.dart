import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/features/predictions/data/predictions_repository.dart';
import 'package:phora/features/predictions/domain/prediction_models.dart';

final currentPredictionProvider =
    AsyncNotifierProvider<CurrentPredictionController, CurrentPrediction>(
      CurrentPredictionController.new,
    );

class CurrentPredictionController extends AsyncNotifier<CurrentPrediction> {
  @override
  Future<CurrentPrediction> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      return const CurrentPrediction(
        phase: PredictionPhase.unknown,
        confidence: 0,
        confidenceExplanation: 'Sign in to view cycle predictions.',
        phaseDistribution: {},
        warningFlags: [],
      );
    }
    return ref.watch(predictionsRepositoryProvider).getCurrentPrediction();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(predictionsRepositoryProvider).getCurrentPrediction(),
    );
  }
}

final predictionCalendarProvider =
    AsyncNotifierProvider<PredictionCalendarController, List<PredictionCalendarDay>>(
      PredictionCalendarController.new,
    );

class PredictionCalendarController
    extends AsyncNotifier<List<PredictionCalendarDay>> {
  @override
  Future<List<PredictionCalendarDay>> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      return const [];
    }
    return ref.watch(predictionsRepositoryProvider).getPredictionCalendar();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(predictionsRepositoryProvider).getPredictionCalendar(),
    );
  }
}
