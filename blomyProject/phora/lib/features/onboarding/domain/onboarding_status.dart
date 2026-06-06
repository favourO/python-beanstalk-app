class OnboardingProgress {
  const OnboardingProgress({
    this.currentStep,
    this.completed = false,
    this.periodLength,
    this.lastPeriodStart,
    this.lastPeriodEnd,
    this.goal,
    this.healthConditions = const [],
    this.updatedAt,
  });

  final int? currentStep;
  final bool completed;
  final int? periodLength;
  final DateTime? lastPeriodStart;
  final DateTime? lastPeriodEnd;
  final String? goal;
  final List<String> healthConditions;
  final DateTime? updatedAt;

  OnboardingProgress copyWith({
    int? currentStep,
    bool? completed,
    int? periodLength,
    DateTime? lastPeriodStart,
    DateTime? lastPeriodEnd,
    String? goal,
    List<String>? healthConditions,
    DateTime? updatedAt,
  }) {
    return OnboardingProgress(
      currentStep: currentStep ?? this.currentStep,
      completed: completed ?? this.completed,
      periodLength: periodLength ?? this.periodLength,
      lastPeriodStart: lastPeriodStart ?? this.lastPeriodStart,
      lastPeriodEnd: lastPeriodEnd ?? this.lastPeriodEnd,
      goal: goal ?? this.goal,
      healthConditions: healthConditions ?? this.healthConditions,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory OnboardingProgress.fromJson(Map<String, dynamic> json) {
    return OnboardingProgress(
      currentStep: _intValue(json['current_step']),
      completed: json['completed'] == true,
      periodLength: _intValue(json['period_length']),
      lastPeriodStart: _dateValue(json['last_period_start']),
      lastPeriodEnd: _dateValue(json['last_period_end']),
      goal: _stringValue(json['goal']),
      healthConditions: _stringList(json['health_conditions']),
      updatedAt: _dateValue(json['updated_at']),
    );
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _dateValue(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _stringValue(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }
}

class OnboardingStatus {
  const OnboardingStatus._({
    required this.isComplete,
    required this.currentStep,
    this.progress,
  });

  const OnboardingStatus.complete()
    : this._(isComplete: true, currentStep: 'done');

  const OnboardingStatus.incomplete({required String currentStep})
    : this._(isComplete: false, currentStep: currentStep);

  const OnboardingStatus.incompleteWithProgress({
    required String currentStep,
    required OnboardingProgress progress,
  }) : this._(
         isComplete: false,
         currentStep: currentStep,
         progress: progress,
       );

  final bool isComplete;
  final String currentStep;
  final OnboardingProgress? progress;
}
