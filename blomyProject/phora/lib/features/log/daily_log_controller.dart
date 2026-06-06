import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/features/home/home_providers.dart';
import 'package:phora/features/insights/insights_providers.dart';
import 'package:phora/features/log/daily_log_models.dart';
import 'package:phora/features/log/daily_log_repository.dart';
import 'package:phora/features/predictions/prediction_providers.dart';

final dailyLogControllerProvider =
    AsyncNotifierProvider<DailyLogController, DailyLogScreenState>(
      DailyLogController.new,
    );

final dailyLogDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

class DailyLogScreenState {
  const DailyLogScreenState({
    required this.draft,
    required this.isDirty,
    required this.isSaved,
    required this.isSaving,
    required this.sectionErrors,
    this.globalError,
    this.isSavingAll = false,
  });

  DailyLogScreenState copyWith({
    DailyLogDraft? draft,
    Map<LogSection, bool>? isDirty,
    Map<LogSection, bool>? isSaved,
    Map<LogSection, bool>? isSaving,
    Map<LogSection, String?>? sectionErrors,
    String? globalError,
    bool? isSavingAll,
  }) {
    return DailyLogScreenState(
      draft: draft ?? this.draft,
      isDirty: isDirty ?? this.isDirty,
      isSaved: isSaved ?? this.isSaved,
      isSaving: isSaving ?? this.isSaving,
      sectionErrors: sectionErrors ?? this.sectionErrors,
      globalError: globalError,
      isSavingAll: isSavingAll ?? this.isSavingAll,
    );
  }

  bool get hasUnsavedChanges => isDirty.values.any((value) => value);

  int get dirtyCount => isDirty.values.where((value) => value).length;

  final DailyLogDraft draft;
  final Map<LogSection, bool> isDirty;
  final Map<LogSection, bool> isSaved;
  final Map<LogSection, bool> isSaving;
  final Map<LogSection, String?> sectionErrors;
  final String? globalError;
  final bool isSavingAll;
}

