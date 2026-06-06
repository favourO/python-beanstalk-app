import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phora/core/i18n/formatters.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/utils/image_upload_preparer.dart';
import 'package:phora/features/cycle/data/cycle_repository.dart';
import 'package:phora/features/home/home_providers.dart';
import 'package:phora/features/insights/insights_providers.dart';
import 'package:phora/features/log/data/voice_log_processor.dart';
import 'package:phora/features/log/daily_log_controller.dart';
import 'package:phora/features/log/daily_log_models.dart';
import 'package:phora/features/log/presentation/log_ui.dart';
import 'package:phora/features/profile/profile_providers.dart';
import 'package:phora/l10n/app_localizations.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  final _symptomsNotesController = TextEditingController();
  final _mucusNotesController = TextEditingController();
  final _intimacyNotesController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _imageUploadPreparer = ImageUploadPreparer();
  final _voiceLogProcessor = const VoiceLogProcessor();

  bool _seededControllers = false;
  final Map<LogSection, bool> _openSections = {
    for (final section in LogSection.values)
      section: section == LogSection.period,
  };

  void _openNextUnsavedSection(DailyLogScreenState state, {LogSection? after}) {
    final nextSection = _nextUnsavedSection(state, after: after);
    for (final section in LogSection.values) {
      _openSections[section] = section == nextSection;
    }
  }

  @override
  void dispose() {
    _symptomsNotesController.dispose();
    _mucusNotesController.dispose();
    _intimacyNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeDate = _dateFromRoute(context);
    final activeLogDate = ref.watch(dailyLogDateProvider);
    if (!_isSameDay(activeLogDate, routeDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _seededControllers = false;
          _symptomsNotesController.clear();
          _mucusNotesController.clear();
          _intimacyNotesController.clear();
          for (final section in LogSection.values) {
            _openSections[section] = section == LogSection.period;
          }
        });
        ref.read(dailyLogDateProvider.notifier).state = routeDate;
      });
    }
    final home = ref.watch(homeDashboardProvider).valueOrNull;
    final cycleStats = ref.watch(cycleStatsProvider).valueOrNull;
    final userProfile = ref.watch(currentUserProfileProvider).valueOrNull;
    final firstName = _firstNameFromProfile(userProfile?.fullName);
    final logStateAsync = ref.watch(dailyLogControllerProvider);
    final dims = context.dims;
    final l10n = context.l10n;

    return PopScope(
      canPop: !(logStateAsync.valueOrNull?.hasUnsavedChanges ?? false),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final current = logStateAsync.valueOrNull;
        if (current == null || !current.hasUnsavedChanges) {
          Navigator.of(context).maybePop();
          return;
        }
        final leave = await _confirmDiscardChanges(context);
        if (leave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: LogPageScaffold(
        header: _TodayLogHeader(
          date: activeLogDate,
          firstName: firstName,
          onCalendarTap: () => context.go('/cycle'),
        ),
        child: logStateAsync.when(
          loading: () => const _LogLoadingState(),
          error:
              (error, _) => _LogLoadErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(dailyLogControllerProvider),
              ),
          data: (state) {
            _seedIfNeeded(state, home);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: dims.scaleSpace(8)),
                _QuickVoiceLogCard(onTap: () => _openVoiceLogSheet(state)),
                SizedBox(height: dims.scaleSpace(14)),
                ...LogSection.values.map(
                  (section) => Padding(
                    padding: EdgeInsets.only(bottom: dims.scaleSpace(16)),
                    child: _buildSectionCard(
                      context: context,
                      state: state,
                      home: home,
                      cycleStats: cycleStats,
                      section: section,
                    ),
                  ),
                ),
                if (state.globalError != null) ...[
                  _InlineErrorBanner(message: state.globalError!),
                  SizedBox(height: dims.scaleSpace(14)),
                ],
                _GlobalSaveButton(
                  label:
                      state.dirtyCount == 0
                          ? l10n.logDailyAllSavedLabel
                          : l10n.logDailySaveRemainingLabel(state.dirtyCount),
                  enabled: state.dirtyCount > 0 && !state.isSavingAll,
                  isSaving: state.isSavingAll,
                  onTap: () async {
                    final success =
                        await ref
                            .read(dailyLogControllerProvider.notifier)
                            .saveRemaining();
                    if (!context.mounted || !success) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.logDailySaved)));
                    context.go('/today');
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openVoiceLogSheet(DailyLogScreenState state) async {
    final rawText = await _requestVoiceTranscript();
    if (rawText == null || rawText.trim().isEmpty) {
      return;
    }
    final result = await _voiceLogProcessor.process(rawText);
    final notifier = ref.read(dailyLogControllerProvider.notifier);
    notifier.updatePeriod(
      (state.draft.period ?? const PeriodLogDraft()).copyWith(
        intensity: _titleCase(result.flowIntensity),
        colour: _titleCase(result.flowColor),
        symptoms: result.symptoms.map(_titleCasePhrase).toList(),
      ),
    );
    notifier.updateSymptoms(
      (state.draft.symptoms ?? const SymptomsLogDraft()).copyWith(
        mood: result.mood.isEmpty ? null : _titleCasePhrase(result.mood.first),
        energyLevel: result.energyLevel?.clamp(1, 10),
        painLevel: result.painLevel?.clamp(1, 10),
        sleepQuality: _titleCase(result.sleepQuality),
        physical: result.symptoms.map(_titleCasePhrase).toList(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice log details filled in for review.')),
    );
  }

  Future<String?> _requestVoiceTranscript() {
    final controller = TextEditingController();
    final colors = context.phora.colors;
    final dims = context.dims;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(24)),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            dims.scaleWidth(18),
            dims.scaleSpace(18),
            dims.scaleWidth(18),
            MediaQuery.viewInsetsOf(context).bottom + dims.scaleSpace(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice transcript',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: dims.scaleSpace(8)),
              Text(
                'Paste or dictate what you said, then review the filled details.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: dims.scaleSpace(14)),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText:
                      'Example: I feel tired, light bleeding, cramps, and bad sleep.',
                ),
              ),
              SizedBox(height: dims.scaleSpace(14)),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(controller.text),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Fill details'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  void _seedIfNeeded(DailyLogScreenState state, dynamic home) {
    if (_seededControllers) {
      return;
    }
    _symptomsNotesController.text = state.draft.symptoms?.notes ?? '';
    _mucusNotesController.text = state.draft.cervicalMucus?.notes ?? '';
    _intimacyNotesController.text = state.draft.intimacy?.notes ?? '';
    _openNextUnsavedSection(state);
    _seededControllers = true;
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required DailyLogScreenState state,
    required dynamic home,
    required dynamic cycleStats,
    required LogSection section,
  }) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final l10n = context.l10n;
    final isOpen = _openSections[section] ?? false;
    final isDirty = state.isDirty[section] ?? false;
    final isSaved = state.isSaved[section] ?? false;
    final error = state.sectionErrors[section];
    final isSaving = state.isSaving[section] ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(
          color:
              isDirty
                  ? const Color(0xFFD9A441)
                  : isOpen
                  ? colors.accentPrimary.withValues(alpha: 0.22)
                  : colors.border,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
              onTap: () {
                setState(() {
                  _openSections[section] = !isOpen;
                });
              },
              child: Padding(
                padding: EdgeInsets.all(dims.scaleWidth(14)),
                child: Row(
                  children: [
                    _SectionStatusIcon(
                      section: section,
                      isDirty: isDirty,
                      isSaved: isSaved,
                    ),
                    SizedBox(width: dims.scaleWidth(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _sectionTitle(l10n, section),
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                  fontSize: dims.scaleText(16),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (section == LogSection.lhTest &&
                                  _isWithinFertileWindow(home)) ...[
                                SizedBox(width: dims.scaleWidth(8)),
                                _HeaderBadge(
                                  label: l10n.logSuggestedTodayLabel,
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: dims.scaleSpace(4)),
                          Text(
                            _sectionSubtitle(
                              context,
                              state,
                              section,
                              isDirty: isDirty,
                              isSaved: isSaved,
                            ),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontSize: dims.scaleText(12),
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 180),
                      turns: isOpen ? 0.25 : 0,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textSecondary,
                        size: dims.scaleText(24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              heightFactor: isOpen ? 1 : 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  dims.scaleWidth(18),
                  0,
                  dims.scaleWidth(18),
                  dims.scaleSpace(18),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: colors.border,
                    ),
                    SizedBox(height: dims.scaleSpace(16)),
                    _sectionBody(context, state, home, cycleStats, section),
                    if (error != null) ...[
                      SizedBox(height: dims.scaleSpace(12)),
                      _InlineErrorBanner(message: error),
                    ],
                    SizedBox(height: dims.scaleSpace(14)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed:
                            isSaving
                                ? null
                                : () async {
                                  if (!_canSaveSection(state, section)) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            section == LogSection.lhTest
                                                ? l10n
                                                    .logLhPhotoValidationMessage
                                                : l10n
                                                    .logSectionEmptyValidationMessage,
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  final success = await ref
                                      .read(dailyLogControllerProvider.notifier)
                                      .saveSection(section);
                                  if (!context.mounted) {
                                    return;
                                  }
                                  if (success) {
                                    final updatedState =
                                        ref
                                            .read(dailyLogControllerProvider)
                                            .valueOrNull;
                                    setState(() {
                                      if (updatedState == null) {
                                        _openSections[section] = false;
                                      } else {
                                        _openNextUnsavedSection(
                                          updatedState,
                                          after: section,
                                        );
                                      }
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.logSectionSavedMessage(
                                            _sectionTitle(l10n, section),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF1E8),
                          foregroundColor: colors.textPrimary,
                          side: BorderSide(color: const Color(0xFFCAA090)),
                          padding: EdgeInsets.symmetric(
                            horizontal: dims.scaleWidth(18),
                            vertical: dims.scaleSpace(14),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              dims.scaleRadius(18),
                            ),
                          ),
                        ),
                        child: Text(
                          isSaving
                              ? l10n.savingLabel
                              : l10n.logSaveSectionLabel(
                                _sectionTitle(l10n, section).toLowerCase(),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionBody(
    BuildContext context,
    DailyLogScreenState state,
    dynamic home,
    dynamic cycleStats,
    LogSection section,
  ) {
    return switch (section) {
      LogSection.period => _PeriodSection(
        draft: state.draft.period ?? const PeriodLogDraft(),
        logDate: state.draft.date,
        inferredStartDate: _inferredPeriodStartDate(
          logDate: state.draft.date,
          periodRanges: cycleStats?.periodRanges ?? const [],
          currentCycleDay: home?.mainStatus.currentCycleDay as int?,
          periodLengthDays: home?.mainStatus.periodLengthDays as int?,
        ),
        currentCycleDay: _cycleDayForLogDate(
          logDate: state.draft.date,
          currentCycleDay: home?.mainStatus.currentCycleDay as int?,
        ),
        periodLengthDays: home?.mainStatus.periodLengthDays as int?,
        onChanged: ref.read(dailyLogControllerProvider.notifier).updatePeriod,
      ),
      LogSection.symptoms => _SymptomsSection(
        draft: state.draft.symptoms ?? const SymptomsLogDraft(),
        notesController: _symptomsNotesController,
        onChanged: ref.read(dailyLogControllerProvider.notifier).updateSymptoms,
      ),
      LogSection.temperature => _TemperatureSection(
        draft: state.draft.temperature ?? const TemperatureLogDraft(),
        wearableConnected: home?.healthSnapshot.wearableConnected == true,
        phaseRaw: home?.mainStatus.currentPhaseRaw as String?,
        onChanged:
            ref.read(dailyLogControllerProvider.notifier).updateTemperature,
      ),
      LogSection.lhTest => _LhTestSection(
        draft: state.draft.lhTest ?? LhTestLogDraft(testedAt: TimeOfDay.now()),
        onChanged: ref.read(dailyLogControllerProvider.notifier).updateLhTest,
        onSelectPhoto: _selectLhPhoto,
        onProcessPhoto: _processLhPhoto,
      ),
      LogSection.cervicalMucus => _CervicalMucusSection(
        draft: state.draft.cervicalMucus ?? const CervicalMucusLogDraft(),
        notesController: _mucusNotesController,
        onChanged:
            ref.read(dailyLogControllerProvider.notifier).updateCervicalMucus,
      ),
      LogSection.intimacy => _IntimacySection(
        draft: state.draft.intimacy ?? const IntimacyLogDraft(),
        notesController: _intimacyNotesController,
        onChanged: ref.read(dailyLogControllerProvider.notifier).updateIntimacy,
      ),
    };
  }

  Future<LhTestLogDraft?> _selectLhPhoto(LhTestLogDraft current) async {
    try {
      final source = await _pickLhImageSource();
      if (source == null) {
        return null;
      }
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2200,
      );
      if (picked == null) {
        return null;
      }
      final prepared = await _imageUploadPreparer.prepareForUpload(picked.path);
      return current.copyWith(
        method: 'photo',
        imageUrl: prepared.path,
        result: null,
        analysisStatus: null,
        analysisMessage: null,
      );
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.logLhImagePrepareError)),
      );
      return null;
    }
  }

  Future<LhTestLogDraft?> _processLhPhoto(LhTestLogDraft current) async {
    final imagePath = current.imageUrl;
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final now = DateTime.now();
      final result = await ref
          .read(cycleRepositoryProvider)
          .logLhImage(
            logDate: DateTime(now.year, now.month, now.day),
            testTime: _formatTime(current.testedAt ?? TimeOfDay.now()),
            imagePath: imagePath,
          );
      final state = result.state.toLowerCase();
      if (result.status != 'ok' ||
          !result.stripValid ||
          state == 'invalid_strip') {
        final message = result.explanation ?? l10n.logLhInvalidStripMessage;
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
        return current.copyWith(
          result: null,
          analysisStatus: 'invalid',
          analysisMessage: message,
        );
      }
      return current.copyWith(
        result: state,
        analysisStatus: 'ready',
        analysisMessage:
            result.explanation ?? l10n.logLhAnalysisCompleteMessage,
      );
    } catch (_) {
      if (!mounted) return null;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.logLhImageAnalysisError)),
      );
      return null;
    }
  }

  Future<ImageSource?> _pickLhImageSource() {
    final colors = context.phora.colors;
    final dims = context.dims;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: colors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(28)),
        ),
      ),
      builder: (context) {
        final l10n = context.l10n;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(20),
              dims.scaleSpace(12),
              dims.scaleWidth(20),
              dims.scaleSpace(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: dims.scaleWidth(42),
                    height: dims.scaleHeight(5),
                    decoration: BoxDecoration(
                      color: colors.borderStrong,
                      borderRadius: BorderRadius.circular(
                        dims.scaleRadius(999),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                Text(
                  l10n.logImageSourceTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: dims.scaleText(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(16)),
                _ImageSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: l10n.logTakePhotoLabel,
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                SizedBox(height: dims.scaleSpace(10)),
                _ImageSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: l10n.logUploadFromLibraryLabel,
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TodayLogHeader extends StatelessWidget {
  const _TodayLogHeader({
    required this.date,
    required this.firstName,
    required this.onCalendarTap,
  });

  final DateTime date;
  final String? firstName;
  final VoidCallback onCalendarTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _HeaderIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => context.go('/today'),
            ),
            const Spacer(),
            _HeaderIconButton(
              icon: Icons.calendar_month_outlined,
              onTap: onCalendarTap,
            ),
          ],
        ),
        SizedBox(height: dims.scaleSpace(24)),
        Text(
          firstName == null ? "Today's Log" : "${firstName!}'s Log",
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontSize: dims.scaleText(28),
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: dims.scaleSpace(6)),
        Text(
          _formatTodayLogDate(context, date),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: dims.scaleText(13),
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

String? _firstNameFromProfile(String? fullName) {
  final trimmed = fullName?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.split(RegExp(r'\s+')).first;
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        onTap: onTap,
        child: Container(
          width: dims.scaleWidth(40),
          height: dims.scaleWidth(40),
          decoration: BoxDecoration(
            color: colors.bgCard,
            shape: BoxShape.circle,
            border: Border.all(color: colors.border),
          ),
          child: Icon(
            icon,
            size: dims.scaleText(18),
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _QuickVoiceLogCard extends StatelessWidget {
  const _QuickVoiceLogCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(dims.scaleWidth(14)),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: dims.scaleWidth(42),
                height: dims.scaleWidth(42),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFE8),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
                child: Icon(
                  Icons.mic_none_rounded,
                  color: const Color(0xFFFF6337),
                  size: dims.scaleText(23),
                ),
              ),
              SizedBox(width: dims.scaleWidth(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick log with voice',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(15),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF6337),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(3)),
                    Text(
                      "Tap and speak, we'll fill in the details",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: dims.scaleText(11),
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: dims.scaleText(24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogLoadingState extends StatelessWidget {
  const _LogLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 120),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LogLoadErrorState extends StatelessWidget {
  const _LogLoadErrorState({required this.message, required this.onRetry});

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
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionStatusIcon extends StatelessWidget {
  const _SectionStatusIcon({
    required this.section,
    required this.isDirty,
    required this.isSaved,
  });

  final LogSection section;
  final bool isDirty;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final icon = switch (section) {
      LogSection.period => Icons.water_drop_outlined,
      LogSection.symptoms => Icons.favorite_border_rounded,
      LogSection.temperature => Icons.device_thermostat_rounded,
      LogSection.lhTest => Icons.science_outlined,
      LogSection.cervicalMucus => Icons.opacity_rounded,
      LogSection.intimacy => Icons.lock_outline_rounded,
    };
    final background =
        isDirty
            ? const Color(0xFFFFF1D6)
            : isSaved
            ? const Color(0xFFE7F4EA)
            : const Color(0xFFFFF1E8);
    final foreground =
        isDirty
            ? const Color(0xFFD39000)
            : isSaved
            ? const Color(0xFF2E8B57)
            : const Color(0xFF8A5A48);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: dims.scaleWidth(48),
          height: dims.scaleWidth(48),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
          ),
          child: Icon(icon, color: foreground),
        ),
        if (isDirty || isSaved)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: dims.scaleWidth(14),
              height: dims.scaleWidth(14),
              decoration: BoxDecoration(
                color:
                    isDirty ? const Color(0xFFD9A441) : const Color(0xFF5FAF72),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(8),
        vertical: dims.scaleSpace(4),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F4EA),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(color: const Color(0xFFF0B6A8)),
      ),
      child: Text(message),
    );
  }
}

class _GlobalSaveButton extends StatelessWidget {
  const _GlobalSaveButton({
    required this.label,
    required this.enabled,
    required this.isSaving,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final gradients = context.phora.gradients;
    final dims = context.dims;
    final background =
        enabled
            ? LinearGradient(colors: gradients.primary)
            : const LinearGradient(
              colors: [Color(0xFFE8E2DE), Color(0xFFE8E2DE)],
            );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
          onTap: enabled && !isSaving ? onTap : null,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(18)),
            child: Center(
              child: Text(
                isSaving ? context.l10n.savingLabel : label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(16),
                  fontWeight: FontWeight.w800,
                  color: enabled ? Colors.white : colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceChipWrap extends StatelessWidget {
  const _ChoiceChipWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labelBuilder,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String Function(String option)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Wrap(
      spacing: dims.scaleWidth(10),
      runSpacing: dims.scaleSpace(10),
      children:
          options.map((option) {
            final active = option == selected;
            return ChoiceChip(
              label: Text(labelBuilder?.call(option) ?? option),
              selected: active,
              onSelected: (_) => onSelected(option),
            );
          }).toList(),
    );
  }
}

class _MultiChipWrap extends StatelessWidget {
  const _MultiChipWrap({
    required this.options,
    required this.selected,
    required this.onToggle,
    this.labelBuilder,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String Function(String option)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Wrap(
      spacing: dims.scaleWidth(10),
      runSpacing: dims.scaleSpace(10),
      children:
          options.map((option) {
            final active = selected.contains(option);
            return FilterChip(
              label: Text(labelBuilder?.call(option) ?? option),
              selected: active,
              onSelected: (_) => onToggle(option),
            );
          }).toList(),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
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
    return Padding(
      padding: EdgeInsets.only(bottom: dims.scaleSpace(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
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

class _PeriodSection extends StatelessWidget {
  const _PeriodSection({
    required this.draft,
    required this.logDate,
    required this.inferredStartDate,
    required this.currentCycleDay,
    required this.periodLengthDays,
    required this.onChanged,
  });

  final PeriodLogDraft draft;
  final DateTime logDate;
  final DateTime inferredStartDate;
  final int? currentCycleDay;
  final int? periodLengthDays;
  final ValueChanged<PeriodLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final effectiveStartDate = draft.startDate ?? inferredStartDate;
    final periodDay = logDate.difference(effectiveStartDate).inDays + 1;
    return Column(
      children: [
        _PeriodRangeBlock(
          logDate: logDate,
          startDate: effectiveStartDate,
          periodDay: periodDay,
          currentCycleDay: currentCycleDay,
          periodLengthDays: periodLengthDays,
          onStartDateChanged:
              (value) => onChanged(draft.copyWith(startDate: value)),
        ),
        SizedBox(height: context.dims.scaleSpace(14)),
        _SectionBlock(
          title: l10n.logPeriodFlowIntensityTitle,
          child: _ChoiceChipWrap(
            options: const ['Spotting', 'Light', 'Medium', 'Heavy'],
            selected: draft.intensity,
            onSelected:
                (value) => onChanged(
                  draft.copyWith(
                    startDate: effectiveStartDate,
                    intensity: value,
                  ),
                ),
            labelBuilder: (value) => _periodIntensityLabel(l10n, value),
          ),
        ),
        _SectionBlock(
          title: l10n.logDailyFlowColourTitle,
          child: Wrap(
            spacing: 12,
            children: [
              _ColorSwatch(
                label: l10n.logPeriodColorBrownLabel,
                color: const Color(0xFFA5622A),
                selected: draft.colour == 'Brown',
                onTap:
                    () => onChanged(
                      draft.copyWith(
                        startDate: effectiveStartDate,
                        colour: 'Brown',
                      ),
                    ),
              ),
              _ColorSwatch(
                label: l10n.logPeriodColorRedLabel,
                color: const Color(0xFFD93D39),
                selected: draft.colour == 'Red',
                onTap:
                    () => onChanged(
                      draft.copyWith(
                        startDate: effectiveStartDate,
                        colour: 'Red',
                      ),
                    ),
              ),
              _ColorSwatch(
                label: l10n.logPeriodColorDarkLabel,
                color: const Color(0xFF862926),
                selected: draft.colour == 'Dark',
                onTap:
                    () => onChanged(
                      draft.copyWith(
                        startDate: effectiveStartDate,
                        colour: 'Dark',
                      ),
                    ),
              ),
              _ColorSwatch(
                label: l10n.logDailyColorPinkLabel,
                color: const Color(0xFFF0A3A3),
                selected: draft.colour == 'Pink',
                onTap:
                    () => onChanged(
                      draft.copyWith(
                        startDate: effectiveStartDate,
                        colour: 'Pink',
                      ),
                    ),
              ),
            ],
          ),
        ),
        _SectionBlock(
          title: l10n.logPeriodSymptomsTitle,
          child: _MultiChipWrap(
            options: const [
              'Cramps',
              'Bloating',
              'Headache',
              'Fatigue',
              'Back Pain',
              'Nausea',
            ],
            selected: draft.symptoms.toSet(),
            onToggle: (value) {
              final next = draft.symptoms.toSet();
              if (!next.add(value)) {
                next.remove(value);
              }
              onChanged(
                draft.copyWith(
                  startDate: effectiveStartDate,
                  symptoms: next.toList(),
                ),
              );
            },
            labelBuilder: (value) => _symptomLabel(l10n, value),
          ),
        ),
      ],
    );
  }
}

class _PeriodRangeBlock extends StatelessWidget {
  const _PeriodRangeBlock({
    required this.logDate,
    required this.startDate,
    required this.periodDay,
    required this.currentCycleDay,
    required this.periodLengthDays,
    required this.onStartDateChanged,
  });

  final DateTime logDate;
  final DateTime startDate;
  final int periodDay;
  final int? currentCycleDay;
  final int? periodLengthDays;
  final ValueChanged<DateTime> onStartDateChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final estimatedEnd =
        periodLengthDays == null
            ? null
            : startDate.add(Duration(days: periodLengthDays!.clamp(1, 14) - 1));

    return _SectionBlock(
      title: 'When did this period start?',
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: startDate,
            firstDate: logDate.subtract(const Duration(days: 14)),
            lastDate: logDate,
          );
          if (picked != null) {
            onStartDateChanged(DateTime(picked.year, picked.month, picked.day));
          }
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(dims.scaleWidth(14)),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: colors.textPrimary),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _periodRangeLabel(startDate, estimatedEnd),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontSize: dims.scaleText(13),
                        fontWeight: FontWeight.w800,
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
                        color: colors.textSecondary,
                        fontSize: dims.scaleText(11.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomsSection extends StatelessWidget {
  const _SymptomsSection({
    required this.draft,
    required this.notesController,
    required this.onChanged,
  });

  final SymptomsLogDraft draft;
  final TextEditingController notesController;
  final ValueChanged<SymptomsLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        _SectionBlock(
          title: l10n.logSymptomsMoodTitle,
          child: _ChoiceChipWrap(
            options: const [
              'Happy',
              'Calm',
              'Sad',
              'Anxious',
              'Irritable',
              'Energetic',
            ],
            selected: draft.mood,
            onSelected: (value) => onChanged(draft.copyWith(mood: value)),
            labelBuilder: (value) => _moodLabel(l10n, value),
          ),
        ),
        _SectionBlock(
          title: l10n.logSymptomsEnergyLevelTitle,
          trailing: Text('${draft.energyLevel ?? 5}/10'),
          child: _TouchAwareSlider(
            initialValue: draft.energyLevel?.toDouble() ?? 5,
            onChanged:
                (value) =>
                    onChanged(draft.copyWith(energyLevel: value.round())),
          ),
        ),
        _SectionBlock(
          title: l10n.logSymptomsPhysicalSymptomsTitle,
          child: _MultiChipWrap(
            options: const [
              'Cramps',
              'Bloating',
              'Headache',
              'Tender Breasts',
              'Fatigue',
              'Back Pain',
              'Acne',
              'Cravings',
            ],
            selected: draft.physical.toSet(),
            onToggle: (value) {
              final next = draft.physical.toSet();
              if (!next.add(value)) {
                next.remove(value);
              }
              onChanged(draft.copyWith(physical: next.toList()));
            },
            labelBuilder: (value) => _physicalSymptomLabel(l10n, value),
          ),
        ),
        _SectionBlock(
          title: l10n.logSymptomsPainLevelTitle,
          trailing: Text('${draft.painLevel ?? 5}/10'),
          child: _TouchAwareSlider(
            initialValue: draft.painLevel?.toDouble() ?? 5,
            onChanged:
                (value) => onChanged(draft.copyWith(painLevel: value.round())),
          ),
        ),
        _SectionBlock(
          title: l10n.logSymptomsSleepQualityTitle,
          child: _ChoiceChipWrap(
            options: const ['Poor', 'Fair', 'Good', 'Great'],
            selected: draft.sleepQuality,
            onSelected:
                (value) => onChanged(draft.copyWith(sleepQuality: value)),
            labelBuilder: (value) => _sleepQualityLabel(l10n, value),
          ),
        ),
        _SectionBlock(
          title: l10n.logNotesTitle,
          child: _NotesField(
            controller: notesController,
            hintText: l10n.logDailySymptomsNotesHint,
            onChanged: (value) => onChanged(draft.copyWith(notes: value)),
          ),
        ),
      ],
    );
  }
}

class _TemperatureSection extends StatelessWidget {
  const _TemperatureSection({
    required this.draft,
    required this.wearableConnected,
    required this.phaseRaw,
    required this.onChanged,
  });

  final TemperatureLogDraft draft;
  final bool wearableConnected;
  final String? phaseRaw;
  final ValueChanged<TemperatureLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final l10n = context.l10n;
    final displayValue = _displayTemperature(
      draft.temperatureCelsius,
      draft.displayUnit,
    );
    final warningText = _temperatureDraftWarning(draft);

    return Column(
      children: [
        if (wearableConnected) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(dims.scaleWidth(14)),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E9),
              borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            ),
            child: Text(l10n.logDailyWearableDetectedMessage),
          ),
          SizedBox(height: dims.scaleSpace(16)),
        ],
        _SectionBlock(
          title: l10n.logDailyBbtTitle,
          trailing: _UnitToggle(
            value: draft.displayUnit,
            onChanged: (value) => onChanged(draft.copyWith(displayUnit: value)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue:
                    displayValue == null ? '' : displayValue.toStringAsFixed(1),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  suffixText: '°${draft.displayUnit}',
                  hintText: '36.7',
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed == null) {
                    return;
                  }
                  onChanged(
                    draft.copyWith(
                      temperatureCelsius:
                          draft.displayUnit == 'F'
                              ? (parsed - 32) * 5 / 9
                              : parsed,
                    ),
                  );
                },
              ),
              SizedBox(height: dims.scaleSpace(10)),
              Text(_temperatureRangeLabel(l10n, phaseRaw)),
            ],
          ),
        ),
        _SectionBlock(
          title: l10n.logTemperatureMeasurementTimeTitle,
          child: Column(
            children: [
              _TimeButton(
                value: draft.measuredAt,
                fallbackLabel: l10n.logDailySelectTimeLabel,
                onTap: () async {
                  final selected = await showTimePicker(
                    context: context,
                    initialTime: draft.measuredAt ?? TimeOfDay.now(),
                  );
                  if (selected == null) return;
                  onChanged(draft.copyWith(measuredAt: selected));
                },
              ),
              SizedBox(height: dims.scaleSpace(12)),
              _ChoiceChipWrap(
                options: const ['oral', 'vaginal', 'wearable', 'unknown'],
                selected: draft.method,
                onSelected: (value) => onChanged(draft.copyWith(method: value)),
                labelBuilder:
                    (value) => switch (value) {
                      'oral' => 'Oral',
                      'vaginal' => 'Vaginal',
                      'wearable' => 'Wearable',
                      _ => 'Unknown',
                    },
              ),
            ],
          ),
        ),
        _SectionBlock(
          title: l10n.logTemperatureQualityFactorsTitle,
          child: Column(
            children: [
              SwitchListTile(
                value: draft.sameTimeAsYesterday,
                onChanged:
                    (value) =>
                        onChanged(draft.copyWith(sameTimeAsYesterday: value)),
                title: Text(l10n.logTemperatureSameTimeLabel),
              ),
              SwitchListTile(
                value: draft.uninterruptedSleep,
                onChanged:
                    (value) =>
                        onChanged(draft.copyWith(uninterruptedSleep: value)),
                title: Text(l10n.logTemperatureSleepLabel),
              ),
              SwitchListTile(
                value: draft.measuredBeforeGettingUp,
                onChanged:
                    (value) => onChanged(
                      draft.copyWith(measuredBeforeGettingUp: value),
                    ),
                title: Text(l10n.logTemperatureBeforeGettingUpLabel),
              ),
              SwitchListTile(
                value: draft.illnessFlag,
                onChanged:
                    (value) => onChanged(draft.copyWith(illnessFlag: value)),
                title: const Text('Illness or fever?'),
              ),
              SwitchListTile(
                value: draft.alcoholFlag,
                onChanged:
                    (value) => onChanged(draft.copyWith(alcoholFlag: value)),
                title: const Text('Alcohol last night?'),
              ),
              SwitchListTile(
                value: draft.stressFlag,
                onChanged:
                    (value) => onChanged(draft.copyWith(stressFlag: value)),
                title: const Text('High stress?'),
              ),
              SwitchListTile(
                value: draft.travelFlag,
                onChanged:
                    (value) => onChanged(draft.copyWith(travelFlag: value)),
                title: const Text('Recent travel?'),
              ),
            ],
          ),
        ),
        if (warningText != null)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: dims.scaleSpace(16)),
            padding: EdgeInsets.all(dims.scaleWidth(14)),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E9),
              borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            ),
            child: Text(warningText),
          ),
      ],
    );
  }
}

class _LhTestSection extends StatelessWidget {
  const _LhTestSection({
    required this.draft,
    required this.onChanged,
    required this.onSelectPhoto,
    required this.onProcessPhoto,
  });

  final LhTestLogDraft draft;
  final ValueChanged<LhTestLogDraft> onChanged;
  final Future<LhTestLogDraft?> Function(LhTestLogDraft current) onSelectPhoto;
  final Future<LhTestLogDraft?> Function(LhTestLogDraft current) onProcessPhoto;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final l10n = context.l10n;
    final hasImage = draft.imageUrl != null && draft.imageUrl!.isNotEmpty;
    final hasResult = draft.result != null && draft.result!.isNotEmpty;
    return Column(
      children: [
        _SectionBlock(
          title: l10n.logDailyEntryMethodTitle,
          child: _ChoiceChipWrap(
            options: const ['photo', 'manual'],
            selected: draft.method == 'photo' ? 'photo' : 'manual',
            onSelected: (value) {
              onChanged(
                draft.copyWith(
                  method: value,
                  analysisStatus:
                      value == 'photo' ? draft.analysisStatus : null,
                  analysisMessage:
                      value == 'photo' ? draft.analysisMessage : null,
                ),
              );
            },
            labelBuilder: (value) => _lhEntryMethodLabel(l10n, value),
          ),
        ),
        if (draft.method == 'photo')
          _SectionBlock(
            title: l10n.logDailyPhotoAnalysisTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(dims.scaleWidth(16)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E9),
                    borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                    border: Border.all(color: const Color(0xFFE6D4CA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasImage
                            ? l10n.logDailyPreviewStripMessage
                            : l10n.logDailyTakeOrUploadStripMessage,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: dims.scaleSpace(8)),
                      Text(
                        hasImage
                            ? l10n.logDailyAnalysisBeforeSaveMessage
                            : l10n.logDailyStripPhotoTipsMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(height: dims.scaleSpace(12)),
                      if (hasImage) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            dims.scaleRadius(16),
                          ),
                          child: Image.file(
                            File(draft.imageUrl!),
                            height: dims.scaleHeight(180),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                height: dims.scaleHeight(120),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(
                                    dims.scaleRadius(16),
                                  ),
                                ),
                                child: Text(l10n.logDailyCouldNotPreviewImage),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(12)),
                      ],
                      Wrap(
                        spacing: dims.scaleWidth(10),
                        runSpacing: dims.scaleSpace(10),
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final result = await onSelectPhoto(draft);
                              if (result != null) {
                                onChanged(result);
                              }
                            },
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: Text(
                              hasImage
                                  ? l10n.logDailyChooseAnotherImageLabel
                                  : l10n.logDailyTakeOrUploadStripPhotoLabel,
                            ),
                          ),
                          if (hasImage)
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                final result = await onProcessPhoto(draft);
                                if (result != null) {
                                  onChanged(result);
                                }
                              },
                              icon: const Icon(Icons.science_rounded),
                              label: Text(l10n.logDailyProcessImageLabel),
                            ),
                        ],
                      ),
                      if (hasImage) ...[
                        SizedBox(height: dims.scaleSpace(12)),
                        _LhAnalysisResultCard(draft: draft),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        _SectionBlock(
          title:
              draft.method == 'photo'
                  ? l10n.logDailyAnalysisResultTitle
                  : l10n.logDailyResultTitle,
          child: _ChoiceChipWrap(
            options: const ['negative', 'low', 'high', 'peak'],
            selected: hasResult ? draft.result : null,
            onSelected:
                (value) => onChanged(
                  draft.copyWith(
                    result: value,
                    analysisStatus:
                        draft.method == 'photo'
                            ? (draft.analysisStatus ?? 'ready')
                            : draft.analysisStatus,
                  ),
                ),
            labelBuilder: (value) => _titleCaseLhResult(l10n, value),
          ),
        ),
        _SectionBlock(
          title: l10n.logDailyTimeOfTestTitle,
          trailing: Text(
            l10n.logDailyBestTestedTimeHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          child: _TimeButton(
            value: draft.testedAt,
            fallbackLabel: l10n.logDailySetTimeLabel,
            onTap: () async {
              final selected = await showTimePicker(
                context: context,
                initialTime: draft.testedAt ?? TimeOfDay.now(),
              );
              if (selected == null) return;
              onChanged(draft.copyWith(testedAt: selected));
            },
          ),
        ),
      ],
    );
  }
}

class _LhAnalysisResultCard extends StatelessWidget {
  const _LhAnalysisResultCard({required this.draft});

  final LhTestLogDraft draft;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isReady = draft.analysisStatus == 'ready';
    final hasMessage =
        draft.analysisMessage != null && draft.analysisMessage!.isNotEmpty;
    final hasResult = draft.result != null && draft.result!.isNotEmpty;
    final background =
        isReady ? const Color(0xFFE9F6EF) : const Color(0xFFFFF4E8);
    final border = isReady ? const Color(0xFFB6DDC4) : const Color(0xFFE7CFB5);
    final accent = isReady ? const Color(0xFF2E7D5A) : const Color(0xFF9C5E1A);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(14)),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isReady
                ? l10n.logDailyAnalysisReadyTitle
                : l10n.logDailyAnalysisNeededTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          if (hasResult) ...[
            SizedBox(height: dims.scaleSpace(6)),
            Text(
              l10n.logDailySuggestedResultLabel(
                _titleCaseLhResult(l10n, draft.result),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (hasMessage) ...[
            SizedBox(height: dims.scaleSpace(6)),
            Text(draft.analysisMessage!, style: theme.textTheme.bodySmall),
          ],
          if (!hasResult) ...[
            SizedBox(height: dims.scaleSpace(6)),
            Text(
              l10n.logDailyProcessImageBeforeSaveMessage,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(16),
            vertical: dims.scaleSpace(16),
          ),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.textPrimary),
              SizedBox(width: dims.scaleWidth(12)),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CervicalMucusSection extends StatelessWidget {
  const _CervicalMucusSection({
    required this.draft,
    required this.notesController,
    required this.onChanged,
  });

  final CervicalMucusLogDraft draft;
  final TextEditingController notesController;
  final ValueChanged<CervicalMucusLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final l10n = context.l10n;
    return Column(
      children: [
        _SectionBlock(
          title: l10n.logDailyTypeTitle,
          trailing:
              draft.type == 'Egg White (Fertile)'
                  ? _HeaderBadge(label: l10n.logDailyFertileSignDetectedLabel)
                  : null,
          child: _ChoiceChipWrap(
            options: const [
              'Dry/None',
              'Sticky',
              'Creamy',
              'Egg White (Fertile)',
              'Watery',
            ],
            selected: draft.type,
            onSelected: (value) => onChanged(draft.copyWith(type: value)),
            labelBuilder: (value) => _mucusTypeLabel(l10n, value),
          ),
        ),
        _SectionBlock(
          title: l10n.logAmountTitle,
          child: _ChoiceChipWrap(
            options: [
              l10n.logAmountLightLabel,
              l10n.logAmountModerateLabel,
              l10n.logAmountHeavyLabel,
            ],
            selected: draft.amount,
            onSelected: (value) => onChanged(draft.copyWith(amount: value)),
          ),
        ),
        _SectionBlock(
          title: l10n.logNotesTitle,
          child: _NotesField(
            controller: notesController,
            hintText: l10n.logDailyAnythingElseHint,
            onChanged: (value) => onChanged(draft.copyWith(notes: value)),
          ),
        ),
        SizedBox(height: dims.scaleSpace(2)),
      ],
    );
  }
}

class _IntimacySection extends StatelessWidget {
  const _IntimacySection({
    required this.draft,
    required this.notesController,
    required this.onChanged,
  });

  final IntimacyLogDraft draft;
  final TextEditingController notesController;
  final ValueChanged<IntimacyLogDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final l10n = context.l10n;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(dims.scaleWidth(14)),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E9),
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
          ),
          child: Text(l10n.logDailyPrivateTrackingMessage),
        ),
        SizedBox(height: dims.scaleSpace(16)),
        _SectionBlock(
          title: l10n.logIntimacyActivityTitle,
          child: _ChoiceChipWrap(
            options: const [
              'Unprotected',
              'Protected',
              'Birth Control',
              'Other',
            ],
            selected: draft.activity,
            onSelected: (value) => onChanged(draft.copyWith(activity: value)),
            labelBuilder: (value) => _intimacyActivityLabel(l10n, value),
          ),
        ),
        _SectionBlock(
          title: l10n.logDailyAdditionalDetailsTitle,
          child: _MultiChipWrap(
            options: const ['Orgasm', 'Painful', 'Dry', 'Bleeding'],
            selected: draft.details.toSet(),
            onToggle: (value) {
              final next = draft.details.toSet();
              if (!next.add(value)) {
                next.remove(value);
              }
              onChanged(draft.copyWith(details: next.toList()));
            },
            labelBuilder: (value) => _intimacyDetailLabel(l10n, value),
          ),
        ),
        _SectionBlock(
          title: l10n.logDailyTimeTitle,
          child: _TimeButton(
            value: draft.time,
            fallbackLabel: l10n.logDailyOptionalLabel,
            onTap: () async {
              final selected = await showTimePicker(
                context: context,
                initialTime: draft.time ?? TimeOfDay.now(),
              );
              if (selected == null) return;
              onChanged(draft.copyWith(time: selected));
            },
          ),
        ),
        _SectionBlock(
          title: l10n.logNotesTitle,
          child: _NotesField(
            controller: notesController,
            hintText: l10n.logDailyOptionalNoteHint,
            onChanged: (value) => onChanged(draft.copyWith(notes: value)),
          ),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.value,
    required this.fallbackLabel,
    required this.onTap,
  });

  final TimeOfDay? value;
  final String fallbackLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(double.infinity, dims.scaleHeight(52)),
        alignment: Alignment.centerLeft,
      ),
      child: Text(
        value == null ? fallbackLabel : _formatTimeDisplay(context, value!),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      minLines: 4,
      decoration: InputDecoration(hintText: hintText),
      onChanged: onChanged,
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: [value == 'C', value == 'F'],
      onPressed: (index) => onChanged(index == 0 ? 'C' : 'F'),
      children: const [Text('°C'), Text('°F')],
    );
  }
}

