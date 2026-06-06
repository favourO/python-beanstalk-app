import 'package:phora/features/wearables/domain/wearable_models.dart';

class OvulationConfidenceResult {
  const OvulationConfidenceResult({
    required this.score,
    required this.summary,
    required this.supportingMessage,
  });

  final double score;
  final String summary;
  final String supportingMessage;
}

class OvulationConfidenceEngine {
  const OvulationConfidenceEngine();

  OvulationConfidenceResult evaluate(List<WearableDailyMetrics> metrics) {
    final bbtMetrics =
        metrics.where((metric) => metric.bbt != null).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (bbtMetrics.length < 6) {
      return const OvulationConfidenceResult(
        score: 0.2,
        summary:
            'More BBT data is needed before temperature can support this prediction.',
        supportingMessage:
            'Vyla only uses readings that meet basal temperature conditions.',
      );
    }

    final recent = bbtMetrics.takeLast(3).toList();
    final baseline =
        bbtMetrics.take(bbtMetrics.length - 3).takeLast(6).toList();
    if (baseline.length < 3 || recent.length < 3) {
      return const OvulationConfidenceResult(
        score: 0.35,
        summary: 'Temperature trends are still building.',
        supportingMessage:
            'Consistent BBT over several mornings may improve fertile window estimates.',
      );
    }

    final baselineAvg = baseline.map((m) => m.bbt!).average();
    final recentAvg = recent.map((m) => m.bbt!).average();
    final sustainedRise = recent.every((m) => m.bbt! >= baselineAvg + 0.18);

    if (!sustainedRise) {
      return const OvulationConfidenceResult(
        score: 0.45,
        summary: 'Temperature trends do not yet show a sustained rise.',
        supportingMessage:
            'Vyla will keep this as supporting context, not medical certainty.',
      );
    }

    final rise = recentAvg - baselineAvg;
    final score = (0.62 + (rise.clamp(0.18, 0.45) - 0.18)).clamp(0.0, 0.9);
    return OvulationConfidenceResult(
      score: score,
      summary: 'This pattern may suggest ovulation.',
      supportingMessage:
          'Temperature trends may support this prediction, but they do not confirm ovulation or replace medical advice.',
    );
  }
}

extension _IterableDoubleAverage on Iterable<double> {
  double average() {
    if (isEmpty) {
      return 0;
    }
    return reduce((a, b) => a + b) / length;
  }
}

extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final items = toList();
    if (items.length <= count) {
      return items;
    }
    return items.skip(items.length - count);
  }
}
