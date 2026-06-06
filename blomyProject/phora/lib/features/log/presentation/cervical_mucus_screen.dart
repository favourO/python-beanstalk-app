import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/cycle/data/cycle_repository.dart';
import 'package:phora/features/log/presentation/log_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CervicalMucusScreen extends ConsumerStatefulWidget {
  const CervicalMucusScreen({super.key});

  @override
  ConsumerState<CervicalMucusScreen> createState() =>
      _CervicalMucusScreenState();
}

class _CervicalMucusScreenState extends ConsumerState<CervicalMucusScreen> {
  String _selectedType = 'Egg White (Fertile)';
  String _selectedAmount = 'Moderate';
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

    return LogPageScaffold(
      header: LogPageHeader(title: context.l10n.logCervicalMucusTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: dims.scaleSpace(8)),
          _MucusSectionCard(
            title: context.l10n.logConsistencyTypeTitle,
            child: Column(
              children: [
                _MucusTypeTile(
                  emoji: '🚫',
                  label: context.l10n.logMucusDryNoneLabel,
                  subtitle: context.l10n.logMucusDryNoneSubtitle,
                  selected: _selectedType == 'Dry / None',
                  onTap: () => setState(() => _selectedType = 'Dry / None'),
                ),
                SizedBox(height: dims.scaleSpace(12)),
                _MucusTypeTile(
                  emoji: '⚪',
                  label: context.l10n.logMucusStickyLabel,
                  subtitle: context.l10n.logMucusStickySubtitle,
                  selected: _selectedType == 'Sticky',
                  onTap: () => setState(() => _selectedType = 'Sticky'),
                ),
                SizedBox(height: dims.scaleSpace(12)),
                _MucusTypeTile(
                  emoji: '💧',
                  label: context.l10n.logMucusCreamyLabel,
                  subtitle: context.l10n.logMucusCreamySubtitle,
                  selected: _selectedType == 'Creamy',
                  onTap: () => setState(() => _selectedType = 'Creamy'),
                ),
                SizedBox(height: dims.scaleSpace(12)),
                _MucusTypeTile(
                  emoji: '✨',
                  label: context.l10n.logMucusEggWhiteLabel,
                  subtitle: context.l10n.logMucusEggWhiteSubtitle,
                  selected: _selectedType == 'Egg White (Fertile)',
                  selectedColor: const Color(0xFF65CAE8),
                  onTap: () {
                    setState(() => _selectedType = 'Egg White (Fertile)');
                  },
                ),
                SizedBox(height: dims.scaleSpace(12)),
                _MucusTypeTile(
                  emoji: '💦',
                  label: context.l10n.logMucusWateryLabel,
                  subtitle: context.l10n.logMucusWaterySubtitle,
                  selected: _selectedType == 'Watery',
                  onTap: () => setState(() => _selectedType = 'Watery'),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _MucusSectionCard(
            title: context.l10n.logAmountTitle,
            child: Row(
              children: [
                Expanded(
                  child: _AmountTile(
                    dots: '•',
                    label: context.l10n.logAmountLightLabel,
                    selected: _selectedAmount == 'Light',
                    onTap: () => setState(() => _selectedAmount = 'Light'),
                  ),
                ),
                SizedBox(width: dims.scaleWidth(12)),
                Expanded(
                  child: _AmountTile(
                    dots: '••',
                    label: context.l10n.logAmountModerateLabel,
                    selected: _selectedAmount == 'Moderate',
                    onTap: () => setState(() => _selectedAmount = 'Moderate'),
                  ),
                ),
                SizedBox(width: dims.scaleWidth(12)),
                Expanded(
                  child: _AmountTile(
                    dots: '•••',
                    label: context.l10n.logAmountHeavyLabel,
                    selected: _selectedAmount == 'Heavy',
                    onTap: () => setState(() => _selectedAmount = 'Heavy'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _MucusSectionCard(
            title: context.l10n.logNotesTitle,
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
                  hintText: context.l10n.logAdditionalObservationsHint,
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
                                .logMucus(
                                  loggedAt: DateTime.now(),
                                  mucusType: _selectedType,
                                  amount: _selectedAmount,
                                  notes: _notesController.text.trim(),
                                );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.logCervicalMucusSaved,
                                ),
                              ),
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
                      _isSaving
                          ? context.l10n.savingLabel
                          : context.l10n.saveMucusLogLabel,
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
}

class _MucusSectionCard extends StatelessWidget {
  const _MucusSectionCard({required this.title, required this.child});

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

class _MucusTypeTile extends StatelessWidget {
  const _MucusTypeTile({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  final String emoji;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final activeColor = selectedColor ?? const Color(0xFFDF577E);

    return Material(
      color: Colors.transparent,
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
            color: selected ? activeColor : colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(color: selected ? activeColor : colors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: dims.scaleWidth(30),
                child: Text(
                  emoji,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: dims.scaleText(22)),
                ),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: dims.scaleText(16),
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(4)),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: dims.scaleText(14),
                        color:
                            selected
                                ? Colors.white.withValues(alpha: 0.82)
                                : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.dots,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String dots;
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
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(24)),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDF577E) : colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(
              color: selected ? const Color(0xFFDF577E) : colors.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                dots,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(22),
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : colors.textPrimary,
                  letterSpacing: dims.scaleWidth(2),
                ),
              ),
              SizedBox(height: dims.scaleSpace(16)),
              Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(16),
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
