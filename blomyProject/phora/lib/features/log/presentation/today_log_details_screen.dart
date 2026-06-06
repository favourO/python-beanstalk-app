import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/home/home_providers.dart';
import 'package:phora/features/insights/insights_providers.dart';
import 'package:phora/features/log/daily_log_controller.dart';
import 'package:phora/features/log/daily_log_models.dart';
import 'package:phora/features/log/presentation/log_ui.dart';
import 'package:phora/features/predictions/prediction_providers.dart';
import 'package:phora/features/profile/profile_providers.dart';
import 'package:go_router/go_router.dart';

class TodayLogDetailsScreen extends ConsumerStatefulWidget {
  const TodayLogDetailsScreen({super.key});

  @override
  ConsumerState<TodayLogDetailsScreen> createState() =>
      _TodayLogDetailsScreenState();
}

class _TodayLogDetailsScreenState extends ConsumerState<TodayLogDetailsScreen> {
  final _symptomsNotesController = TextEditingController();
  final _mucusNotesController = TextEditingController();
  final _intimacyNotesController = TextEditingController();
  bool _seededControllers = false;
  bool _seededActiveSection = false;
  bool _periodRangeChangedByUser = false;
  LogSection? _activeSection;

  static const _periodSymptoms = [
    'Cramps',
    'Bloating',
    'Headache',
    'Fatigue',
    'Back Pain',
    'Nausea',
  ];

  static const _physicalSymptoms = [
    'Cramps',
    'Bloating',
    'Headache',
    'Tender Breasts',
    'Fatigue',
    'Back Pain',
    'Acne',
    'Cravings',
  ];

