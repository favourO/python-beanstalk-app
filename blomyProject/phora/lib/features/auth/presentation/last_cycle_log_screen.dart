import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/cycle/data/cycle_repository.dart';

abstract final class _LastCyclePalette {
  static const accent = Color(0xFFFF8A4C);
  static const accentSoft = Color(0xFFFFE7D8);
}

class LastCycleLogScreen extends ConsumerStatefulWidget {
  const LastCycleLogScreen({super.key});

  @override
  ConsumerState<LastCycleLogScreen> createState() => _LastCycleLogScreenState();
}

class _LastCycleLogScreenState extends ConsumerState<LastCycleLogScreen> {
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 28));
  }

  Future<void> _pickDate() async {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _LastCyclePalette.accent,
              secondary: _LastCyclePalette.accent,
              surface:
                  isLight ? const Color(0xFFFFF6F0) : const Color(0xFF1C1520),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _saveAndContinue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(cycleRepositoryProvider).logPeriodStart(
            startedAt: _selectedDate,
          );
      await ref.read(onboardingStatusProvider.notifier).completeLastCycleLog();
      if (!mounted) return;
      context.go('/subscription');
    } catch (error) {
      if (!mounted) return;
      showAuthError(context, error);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Scaffold(
      body: DecoratedBox(
        decoration: authBackgroundDecoration(context),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(24),
              dims.scaleSpace(24),
              dims.scaleWidth(24),
              dims.scaleSpace(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When did your last period start?',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: dims.scaleText(34),
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                ),
                SizedBox(height: dims.scaleSpace(12)),
                Text(
                  'This is required to personalise your cycle timeline before you continue.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: dims.scaleText(16),
                        color: colors.textSecondary,
                        height: 1.5,
                      ),
                ),
                SizedBox(height: dims.scaleSpace(28)),
                Text(
                  'Last period start date',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(16),
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                ),
                SizedBox(height: dims.scaleSpace(12)),
                InkWell(
                  borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: dims.scaleWidth(18),
                      vertical: dims.scaleSpace(18),
                    ),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).brightness == Brightness.light
                              ? _LastCyclePalette.accentSoft.withValues(alpha: 0.34)
                              : colors.bgCard,
                      borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                      border: Border.all(
                        color:
                            Theme.of(context).brightness == Brightness.light
                                ? const Color(0xFFFFD9C2)
                                : colors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatDate(_selectedDate),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: dims.scaleText(18),
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.calendar_month_rounded,
                          color: _LastCyclePalette.accent,
                          size: dims.scaleText(22),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveAndContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: _LastCyclePalette.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        vertical: dims.scaleSpace(16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(18),
                        ),
                      ),
                    ),
                    child: Text(_isSaving ? 'Saving...' : 'Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
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
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}
