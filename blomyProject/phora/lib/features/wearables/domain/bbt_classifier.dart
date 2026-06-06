import 'wearable_models.dart';

enum TemperatureClassification { basalBodyTemperature, bodyTemperature }

class TemperatureReading {
  const TemperatureReading({
    required this.valueCelsius,
    required this.recordedAt,
    required this.source,
    required this.trustedSource,
    this.collectedDuringSleep = false,
    this.collectedAfterWaking = false,
    this.priorContinuousSleepMinutes,
    this.excessiveMovementBeforeReading = false,
  });

  final double valueCelsius;
  final DateTime recordedAt;
  final WearableSource source;
  final bool trustedSource;
  final bool collectedDuringSleep;
  final bool collectedAfterWaking;
  final int? priorContinuousSleepMinutes;
  final bool excessiveMovementBeforeReading;
}

class BbtClassificationResult {
  const BbtClassificationResult({
    required this.classification,
    required this.reason,
    required this.reading,
  });

  final TemperatureClassification classification;
  final String reason;
  final TemperatureReading reading;

  bool get isBbt =>
      classification == TemperatureClassification.basalBodyTemperature;
}

class BbtClassifier {
  const BbtClassifier();

  BbtClassificationResult classify(TemperatureReading reading) {
    final hour = reading.recordedAt.hour;
    final inBbtWindow = hour >= 3 && hour <= 7;
    final enoughSleep =
        (reading.priorContinuousSleepMinutes ?? 0) >=
        _minimumContinuousSleepMinutes;
    final sleepTimingOk =
        reading.collectedDuringSleep || reading.collectedAfterWaking;
    final plausible = reading.valueCelsius >= 34 && reading.valueCelsius <= 39;

    if (!plausible) {
      return _bodyTemp(reading, 'Temperature value is outside BBT range.');
    }
    if (!reading.trustedSource) {
      return _bodyTemp(reading, 'Reading source is not trusted for BBT.');
    }
    if (!inBbtWindow && !reading.collectedAfterWaking) {
      return _bodyTemp(reading, 'Reading was not collected around waking.');
    }
    if (!sleepTimingOk) {
      return _bodyTemp(
        reading,
        'Reading was not collected during sleep or waking.',
      );
    }
    if (!enoughSleep) {
      return _bodyTemp(reading, 'Not enough continuous sleep before reading.');
    }
    if (reading.excessiveMovementBeforeReading) {
      return _bodyTemp(reading, 'Movement before reading may affect BBT.');
    }
    return BbtClassificationResult(
      classification: TemperatureClassification.basalBodyTemperature,
      reason: 'Reading matches basal body temperature conditions.',
      reading: reading,
    );
  }

  BbtClassificationResult _bodyTemp(TemperatureReading reading, String reason) {
    return BbtClassificationResult(
      classification: TemperatureClassification.bodyTemperature,
      reason: reason,
      reading: reading,
    );
  }

  static const _minimumContinuousSleepMinutes = 180;
}
