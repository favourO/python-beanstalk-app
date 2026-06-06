import 'bbt_classifier.dart';
import 'wearable_models.dart';

class BBTValidationResult {
  const BBTValidationResult({
    required this.type,
    required this.valid,
    required this.confidence,
    this.invalidReason,
  });

  final TemperatureReadingType type;
  final bool valid;
  final String confidence;
  final String? invalidReason;
}

class BBTValidationService {
  const BBTValidationService();

  BBTValidationResult validate(
    TemperatureReading reading,
    SleepSession? sleep, {
    bool illnessFlag = false,
    bool manuallyEnteredAsNormalTemperature = false,
  }) {
    if (manuallyEnteredAsNormalTemperature) {
      return const BBTValidationResult(
        type: TemperatureReadingType.normalBodyTemperature,
        valid: false,
        confidence: 'low',
        invalidReason: 'Reading was entered as normal body temperature.',
      );
    }
    if (illnessFlag) {
      return const BBTValidationResult(
        type: TemperatureReadingType.invalidForBBT,
        valid: false,
        confidence: 'low',
        invalidReason: 'Illness or fever may distort resting temperature.',
      );
    }

    final sleepMinutes =
        sleep?.totalMinutes ?? reading.priorContinuousSleepMinutes ?? 0;
    final enrichedReading = TemperatureReading(
      valueCelsius: reading.valueCelsius,
      recordedAt: reading.recordedAt,
      source: reading.source,
      trustedSource: reading.trustedSource,
      collectedDuringSleep:
          reading.collectedDuringSleep ||
          (sleep != null &&
              !reading.recordedAt.isBefore(sleep.startedAt) &&
              !reading.recordedAt.isAfter(sleep.endedAt)),
      collectedAfterWaking:
          reading.collectedAfterWaking ||
          (sleep != null &&
              reading.recordedAt.difference(sleep.endedAt).inMinutes.abs() <=
                  45),
      priorContinuousSleepMinutes: sleepMinutes,
      excessiveMovementBeforeReading: reading.excessiveMovementBeforeReading,
    );

    final result = const BbtClassifier().classify(enrichedReading);
    if (!result.isBbt) {
      return BBTValidationResult(
        type: TemperatureReadingType.invalidForBBT,
        valid: false,
        confidence: 'low',
        invalidReason: result.reason,
      );
    }

    return BBTValidationResult(
      type: TemperatureReadingType.basalBodyTemperature,
      valid: true,
      confidence: sleepMinutes >= 240 ? 'high' : 'medium',
    );
  }
}