class _TouchAwareSlider extends StatefulWidget {
  const _TouchAwareSlider({
    required this.initialValue,
    required this.onChanged,
  });

  final double initialValue;
  final ValueChanged<double> onChanged;

  @override
  State<_TouchAwareSlider> createState() => _TouchAwareSliderState();
}

class _TouchAwareSliderState extends State<_TouchAwareSlider> {
  late double _value = widget.initialValue;

  @override
  void didUpdateWidget(covariant _TouchAwareSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _value = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      min: 1,
      max: 10,
      divisions: 9,
      value: _value,
      onChanged: (value) {
        setState(() => _value = value);
        widget.onChanged(value);
      },
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(dims.scaleWidth(10)),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xFF8A5A48) : const Color(0xFFD9D1CB),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dims.scaleWidth(26),
              height: dims.scaleWidth(26),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(height: dims.scaleSpace(6)),
            Text(label),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmDiscardChanges(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.logDiscardChangesTitle),
        content: Text(l10n.logDiscardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.logStayLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.logLeaveLabel),
          ),
        ],
      );
    },
  );
}

String _sectionTitle(AppLocalizations l10n, LogSection section) {
  return switch (section) {
    LogSection.period => l10n.logSectionPeriodTitle,
    LogSection.symptoms => l10n.logSectionSymptomsTitle,
    LogSection.temperature => l10n.logSectionTemperatureTitle,
    LogSection.lhTest => l10n.logSectionLhTestTitle,
    LogSection.cervicalMucus => l10n.logSectionCervicalMucusTitle,
    LogSection.intimacy => l10n.logSectionIntimacyTitle,
  };
}