  @override
  void dispose() {
    _symptomsNotesController.dispose();
    _mucusNotesController.dispose();
    _intimacyNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    final stateAsync = ref.watch(dailyLogControllerProvider);
    final home = ref.watch(homeDashboardProvider).valueOrNull;
    final cycleStats = ref.watch(cycleStatsProvider).valueOrNull;
    final currentPrediction = ref.watch(currentPredictionProvider).valueOrNull;

    return LogPageScaffold(
      backgroundColor: palette.pageBackground,
      header: const _AssistantHeader(),
      child: stateAsync.when(
        loading:
            () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 120),
              child: Center(child: CircularProgressIndicator()),
            ),
        error:
            (error, _) => _ErrorState(
              message: error.toString(),
              onRetry: () => ref.invalidate(dailyLogControllerProvider),
            ),
        data: (state) {
          _seedControllers(state);
          _seedActiveSection(state);
          final recentNotes = _recentNotes(state);
          final inferredPeriodStartDate = _inferredPeriodStartDate(
            logDate: state.draft.date,
            periodRanges: cycleStats?.periodRanges ?? const [],
            currentCycleDay: home?.mainStatus.currentCycleDay,
            periodLengthDays: home?.mainStatus.periodLengthDays,
          );
          final calendarPeriodRange = _calendarPeriodRangeForMonth(
            logDate: state.draft.date,
            periodRanges: cycleStats?.periodRanges ?? const [],
            calendarStartDate:
                currentPrediction?.cycleStartDate ??
                cycleStats?.firstPeriodStartDate ??
                _currentCycleStartDateFromPrediction(
                  currentPrediction?.cycleDay,
                ),
            cycleLengthDays:
                currentPrediction?.cycleLength ??
                home?.mainStatus.cycleLengthDays,
            periodLengthDays:
                currentPrediction?.periodLength ??
                home?.mainStatus.periodLengthDays,
          );
          final confirmedPeriodStartDate =
              _periodRangeChangedByUser
                  ? state.draft.period?.startDate ?? inferredPeriodStartDate
                  : calendarPeriodRange?.start ??
                      state.draft.period?.startDate ??
                      inferredPeriodStartDate;
          final confirmedPeriodEndDate =
              _periodRangeChangedByUser
                  ? state.draft.period?.endDate ??
                      _estimatedPeriodEndDate(
                        startDate: confirmedPeriodStartDate,
                        periodLengthDays: home?.mainStatus.periodLengthDays,
                      )
                  : calendarPeriodRange?.end ??
                      state.draft.period?.endDate ??
                      _estimatedPeriodEndDate(
                        startDate: confirmedPeriodStartDate,
                        periodLengthDays: home?.mainStatus.periodLengthDays,
                      );
          final currentCycleDay = _cycleDayForLogDate(
            logDate: state.draft.date,
            currentCycleDay: home?.mainStatus.currentCycleDay,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IntroHero(),
              SizedBox(height: dims.scaleSpace(18)),
              _ProgressCard(
                state: state,
                activeSection: _activeSection,
                onSelect: (section) => setState(() => _activeSection = section),
              ),
              SizedBox(height: dims.scaleSpace(14)),
              _PeriodRangeQuestion(
                logDate: state.draft.date,
                startDate: confirmedPeriodStartDate,
                endDate: confirmedPeriodEndDate,
                periodDay:
                    state.draft.date
                        .difference(confirmedPeriodStartDate)
                        .inDays +
                    1,
                currentCycleDay: currentCycleDay,
                onRangeChanged: (range) {
                  _persistPeriodRange(context, state, range);
                },
              ),
              if (_activeSection != null) ...[
                SizedBox(height: dims.scaleSpace(18)),
                _QuestionPanel(
                  section: _activeSection!,
                  state: state,
                  inferredPeriodStartDate: confirmedPeriodStartDate,
                  inferredPeriodEndDate: confirmedPeriodEndDate,
                  symptomsNotesController: _symptomsNotesController,
                  mucusNotesController: _mucusNotesController,
                  intimacyNotesController: _intimacyNotesController,
                  onClose: () => setState(() => _activeSection = null),
                  onPeriodChanged:
                      (draft) => ref
                          .read(dailyLogControllerProvider.notifier)
                          .updatePeriod(draft),
                  onSymptomsChanged:
                      (draft) => ref
                          .read(dailyLogControllerProvider.notifier)
                          .updateSymptoms(draft),
                  onTemperatureChanged:
                      (draft) => ref
                          .read(dailyLogControllerProvider.notifier)
                          .updateTemperature(draft),
                  onLhChanged:
                      (draft) => ref
                          .read(dailyLogControllerProvider.notifier)
                          .updateLhTest(draft),
                  onMucusChanged:
                      (draft) => ref
                          .read(dailyLogControllerProvider.notifier)
                          .updateCervicalMucus(draft),
                  onIntimacyChanged:
                      (draft) => ref
                          .read(dailyLogControllerProvider.notifier)
                          .updateIntimacy(draft),
                  onSave:
                      () => _saveActiveSection(
                        context,
                        _activeSection!,
                        state,
                        requiredPeriodStartDate: confirmedPeriodStartDate,
                        requiredPeriodEndDate: confirmedPeriodEndDate,
                      ),
                ),
              ] else ...[
                SizedBox(height: dims.scaleSpace(18)),
                _RecentNoteCard(notes: recentNotes),
              ],
            ],
          );
        },
      ),
    );
  }

  void _seedControllers(DailyLogScreenState state) {
    if (_seededControllers) return;
    _seededControllers = true;
    _symptomsNotesController.text = state.draft.symptoms?.notes ?? '';
    _mucusNotesController.text = state.draft.cervicalMucus?.notes ?? '';
    _intimacyNotesController.text = state.draft.intimacy?.notes ?? '';
  }

  void _seedActiveSection(DailyLogScreenState state) {
    if (_seededActiveSection) return;
    _seededActiveSection = true;
    _activeSection = _sectionFromRoute(context) ?? _nextUnsavedSection(state);
  }

  Future<void> _persistPeriodRange(
    BuildContext context,
    DailyLogScreenState state,
    DateTimeRange range,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final logDate = _dateOnly(state.draft.date);
    final rangeStart = _dateOnly(range.start);
    final rangeEnd = _dateOnly(range.end);
    if (logDate.isBefore(rangeStart) || logDate.isAfter(rangeEnd)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Select a range that includes this log day.'),
        ),
      );
      return;
    }

    setState(() => _periodRangeChangedByUser = true);
    final notifier = ref.read(dailyLogControllerProvider.notifier);
    final currentState = ref.read(dailyLogControllerProvider).valueOrNull;
    notifier.updatePeriod(
      (currentState?.draft.period ??
              state.draft.period ??
              const PeriodLogDraft())
          .copyWith(startDate: rangeStart, endDate: rangeEnd),
    );
    final success = await notifier.saveSection(LogSection.period);
    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Period range updated')),
      );
    } else {
      final error =
          ref
              .read(dailyLogControllerProvider)
              .valueOrNull
              ?.sectionErrors[LogSection.period];
      messenger.showSnackBar(
        SnackBar(content: Text(error ?? 'Could not update period range')),
      );
    }
  }

  Future<void> _saveActiveSection(
    BuildContext context,
    LogSection section,
    DailyLogScreenState state, {
    DateTime? requiredPeriodStartDate,
    DateTime? requiredPeriodEndDate,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(dailyLogControllerProvider.notifier);
    if (section == LogSection.period && requiredPeriodStartDate != null) {
      final requiredPeriodEnd =
          requiredPeriodEndDate ?? requiredPeriodStartDate;
      final logDate = _dateOnly(state.draft.date);
      final rangeStart = _dateOnly(requiredPeriodStartDate);
      final rangeEnd = _dateOnly(requiredPeriodEnd);
      if (logDate.isBefore(rangeStart) || logDate.isAfter(rangeEnd)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Update the period range to include this day before saving.',
            ),
          ),
        );
        return;
      }
      final periodDraft = (ref
                  .read(dailyLogControllerProvider)
                  .valueOrNull
                  ?.draft
                  .period ??
              state.draft.period ??
              const PeriodLogDraft())
          .copyWith(startDate: rangeStart, endDate: rangeEnd);
      notifier.updatePeriod(periodDraft);
    }
    final success = await notifier.saveSection(section);
    if (!mounted) return;
    if (success) {
      final updatedState = ref.read(dailyLogControllerProvider).valueOrNull;
      setState(() {
        _activeSection =
            updatedState == null
                ? null
                : _nextUnsavedSection(updatedState, after: section);
      });
      messenger.showSnackBar(
        SnackBar(content: Text('${_sectionTitle(section)} saved')),
      );
    } else {
      final error =
          ref
              .read(dailyLogControllerProvider)
              .valueOrNull
              ?.sectionErrors[section];
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Could not save ${_sectionTitle(section).toLowerCase()}',
          ),
        ),
      );
    }
  }

  String _sectionTitle(LogSection section) {
    return switch (section) {
      LogSection.period => 'Period',
      LogSection.symptoms => 'Symptoms',
      LogSection.temperature => 'Temperature',
      LogSection.lhTest => 'LH Test',
      LogSection.cervicalMucus => 'Cervical Mucus',
      LogSection.intimacy => 'Intimacy',
    };
  }

  List<_RecentNoteEntry> _recentNotes(DailyLogScreenState state) {
    final dateLabel = _formatNoteDate(state.draft.date);
    return [
          (source: 'Symptoms', note: state.draft.symptoms?.notes),
          (source: 'Intimacy', note: state.draft.intimacy?.notes),
          (source: 'Mucus', note: state.draft.cervicalMucus?.notes),
        ]
        .where((entry) => entry.note?.trim().isNotEmpty ?? false)
        .map(
          (entry) => _RecentNoteEntry(
            text: entry.note!.trim(),
            source: entry.source,
            dateLabel: dateLabel,
          ),
        )
        .toList();
  }

  String _formatNoteDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final day = date.day;
    final suffix =
        day >= 11 && day <= 13
            ? 'th'
            : switch (day % 10) {
              1 => 'st',
              2 => 'nd',
              3 => 'rd',
              _ => 'th',
            };
    return '$day$suffix ${months[date.month - 1]}';
  }
}

