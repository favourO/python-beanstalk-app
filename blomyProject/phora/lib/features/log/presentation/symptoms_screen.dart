import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/cycle/data/cycle_repository.dart';
import 'package:phora/features/log/presentation/log_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SymptomsScreen extends ConsumerStatefulWidget {
  const SymptomsScreen({super.key});

  @override
  ConsumerState<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends ConsumerState<SymptomsScreen> {
  double _energyLevel = 7;
  double _painLevel = 3;
  String _selectedMood = 'Happy';
  String _sleepQuality = 'Good';
  final Set<String> _selectedSymptoms = {'Bloating', 'Fatigue'};
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final gradients = context.phora.gradients;
    final dims = context.dims;
    final l10n = context.l10n;

    return LogPageScaffold(
      header: LogPageHeader(title: l10n.logSymptomsTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: dims.scaleSpace(8)),
          _SymptomsSectionCard(
            title: l10n.logSymptomsEnergyLevelTitle,
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: dims.scaleHeight(8),
                    activeTrackColor: colors.accentPrimary,
                    inactiveTrackColor: colors.phaseOvulatory.withValues(
                      alpha: 0.65,
                    ),
                    thumbColor: Colors.white,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: dims.scaleWidth(10),
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    min: 0,
                    max: 10,
                    divisions: 10,
                    value: _energyLevel,
                    onChanged: (value) => setState(() => _energyLevel = value),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(2)),
                Row(
                  children: [
                    Text(
                      l10n.logScaleLowLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: dims.scaleText(14),
                        color: colors.textTertiary,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${_energyLevel.round()}/10',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontSize: dims.scaleText(16),
                            fontWeight: FontWeight.w800,
                            color: colors.accentPrimary,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      l10n.logScaleHighLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: dims.scaleText(14),
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _SymptomsSectionCard(
            title: l10n.logSymptomsMoodTitle,
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: dims.scaleWidth(12),
              mainAxisSpacing: dims.scaleSpace(12),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.82,
              children: [
                _MoodTile(
                  emoji: '🙂',
                  label: l10n.logMoodHappyLabel,
                  selected: _selectedMood == 'Happy',
                  selectedColor: const Color(0xFF69D4A1),
                  onTap: () => setState(() => _selectedMood = 'Happy'),
                ),
                _MoodTile(
                  emoji: '😢',
                  label: l10n.logMoodSadLabel,
                  selected: _selectedMood == 'Sad',
                  selectedColor: colors.accentInfo,
                  onTap: () => setState(() => _selectedMood = 'Sad'),
                ),
                _MoodTile(
                  emoji: '😰',
                  label: l10n.logMoodAnxiousLabel,
                  selected: _selectedMood == 'Anxious',
                  selectedColor: colors.accentWarning,
                  onTap: () => setState(() => _selectedMood = 'Anxious'),
                ),
                _MoodTile(
                  emoji: '😤',
                  label: l10n.logMoodIrritableLabel,
                  selected: _selectedMood == 'Irritable',
                  selectedColor: colors.accentDanger,
                  onTap: () => setState(() => _selectedMood = 'Irritable'),
                ),
                _MoodTile(
                  emoji: '😌',
                  label: l10n.logMoodCalmLabel,
                  selected: _selectedMood == 'Calm',
                  selectedColor: colors.phaseOvulatory,
                  onTap: () => setState(() => _selectedMood = 'Calm'),
                ),
                _MoodTile(
                  emoji: '⚡',
                  label: l10n.logMoodEnergeticLabel,
                  selected: _selectedMood == 'Energetic',
                  selectedColor: colors.phaseLuteal,
                  onTap: () => setState(() => _selectedMood = 'Energetic'),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _SymptomsSectionCard(
            title: l10n.logSymptomsPhysicalSymptomsTitle,
            child: Wrap(
              spacing: dims.scaleWidth(10),
              runSpacing: dims.scaleSpace(10),
              children:
                  [
                    'Cramps',
                    'Bloating',
                    'Headache',
                    'Breast Tenderness',
                    'Nausea',
                    'Fatigue',
                    'Back Pain',
                    'Acne',
                    'Cravings',
                  ].map((symptom) {
                    final isSelected = _selectedSymptoms.contains(symptom);
                    return _SymptomChip(
                      label: _symptomLabel(l10n, symptom),
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedSymptoms.remove(symptom);
                          } else {
                            _selectedSymptoms.add(symptom);
                          }
                        });
                      },
                    );
                  }).toList(),
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _SymptomsSectionCard(
            title: l10n.logSymptomsPainLevelTitle,
            child: Column(
              children: [
                _GradientTrack(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF69D4A1),
                      const Color(0xFFF4C84D),
                      const Color(0xFFF07A7A),
                    ],
                  ),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: dims.scaleHeight(8),
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: dims.scaleWidth(10),
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                      trackShape: const RectangularSliderTrackShape(),
                    ),
                    child: Slider(
                      min: 0,
                      max: 10,
                      divisions: 10,
                      value: _painLevel,
                      onChanged: (value) => setState(() => _painLevel = value),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(10)),
                Row(
                  children: [
                    Text(
                      l10n.logScaleNoneLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: dims.scaleText(14),
                        color: colors.textTertiary,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${_painLevel.round()}/10',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontSize: dims.scaleText(16),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF4C84D),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      l10n.logScaleSevereLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: dims.scaleText(14),
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _SymptomsSectionCard(
            title: l10n.logSymptomsSleepQualityTitle,
            child: Row(
              children: [
                Expanded(
                  child: _SleepTile(
                    emoji: '😴',
                    label: l10n.logSleepPoorLabel,
                    selected: _sleepQuality == 'Poor',
                    onTap: () => setState(() => _sleepQuality = 'Poor'),
                  ),
                ),
                SizedBox(width: dims.scaleWidth(10)),
                Expanded(
                  child: _SleepTile(
                    emoji: '😐',
                    label: l10n.logSleepFairLabel,
                    selected: _sleepQuality == 'Fair',
                    onTap: () => setState(() => _sleepQuality = 'Fair'),
                  ),
                ),
                SizedBox(width: dims.scaleWidth(10)),
                Expanded(
                  child: _SleepTile(
                    emoji: '😊',
                    label: l10n.logSleepGoodLabel,
                    selected: _sleepQuality == 'Good',
                    onTap: () => setState(() => _sleepQuality = 'Good'),
                  ),
                ),
                SizedBox(width: dims.scaleWidth(10)),
                Expanded(
                  child: _SleepTile(
                    emoji: '😴',
                    label: l10n.logSleepGreatLabel,
                    selected: _sleepQuality == 'Great',
                    onTap: () => setState(() => _sleepQuality = 'Great'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _SymptomsSectionCard(
            title: l10n.logNotesTitle,
            child: Container(
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                border: Border.all(color: colors.border),
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 5,
                minLines: 5,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(15),
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: l10n.logSymptomsNotesHint,
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: dims.scaleText(15),
                    color: colors.textTertiary,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(dims.scaleWidth(18)),
                ),
              ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(26)),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradients.primary),
              borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                onTap:
                    _isSaving
                        ? null
                        : () async {
                          setState(() => _isSaving = true);
                          try {
                            await ref
                                .read(cycleRepositoryProvider)
                                .logSymptoms(
                                  logDate: DateTime.now(),
                                  symptoms:
                                      _selectedSymptoms
                                          .map(_normalizeSymptom)
                                          .toList(),
                                  severity: _severityFromPain(_painLevel),
                                  notes: _notesController.text.trim(),
                                  metadata: {
                                    'energy_level': _energyDescriptor(
                                      _energyLevel,
                                    ),
                                    'energy_score': _energyLevel.round(),
                                    'pain_score': _painLevel.round(),
                                    'mood': _selectedMood.toLowerCase(),
                                    'sleep_quality':
                                        _sleepQuality.toLowerCase(),
                                  },
                                );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.logSymptomsSaved)),
                            );
                            context.go('/log');
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          } finally {
                            if (context.mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(18)),
                  child: Center(
                    child: Text(
                      _isSaving ? l10n.savingLabel : l10n.saveSymptomsLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: dims.scaleText(16),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _symptomLabel(dynamic l10n, String symptom) {
    switch (symptom) {
      case 'Cramps':
        return l10n.logSymptomCrampsLabel;
      case 'Bloating':
        return l10n.logSymptomBloatingLabel;
      case 'Headache':
        return l10n.logSymptomHeadacheLabel;
      case 'Breast Tenderness':
        return l10n.logSymptomBreastTendernessLabel;
      case 'Nausea':
        return l10n.logSymptomNauseaLabel;
      case 'Fatigue':
        return l10n.logSymptomFatigueLabel;
      case 'Back Pain':
        return l10n.logSymptomBackPainLabel;
      case 'Acne':
        return l10n.logSymptomAcneLabel;
      case 'Cravings':
        return l10n.logSymptomCravingsLabel;
      default:
        return symptom;
    }
  }
}

String _normalizeSymptom(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}

String _severityFromPain(double painLevel) {
  if (painLevel >= 7) return 'severe';
  if (painLevel >= 4) return 'moderate';
  if (painLevel >= 1) return 'mild';
  return 'none';
}

String _energyDescriptor(double energyLevel) {
  if (energyLevel <= 3) return 'low';
  if (energyLevel <= 7) return 'medium';
  return 'high';
}

class _SymptomsSectionCard extends StatelessWidget {
  const _SymptomsSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(20)),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: dims.scaleText(18),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          child,
        ],
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final Color selectedColor;
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
          decoration: BoxDecoration(
            color: selected ? selectedColor : colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(color: selected ? selectedColor : colors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: TextStyle(fontSize: dims.scaleText(28))),
              SizedBox(height: dims.scaleSpace(14)),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(15),
                  color: selected ? Colors.white : colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomChip extends StatelessWidget {
  const _SymptomChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(18),
            vertical: dims.scaleSpace(12),
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDF577E) : colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            border: Border.all(
              color: selected ? const Color(0xFFDF577E) : colors.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: dims.scaleText(14),
              color: selected ? Colors.white : colors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientTrack extends StatelessWidget {
  const _GradientTrack({required this.gradient, required this.child});

  final Gradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: child,
    );
  }
}

class _SleepTile extends StatelessWidget {
  const _SleepTile({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
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
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(18)),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDF577E) : colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(
              color: selected ? const Color(0xFFDF577E) : colors.border,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: TextStyle(fontSize: dims.scaleText(22))),
              SizedBox(height: dims.scaleSpace(10)),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(14),
                  color: selected ? Colors.white : colors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