class DailyLogController extends AsyncNotifier<DailyLogScreenState> {
  @override
  Future<DailyLogScreenState> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      throw StateError('Sign in to view today\'s log.');
    }
    final date = ref.watch(dailyLogDateProvider);
    final draft = await ref
        .watch(dailyLogRepositoryProvider)
        .getDailyLog(userId: session.userId, date: date);
    final saved = blankSectionMap();
    for (final section in LogSection.values) {
      saved[section] = _sectionHasData(draft, section);
    }
    return DailyLogScreenState(
      draft: draft,
      isDirty: blankSectionMap(),
      isSaved: saved,
      isSaving: blankSectionMap(),
      sectionErrors: {for (final section in LogSection.values) section: null},
    );
  }

  void updatePeriod(PeriodLogDraft draft) => _updateSection(
    LogSection.period,
    current: state.value!.draft.copyWith(period: draft),
  );

  void updateSymptoms(SymptomsLogDraft draft) => _updateSection(
    LogSection.symptoms,
    current: state.value!.draft.copyWith(symptoms: draft),
  );

  void updateTemperature(TemperatureLogDraft draft) => _updateSection(
    LogSection.temperature,
    current: state.value!.draft.copyWith(temperature: draft),
  );

  void updateLhTest(LhTestLogDraft draft) => _updateSection(
    LogSection.lhTest,
    current: state.value!.draft.copyWith(lhTest: draft),
  );

  void updateCervicalMucus(CervicalMucusLogDraft draft) => _updateSection(
    LogSection.cervicalMucus,
    current: state.value!.draft.copyWith(cervicalMucus: draft),
  );

  void updateIntimacy(IntimacyLogDraft draft) => _updateSection(
    LogSection.intimacy,
    current: state.value!.draft.copyWith(intimacy: draft),
  );

  Future<bool> saveSection(LogSection section) async {
    final current = state.valueOrNull;
    if (current == null || !_sectionHasData(current.draft, section)) {
      return false;
    }
    final saving = Map<LogSection, bool>.from(current.isSaving)
      ..[section] = true;
    final errors = Map<LogSection, String?>.from(current.sectionErrors)
      ..[section] = null;
    state = AsyncData(
      current.copyWith(
        isSaving: saving,
        sectionErrors: errors,
        globalError: null,
      ),
    );
    try {
      await ref
          .read(dailyLogRepositoryProvider)
          .saveSection(draft: current.draft, section: section);
      final nextDirty = Map<LogSection, bool>.from(state.value!.isDirty)
        ..[section] = false;
      final nextSaved = Map<LogSection, bool>.from(state.value!.isSaved)
        ..[section] = true;
      final nextSaving = Map<LogSection, bool>.from(state.value!.isSaving)
        ..[section] = false;
      state = AsyncData(
        state.value!.copyWith(
          isDirty: nextDirty,
          isSaved: nextSaved,
          isSaving: nextSaving,
        ),
      );
      ref.invalidate(homeDashboardProvider);
      if (section == LogSection.period) {
        _refreshCycleViews();
      }
      return true;
    } catch (error) {
      final nextSaving = Map<LogSection, bool>.from(state.value!.isSaving)
        ..[section] = false;
      final nextErrors = Map<LogSection, String?>.from(
        state.value!.sectionErrors,
      )..[section] = error.toString();
      state = AsyncData(
        state.value!.copyWith(isSaving: nextSaving, sectionErrors: nextErrors),
      );
      return false;
    }
  }

  Future<bool> saveRemaining() async {
    final current = state.valueOrNull;
    if (current == null || current.dirtyCount == 0) {
      return false;
    }
    final dirty =
        current.isDirty.entries
            .where(
              (entry) =>
                  entry.value && _sectionHasData(current.draft, entry.key),
            )
            .map((entry) => entry.key)
            .toSet();
    if (dirty.isEmpty) {
      state = AsyncData(current.copyWith(globalError: null));
      return false;
    }
    state = AsyncData(current.copyWith(isSavingAll: true, globalError: null));
    try {
      await ref
          .read(dailyLogRepositoryProvider)
          .saveSections(draft: current.draft, sections: dirty);
      final nextDirty = blankSectionMap();
      final nextSaved = Map<LogSection, bool>.from(current.isSaved);
      for (final section in dirty) {
        nextSaved[section] = true;
      }
      state = AsyncData(
        state.value!.copyWith(
          isDirty: nextDirty,
          isSaved: nextSaved,
          isSavingAll: false,
          globalError: null,
        ),
      );
      ref.invalidate(homeDashboardProvider);
      if (dirty.contains(LogSection.period)) {
        _refreshCycleViews();
      }
      return true;
    } catch (error) {
      state = AsyncData(
        state.value!.copyWith(
          isSavingAll: false,
          globalError: error.toString(),
        ),
      );
      return false;
    }
  }

  void clearGlobalError() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(globalError: null));
  }

  void _updateSection(LogSection section, {required DailyLogDraft current}) {
    final existing = state.valueOrNull;
    if (existing == null) return;
    final dirty = Map<LogSection, bool>.from(existing.isDirty)
      ..[section] = true;
    final errors = Map<LogSection, String?>.from(existing.sectionErrors)
      ..[section] = null;
    state = AsyncData(
      existing.copyWith(draft: current, isDirty: dirty, sectionErrors: errors),
    );
  }

  void _refreshCycleViews() {
    ref.invalidate(cycleStatsProvider);
    ref.invalidate(currentPredictionProvider);
    ref.invalidate(predictionCalendarProvider);
  }
}

bool _sectionHasData(DailyLogDraft draft, LogSection section) {
  return switch (section) {
    LogSection.period => draft.period?.hasData ?? false,
    LogSection.symptoms => draft.symptoms?.hasData ?? false,
    LogSection.temperature => draft.temperature?.hasData ?? false,
    LogSection.lhTest => draft.lhTest?.hasData ?? false,
    LogSection.cervicalMucus => draft.cervicalMucus?.hasData ?? false,
    LogSection.intimacy => draft.intimacy?.hasData ?? false,
  };
}