LogSection? _nextUnsavedSection(
  DailyLogScreenState state, {
  LogSection? after,
}) {
  final sections = LogSection.values;
  if (after != null) {
    final currentIndex = sections.indexOf(after);
    for (var offset = 1; offset < sections.length; offset += 1) {
      final section = sections[(currentIndex + offset) % sections.length];
      if (state.isSaved[section] != true) {
        return section;
      }
    }
    return null;
  }

  for (final section in sections) {
    if (state.isSaved[section] != true) {
      return section;
    }
  }
  return null;
}

LogSection? _sectionFromRoute(BuildContext context) {
  final raw =
      GoRouterState.of(context).uri.queryParameters['section']?.toLowerCase();
  return switch (raw) {
    'period' => LogSection.period,
    'symptoms' => LogSection.symptoms,
    'temperature' => LogSection.temperature,
    'lh-test' || 'lh_test' || 'lh' => LogSection.lhTest,
    'cervical-mucus' || 'cervical_mucus' || 'mucus' => LogSection.cervicalMucus,
    'intimacy' => LogSection.intimacy,
    _ => null,
  };
}

class _RecentNoteEntry {
  const _RecentNoteEntry({
    required this.text,
    required this.source,
    required this.dateLabel,
  });

  final String text;
  final String source;
  final String dateLabel;
}

class _AiLogPalette {
  const _AiLogPalette({
    required this.pageBackground,
    required this.cardBackground,
    required this.subtleCardBackground,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.iconButtonBackground,
    required this.progressTrack,
    required this.unselectedRing,
    required this.inputBackground,
    required this.activeChipBackground,
  });

  final Color pageBackground;
  final Color cardBackground;
  final Color subtleCardBackground;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color iconButtonBackground;
  final Color progressTrack;
  final Color unselectedRing;
  final Color inputBackground;
  final Color activeChipBackground;

  static _AiLogPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _AiLogPalette(
        pageBackground: Color(0xFF121216),
        cardBackground: Color(0xFF1B1C22),
        subtleCardBackground: Color(0xFF22232B),
        border: Color(0xFF2E303A),
        primaryText: Color(0xFFF7EFEA),
        secondaryText: Color(0xFFD2C0B6),
        tertiaryText: Color(0xFF9B8A83),
        iconButtonBackground: Color(0xFF121216),
        progressTrack: Color(0xFF343641),
        unselectedRing: Color(0xFF4A4D58),
        inputBackground: Color(0xFF1A1B21),
        activeChipBackground: Color(0xFF2A2421),
      );
    }
    return const _AiLogPalette(
      pageBackground: Color(0xFFFFFBF7),
      cardBackground: Colors.white,
      subtleCardBackground: Color(0xFFFFFBF8),
      border: Color(0xFFF0E4DC),
      primaryText: Color(0xFF231410),
      secondaryText: Color(0xFF745447),
      tertiaryText: Color(0xFFC0AAA0),
      iconButtonBackground: Color(0xFFFFFBF7),
      progressTrack: Color(0xFFF2E8E2),
      unselectedRing: Color(0xFFE4D4CB),
      inputBackground: Color(0xFFFFFCFA),
      activeChipBackground: Color(0xFFFFF1E8),
    );
  }
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        "Today's log",
        style: AppTheme.screenHeaderStyle(
          context,
          dims,
          color: palette.primaryText,
        ),
      ),
    );
  }
}