String _sectionSubtitle(
  BuildContext context,
  DailyLogScreenState state,
  LogSection section, {
  required bool isDirty,
  required bool isSaved,
}) {
  final l10n = context.l10n;
  if (isDirty) {
    return l10n.logUnsavedChangesLabel;
  }
  if (isSaved) {
    return _savedSummary(context, state.draft, section);
  }
  return switch (section) {
    LogSection.period => l10n.logSectionPeriodSubtitle,
    LogSection.symptoms => l10n.logSectionSymptomsSubtitle,
    LogSection.temperature => l10n.logSectionTemperatureSubtitle,
    LogSection.lhTest => l10n.logSectionLhTestSubtitle,
    LogSection.cervicalMucus => l10n.logSectionCervicalMucusSubtitle,
    LogSection.intimacy => l10n.logSectionIntimacySubtitle,
  };
}

String _savedSummary(
  BuildContext context,
  DailyLogDraft draft,
  LogSection section,
) {
  final l10n = context.l10n;
  return switch (section) {
    LogSection.period => [
      if (draft.period?.intensity != null)
        _periodIntensityLabel(l10n, draft.period!.intensity!),
      if (draft.period?.colour != null)
        _periodColorLabel(l10n, draft.period!.colour!),
      if ((draft.period?.symptoms.isNotEmpty ?? false))
        draft.period!.symptoms
            .take(2)
            .map((value) => _symptomLabel(l10n, value))
            .join(', '),
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
    LogSection.symptoms => [
      if (draft.symptoms?.mood != null) _moodLabel(l10n, draft.symptoms!.mood!),
      if (draft.symptoms?.energyLevel != null)
        l10n.logSavedEnergyLabel(draft.symptoms!.energyLevel!),
      if (draft.symptoms?.painLevel != null)
        l10n.logSavedPainLabel(draft.symptoms!.painLevel!),
      if (draft.symptoms?.sleepQuality != null)
        _sleepQualityLabel(l10n, draft.symptoms!.sleepQuality!),
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
    LogSection.temperature => [
      if (draft.temperature?.temperatureCelsius != null)
        '${draft.temperature!.temperatureCelsius!.toStringAsFixed(1)} °C',
      if (draft.temperature?.measuredAt != null)
        _formatTimeDisplay(context, draft.temperature!.measuredAt!),
    ].join(' · '),
    LogSection.lhTest => [
      _titleCaseLhResult(l10n, draft.lhTest?.result),
      if (draft.lhTest?.testedAt != null)
        _formatTimeDisplay(context, draft.lhTest!.testedAt!),
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
    LogSection.cervicalMucus => [
      if (draft.cervicalMucus?.type != null)
        _mucusTypeLabel(l10n, draft.cervicalMucus!.type!),
      if (draft.cervicalMucus?.amount != null)
        _periodIntensityLabel(l10n, draft.cervicalMucus!.amount!),
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
    LogSection.intimacy => l10n.logLoggedPrivatelyLabel,
  };
}

bool _canSaveSection(DailyLogScreenState state, LogSection section) {
  if (!_draftSectionHasData(state.draft, section)) {
    return false;
  }
  if (section != LogSection.lhTest) {
    return true;
  }
  final lh = state.draft.lhTest;
  if (lh == null) {
    return false;
  }
  if (lh.method != 'photo') {
    return true;
  }
  return (lh.imageUrl?.isNotEmpty ?? false) && (lh.result?.isNotEmpty ?? false);
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

bool _draftSectionHasData(DailyLogDraft draft, LogSection section) {
  return switch (section) {
    LogSection.period => draft.period?.hasData ?? false,
    LogSection.symptoms => draft.symptoms?.hasData ?? false,
    LogSection.temperature => draft.temperature?.hasData ?? false,
    LogSection.lhTest => draft.lhTest?.hasData ?? false,
    LogSection.cervicalMucus => draft.cervicalMucus?.hasData ?? false,
    LogSection.intimacy => draft.intimacy?.hasData ?? false,
  };
}

bool _isWithinFertileWindow(dynamic home) {
  final now = DateTime.now();
  final start = home?.fertility.fertileWindowStart as DateTime?;
  final end = home?.fertility.fertileWindowEnd as DateTime?;
  if (start == null || end == null) {
    return false;
  }
  final day = DateTime(now.year, now.month, now.day);
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  return !day.isBefore(startDay) && !day.isAfter(endDay);
}

String _periodIntensityLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Spotting' => l10n.logPeriodFlowSpottingLabel,
    'Light' => l10n.logAmountLightLabel,
    'Medium' => l10n.logPeriodFlowMediumLabel,
    'Heavy' => l10n.logAmountHeavyLabel,
    _ => value,
  };
}

String _symptomLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Cramps' => l10n.logSymptomCrampsLabel,
    'Bloating' => l10n.logSymptomBloatingLabel,
    'Headache' => l10n.logSymptomHeadacheLabel,
    'Fatigue' => l10n.logSymptomFatigueLabel,
    'Back Pain' => l10n.logSymptomBackPainLabel,
    'Nausea' => l10n.logSymptomNauseaLabel,
    _ => value,
  };
}

String _periodColorLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Brown' => l10n.logPeriodColorBrownLabel,
    'Red' => l10n.logPeriodColorRedLabel,
    'Dark' => l10n.logPeriodColorDarkLabel,
    'Pink' => l10n.logDailyColorPinkLabel,
    _ => value,
  };
}

