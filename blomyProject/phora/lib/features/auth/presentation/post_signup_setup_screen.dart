import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/formatters.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/onboarding/data/onboarding_repository.dart';
import 'package:phora/features/onboarding/domain/onboarding_status.dart';
import 'package:phora/features/onboarding/presentation/widgets/onboarding_components.dart';

abstract final class _SetupPalette {
  static const accent = Color(0xFFFF8A4C);
  static const accentSoft = Color(0xFFFFE7D8);
  static const accentSoftStrong = Color(0xFFFFD9C2);
  static const orbOne = Color(0xFFFFE6D6);
  static const orbTwo = Color(0xFFFFF0E6);
}

class PostSignupSetupScreen extends ConsumerStatefulWidget {
  const PostSignupSetupScreen({super.key});

  @override
  ConsumerState<PostSignupSetupScreen> createState() =>
      _PostSignupSetupScreenState();
}

class _PostSignupSetupScreenState extends ConsumerState<PostSignupSetupScreen> {
  static const _stepCount = 4;
  static const _defaultCycleLength = 28;
  static const _goalIds = <String>[
    'cycle_tracking',
    'avoid_pregnancy',
    'trying_to_conceive',
    'pregnancy',
  ];
  static const _conditions = <String>[
    'Hormone imbalance',
    'Irregular cycle',
    'PCOS',
    'Miscarriage history',
    'Just came off from birth control',
    'None',
  ];

