import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/i18n/formatters.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/design_tokens.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/features/insights/domain/cycle_stats.dart';
import 'package:phora/features/insights/insights_providers.dart';
import 'package:phora/features/log/daily_log_models.dart';
import 'package:phora/features/log/daily_log_repository.dart';
import 'package:phora/features/predictions/domain/prediction_models.dart';
import 'package:phora/features/predictions/prediction_providers.dart';

class CycleScreen extends ConsumerStatefulWidget {
  const CycleScreen({super.key});

  @override
  ConsumerState<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends ConsumerState<CycleScreen> {
  static const int _visiblePredictionMonthCount = 6;
  static const int _predictionMonthsAhead = 6;

  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _showSelectedDaySheet({
    required DateTime selectedDate,
    required List<PredictionCalendarDay> predictionDays,
    required CurrentPrediction? currentPrediction,
    required DateTime? calendarStartDate,
  }) async {
    final dims = context.dims;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(16),
              dims.scaleSpace(12),
              dims.scaleWidth(16),
              dims.scaleSpace(10),
            ),
            child: _SelectedDaySheet(
              selectedDate: selectedDate,
              predictionDays: predictionDays,
              currentPrediction: currentPrediction,
              calendarStartDate: calendarStartDate,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final calendarDays =
        ref.watch(predictionCalendarProvider).valueOrNull ?? const [];
    final currentPrediction = ref.watch(currentPredictionProvider).valueOrNull;
    final cycleStats = ref.watch(cycleStatsProvider).valueOrNull;
    final calendarStartDate = _calendarHistoryStartDate(
      currentPrediction: currentPrediction,
      cycleStats: cycleStats,
    );
    final visibleMonths = _visibleMonths(
      visibleMonth: _visibleMonth,
      calendarStartDate: calendarStartDate,
      monthCount: _visiblePredictionMonthCount,
      monthsAhead: _predictionMonthsAhead,
    );
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: ColoredBox(
        color: isDark ? colors.bg : const Color(0xFFFFFBF7),
        child: SafeArea(
          child: Column(
            children: [
              _CalendarHeader(
                visibleMonth: _visibleMonth,
                calendarStartDate: calendarStartDate,
                monthsAhead: _predictionMonthsAhead,
                onMonthSelected: (month) {
                  setState(() {
                    _visibleMonth = month;
                    _selectedDate = DateTime(month.year, month.month, 1);
                  });
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(24),
                    dims.scaleSpace(10),
                    dims.scaleWidth(24),
                    dims.scaleSpace(28),
                  ),
                  child: Column(
                    children: [
                      const _PhaseLegendCard(),
                      SizedBox(height: dims.scaleSpace(16)),
                      for (final month in visibleMonths) ...[
                        _MonthStackCard(
                          visibleMonth: month,
                          selectedDate: _selectedDate,
                          predictionDays: calendarDays,
                          currentPrediction: currentPrediction,
                          calendarStartDate: calendarStartDate,
                          periodRanges: cycleStats?.periodRanges ?? const [],
                          onSelectDay: (day) async {
                            setState(() {
                              _selectedDate = DateTime(
                                day.year,
                                day.month,
                                day.day,
                              );
                            });
                            await _showSelectedDaySheet(
                              selectedDate: day,
                              predictionDays: calendarDays,
                              currentPrediction: currentPrediction,
                              calendarStartDate: calendarStartDate,
                            );
                          },
                        ),
                        SizedBox(height: dims.scaleSpace(14)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.visibleMonth,
    required this.calendarStartDate,
    required this.monthsAhead,
    required this.onMonthSelected,
  });

  final DateTime visibleMonth;
  final DateTime? calendarStartDate;
  final int monthsAhead;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthChoices = _monthChoices(
      visibleMonth: visibleMonth,
      calendarStartDate: calendarStartDate,
      monthsAhead: monthsAhead,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(24),
        dims.scaleSpace(16),
        dims.scaleWidth(24),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: dims.scaleHeight(54),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Calendar',
                style: AppTheme.screenHeaderStyle(
                  context,
                  dims,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          PopupMenuButton<DateTime>(
            initialValue:
                monthChoices.any((month) => _isSameMonth(month, visibleMonth))
                    ? visibleMonth
                    : null,
            color: isDark ? colors.bgCard : Colors.white,
            surfaceTintColor: Colors.transparent,
            shadowColor: isDark ? Colors.black54 : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
              side: BorderSide(color: colors.border),
            ),
            onSelected: onMonthSelected,
            itemBuilder: (context) {
              return monthChoices.map((month) {
                return PopupMenuItem(
                  value: month,
                  child: Text(
                    _monthYearLabel(context, month),
                    style: TextStyle(color: colors.textPrimary),
                  ),
                );
              }).toList();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _monthYearLabel(context, visibleMonth),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: AppTheme.headingFontFamily,
                    color: colors.textPrimary,
                    fontSize: dims.scaleText(16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: dims.scaleWidth(8)),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.textPrimary,
                  size: dims.scaleText(26),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseLegendCard extends StatelessWidget {
  const _PhaseLegendCard();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return _CalendarCard(
      radius: 10,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(12),
        vertical: dims.scaleSpace(11),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _LegendItem(
            icon: Icons.water_drop_rounded,
            label: 'Menstrual',
            color: Color(0xFFFF5E68),
          ),
          _LegendItem(
            icon: Icons.circle,
            label: 'Follicular',
            color: Color(0xFF7DD6A5),
          ),
          _LegendItem(
            icon: Icons.wb_sunny_rounded,
            label: 'Ovulation',
            color: Color(0xFF1E9AF0),
          ),
          _LegendItem(
            icon: Icons.circle,
            label: 'Luteal',
            color: Color(0xFFC78ADD),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: dims.scaleText(16)),
          SizedBox(width: dims.scaleWidth(6)),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                fontSize: dims.scaleText(12.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthStackCard extends StatelessWidget {
  const _MonthStackCard({
    required this.visibleMonth,
    required this.selectedDate,
    required this.predictionDays,
    required this.currentPrediction,
    required this.calendarStartDate,
    required this.periodRanges,
    required this.onSelectDay,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<PredictionCalendarDay> predictionDays;
  final CurrentPrediction? currentPrediction;
  final DateTime? calendarStartDate;
  final List<CyclePeriodRange> periodRanges;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = _buildMonthCells(
      visibleMonth: visibleMonth,
      selectedDate: selectedDate,
      predictionDays: predictionDays,
      currentPrediction: currentPrediction,
      calendarStartDate: calendarStartDate,
      periodRanges: periodRanges,
      currentMonthTextColor: colors.textPrimary,
      inactiveTextColor: colors.textTertiary,
      colors: colors,
      isDark: isDark,
    );

    return _CalendarCard(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(18),
        dims.scaleWidth(16),
        dims.scaleSpace(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthYearLabel(context, visibleMonth),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: AppTheme.headingFontFamily,
                    color: colors.textPrimary,
                    fontSize: dims.scaleText(16),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Cycle Day 1 - ${DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontSize: dims.scaleText(12.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(16)),
          Row(
            children:
                _weekdayLabels.map((label) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(
                          color: colors.textSecondary,
                          fontSize: dims.scaleText(10.8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: dims.scaleWidth(7),
              mainAxisSpacing: dims.scaleSpace(7),
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              return _CalendarDayCell(
                day: day,
                onTap: day.isEnabled ? () => onSelectDay(day.date) : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.day, required this.onTap});

  final _CalendarVisualDay day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final circleSize = dims.scaleWidth(34);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: day.backgroundColor,
              border:
                  day.isSelected
                      ? Border.all(
                        color: colors.accentPrimary,
                        width: 2.5,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      )
                      : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.date.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: day.textColor,
                fontSize: dims.scaleText(12.5),
                fontWeight:
                    day.isCurrentMonth ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          if (day.isOvulation)
            Positioned(
              bottom: -dims.scaleSpace(3),
              child: Icon(
                Icons.wb_sunny_rounded,
                color: colors.phaseOvulatory,
                size: dims.scaleText(16),
              ),
            ),
          if (day.hasMenstrualDrop)
            Positioned(
              bottom: -dims.scaleSpace(9),
              child: Icon(
                Icons.water_drop_rounded,
                color: colors.phaseMenstrual,
                size: dims.scaleText(16),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedDaySheet extends ConsumerWidget {
  const _SelectedDaySheet({
    required this.selectedDate,
    required this.predictionDays,
    required this.currentPrediction,
    required this.calendarStartDate,
  });

  final DateTime selectedDate;
  final List<PredictionCalendarDay> predictionDays;
  final CurrentPrediction? currentPrediction;
  final DateTime? calendarStartDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final session = ref.watch(authSessionProvider).valueOrNull;
    final logFuture =
        session == null || !session.isAuthenticated
            ? Future<DailyLogDraft?>.value(null)
            : ref
                .read(dailyLogRepositoryProvider)
                .getDailyLog(userId: session.userId, date: selectedDate)
                .then<DailyLogDraft?>((value) => value);

    return _CalendarCard(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(18),
        dims.scaleSpace(18),
        dims.scaleWidth(18),
        dims.scaleSpace(18),
      ),
      child: FutureBuilder<DailyLogDraft?>(
        future: logFuture,
        builder: (context, snapshot) {
          final dailyLog = snapshot.data;
          final details = _buildSelectedDayDetails(
            context: context,
            selectedDate: selectedDate,
            predictionDays: predictionDays,
            currentPrediction: currentPrediction,
            calendarStartDate: calendarStartDate,
            dailyLog: dailyLog,
          );
          final hasLogData = dailyLog != null && _dailyLogHasData(dailyLog);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: dims.scaleWidth(42),
                  height: dims.scaleHeight(4),
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: dims.scaleSpace(16)),
              Text(
                _longDateLabel(context, selectedDate),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: AppTheme.headingFontFamily,
                  color: colors.textPrimary,
                  fontSize: dims.scaleText(16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: dims.scaleSpace(4)),
              Text(
                context.l10n.calendarSelectedDaySummary(
                  details.cycleDay,
                  details.phaseLabel,
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                  fontSize: dims.scaleText(12.5),
                ),
              ),
              SizedBox(height: dims.scaleSpace(18)),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else ...[
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: dims.scaleWidth(12),
                  mainAxisSpacing: dims.scaleSpace(12),
                  childAspectRatio: 1.95,
                  children: [
                    _LoggedDataCard(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      label: context.l10n.calendarMoodLabel,
                      value: details.mood,
                    ),
                    _LoggedDataCard(
                      icon: Icons.healing_rounded,
                      label: context.l10n.calendarSymptomsLabel,
                      value: details.symptoms,
                    ),
                    _LoggedDataCard(
                      icon: Icons.nightlight_round,
                      label: context.l10n.calendarSleepLabel,
                      value: details.sleep,
                    ),
                    _LoggedDataCard(
                      icon: Icons.battery_charging_full_rounded,
                      label: context.l10n.calendarEnergyLabel,
                      value: details.energy,
                    ),
                  ],
                ),
                SizedBox(height: dims.scaleSpace(16)),
                Text(
                  context.l10n.logNotesTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontSize: dims.scaleText(13.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(8)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(dims.scaleWidth(14)),
                  decoration: BoxDecoration(
                    color: colors.bgSurface,
                    borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    details.notes,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      fontSize: dims.scaleText(12.5),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(14)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _openDailyLog(context, selectedDate),
                    child: Text(hasLogData ? 'Update details' : 'Add details'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LoggedDataCard extends StatelessWidget {
  const _LoggedDataCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(dims.scaleWidth(10)),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: dims.scaleWidth(36),
            height: dims.scaleWidth(36),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? colors.accentPrimary.withValues(alpha: 0.16)
                      : const Color(0xFFFFE6D6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF6F61),
              size: dims.scaleText(19),
            ),
          ),
          SizedBox(width: dims.scaleWidth(8)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.textPrimary,
                    fontSize: dims.scaleText(11.8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: dims.scaleText(10.3),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.child, this.padding, this.radius = 18});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(dims.scaleWidth(16)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgCard : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(dims.scaleRadius(radius)),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0xFFE9BBB0).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CalendarVisualDay {
  const _CalendarVisualDay({
    required this.date,
    required this.isCurrentMonth,
    required this.isEnabled,
    required this.backgroundColor,
    required this.textColor,
    required this.isSelected,
    required this.isOvulation,
    required this.hasMenstrualDrop,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isEnabled;
  final Color backgroundColor;
  final Color textColor;
  final bool isSelected;
  final bool isOvulation;
  final bool hasMenstrualDrop;
}

class _SelectedDayDetails {
  const _SelectedDayDetails({
    required this.cycleDay,
    required this.phaseLabel,
    required this.mood,
    required this.symptoms,
    required this.sleep,
    required this.energy,
    required this.notes,
  });

  final int cycleDay;
  final String phaseLabel;
  final String mood;
  final String symptoms;
  final String sleep;
  final String energy;
  final String notes;
}

List<_CalendarVisualDay> _buildMonthCells({
  required DateTime visibleMonth,
  required DateTime selectedDate,
  required List<PredictionCalendarDay> predictionDays,
  required CurrentPrediction? currentPrediction,
  required DateTime? calendarStartDate,
  required List<CyclePeriodRange> periodRanges,
  required Color currentMonthTextColor,
  required Color inactiveTextColor,
  required AppColors colors,
  required bool isDark,
}) {
  final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
  final daysInMonth =
      DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
  final sundayOffset = firstOfMonth.weekday % 7;
  final gridStart = firstOfMonth.subtract(Duration(days: sundayOffset));
  final visibleCellCount = ((sundayOffset + daysInMonth) / 7).ceil() * 7;
  final predictionMap = {
    for (final day in predictionDays)
      DateTime(day.date.year, day.date.month, day.date.day): day,
  };

  return List.generate(visibleCellCount, (index) {
    final date = gridStart.add(Duration(days: index));
    final key = DateTime(date.year, date.month, date.day);
    final prediction = predictionMap[key];
    final isCurrentMonth = date.month == visibleMonth.month;
    final isBeforeCalendarStart =
        calendarStartDate != null &&
        key.isBefore(
          DateTime(
            calendarStartDate.year,
            calendarStartDate.month,
            calendarStartDate.day,
          ),
        );
    final derivedPhase = _derivedPhaseForDate(
      date: key,
      currentPrediction: currentPrediction,
      calendarStartDate: calendarStartDate,
    );
    final phase =
        isCurrentMonth && !isBeforeCalendarStart
            ? _calendarPhase(prediction, derivedPhase)
            : PredictionPhase.unknown;
    final ovulationDate = currentPrediction?.ovulationDate;
    final isPredictedOvulation =
        ovulationDate != null && _isSameDay(ovulationDate, date);
    final isOvulation =
        prediction?.isOvulation == true ||
        isPredictedOvulation ||
        phase == PredictionPhase.ovulatory;
    final isLoggedPeriodRange = periodRanges.any(
      (range) => range.contains(key),
    );
    final showPeriod =
        prediction?.isPeriod == true ||
        phase == PredictionPhase.menstrual ||
        isLoggedPeriodRange;

    return _CalendarVisualDay(
      date: date,
      isCurrentMonth: isCurrentMonth,
      isEnabled: isCurrentMonth && !isBeforeCalendarStart,
      isSelected: _isSameDay(date, selectedDate),
      isOvulation: isOvulation,
      hasMenstrualDrop: isCurrentMonth && showPeriod,
      backgroundColor:
          isCurrentMonth
              ? _phaseBackground(
                showPeriod ? PredictionPhase.menstrual : phase,
                isOvulation,
                colors,
                isDark,
              )
              : Colors.transparent,
      textColor:
          isCurrentMonth && !isBeforeCalendarStart
              ? currentMonthTextColor
              : inactiveTextColor,
    );
  });
}

PredictionPhase _calendarPhase(
  PredictionCalendarDay? prediction,
  PredictionPhase derivedPhase,
) {
  if (prediction?.isOvulation == true) {
    return PredictionPhase.ovulatory;
  }
  if (prediction?.isPeriod == true) {
    return PredictionPhase.menstrual;
  }
  if (derivedPhase != PredictionPhase.unknown) {
    return derivedPhase;
  }
  return prediction?.phase ?? PredictionPhase.unknown;
}

PredictionPhase _derivedPhaseForDate({
  required DateTime date,
  required CurrentPrediction? currentPrediction,
  required DateTime? calendarStartDate,
}) {
  final cycleStart =
      calendarStartDate ?? _currentCycleStartDate(currentPrediction);
  if (cycleStart == null) {
    return PredictionPhase.unknown;
  }

  final start = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);
  final target = DateTime(date.year, date.month, date.day);
  final daysSinceStart = target.difference(start).inDays;
  if (daysSinceStart < 0) {
    return PredictionPhase.unknown;
  }

  final cycleLength = (currentPrediction?.cycleLength ?? 28).clamp(21, 45);
  final periodLength = (currentPrediction?.periodLength ?? 5).clamp(1, 10);
  final cycleDay = (daysSinceStart % cycleLength) + 1;
  final predictedOvulationDate = currentPrediction?.ovulationDate;
  final ovulationDay =
      predictedOvulationDate == null
          ? (cycleLength - 14).clamp(8, 24)
          : ((DateTime(
                    predictedOvulationDate.year,
                    predictedOvulationDate.month,
                    predictedOvulationDate.day,
                  ).difference(start).inDays %
                  cycleLength) +
              1);

  if (cycleDay <= periodLength) {
    return PredictionPhase.menstrual;
  }
  if ((cycleDay - ovulationDay).abs() <= 1) {
    return PredictionPhase.ovulatory;
  }
  if (cycleDay < ovulationDay) {
    return PredictionPhase.follicular;
  }
  return PredictionPhase.luteal;
}

Color _phaseBackground(
  PredictionPhase phase,
  bool isOvulation,
  AppColors colors,
  bool isDark,
) {
  if (isOvulation) {
    return isDark
        ? colors.phaseOvulatory.withValues(alpha: 0.28)
        : const Color(0xFFD9ECFF);
  }
  if (isDark) {
    return switch (phase) {
      PredictionPhase.follicular => colors.phaseFollicular.withValues(
        alpha: 0.28,
      ),
      PredictionPhase.ovulatory => colors.phaseOvulatory.withValues(
        alpha: 0.28,
      ),
      PredictionPhase.luteal => colors.phaseLuteal.withValues(alpha: 0.28),
      PredictionPhase.menstrual => colors.phaseMenstrual.withValues(
        alpha: 0.28,
      ),
      PredictionPhase.unknown => Colors.transparent,
    };
  }
  return switch (phase) {
    PredictionPhase.follicular => const Color(0xFFDDF4E5),
    PredictionPhase.ovulatory => const Color(0xFFD9ECFF),
    PredictionPhase.luteal => const Color(0xFFEEDDF9),
    PredictionPhase.menstrual => const Color(0xFFFFDCCE),
    PredictionPhase.unknown => Colors.transparent,
  };
}

_SelectedDayDetails _buildSelectedDayDetails({
  required BuildContext context,
  required DateTime selectedDate,
  required List<PredictionCalendarDay> predictionDays,
  required CurrentPrediction? currentPrediction,
  required DateTime? calendarStartDate,
  required DailyLogDraft? dailyLog,
}) {
  PredictionCalendarDay? selectedPrediction;
  for (final day in predictionDays) {
    if (_isSameDay(day.date, selectedDate)) {
      selectedPrediction = day;
      break;
    }
  }

  final phase = _calendarPhase(
    selectedPrediction,
    _derivedPhaseForDate(
      date: selectedDate,
      currentPrediction: currentPrediction,
      calendarStartDate: calendarStartDate,
    ),
  );
  final cycleDay = _derivedCycleDay(
    selectedDate: selectedDate,
    currentPrediction: currentPrediction,
    calendarStartDate: calendarStartDate,
  );

  final logSymptoms = dailyLog?.symptoms;
  final period = dailyLog?.period;
  final temperature = dailyLog?.temperature;
  final lhTest = dailyLog?.lhTest;
  final cervicalMucus = dailyLog?.cervicalMucus;
  final intimacy = dailyLog?.intimacy;
  final symptomLabels = [...?period?.symptoms, ...?logSymptoms?.physical];
  final notes = [
    if (logSymptoms?.notes?.trim().isNotEmpty == true)
      'Symptoms: ${logSymptoms!.notes!.trim()}',
    if (cervicalMucus?.notes?.trim().isNotEmpty == true)
      'Mucus: ${cervicalMucus!.notes!.trim()}',
    if (intimacy?.notes?.trim().isNotEmpty == true)
      'Intimacy: ${intimacy!.notes!.trim()}',
    if (dailyLog?.notes?.trim().isNotEmpty == true) dailyLog!.notes!.trim(),
  ];

  return _SelectedDayDetails(
    cycleDay: cycleDay,
    phaseLabel: _phaseLabel(context, phase),
    mood:
        _displayValue(logSymptoms?.mood) ??
        switch (phase) {
          PredictionPhase.menstrual => context.l10n.calendarMoodMenstrual,
          PredictionPhase.follicular => context.l10n.calendarMoodFollicular,
          PredictionPhase.ovulatory => context.l10n.calendarMoodOvulatory,
          PredictionPhase.luteal => context.l10n.calendarMoodLuteal,
          PredictionPhase.unknown => context.l10n.calendarMoodUnknown,
        },
    symptoms:
        symptomLabels.isNotEmpty
            ? symptomLabels.join(', ')
            : selectedPrediction?.hasDot == true
            ? context.l10n.calendarSymptomsPresent
            : context.l10n.calendarSymptomsNone,
    sleep:
        _displayValue(logSymptoms?.sleepQuality) ??
        switch (phase) {
          PredictionPhase.menstrual => context.l10n.calendarSleepMenstrual,
          PredictionPhase.follicular => context.l10n.calendarSleepFollicular,
          PredictionPhase.ovulatory => context.l10n.calendarSleepOvulatory,
          PredictionPhase.luteal => context.l10n.calendarSleepLuteal,
          PredictionPhase.unknown => context.l10n.calendarSleepUnknown,
        },
    energy:
        logSymptoms?.energyLevel == null
            ? _extraLogSummary(
                  temperature: temperature,
                  lhTest: lhTest,
                  cervicalMucus: cervicalMucus,
                  intimacy: intimacy,
                ) ??
                switch (phase) {
                  PredictionPhase.menstrual =>
                    context.l10n.calendarEnergyMenstrual,
                  PredictionPhase.follicular =>
                    context.l10n.calendarEnergyFollicular,
                  PredictionPhase.ovulatory =>
                    context.l10n.calendarEnergyOvulatory,
                  PredictionPhase.luteal => context.l10n.calendarEnergyLuteal,
                  PredictionPhase.unknown => context.l10n.calendarEnergyUnknown,
                }
            : '${logSymptoms!.energyLevel}/5',
    notes:
        notes.isNotEmpty
            ? notes.join('\n')
            : switch (phase) {
              PredictionPhase.menstrual => context.l10n.calendarNotesMenstrual,
              PredictionPhase.follicular =>
                context.l10n.calendarNotesFollicular,
              PredictionPhase.ovulatory => context.l10n.calendarNotesOvulatory,
              PredictionPhase.luteal => context.l10n.calendarNotesLuteal,
              PredictionPhase.unknown => context.l10n.calendarNotesUnknown,
            },
  );
}

int _derivedCycleDay({
  required DateTime selectedDate,
  required CurrentPrediction? currentPrediction,
  required DateTime? calendarStartDate,
}) {
  final cycleStart =
      calendarStartDate ?? _currentCycleStartDate(currentPrediction);
  final target = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );
  if (cycleStart == null || target.isBefore(cycleStart)) {
    return selectedDate.day.clamp(1, 60);
  }
  final cycleLength = (currentPrediction?.cycleLength ?? 28).clamp(21, 45);
  return (target.difference(cycleStart).inDays % cycleLength) + 1;
}

String _phaseLabel(BuildContext context, PredictionPhase phase) {
  return switch (phase) {
    PredictionPhase.menstrual => context.l10n.todayPhaseMenstrual,
    PredictionPhase.follicular => context.l10n.todayPhaseFollicular,
    PredictionPhase.ovulatory => context.l10n.todayPhaseOvulatory,
    PredictionPhase.luteal => context.l10n.todayPhaseLuteal,
    PredictionPhase.unknown => context.l10n.calendarPhaseUnknown,
  };
}

bool _dailyLogHasData(DailyLogDraft draft) {
  return (draft.period?.hasData ?? false) ||
      (draft.symptoms?.hasData ?? false) ||
      (draft.temperature?.hasData ?? false) ||
      (draft.lhTest?.hasData ?? false) ||
      (draft.cervicalMucus?.hasData ?? false) ||
      (draft.intimacy?.hasData ?? false) ||
      (draft.notes?.trim().isNotEmpty ?? false);
}

String? _displayValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String? _extraLogSummary({
  required TemperatureLogDraft? temperature,
  required LhTestLogDraft? lhTest,
  required CervicalMucusLogDraft? cervicalMucus,
  required IntimacyLogDraft? intimacy,
}) {
  final parts = [
    if (temperature?.temperatureCelsius != null)
      'BBT ${temperature!.temperatureCelsius!.toStringAsFixed(1)}°C',
    if (lhTest?.result?.trim().isNotEmpty == true)
      'LH ${lhTest!.result!.trim()}',
    if (cervicalMucus?.type?.trim().isNotEmpty == true)
      'Mucus ${cervicalMucus!.type!.trim()}',
    if (intimacy?.activity?.trim().isNotEmpty == true)
      intimacy!.activity!.trim(),
  ];
  return parts.isEmpty ? null : parts.join(' • ');
}

void _openDailyLog(BuildContext context, DateTime date) {
  Navigator.of(context).pop();
  context.go('/log?date=${_dateOnly(date)}');
}

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _monthYearLabel(BuildContext context, DateTime date) {
  return AppFormatters.formatMonthYear(
    date,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

String _longDateLabel(BuildContext context, DateTime date) {
  return AppFormatters.formatDateLong(
    date,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

DateTime? _currentCycleStartDate(CurrentPrediction? currentPrediction) {
  final cycleDay = currentPrediction?.cycleDay;
  if (cycleDay == null || cycleDay < 1) {
    return null;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: cycleDay - 1));
}

DateTime? _calendarHistoryStartDate({
  required CurrentPrediction? currentPrediction,
  required CycleStats? cycleStats,
}) {
  final dates = <DateTime>[
    if (cycleStats?.firstPeriodStartDate != null)
      cycleStats!.firstPeriodStartDate!,
    if (currentPrediction?.cycleStartDate != null)
      currentPrediction!.cycleStartDate!,
    if (_currentCycleStartDate(currentPrediction) case final inferred?)
      inferred,
    for (final range in cycleStats?.periodRanges ?? const <CyclePeriodRange>[])
      range.startDate,
  ];
  if (dates.isEmpty) {
    return null;
  }
  dates.sort((a, b) => a.compareTo(b));
  final earliest = dates.first;
  return DateTime(earliest.year, earliest.month, earliest.day);
}

List<DateTime> _visibleMonths({
  required DateTime visibleMonth,
  required DateTime? calendarStartDate,
  required int monthCount,
  required int monthsAhead,
}) {
  final startMonth =
      calendarStartDate == null
          ? null
          : DateTime(calendarStartDate.year, calendarStartDate.month, 1);
  final now = DateTime.now();
  final maxMonth = DateTime(now.year, now.month + monthsAhead, 1);
  final months = <DateTime>[];
  for (var i = 0; i < monthCount; i++) {
    final month = DateTime(visibleMonth.year, visibleMonth.month + i, 1);
    if (month.isAfter(maxMonth)) {
      break;
    }
    if (startMonth != null && month.isBefore(startMonth)) {
      continue;
    }
    months.add(month);
  }
  return months.isEmpty
      ? [DateTime(visibleMonth.year, visibleMonth.month, 1)]
      : months;
}

List<DateTime> _monthChoices({
  required DateTime visibleMonth,
  required DateTime? calendarStartDate,
  required int monthsAhead,
}) {
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month, 1);
  final maxMonth = DateTime(now.year, now.month + monthsAhead, 1);
  final startMonth =
      calendarStartDate == null
          ? DateTime(visibleMonth.year, visibleMonth.month - 11, 1)
          : DateTime(calendarStartDate.year, calendarStartDate.month, 1);
  final months = <DateTime>[];
  var cursor = maxMonth;
  while (!cursor.isBefore(startMonth)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month - 1, 1);
  }
  if (!months.any((month) => _isSameMonth(month, currentMonth))) {
    months.add(currentMonth);
  }
  return months;
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isSameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

const _weekdayLabels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
