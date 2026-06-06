import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/log/presentation/log_ui.dart';
import 'package:phora/features/sensor/data/sensor_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TemperatureScreen extends ConsumerStatefulWidget {
  const TemperatureScreen({super.key});

  @override
  ConsumerState<TemperatureScreen> createState() => _TemperatureScreenState();
}

class _TemperatureScreenState extends ConsumerState<TemperatureScreen> {
  double _temperature = 36.7;
  String _unit = 'C';
  TimeOfDay _measuredAt = const TimeOfDay(hour: 6, minute: 30);
  String _method = 'oral';
  bool _sameTime = true;
  bool _uninterruptedSleep = true;
  bool _measuredBeforeGettingUp = true;
  bool _illnessFlag = false;
  bool _alcoholFlag = false;
  bool _stressFlag = false;
  bool _travelFlag = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final gradients = context.phora.gradients;
    final dims = context.dims;
    final l10n = context.l10n;

    return LogPageScaffold(
      header: LogPageHeader(title: l10n.logTemperatureTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: dims.scaleSpace(8)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(dims.scaleWidth(20)),
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
              border: Border.all(
                color: colors.phaseOvulatory.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: dims.scaleWidth(36),
                  height: dims.scaleWidth(36),
                  decoration: BoxDecoration(
                    color: colors.bgSurface,
                    borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '⌚',
                    style: TextStyle(fontSize: dims.scaleText(18)),
                  ),
                ),
                SizedBox(width: dims.scaleWidth(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.logTemperatureWatchConnectedTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: dims.scaleText(16),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(6)),
                      Text(
                        l10n.logTemperatureWatchConnectedSubtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: dims.scaleText(14),
                          color: colors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _TemperatureSectionCard(
            title: l10n.logTemperatureBbtTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.scaleWidth(18),
                    vertical: dims.scaleSpace(14),
                  ),
                  decoration: BoxDecoration(
                    color: colors.bgSurface,
                    borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _temperature.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall?.copyWith(
                            fontSize: dims.scaleText(32),
                            fontWeight: FontWeight.w800,
                            letterSpacing: dims.scaleWidth(2),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          _StepperButton(
                            icon: Icons.keyboard_arrow_up_rounded,
                            onTap: () {
                              setState(() {
                                _temperature += _unit == 'C' ? 0.1 : 0.2;
                              });
                            },
                          ),
                          SizedBox(height: dims.scaleSpace(4)),
                          _StepperButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            onTap: () {
                              setState(() {
                                _temperature -= _unit == 'C' ? 0.1 : 0.2;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(width: dims.scaleWidth(16)),
                      Text(
                        _unit == 'C' ? '°C' : '°F',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: dims.scaleText(20),
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: dims.scaleSpace(16)),
                Row(
                  children: [
                    Expanded(
                      child: _UnitButton(
                        label: '°C',
                        selected: _unit == 'C',
                        onTap: () => setState(() => _unit = 'C'),
                      ),
                    ),
                    SizedBox(width: dims.scaleWidth(12)),
                    Expanded(
                      child: _UnitButton(
                        label: '°F',
                        selected: _unit == 'F',
                        onTap: () => setState(() => _unit = 'F'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: dims.scaleSpace(14)),
                Text(
                  l10n.logTemperatureNormalRangeNote,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: dims.scaleText(14),
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _TemperatureSectionCard(
            title: l10n.logTemperatureMeasurementTimeTitle,
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                    onTap: () async {
                      final selected = await showTimePicker(
                        context: context,
                        initialTime: _measuredAt,
                      );
                      if (selected == null) return;
                      setState(() => _measuredAt = selected);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: dims.scaleWidth(18),
                        vertical: dims.scaleSpace(18),
                      ),
                      decoration: BoxDecoration(
                        color: colors.bgSurface,
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(18),
                        ),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        _formatTimeOfDay(_measuredAt),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: dims.scaleText(18),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(14)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(16)),
                  decoration: BoxDecoration(
                    color: colors.bgSurface,
                    borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                    border: Border.all(color: colors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _method,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(value: 'oral', child: Text(context.l10n.temperatureMethodOral)),
                        DropdownMenuItem(
                          value: 'vaginal',
                          child: Text(context.l10n.temperatureMethodVaginal),
                        ),
                        DropdownMenuItem(
                          value: 'wearable',
                          child: Text(context.l10n.temperatureMethodWearable),
                        ),
                        DropdownMenuItem(
                          value: 'unknown',
                          child: Text(context.l10n.temperatureMethodUnknown),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _method = value);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _TemperatureSectionCard(
            title: l10n.logTemperatureQualityFactorsTitle,
            child: Column(
              children: [
                _QualityRow(
                  label: l10n.logTemperatureSameTimeLabel,
                  value: _sameTime,
                  onChanged: (value) => setState(() => _sameTime = value),
                ),
                _QualityDivider(),
                _QualityRow(
                  label: l10n.logTemperatureSleepLabel,
                  value: _uninterruptedSleep,
                  onChanged:
                      (value) => setState(() => _uninterruptedSleep = value),
                ),
                _QualityDivider(),
                _QualityRow(
                  label: l10n.logTemperatureBeforeGettingUpLabel,
                  value: _measuredBeforeGettingUp,
                  onChanged: (value) {
                    setState(() => _measuredBeforeGettingUp = value);
                  },
                ),
                _QualityDivider(),
                _QualityRow(
                  label: 'Illness or fever?',
                  value: _illnessFlag,
                  onChanged: (value) => setState(() => _illnessFlag = value),
                ),
                _QualityDivider(),
                _QualityRow(
                  label: 'Alcohol last night?',
                  value: _alcoholFlag,
                  onChanged: (value) => setState(() => _alcoholFlag = value),
                ),
                _QualityDivider(),
                _QualityRow(
                  label: 'High stress?',
                  value: _stressFlag,
                  onChanged: (value) => setState(() => _stressFlag = value),
                ),
                _QualityDivider(),
                _QualityRow(
                  label: 'Recent travel?',
                  value: _travelFlag,
                  onChanged: (value) => setState(() => _travelFlag = value),
                ),
              ],
            ),
          ),
          if (_warningText != null) ...[
            SizedBox(height: dims.scaleSpace(18)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(dims.scaleWidth(16)),
              decoration: BoxDecoration(
                color: colors.bgElevated,
                borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                border: Border.all(
                  color: colors.accentPrimary.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                _warningText!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: dims.scaleText(13),
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
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
                            final measuredAt = _measuredDateTime();
                            await ref
                                .read(sensorRepositoryProvider)
                                .ingestTemperature(
                                  measuredAt: measuredAt,
                                  temperatureCelsius:
                                      _temperatureCelsius(_temperature, _unit),
                                  method: _method,
                                  quality: {
                                    'sleep_quality_score': _sleepQualityScore(
                                      sameTime: _sameTime,
                                      uninterruptedSleep: _uninterruptedSleep,
                                      measuredBeforeGettingUp:
                                          _measuredBeforeGettingUp,
                                    ),
                                    'sleep_minutes':
                                        _uninterruptedSleep ? 420 : 300,
                                    'same_time_as_yesterday': _sameTime,
                                    'uninterrupted_sleep':
                                        _uninterruptedSleep,
                                    'measured_before_getting_up':
                                        _measuredBeforeGettingUp,
                                    'illness_flag': _illnessFlag,
                                    'alcohol_flag': _alcoholFlag,
                                    'stress_flag': _stressFlag,
                                    'travel_flag': _travelFlag,
                                    'excluded_from_ovulation_prediction':
                                        _shouldExcludeFromPrediction,
                                    if (_warningText != null)
                                      'exclusion_reason': _warningText,
                                  },
                                );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.logTemperatureSaved)),
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
                      _isSaving ? l10n.savingLabel : l10n.saveTemperatureLabel,
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

  DateTime _measuredDateTime() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      _measuredAt.hour,
      _measuredAt.minute,
    );
  }

  bool get _isMorningWindow =>
      _measuredAt.hour >= 3 && _measuredAt.hour < 7;

  bool get _looksHighTemperature =>
      _temperatureCelsius(_temperature, _unit) >= 37.5;

  bool get _shouldExcludeFromPrediction =>
      !_isMorningWindow ||
      !_uninterruptedSleep ||
      !_measuredBeforeGettingUp ||
      _illnessFlag ||
      _alcoholFlag ||
      _travelFlag;

  String? get _warningText {
    if (!_isMorningWindow) {
      return 'This temperature was not collected between 3am and 7am. '
          'Vyla can save it for your records, but it will not affect ovulation prediction.';
    }
    if (_looksHighTemperature) {
      return 'This temperature looks higher than a normal resting BBT reading. '
          'It may reflect fever, illness, or a late measurement and may be excluded from ovulation prediction.';
    }
    if (_illnessFlag || _alcoholFlag || _travelFlag) {
      return 'This reading may be excluded from ovulation prediction because illness, alcohol, or travel can distort resting temperature.';
    }
    return null;
  }
}

double _temperatureCelsius(double temperature, String unit) {
  final celsius = unit == 'F' ? (temperature - 32) * 5 / 9 : temperature;
  return double.parse(celsius.toStringAsFixed(2));
}

double _sleepQualityScore({
  required bool sameTime,
  required bool uninterruptedSleep,
  required bool measuredBeforeGettingUp,
}) {
  var score = 1.0;
  if (!sameTime) score -= 0.2;
  if (!uninterruptedSleep) score -= 0.35;
  if (!measuredBeforeGettingUp) score -= 0.2;
  return score.clamp(0.1, 1.0);
}

String _formatTimeOfDay(TimeOfDay value) {
  final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

class _TemperatureSectionCard extends StatelessWidget {
  const _TemperatureSectionCard({required this.title, required this.child});

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

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return InkWell(
      borderRadius: BorderRadius.circular(dims.scaleRadius(10)),
      onTap: onTap,
      child: SizedBox(
        width: dims.scaleWidth(28),
        height: dims.scaleWidth(20),
        child: Icon(icon, color: colors.textTertiary, size: dims.scaleText(18)),
      ),
    );
  }
}

class _UnitButton extends StatelessWidget {
  const _UnitButton({
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
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(16)),
          decoration: BoxDecoration(
            color: selected ? colors.bgElevated : colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
            border: Border.all(
              color: selected ? colors.accentPrimary : colors.border,
              width: selected ? 1.3 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: dims.scaleText(16),
              fontWeight: FontWeight.w800,
              color: selected ? colors.textPrimary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: dims.scaleText(15),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: dims.scaleWidth(16)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: colors.accentPrimary,
            inactiveThumbColor: colors.textQuaternary,
            inactiveTrackColor: colors.bgSurface,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _QualityDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    return Divider(color: colors.divider, height: 1);
  }
}