String _physicalSymptomLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Tender Breasts' => l10n.logDailySymptomTenderBreastsLabel,
    'Acne' => l10n.logSymptomAcneLabel,
    'Cravings' => l10n.logSymptomCravingsLabel,
    _ => _symptomLabel(l10n, value),
  };
}

String _moodLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Happy' => l10n.logMoodHappyLabel,
    'Calm' => l10n.logMoodCalmLabel,
    'Sad' => l10n.logMoodSadLabel,
    'Anxious' => l10n.logMoodAnxiousLabel,
    'Irritable' => l10n.logMoodIrritableLabel,
    'Energetic' => l10n.logMoodEnergeticLabel,
    _ => value,
  };
}

String _sleepQualityLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Poor' => l10n.logSleepPoorLabel,
    'Fair' => l10n.logSleepFairLabel,
    'Good' => l10n.logSleepGoodLabel,
    'Great' => l10n.logSleepGreatLabel,
    _ => value,
  };
}

String _lhEntryMethodLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'photo' => l10n.logDailyPhotoAnalysisLabel,
    'manual' => l10n.logDailyManualLabel,
    _ => value,
  };
}

String _mucusTypeLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Dry/None' => l10n.logDailyMucusDryNoneLabel,
    'Sticky' => l10n.logMucusStickyLabel,
    'Creamy' => l10n.logMucusCreamyLabel,
    'Egg White (Fertile)' => l10n.logMucusEggWhiteLabel,
    'Watery' => l10n.logMucusWateryLabel,
    _ => value,
  };
}

