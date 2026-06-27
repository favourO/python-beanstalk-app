enum PredictionPhase { menstrual, follicular, ovulatory, luteal, unknown }

enum CycleForecastSuggestionType { ovulationShift, periodShift, unknown }

enum CycleForecastSuggestionStatus {
  pending,
  accepted,
  rejected,
  expired,
  unknown,
}

class CurrentPrediction {
  const CurrentPrediction({
    required this.phase,
    required this.confidence,
    required this.confidenceExplanation,
    required this.phaseDistribution,
    required this.warningFlags,
    this.cycleDay,
    this.cycleLength,
    this.cycleStartDate,
    this.periodLength,
    this.fertileWindowStart,
    this.fertileWindowEnd,
    this.ovulationDate,
    this.nextPeriodDate,
    this.ageContextSummary,
  });

  final PredictionPhase phase;
  final double confidence;
  final String confidenceExplanation;
  final Map<PredictionPhase, double> phaseDistribution;
  final List<String> warningFlags;
  final int? cycleDay;
  final int? cycleLength;
  final DateTime? cycleStartDate;
  final int? periodLength;
  final DateTime? fertileWindowStart;
  final DateTime? fertileWindowEnd;
  final DateTime? ovulationDate;
  final DateTime? nextPeriodDate;
  final String? ageContextSummary;

  String get phaseLabel {
    return switch (phase) {
      PredictionPhase.menstrual => 'Menstrual',
      PredictionPhase.follicular => 'Follicular',
      PredictionPhase.ovulatory => 'Ovulatory',
      PredictionPhase.luteal => 'Luteal',
      PredictionPhase.unknown => 'Cycle',
    };
  }

  String get fertilityLabel {
    final ovulatoryWeight = phaseDistribution[PredictionPhase.ovulatory] ?? 0;
    final fertileWeight = switch (phase) {
      PredictionPhase.ovulatory => 0.9,
      PredictionPhase.follicular when ovulatoryWeight >= 0.2 => 0.7,
      PredictionPhase.follicular => 0.42,
      PredictionPhase.luteal => 0.18,
      PredictionPhase.menstrual => 0.08,
      PredictionPhase.unknown => confidence,
    };

    if (fertileWeight >= 0.75) {
      return 'High';
    }
    if (fertileWeight >= 0.4) {
      return 'Medium';
    }
    return 'Low';
  }

  double get fertilityProgress {
    final ovulatoryWeight = phaseDistribution[PredictionPhase.ovulatory] ?? 0;
    final value = switch (phase) {
      PredictionPhase.ovulatory => 0.86,
      PredictionPhase.follicular => ovulatoryWeight >= 0.2 ? 0.62 : 0.38,
      PredictionPhase.luteal => 0.18,
      PredictionPhase.menstrual => 0.08,
      PredictionPhase.unknown => confidence,
    };
    return value.clamp(0.0, 1.0);
  }
}

class PredictionCalendarDay {
  const PredictionCalendarDay({
    required this.date,
    required this.phase,
    this.hasDot = false,
    this.isOvulation = false,
    this.isFertile = false,
    this.isPeriod = false,
  });

  final DateTime date;
  final PredictionPhase phase;
  final bool hasDot;
  final bool isOvulation;
  final bool isFertile;
  final bool isPeriod;
}

class CycleForecastSuggestion {
  const CycleForecastSuggestion({
    required this.id,
    required this.type,
    required this.status,
    required this.evidence,
    this.cycleId,
    this.currentValue,
    this.suggestedValue,
    this.createdAt,
    this.decidedAt,
  });

  final String id;
  final CycleForecastSuggestionType type;
  final CycleForecastSuggestionStatus status;
  final String? cycleId;
  final DateTime? currentValue;
  final DateTime? suggestedValue;
  final List<CycleForecastEvidence> evidence;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  bool get isPending => status == CycleForecastSuggestionStatus.pending;

  String get typeLabel {
    return switch (type) {
      CycleForecastSuggestionType.ovulationShift => 'Ovulation update',
      CycleForecastSuggestionType.periodShift => 'Period update',
      CycleForecastSuggestionType.unknown => 'Forecast update',
    };
  }
}

class CycleForecastEvidence {
  const CycleForecastEvidence({
    required this.label,
    required this.summary,
    this.sourceType,
    this.confidence,
  });

  final String label;
  final String summary;
  final String? sourceType;
  final double? confidence;
}
