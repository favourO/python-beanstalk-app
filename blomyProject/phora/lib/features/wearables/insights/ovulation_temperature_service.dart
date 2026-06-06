import 'package:phora/features/wearables/domain/wearable_models.dart';

enum OvulationTemperatureStatus {
  insufficientData,
  noSustainedRise,
  sustainedRiseDetected,
}

class OvulationTemperatureResult {
  const OvulationTemperatureResult({
    required this.status,
    required this.confidence,
    required this.summary,
    this.estimatedOvulationDate,
    this.baselineCelsius,
  });

  final OvulationTemperatureStatus status;
  final double confidence;
  final String summary;
  final DateTime? estimatedOvulationDate;
  final double? baselineCelsius;
}

class OvulationTemperatureService {
  const OvulationTemperatureService();

  OvulationTemperatureResult analyse(List<BBTReading> readings) {
    final valid =
        readings
            .where(
              (reading) =>
                  reading.valid &&
                  reading.type == TemperatureReadingType.basalBodyTemperature,
            )
            .toList()
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    if (valid.length < 8) {
      return const OvulationTemperatureResult(
        status: OvulationTemperatureStatus.insufficientData,
        confidence: 0.2,
        summary:
            'Vyla needs at least 5 baseline readings and 3 elevated readings before temperature can support ovulation timing.',
      );
    }

    for (var index = 5; index <= valid.length - 3; index++) {
      final baselineReadings = valid.sublist(
        (index - 7).clamp(0, index),
        index,
      );
      if (baselineReadings.length < 5) {
        continue;
      }
      final baseline = baselineReadings.map((r) => r.valueCelsius).average();
      final elevated = valid.sublist(index, index + 3);
      final sustainedRise = elevated.every(
        (reading) => reading.valueCelsius >= baseline + 0.2,
      );
      if (!sustainedRise) {
        continue;
      }
      final firstElevated = elevated.first.measuredAt;
      return OvulationTemperatureResult(
        status: OvulationTemperatureStatus.sustainedRiseDetected,
        confidence: 0.72,
        summary:
            'Your temperature trend may suggest ovulation recently occurred.',
        estimatedOvulationDate: DateTime(
          firstElevated.year,
          firstElevated.month,
          firstElevated.day,
        ).subtract(const Duration(days: 1)),
        baselineCelsius: baseline,
      );
    }

    return const OvulationTemperatureResult(
      status: OvulationTemperatureStatus.noSustainedRise,
      confidence: 0.45,
      summary:
          'Vyla has valid BBT readings, but has not detected a sustained 3-day temperature rise yet.',
    );
  }
}

extension _Average on Iterable<double> {
  double average() {
    if (isEmpty) {
      return 0;
    }
    return reduce((a, b) => a + b) / length;
  }
}