String _intimacyActivityLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Unprotected' => l10n.logIntimacyUnprotectedLabel,
    'Protected' => l10n.logIntimacyProtectedLabel,
    'Birth Control' => l10n.logIntimacyBirthControlLabel,
    'Other' => l10n.logIntimacyOtherLabel,
    _ => value,
  };
}

String _intimacyDetailLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'Orgasm' => l10n.logIntimacyDetailOrgasmLabel,
    'Painful' => l10n.logIntimacyDetailPainfulLabel,
    'Dry' => l10n.logIntimacyDetailDryLabel,
    'Bleeding' => l10n.logIntimacyDetailBleedingLabel,
    _ => value,
  };
}

double? _displayTemperature(double? celsius, String unit) {
  if (celsius == null) {
    return null;
  }
  return unit == 'F' ? ((celsius * 9 / 5) + 32) : celsius;
}

String _temperatureRangeLabel(AppLocalizations l10n, String? phaseRaw) {
  return switch ((phaseRaw ?? '').trim().toLowerCase()) {
    'luteal' => l10n.logTemperatureLutealRangeLabel,
    'ovulation' || 'ovulatory' => l10n.logTemperatureOvulationRangeLabel,
    'menstrual' || 'menstruation' => l10n.logTemperatureMenstrualRangeLabel,
    _ => l10n.logTemperatureFollicularRangeLabel,
  };
}