  final _pageController = PageController();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _didHydrateFromBackend = false;
  int? _periodLength;
  String? _selectedGoalId;
  DateTime _visibleMonth = _monthStart(DateTime.now());
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  final Set<String> _selectedConditions = <String>{};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToStep(int step) async {
    if (step < 0 || step >= _stepCount) return;
    await _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() => _currentStep = step);
  }

  Future<void> _handleBack() async {
    if (_currentStep == 0) {
      context.pop();
      return;
    }
    await _goToStep(_currentStep - 1);
  }

  Future<void> _handleContinue() async {
    switch (_currentStep) {
      case 0:
        if (_periodLength == null) {
          showAuthError(context, context.l10n.postSignupPeriodLengthError);
          return;
        }
        await _saveDraftProgress(currentStep: 2);
        await _goToStep(1);
        return;
      case 1:
        if (!_hasSelectedRange) {
          showAuthError(context, context.l10n.postSignupLastPeriodError);
          return;
        }
        await _saveDraftProgress(currentStep: 3);
        await _goToStep(2);
        return;
      case 2:
        if (_selectedGoalId == null) {
          showAuthError(context, context.l10n.postSignupGoalError);
          return;
        }
        await _saveDraftProgress(currentStep: 4);
        await _goToStep(3);
        return;
      case 3:
        if (_selectedConditions.isEmpty) {
          showAuthError(context, context.l10n.postSignupConditionsError);
          return;
        }
        await _submitSetup();
        return;
    }
  }

  bool get _canContinueCurrentStep {
    if (_isSubmitting) {
      return false;
    }
    return switch (_currentStep) {
      0 => _periodLength != null,
      1 => _hasSelectedRange,
      _ => true,
    };
  }

  bool get _hasSelectedRange {
    return _rangeStart != null &&
        _rangeEnd != null &&
        !_isSameDay(_rangeStart!, _rangeEnd!);
  }

  Future<void> _saveDraftProgress({required int currentStep}) async {
    final normalizedConditions =
        _selectedConditions.contains('None')
            ? const <String>[]
            : _selectedConditions.toList();
    final progress = await ref
        .read(onboardingRepositoryProvider)
        .saveProgress(
          currentStep: currentStep,
          periodLength: _periodLength,
          lastPeriodStart: _rangeStart,
          lastPeriodEnd: _rangeEnd,
          goal: _selectedGoalId,
          healthConditions: normalizedConditions,
        );
    await ref
        .read(onboardingStatusProvider.notifier)
        .setBackendProgress(progress);
  }

  void _maybeHydrateFromProgress(OnboardingProgress? progress) {
    if (_didHydrateFromBackend || progress == null) {
      return;
    }
    _didHydrateFromBackend = true;
    _periodLength = progress.periodLength ?? _periodLength;
    _rangeStart = progress.lastPeriodStart ?? _rangeStart;
    _rangeEnd = progress.lastPeriodEnd ?? _rangeEnd;
    _selectedGoalId = _normalizeGoalId(progress.goal) ?? _selectedGoalId;
    _selectedConditions
      ..clear()
      ..addAll(progress.healthConditions);
    if (_selectedConditions.isEmpty && progress.healthConditions.isEmpty) {
      _selectedConditions.remove('None');
    }
    if (_rangeStart != null) {
      _visibleMonth = _monthStart(_rangeStart!);
    }
    final resolvedStep = ((progress.currentStep ?? 1) - 1).clamp(
      0,
      _stepCount - 1,
    );
    _currentStep = resolvedStep;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      _pageController.jumpToPage(resolvedStep);
      if (mounted) {
        setState(() {});
      }
    });
  }

  String? _normalizeGoalId(String? goal) {
    return switch (goal) {
      null => null,
      'avoid' => 'avoid_pregnancy',
      'conceive' => 'trying_to_conceive',
      'track' => 'cycle_tracking',
      _ => goal,
    };
  }

  Future<void> _submitSetup() async {
    if (_isSubmitting ||
        _rangeStart == null ||
        _rangeEnd == null ||
        _selectedGoalId == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final selectedConditions =
          _selectedConditions.contains('None')
              ? const <String>[]
              : _selectedConditions.toList();

      await ref
          .read(onboardingRepositoryProvider)
          .completeOnboarding(
            lastPeriodStart: _rangeStart!,
            lastPeriodEnd: _rangeEnd!,
            averagePeriodLength: _periodLength!,
            averageCycleLength: _defaultCycleLength,
            goal: _selectedGoalId!,
            healthConditions: selectedConditions,
          );
      await ref.read(onboardingStatusProvider.notifier).completeCurrentFlow();
      if (!mounted) return;
      context.go('/subscription');
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _toggleCondition(String condition) {
    setState(() {
      if (condition == 'None') {
        if (_selectedConditions.contains('None')) {
          _selectedConditions.remove('None');
        } else {
          _selectedConditions
            ..clear()
            ..add('None');
        }
        return;
      }

      _selectedConditions.remove('None');
      if (_selectedConditions.contains(condition)) {
        _selectedConditions.remove(condition);
      } else {
        _selectedConditions.add(condition);
      }
    });
  }

  void _handleDayTap(DateTime day) {
    setState(() {
      if (_rangeStart == null || _rangeEnd != null) {
        _rangeStart = day;
        _rangeEnd = null;
        return;
      }

      if (day.isBefore(_rangeStart!)) {
        _rangeStart = day;
        return;
      }

      _rangeEnd = day;
      final inclusiveLength = day.difference(_rangeStart!).inDays + 1;
      _periodLength = inclusiveLength.clamp(2, 8);
    });
  }

  @override
  Widget build(BuildContext context) {
    final onboardingStatus = ref.watch(onboardingStatusProvider).valueOrNull;
    _maybeHydrateFromProgress(onboardingStatus?.progress);
    final dims = context.dims;
    final colors = context.phora.colors;

    return Scaffold(
      body: Stack(
        children: [
          DecoratedBox(
            decoration: authBackgroundDecoration(context),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: -24,
            right: -48,
            child: _BlurOrb(
              size: 180,
              color: _SetupPalette.orbOne.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            bottom: 96,
            left: -36,
            child: _BlurOrb(
              size: 170,
              color: _SetupPalette.orbTwo.withValues(alpha: 0.24),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(20),
                    dims.scaleSpace(16),
                    dims.scaleWidth(20),
                    dims.scaleSpace(12),
                  ),
                  child: Row(
                    children: [
                      _BackButton(onTap: _handleBack),
                      SizedBox(width: dims.scaleWidth(16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.postSignupTitle,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                            SizedBox(height: dims.scaleSpace(10)),
                            _ProgressBar(
                              count: _stepCount,
                              currentStep: _currentStep,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _SetupPage(
                        stepLabel: context.l10n.postSignupStepLabel(1),
                        title: context.l10n.postSignupStep1Title,
                        subtitle: context.l10n.postSignupStep1Subtitle,
                        child: _PeriodLengthStep(
                          value: _periodLength,
                          onChanged:
                              (value) => setState(() => _periodLength = value),
                        ),
                      ),
                      _SetupPage(
                        stepLabel: context.l10n.postSignupStepLabel(2),
                        title: context.l10n.postSignupStep2Title,
                        subtitle: context.l10n.postSignupStep2Subtitle,
                        child: _LastPeriodStep(
                          visibleMonth: _visibleMonth,
                          rangeStart: _rangeStart,
                          rangeEnd: _rangeEnd,
                          onPreviousMonth: () {
                            setState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month - 1,
                                1,
                              );
                            });
                          },
                          onNextMonth: () {
                            setState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month + 1,
                                1,
                              );
                            });
                          },
                          onDayTap: _handleDayTap,
                        ),
                      ),
                      _SetupPage(
                        stepLabel: context.l10n.postSignupStepLabel(3),
                        title: context.l10n.postSignupStep3Title,
                        subtitle: context.l10n.postSignupStep3Subtitle,
                        child: _GoalStep(
                          selectedGoalId: _selectedGoalId,
                          onSelected: (value) {
                            setState(() => _selectedGoalId = value);
                          },
                        ),
                      ),
                      _SetupPage(
                        stepLabel: context.l10n.postSignupStepLabel(4),
                        title: context.l10n.postSignupStep4Title,
                        subtitle: context.l10n.postSignupStep4Subtitle,
                        child: _ConditionsStep(
                          selectedConditions: _selectedConditions,
                          onToggle: _toggleCondition,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(24),
                    dims.scaleSpace(8),
                    dims.scaleWidth(24),
                    dims.scaleSpace(24),
                  ),
                  child: _GlassPanel(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(18),
                      dims.scaleSpace(14),
                      dims.scaleWidth(18),
                      dims.scaleSpace(18),
                    ),
                    child: Column(
                      children: [
                        _StepDots(count: _stepCount, currentStep: _currentStep),
                        SizedBox(height: dims.scaleSpace(16)),
                        SizedBox(
                          width: double.infinity,
                          child: OnboardingPrimaryButton(
                            label:
                                _isSubmitting
                                    ? context.l10n.savingLabel
                                    : _currentStep == _stepCount - 1
                                    ? context.l10n.finishLabel
                                    : context.l10n.saveLabelAction,
                            onPressed:
                                _canContinueCurrentStep
                                    ? _handleContinue
                                    : null,
                          ),
                        ),
                      ],
                    ),
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

class _SetupPage extends StatelessWidget {
  const _SetupPage({
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String stepLabel;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(24),
        dims.scaleSpace(12),
        dims.scaleWidth(24),
        dims.scaleSpace(16),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: dims.scaleSpace(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(12),
                  vertical: dims.scaleSpace(6),
                ),
                decoration: BoxDecoration(
                  color: _SetupPalette.accentSoft,
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
                child: Text(
                  stepLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _SetupPalette.accent,
                    fontSize: dims.scaleText(12),
                  ),
                ),
              ),
              SizedBox(height: dims.scaleSpace(14)),
              Text(
                title,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: dims.scaleText(28),
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                  letterSpacing: -0.7,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: dims.scaleSpace(12)),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(15),
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: dims.scaleSpace(28)),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodLengthStep extends StatelessWidget {
  const _PeriodLengthStep({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassPanel(
          width: double.infinity,
          padding: EdgeInsets.all(dims.scaleWidth(22)),
          child: Column(
            children: [
              Text(
                value == null
                    ? context.l10n.postSignupSelectRange
                    : context.l10n.postSignupDaysLabel(value!),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: dims.scaleText(34),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: dims.scaleSpace(8)),
              Text(
                context.l10n.postSignupPeriodLengthHelp,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: dims.scaleSpace(18)),
              Slider(
                value: (value ?? 2).toDouble(),
                min: 2,
                max: 8,
                divisions: 6,
                activeColor: _SetupPalette.accent,
                inactiveColor: colors.border,
                onChanged: (next) => onChanged(next.round()),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(4)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final label = '${index + 2}';
                    final selected = value == index + 2;
                    return Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            selected
                                ? _SetupPalette.accent
                                : colors.textTertiary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: dims.scaleSpace(14)),
        _InsightCard(
          icon: Icons.auto_awesome_rounded,
          title: context.l10n.postSignupPredictionQualityTitle,
          description: context.l10n.postSignupPredictionQualityDescription,
        ),
      ],
    );
  }
}

class _LastPeriodStep extends StatelessWidget {
  const _LastPeriodStep({
    required this.visibleMonth,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDayTap,
  });

  final DateTime visibleMonth;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final monthDays = _buildCalendarDays(visibleMonth);

    return _GlassPanel(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(18)),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _monthLabel(context, visibleMonth),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(8)),
          const _WeekdayHeader(),
          SizedBox(height: dims.scaleSpace(6)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: monthDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = monthDays[index];
              final isMuted = day.month != visibleMonth.month;
              final isStart =
                  rangeStart != null && _isSameDay(day, rangeStart!);
              final isEnd = rangeEnd != null && _isSameDay(day, rangeEnd!);
              final inRange = _isInRange(day, rangeStart, rangeEnd);

              return _CalendarCell(
                day: day,
                muted: isMuted,
                selected: isStart || isEnd,
                inRange: inRange,
                onTap: () => onDayTap(day),
              );
            },
          ),
          SizedBox(height: dims.scaleSpace(16)),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              rangeStart == null
                  ? context.l10n.postSignupSelectFirstDayPrompt
                  : rangeEnd == null || _isSameDay(rangeStart!, rangeEnd!)
                  ? context.l10n.postSignupSelectedSingle(
                    _dateLabel(context, rangeStart!),
                  )
                  : context.l10n.postSignupSelectedRange(
                    _dateLabel(context, rangeStart!),
                    _dateLabel(context, rangeEnd!),
                  ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.selectedGoalId, required this.onSelected});

  final String? selectedGoalId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Column(
      children:
          _PostSignupSetupScreenState._goalIds.map((goalId) {
            final selected = goalId == selectedGoalId;
            return Padding(
              padding: EdgeInsets.only(bottom: dims.scaleSpace(12)),
              child: _SelectableCard(
                label: _goalTitle(context, goalId),
                description: _goalSubtitle(context, goalId),
                selected: selected,
                multiSelect: false,
                onTap: () => onSelected(goalId),
              ),
            );
          }).toList(),
    );
  }
}

class _ConditionsStep extends StatelessWidget {
  const _ConditionsStep({
    required this.selectedConditions,
    required this.onToggle,
  });

  final Set<String> selectedConditions;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Column(
      children:
          _PostSignupSetupScreenState._conditions.map((condition) {
            final selected = selectedConditions.contains(condition);
            return Padding(
              padding: EdgeInsets.only(bottom: dims.scaleSpace(12)),
              child: _SelectableCard(
                label: _conditionLabel(context, condition),
                selected: selected,
                multiSelect: true,
                onTap: () => onToggle(condition),
              ),
            );
          }).toList(),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.multiSelect,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedFill =
        isDark
            ? LinearGradient(
              colors: [const Color(0xFF4E2E1D), const Color(0xFF6A3B22)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
            : const LinearGradient(
              colors: [
                _SetupPalette.accentSoft,
                _SetupPalette.accentSoftStrong,
              ],
            );
    final selectedTitleColor = isDark ? Colors.white : colors.textPrimary;
    final selectedDescriptionColor =
        isDark ? const Color(0xFFFFD9C2) : colors.textSecondary;

    return Material(
      color: colors.bgCard.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(18),
            vertical: dims.scaleSpace(18),
          ),
          decoration: BoxDecoration(
            gradient: selected ? selectedFill : null,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(
              color: selected ? _SetupPalette.accent : colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(15),
                        fontWeight: FontWeight.w700,
                        color:
                            selected ? selectedTitleColor : colors.textPrimary,
                      ),
                    ),
                    if (description != null) ...[
                      SizedBox(height: dims.scaleSpace(4)),
                      Text(
                        description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              selected
                                  ? selectedDescriptionColor
                                  : colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(16)),
              _SelectionIndicator(selected: selected, multiSelect: multiSelect),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({
    required this.selected,
    required this.multiSelect,
  });

  final bool selected;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final size = dims.scaleWidth(24);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color:
            selected
                ? _SetupPalette.accent.withValues(alpha: 0.16)
                : Colors.transparent,
        shape: multiSelect ? BoxShape.rectangle : BoxShape.circle,
        borderRadius:
            multiSelect ? BorderRadius.circular(dims.scaleRadius(6)) : null,
        border: Border.all(
          color: selected ? _SetupPalette.accent : colors.borderStrong,
          width: 2,
        ),
      ),
      child:
          selected
              ? Icon(
                multiSelect ? Icons.check_rounded : Icons.circle,
                size: multiSelect ? dims.scaleText(16) : dims.scaleText(10),
                color: _SetupPalette.accent,
              )
              : null,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Material(
      color: colors.bgCard.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: dims.scaleWidth(42),
          height: dims.scaleWidth(42),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: dims.scaleText(18),
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.width, this.padding});

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.bgCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        border: Border.all(color: colors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return _GlassPanel(
      padding: EdgeInsets.all(dims.scaleWidth(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: dims.scaleWidth(40),
            height: dims.scaleWidth(40),
            decoration: BoxDecoration(
              color: _SetupPalette.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
            ),
            child: Icon(icon, color: _SetupPalette.accent),
          ),
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.count, required this.currentStep});

  final int count;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Row(
      children: List.generate(count, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: dims.scaleWidth(4)),
            height: dims.scaleHeight(4),
            decoration: BoxDecoration(
              color: active ? _SetupPalette.accent : colors.border,
              borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            ),
          ),
        );
      }),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.currentStep});

  final int count;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == currentStep;
        return Container(
          width: selected ? dims.scaleWidth(18) : dims.scaleWidth(8),
          height: dims.scaleWidth(8),
          margin: EdgeInsets.symmetric(horizontal: dims.scaleWidth(4)),
          decoration: BoxDecoration(
            color: selected ? _SetupPalette.accent : colors.border,
            borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
          ),
        );
      }),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final labels = MaterialLocalizations.of(context).narrowWeekdays
        .map((label) => label.toUpperCase())
        .toList(growable: false);

    return Row(
      children:
          labels.map((label) {
            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  fontSize: dims.scaleText(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.muted,
    required this.selected,
    required this.inRange,
    required this.onTap,
  });

  final DateTime day;
  final bool muted;
  final bool selected;
  final bool inRange;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    final background =
        selected
            ? _SetupPalette.accent
            : inRange
            ? _SetupPalette.accent.withValues(alpha: 0.16)
            : Colors.transparent;
    final foreground =
        selected
            ? Colors.white
            : muted
            ? colors.textTertiary
            : colors.textPrimary;

    return Padding(
      padding: EdgeInsets.all(dims.scaleWidth(2)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

List<DateTime> _buildCalendarDays(DateTime month) {
  final firstOfMonth = DateTime(month.year, month.month, 1);
  final gridStart = firstOfMonth.subtract(
    Duration(days: firstOfMonth.weekday % 7),
  );
  return List<DateTime>.generate(
    42,
    (index) => gridStart.add(Duration(days: index)),
  );
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _isInRange(DateTime day, DateTime? start, DateTime? end) {
  if (start == null) return false;
  final normalizedDay = DateTime(day.year, day.month, day.day);
  final normalizedStart = DateTime(start.year, start.month, start.day);
  if (end == null) {
    return _isSameDay(normalizedDay, normalizedStart);
  }
  final normalizedEnd = DateTime(end.year, end.month, end.day);
  return !normalizedDay.isBefore(normalizedStart) &&
      !normalizedDay.isAfter(normalizedEnd);
}

String _monthLabel(BuildContext context, DateTime month) {
  return AppFormatters.formatMonthYear(
    month,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

String _dateLabel(BuildContext context, DateTime value) {
  return AppFormatters.formatDateMedium(
    value,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

String _goalTitle(BuildContext context, String goalId) {
  return switch (goalId) {
    'cycle_tracking' => context.l10n.goalCycleTrackingTitle,
    'avoid_pregnancy' => context.l10n.goalAvoidPregnancyTitle,
    'trying_to_conceive' => context.l10n.goalTryingToConceiveTitle,
    'pregnancy' => context.l10n.goalPregnancyTitle,
    _ => goalId,
  };
}

String _goalSubtitle(BuildContext context, String goalId) {
  return switch (goalId) {
    'cycle_tracking' => context.l10n.goalCycleTrackingSubtitle,
    'avoid_pregnancy' => context.l10n.goalAvoidPregnancySubtitle,
    'trying_to_conceive' => context.l10n.goalTryingToConceiveSubtitle,
    'pregnancy' => context.l10n.goalPregnancySubtitle,
    _ => '',
  };
}

String _conditionLabel(BuildContext context, String condition) {
  return switch (condition) {
    'Hormone imbalance' => context.l10n.conditionHormoneImbalance,
    'Irregular cycle' => context.l10n.conditionIrregularCycle,
    'PCOS' => context.l10n.conditionPcos,
    'Miscarriage history' => context.l10n.conditionMiscarriageHistory,
    'Just came off from birth control' => context.l10n.conditionBirthControl,
    'None' => context.l10n.conditionNone,
    _ => condition,
  };
}