class _IntroHero extends ConsumerWidget {
  const _IntroHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    final fullName =
        ref.watch(currentUserProfileProvider).valueOrNull?.fullName;
    final firstName = fullName?.trim().split(RegExp(r'\s+')).first;
    final greetingName =
        (firstName?.isNotEmpty ?? false) ? firstName! : 'there';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: dims.scaleSpace(10)),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: dims.scaleText(28),
              height: 1.05,
              fontWeight: FontWeight.w500,
              fontFamily: 'Georgia',
              color: palette.primaryText,
              letterSpacing: -0.8,
            ),
            children: [
              TextSpan(text: 'Hi $greetingName'),
              TextSpan(
                text: ' 👋',
                style: TextStyle(
                  fontSize: dims.scaleText(20),
                  fontFamily: null,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: dims.scaleSpace(10)),
        SizedBox(
          width: dims.scaleWidth(220),
          child: Text(
            'I\'ll help you log everything\ntoday in a simple, natural way.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: dims.scaleText(12.5),
              height: 1.5,
              color: palette.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.state,
    required this.activeSection,
    required this.onSelect,
  });

  final DailyLogScreenState state;
  final LogSection? activeSection;
  final ValueChanged<LogSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    final completed =
        LogSection.values.where((section) => _isSaved(section, state)).length;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: dims.scaleText(13.5),
              fontWeight: FontWeight.w700,
              color: palette.primaryText,
            ),
          ),
          SizedBox(height: dims.scaleSpace(6)),
          Text(
            '$completed of 6 sections logged',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(11.25),
              color: palette.secondaryText,
            ),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          ClipRRect(
            borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            child: LinearProgressIndicator(
              value: completed / 6,
              minHeight: 5,
              backgroundColor: palette.progressTrack,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF7647)),
            ),
          ),
          SizedBox(height: dims.scaleSpace(14)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProgressItem(
                label: 'Period',
                icon: Icons.water_drop_outlined,
                completed: _isSaved(LogSection.period, state),
                active: activeSection == LogSection.period,
                onTap: () => onSelect(LogSection.period),
              ),
              _ProgressItem(
                label: 'Symptoms',
                icon: Icons.favorite_border_rounded,
                completed: _isSaved(LogSection.symptoms, state),
                active: activeSection == LogSection.symptoms,
                onTap: () => onSelect(LogSection.symptoms),
              ),
              _ProgressItem(
                label: 'Temp',
                icon: Icons.device_thermostat_rounded,
                completed: _isSaved(LogSection.temperature, state),
                active: activeSection == LogSection.temperature,
                onTap: () => onSelect(LogSection.temperature),
              ),
              _ProgressItem(
                label: 'LH Test',
                icon: Icons.science_outlined,
                completed: _isSaved(LogSection.lhTest, state),
                active: activeSection == LogSection.lhTest,
                onTap: () => onSelect(LogSection.lhTest),
              ),
              _ProgressItem(
                label: 'Mucus',
                icon: Icons.opacity_outlined,
                completed: _isSaved(LogSection.cervicalMucus, state),
                active: activeSection == LogSection.cervicalMucus,
                onTap: () => onSelect(LogSection.cervicalMucus),
              ),
              _ProgressItem(
                label: 'Intimacy',
                icon: Icons.favorite_outline_rounded,
                completed: _isSaved(LogSection.intimacy, state),
                active: activeSection == LogSection.intimacy,
                onTap: () => onSelect(LogSection.intimacy),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSaved(LogSection section, DailyLogScreenState state) {
    return state.isSaved[section] == true ||
        state.isDirty[section] == false &&
            switch (section) {
              LogSection.period => state.draft.period?.hasData ?? false,
              LogSection.symptoms => state.draft.symptoms?.hasData ?? false,
              LogSection.temperature =>
                state.draft.temperature?.hasData ?? false,
              LogSection.lhTest => state.draft.lhTest?.hasData ?? false,
              LogSection.cervicalMucus =>
                state.draft.cervicalMucus?.hasData ?? false,
              LogSection.intimacy => state.draft.intimacy?.hasData ?? false,
            };
  }
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({
    required this.label,
    required this.icon,
    required this.completed,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool completed;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        child: Column(
          children: [
            Container(
              width: dims.scaleWidth(32),
              height: dims.scaleWidth(32),
              decoration: BoxDecoration(
                color:
                    completed || active
                        ? palette.activeChipBackground
                        : palette.subtleCardBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      active
                          ? const Color(0xFFFF7647)
                          : completed
                          ? const Color(0xFFFFD7C5)
                          : palette.border,
                ),
              ),
              child: Icon(
                icon,
                size: dims.scaleText(16),
                color:
                    completed || active
                        ? const Color(0xFFFF6A3D)
                        : palette.secondaryText,
              ),
            ),
            SizedBox(height: dims.scaleSpace(6)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: dims.scaleText(9.2),
                color: palette.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.section,
    required this.state,
    required this.inferredPeriodStartDate,
    required this.inferredPeriodEndDate,
    required this.symptomsNotesController,
    required this.mucusNotesController,
    required this.intimacyNotesController,
    required this.onClose,
    required this.onPeriodChanged,
    required this.onSymptomsChanged,
    required this.onTemperatureChanged,
    required this.onLhChanged,
    required this.onMucusChanged,
    required this.onIntimacyChanged,
    required this.onSave,
  });

  final LogSection section;
  final DailyLogScreenState state;
  final DateTime inferredPeriodStartDate;
  final DateTime inferredPeriodEndDate;
  final TextEditingController symptomsNotesController;
  final TextEditingController mucusNotesController;
  final TextEditingController intimacyNotesController;
  final VoidCallback onClose;
  final ValueChanged<PeriodLogDraft> onPeriodChanged;
  final ValueChanged<SymptomsLogDraft> onSymptomsChanged;
  final ValueChanged<TemperatureLogDraft> onTemperatureChanged;
  final ValueChanged<LhTestLogDraft> onLhChanged;
  final ValueChanged<CervicalMucusLogDraft> onMucusChanged;
  final ValueChanged<IntimacyLogDraft> onIntimacyChanged;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    final isSaving = state.isSaving[section] == true;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _title(section),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: dims.scaleText(18),
                    fontWeight: FontWeight.w700,
                    color: palette.primaryText,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(14)),
          _body(context),
          SizedBox(height: dims.scaleSpace(18)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : onSave,
              child: Text(isSaving ? 'Saving...' : 'Save ${_title(section)}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    return switch (section) {
      LogSection.period => _PeriodQuestions(
        draft: state.draft.period ?? const PeriodLogDraft(),
        inferredStartDate: inferredPeriodStartDate,
        inferredEndDate: inferredPeriodEndDate,
        onChanged: onPeriodChanged,
      ),
      LogSection.symptoms => _SymptomsQuestions(
        draft: state.draft.symptoms ?? const SymptomsLogDraft(),
        notesController: symptomsNotesController,
        onChanged: onSymptomsChanged,
      ),
      LogSection.temperature => _TemperatureQuestions(
        draft: state.draft.temperature ?? const TemperatureLogDraft(),
        onChanged: onTemperatureChanged,
      ),
      LogSection.lhTest => _LhQuestions(
        draft: state.draft.lhTest ?? const LhTestLogDraft(),
        onChanged: onLhChanged,
      ),
      LogSection.cervicalMucus => _MucusQuestions(
        draft: state.draft.cervicalMucus ?? const CervicalMucusLogDraft(),
        notesController: mucusNotesController,
        onChanged: onMucusChanged,
      ),
      LogSection.intimacy => _IntimacyQuestions(
        draft: state.draft.intimacy ?? const IntimacyLogDraft(),
        notesController: intimacyNotesController,
        onChanged: onIntimacyChanged,
      ),
    };
  }

  String _title(LogSection section) {
    return switch (section) {
      LogSection.period => 'Period',
      LogSection.symptoms => 'Symptoms',
      LogSection.temperature => 'Temperature',
      LogSection.lhTest => 'LH Test',
      LogSection.cervicalMucus => 'Cervical Mucus',
      LogSection.intimacy => 'Intimacy',
    };
  }
}

class _QuestionBlock extends StatelessWidget {
  const _QuestionBlock({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: dims.scaleSpace(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    fontWeight: FontWeight.w700,
                    color: palette.primaryText,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: dims.scaleSpace(10)),
          child,
        ],
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    return Wrap(
      spacing: dims.scaleWidth(8),
      runSpacing: dims.scaleSpace(8),
      children:
          options.map((value) {
            final isSelected = value == selected;
            return InkWell(
              onTap: () => onSelected(value),
              borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(14),
                  vertical: dims.scaleSpace(12),
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? palette.activeChipBackground
                          : palette.subtleCardBackground,
                  borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
                  border: Border.all(
                    color:
                        isSelected ? const Color(0xFFFF7647) : palette.border,
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color:
                        isSelected
                            ? const Color(0xFFFF6A3D)
                            : palette.primaryText,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

class _MultiChoiceWrap extends StatelessWidget {
  const _MultiChoiceWrap({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.dims.scaleWidth(8),
      runSpacing: context.dims.scaleSpace(8),
      children:
          options
              .map(
                (value) => _ChoiceWrap(
                  options: [value],
                  selected: selected.contains(value) ? value : null,
                  onSelected: (_) => onToggle(value),
                ),
              )
              .toList(),
    );
  }
}

class _PeriodQuestions extends StatelessWidget {
  const _PeriodQuestions({
    required this.draft,
    required this.inferredStartDate,
    required this.inferredEndDate,
    required this.onChanged,
  });

  final PeriodLogDraft draft;
  final DateTime inferredStartDate;
  final DateTime inferredEndDate;
  final ValueChanged<PeriodLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveStartDate = draft.startDate ?? inferredStartDate;
    final effectiveEndDate = draft.endDate ?? inferredEndDate;
    return Column(
      children: [
        _QuestionBlock(
          title: 'What is your flow intensity today?',
          child: _ChoiceWrap(
            options: const ['Spotting', 'Light', 'Medium', 'Heavy'],
            selected: draft.intensity,
            onSelected:
                (value) => onChanged(
                  draft.copyWith(
                    startDate: effectiveStartDate,
                    endDate: effectiveEndDate,
                    intensity: value,
                  ),
                ),
          ),
        ),
        _QuestionBlock(
          title: 'What is your flow colour?',
          child: _ChoiceWrap(
            options: const ['Brown', 'Red', 'Dark', 'Pink'],
            selected: draft.colour,
            onSelected:
                (value) => onChanged(
                  draft.copyWith(
                    startDate: effectiveStartDate,
                    endDate: effectiveEndDate,
                    colour: value,
                  ),
                ),
          ),
        ),
        _QuestionBlock(
          title: 'Which period symptoms apply?',
          child: _MultiChoiceWrap(
            options: _TodayLogDetailsScreenState._periodSymptoms,
            selected: draft.symptoms.toSet(),
            onToggle: (value) {
              final next = draft.symptoms.toSet();
              if (!next.add(value)) {
                next.remove(value);
              }
              onChanged(
                draft.copyWith(
                  startDate: effectiveStartDate,
                  endDate: effectiveEndDate,
                  symptoms: next.toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeriodRangeQuestion extends StatelessWidget {
  const _PeriodRangeQuestion({
    required this.logDate,
    required this.startDate,
    required this.endDate,
    required this.periodDay,
    required this.currentCycleDay,
    required this.onRangeChanged,
  });

  final DateTime logDate;
  final DateTime startDate;
  final DateTime endDate;
  final int periodDay;
  final int? currentCycleDay;
  final ValueChanged<DateTimeRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(
      endDate.isBefore(normalizedStart) ? normalizedStart : endDate,
    );
    final titleDate = _ordinalDay(normalizedStart);

    return _QuestionBlock(
      title: 'Period started $titleDate?',
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: () async {
          final earliest = logDate.subtract(const Duration(days: 14));
          final latest = logDate.add(const Duration(days: 14));
          final initialStart =
              normalizedStart.isAfter(latest) ? logDate : normalizedStart;
          final initialEnd =
              normalizedEnd.isBefore(initialStart)
                  ? initialStart
                  : normalizedEnd;
          final picked = await showDateRangePicker(
            context: context,
            initialDateRange: DateTimeRange(
              start: initialStart,
              end: initialEnd.isAfter(latest) ? latest : initialEnd,
            ),
            firstDate:
                initialStart.isBefore(earliest) ? initialStart : earliest,
            lastDate: latest,
            helpText: 'Select period range',
            saveText: 'Done',
          );
          if (picked != null) {
            onRangeChanged(
              DateTimeRange(
                start: _dateOnly(picked.start),
                end: _dateOnly(picked.end),
              ),
            );
          }
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(dims.scaleWidth(14)),
          decoration: BoxDecoration(
            color: palette.subtleCardBackground,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: palette.primaryText),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _periodRangeLabel(normalizedStart, normalizedEnd),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.primaryText,
                        fontSize: dims.scaleText(14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(4)),
                    Text(
                      'Change if not',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFFF6A3D),
                        fontSize: dims.scaleText(11.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(4)),
                    Text(
                      [
                        'Logging period day ${periodDay.clamp(1, 99)}',
                        if (currentCycleDay != null)
                          'Cycle Day ${currentCycleDay!.clamp(1, 999)}',
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.secondaryText,
                        fontSize: dims.scaleText(12),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar_rounded, color: palette.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomsQuestions extends StatelessWidget {
  const _SymptomsQuestions({
    required this.draft,
    required this.notesController,
    required this.onChanged,
  });

  final SymptomsLogDraft draft;
  final TextEditingController notesController;
  final ValueChanged<SymptomsLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuestionBlock(
          title: 'How is your mood?',
          child: _ChoiceWrap(
            options: const ['Happy', 'Calm', 'Sad', 'Anxious', 'Irritable'],
            selected: draft.mood,
            onSelected: (value) => onChanged(draft.copyWith(mood: value)),
          ),
        ),
        _QuestionBlock(
          title: 'Which physical symptoms are you feeling?',
          child: _MultiChoiceWrap(
            options: _TodayLogDetailsScreenState._physicalSymptoms,
            selected: draft.physical.toSet(),
            onToggle: (value) {
              final next = draft.physical.toSet();
              if (!next.add(value)) {
                next.remove(value);
              }
              onChanged(draft.copyWith(physical: next.toList()));
            },
          ),
        ),
        _QuestionBlock(
          title: 'Energy level',
          trailing: Text('${draft.energyLevel ?? 5}/10'),
          child: Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: (draft.energyLevel ?? 5).toDouble(),
            onChanged:
                (value) =>
                    onChanged(draft.copyWith(energyLevel: value.round())),
          ),
        ),
        _QuestionBlock(
          title: 'Pain level',
          trailing: Text('${draft.painLevel ?? 5}/10'),
          child: Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: (draft.painLevel ?? 5).toDouble(),
            onChanged:
                (value) => onChanged(draft.copyWith(painLevel: value.round())),
          ),
        ),
        _QuestionBlock(
          title: 'Sleep quality',
          child: _ChoiceWrap(
            options: const ['Poor', 'Fair', 'Good', 'Great'],
            selected: draft.sleepQuality,
            onSelected:
                (value) => onChanged(draft.copyWith(sleepQuality: value)),
          ),
        ),
        _QuestionBlock(
          title: 'Add a note',
          child: _NotesField(
            controller: notesController,
            onChanged: (value) => onChanged(draft.copyWith(notes: value)),
          ),
        ),
      ],
    );
  }
}

class _TemperatureQuestions extends StatelessWidget {
  const _TemperatureQuestions({required this.draft, required this.onChanged});

  final TemperatureLogDraft draft;
  final ValueChanged<TemperatureLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = _AiLogPalette.of(context);
    return Column(
      children: [
        _QuestionBlock(
          title: 'What is your temperature?',
          child: TextFormField(
            initialValue:
                draft.temperatureCelsius == null
                    ? ''
                    : draft.temperatureCelsius!.toStringAsFixed(1),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: palette.primaryText),
            decoration: InputDecoration(
              hintText: '36.7',
              suffixText: '°${draft.displayUnit}',
            ),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed == null) return;
              onChanged(draft.copyWith(temperatureCelsius: parsed));
            },
          ),
        ),
        _QuestionBlock(
          title: 'Measurement unit',
          child: _ChoiceWrap(
            options: const ['C', 'F'],
            selected: draft.displayUnit,
            onSelected:
                (value) => onChanged(draft.copyWith(displayUnit: value)),
          ),
        ),
        _QuestionBlock(
          title: 'What time did you measure it?',
          child: _TimePickerButton(
            value: draft.measuredAt,
            onSelected: (value) => onChanged(draft.copyWith(measuredAt: value)),
          ),
        ),
        _QuestionBlock(
          title: 'Quality checks',
          child: Column(
            children: [
              _ToggleTile(
                label: 'Same time as yesterday',
                value: draft.sameTimeAsYesterday,
                onChanged:
                    (value) =>
                        onChanged(draft.copyWith(sameTimeAsYesterday: value)),
              ),
              _ToggleTile(
                label: 'Uninterrupted sleep',
                value: draft.uninterruptedSleep,
                onChanged:
                    (value) =>
                        onChanged(draft.copyWith(uninterruptedSleep: value)),
              ),
              _ToggleTile(
                label: 'Measured before getting up',
                value: draft.measuredBeforeGettingUp,
                onChanged:
                    (value) => onChanged(
                      draft.copyWith(measuredBeforeGettingUp: value),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LhQuestions extends StatelessWidget {
  const _LhQuestions({required this.draft, required this.onChanged});

  final LhTestLogDraft draft;
  final ValueChanged<LhTestLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuestionBlock(
          title: 'What was your LH test result?',
          child: _ChoiceWrap(
            options: const ['negative', 'low', 'high', 'peak'],
            selected: draft.result,
            onSelected:
                (value) =>
                    onChanged(draft.copyWith(result: value, method: 'manual')),
          ),
        ),
        _QuestionBlock(
          title: 'What time did you take the test?',
          child: _TimePickerButton(
            value: draft.testedAt,
            onSelected: (value) => onChanged(draft.copyWith(testedAt: value)),
          ),
        ),
      ],
    );
  }
}

class _MucusQuestions extends StatelessWidget {
  const _MucusQuestions({
    required this.draft,
    required this.notesController,
    required this.onChanged,
  });

  final CervicalMucusLogDraft draft;
  final TextEditingController notesController;
  final ValueChanged<CervicalMucusLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuestionBlock(
          title: 'What type of cervical mucus do you notice?',
          child: _ChoiceWrap(
            options: const [
              'Dry/None',
              'Sticky',
              'Creamy',
              'Egg White (Fertile)',
              'Watery',
            ],
            selected: draft.type,
            onSelected: (value) => onChanged(draft.copyWith(type: value)),
          ),
        ),
        _QuestionBlock(
          title: 'How much is there?',
          child: _ChoiceWrap(
            options: const ['Light', 'Moderate', 'Heavy'],
            selected: draft.amount,
            onSelected: (value) => onChanged(draft.copyWith(amount: value)),
          ),
        ),
        _QuestionBlock(
          title: 'Add a note',
          child: _NotesField(
            controller: notesController,
            onChanged: (value) => onChanged(draft.copyWith(notes: value)),
          ),
        ),
      ],
    );
  }
}

class _IntimacyQuestions extends StatelessWidget {
  const _IntimacyQuestions({
    required this.draft,
    required this.notesController,
    required this.onChanged,
  });

  final IntimacyLogDraft draft;
  final TextEditingController notesController;
  final ValueChanged<IntimacyLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuestionBlock(
          title: 'What kind of intimacy did you log?',
          child: _ChoiceWrap(
            options: const [
              'Unprotected',
              'Protected',
              'Birth Control',
              'Other',
            ],
            selected: draft.activity,
            onSelected: (value) => onChanged(draft.copyWith(activity: value)),
          ),
        ),
        _QuestionBlock(
          title: 'Any additional details?',
          child: _MultiChoiceWrap(
            options: const ['Orgasm', 'Painful', 'Dry', 'Bleeding'],
            selected: draft.details.toSet(),
            onToggle: (value) {
              final next = draft.details.toSet();
              if (!next.add(value)) {
                next.remove(value);
              }
              onChanged(draft.copyWith(details: next.toList()));
            },
          ),
        ),
        _QuestionBlock(
          title: 'What time was it?',
          child: _TimePickerButton(
            value: draft.time,
            onSelected: (value) => onChanged(draft.copyWith(time: value)),
          ),
        ),
        _QuestionBlock(
          title: 'Add a note',
          child: _NotesField(
            controller: notesController,
            onChanged: (value) => onChanged(draft.copyWith(notes: value)),
          ),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = _AiLogPalette.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: palette.primaryText)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({required this.value, required this.onSelected});

  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onSelected;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    return OutlinedButton(
      onPressed: () async {
        final selected = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (selected != null) {
          onSelected(selected);
        }
      },
      style: OutlinedButton.styleFrom(
        minimumSize: Size(double.infinity, dims.scaleHeight(48)),
        alignment: Alignment.centerLeft,
        side: BorderSide(color: palette.border),
      ),
      child: Text(value == null ? 'Select time' : value!.format(context)),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = _AiLogPalette.of(context);
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 4,
      style: TextStyle(color: palette.primaryText),
      decoration: const InputDecoration(hintText: 'Add an optional note'),
      onChanged: onChanged,
    );
  }
}

class _RecentNoteCard extends StatelessWidget {
  const _RecentNoteCard({required this.notes});

  final List<_RecentNoteEntry> notes;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final palette = _AiLogPalette.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent note',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(13.5),
                  fontWeight: FontWeight.w700,
                  color: palette.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(10)),
          if (notes.isEmpty)
            Text(
              'No recent notes yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(12.6),
                color: palette.primaryText,
                height: 1.45,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  notes.map((note) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: dims.scaleSpace(10)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '"${note.text}"',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                fontSize: dims.scaleText(12.6),
                                color: palette.primaryText,
                                height: 1.45,
                              ),
                            ),
                          ),
                          SizedBox(width: dims.scaleWidth(10)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: dims.scaleWidth(10),
                              vertical: dims.scaleSpace(6),
                            ),
                            decoration: BoxDecoration(
                              color: palette.activeChipBackground,
                              borderRadius: BorderRadius.circular(
                                dims.scaleRadius(999),
                              ),
                              border: Border.all(color: palette.border),
                            ),
                            child: Text(
                              '${note.dateLabel} ${note.source}',
                              textAlign: TextAlign.right,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                fontSize: dims.scaleText(10.8),
                                color: palette.secondaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(dims.scaleWidth(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 36),
            SizedBox(height: dims.scaleSpace(12)),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: dims.scaleSpace(16)),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _periodRangeLabel(DateTime start, DateTime? end) {
  if (end == null || _isSameDay(start, end)) {
    return 'Started ${_monthDay(start)}';
  }
  return '${_monthDay(start)} - ${_monthDay(end)}';
}

DateTime _estimatedPeriodEndDate({
  required DateTime startDate,
  required int? periodLengthDays,
}) {
  return _dateOnly(
    startDate.add(Duration(days: (periodLengthDays ?? 5).clamp(1, 14) - 1)),
  );
}

DateTimeRange? _calendarPeriodRangeForMonth({
  required DateTime logDate,
  required List<dynamic> periodRanges,
  required DateTime? calendarStartDate,
  required int? cycleLengthDays,
  required int? periodLengthDays,
}) {
  final loggedRange = _periodRangeInSameMonth(
    logDate: logDate,
    periodRanges: periodRanges,
  );
  if (calendarStartDate == null) {
    return loggedRange;
  }

  final monthStart = DateTime(logDate.year, logDate.month);
  final monthEnd = DateTime(logDate.year, logDate.month + 1, 0);
  final cycleLength = (cycleLengthDays ?? 28).clamp(21, 45);
  final periodLength = (periodLengthDays ?? 5).clamp(1, 14);
  var start = _dateOnly(calendarStartDate);

  while (start.isAfter(monthEnd)) {
    start = start.subtract(Duration(days: cycleLength));
  }
  while (start.add(Duration(days: cycleLength)).isBefore(monthStart)) {
    start = start.add(Duration(days: cycleLength));
  }
  if (start.month != logDate.month || start.year != logDate.year) {
    final nextStart = start.add(Duration(days: cycleLength));
    if (nextStart.month == logDate.month && nextStart.year == logDate.year) {
      start = nextStart;
    }
  }
  if (start.month != logDate.month || start.year != logDate.year) {
    return loggedRange;
  }

  final predictedRange = DateTimeRange(
    start: start,
    end: start.add(Duration(days: periodLength - 1)),
  );
  if (loggedRange == null) {
    return predictedRange;
  }
  final loggedRangeDays =
      _dateOnly(
        loggedRange.end,
      ).difference(_dateOnly(loggedRange.start)).inDays +
      1;
  if (loggedRangeDays <= 1 &&
      _rangeContains(predictedRange, _dateOnly(logDate))) {
    return predictedRange;
  }
  return loggedRange;
}

bool _rangeContains(DateTimeRange range, DateTime date) {
  final key = _dateOnly(date);
  return !key.isBefore(_dateOnly(range.start)) &&
      !key.isAfter(_dateOnly(range.end));
}

DateTimeRange? _periodRangeInSameMonth({
  required DateTime logDate,
  required List<dynamic> periodRanges,
}) {
  for (final range in periodRanges.reversed) {
    final startDate = range.startDate;
    final endDate = range.endDate;
    if (startDate is! DateTime) {
      continue;
    }
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd =
        endDate is DateTime ? _dateOnly(endDate) : normalizedStart;
    final startsInMonth =
        normalizedStart.year == logDate.year &&
        normalizedStart.month == logDate.month;
    final endsInMonth =
        normalizedEnd.year == logDate.year &&
        normalizedEnd.month == logDate.month;
    if (startsInMonth || endsInMonth) {
      return DateTimeRange(start: normalizedStart, end: normalizedEnd);
    }
  }
  return null;
}

DateTime? _currentCycleStartDateFromPrediction(int? cycleDay) {
  if (cycleDay == null || cycleDay < 1) {
    return null;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: cycleDay - 1));
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _ordinalDay(DateTime value) {
  final day = value.day;
  final suffix =
      day >= 11 && day <= 13
          ? 'th'
          : switch (day % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
  return '$day$suffix';
}

String _monthDay(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}';
}

DateTime _inferredPeriodStartDate({
  required DateTime logDate,
  required List<dynamic> periodRanges,
  required int? currentCycleDay,
  required int? periodLengthDays,
}) {
  final currentMonthStartDate = _periodStartInSameMonth(
    logDate: logDate,
    periodRanges: periodRanges,
  );
  if (currentMonthStartDate != null) {
    return currentMonthStartDate;
  }

  for (final range in periodRanges.reversed) {
    if (range.contains(logDate) == true) {
      final startDate = range.startDate;
      if (startDate is DateTime) {
        return DateTime(startDate.year, startDate.month, startDate.day);
      }
    }
  }
  final expectedPeriodLength = (periodLengthDays ?? 7).clamp(1, 14);
  if (currentCycleDay != null &&
      currentCycleDay > 0 &&
      currentCycleDay <= expectedPeriodLength) {
    return logDate.subtract(Duration(days: currentCycleDay - 1));
  }
  return logDate;
}

DateTime? _periodStartInSameMonth({
  required DateTime logDate,
  required List<dynamic> periodRanges,
}) {
  for (final range in periodRanges.reversed) {
    final startDate = range.startDate;
    final endDate = range.endDate;
    if (startDate is! DateTime) {
      continue;
    }
    final startsInMonth =
        startDate.year == logDate.year && startDate.month == logDate.month;
    final endsInMonth =
        endDate is DateTime &&
        endDate.year == logDate.year &&
        endDate.month == logDate.month;
    if (startsInMonth || endsInMonth) {
      return DateTime(startDate.year, startDate.month, startDate.day);
    }
  }
  return null;
}

int? _cycleDayForLogDate({
  required DateTime logDate,
  required int? currentCycleDay,
}) {
  if (currentCycleDay == null || currentCycleDay <= 0) {
    return null;
  }
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  return (currentCycleDay + logDate.difference(todayOnly).inDays).clamp(1, 999);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