String? _temperatureDraftWarning(TemperatureLogDraft draft) {
  final measuredAt = draft.measuredAt;
  if (measuredAt != null && (measuredAt.hour < 3 || measuredAt.hour >= 7)) {
    return 'This temperature was not collected between 3am and 7am. '
        'Vyla can save it for your records, but it will not affect ovulation prediction.';
  }
  if (draft.temperatureCelsius != null && draft.temperatureCelsius! >= 37.5) {
    return 'This temperature looks higher than a normal resting BBT reading. '
        'It may reflect fever, illness, or a late measurement and may be excluded from ovulation prediction.';
  }
  if (draft.illnessFlag || draft.alcoholFlag || draft.travelFlag) {
    return 'This reading may be excluded from ovulation prediction because illness, alcohol, or travel can distort resting temperature.';
  }
  return null;
}

String _titleCaseLhResult(AppLocalizations l10n, String? value) {
  return switch ((value ?? '').trim().toLowerCase()) {
    'negative' => l10n.logDailyLhNegativeLabel,
    'low' => l10n.logScaleLowLabel,
    'high' => l10n.logScaleHighLabel,
    'peak' => l10n.logDailyLhPeakLabel,
    _ => '',
  };
}

String? _titleCase(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _titleCasePhrase(String value) => _titleCase(value) ?? value;

String _formatTodayLogDate(BuildContext context, DateTime value) {
  return AppFormatters.formatDateLong(
    value,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

String _periodRangeLabel(DateTime start, DateTime? end) {
  if (end == null || _isSameDay(start, end)) {
    return 'Started ${_monthDay(start)}';
  }
  return '${_monthDay(start)} - ${_monthDay(end)}';
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

DateTime _dateFromRoute(BuildContext context) {
  final raw = GoRouterState.of(context).uri.queryParameters['date'];
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  final value = parsed ?? DateTime.now();
  return DateTime(value.year, value.month, value.day);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatTimeDisplay(BuildContext context, TimeOfDay value) {
  final dateTime = DateTime(2000, 1, 1, value.hour, value.minute);
  return AppFormatters.formatTime(
    dateTime,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

String _formatTime(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
