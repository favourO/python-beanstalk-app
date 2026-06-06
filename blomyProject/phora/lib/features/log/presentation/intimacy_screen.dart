import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/cycle/data/cycle_repository.dart';
import 'package:phora/features/log/presentation/log_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class IntimacyScreen extends ConsumerStatefulWidget {
  const IntimacyScreen({super.key});

  @override
  ConsumerState<IntimacyScreen> createState() => _IntimacyScreenState();
}

class _IntimacyScreenState extends ConsumerState<IntimacyScreen> {
  String _selectedActivity = 'Unprotected';
  final Set<String> _selectedDetails = {};
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
      header: LogPageHeader(title: l10n.logIntimacyTitle),
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
                color: colors.accentPrimary.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: dims.scaleWidth(34),
                  child: Text(
                    '🔒',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: dims.scaleText(24)),
                  ),
                ),
                SizedBox(width: dims.scaleWidth(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.logIntimacyPrivacyTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: dims.scaleText(16),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(6)),
                      Text(
                        l10n.logIntimacyPrivacySubtitle,
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
          _IntimacySectionCard(
            title: l10n.logIntimacyActivityTitle,
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: dims.scaleWidth(12),
              mainAxisSpacing: dims.scaleSpace(12),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.05,
              children: [
                _ActivityTile(
                  emoji: '❤️',
                  label: l10n.logIntimacyUnprotectedLabel,
                  selected: _selectedActivity == 'Unprotected',
                  onTap:
                      () => setState(() => _selectedActivity = 'Unprotected'),
                ),
                _ActivityTile(
                  emoji: '🛡️',
                  label: l10n.logIntimacyProtectedLabel,
                  selected: _selectedActivity == 'Protected',
                  onTap: () => setState(() => _selectedActivity = 'Protected'),
                ),
                _ActivityTile(
                  emoji: '💊',
                  label: l10n.logIntimacyBirthControlLabel,
                  selected: _selectedActivity == 'Birth Control',
                  onTap:
                      () => setState(() => _selectedActivity = 'Birth Control'),
                ),
                _ActivityTile(
                  emoji: '🤗',
                  label: l10n.logIntimacyOtherLabel,
                  selected: _selectedActivity == 'Other',
                  onTap: () => setState(() => _selectedActivity = 'Other'),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _IntimacySectionCard(
            title: l10n.logIntimacyTimeOptionalTitle,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: dims.scaleWidth(18),
                vertical: dims.scaleSpace(18),
              ),
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                '22:30',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(18),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _IntimacySectionCard(
            title: l10n.logIntimacyDetailsOptionalTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: dims.scaleWidth(10),
                  runSpacing: dims.scaleSpace(10),
                  children:
                      ['Orgasm', 'Painful', 'Dry', 'Bleeding'].map((detail) {
                        final isSelected = _selectedDetails.contains(detail);
                        return _IntimacyChip(
                          label: _intimacyDetailLabel(l10n, detail),
                          selected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedDetails.remove(detail);
                              } else {
                                _selectedDetails.add(detail);
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.bgSurface,
                    borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                    border: Border.all(color: colors.border),
                  ),
                  child: TextField(
                    controller: _notesController,
                    maxLines: 4,
                    minLines: 4,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: dims.scaleText(15),
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.logIntimacyNotesHint,
                      hintStyle: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(
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
              ],
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
                                .logIntimacy(
                                  logDate: DateTime.now(),
                                  hadIntimacy: true,
                                  protectionUsed:
                                      _selectedActivity == 'Protected',
                                  ejaculation:
                                      _selectedActivity == 'Unprotected',
                                  partnerGender: _partnerGenderForActivity(
                                    _selectedActivity,
                                  ),
                                  notes: _buildIntimacyNotes(
                                    _notesController.text.trim(),
                                    _selectedActivity,
                                    _selectedDetails,
                                  ),
                                );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.logIntimacySaved)),
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
                      _isSaving ? l10n.savingLabel : l10n.saveIntimacyLogLabel,
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

  String _intimacyDetailLabel(dynamic l10n, String detail) {
    switch (detail) {
      case 'Orgasm':
        return l10n.logIntimacyDetailOrgasmLabel;
      case 'Painful':
        return l10n.logIntimacyDetailPainfulLabel;
      case 'Dry':
        return l10n.logIntimacyDetailDryLabel;
      case 'Bleeding':
        return l10n.logIntimacyDetailBleedingLabel;
      default:
        return detail;
    }
  }
}

String? _partnerGenderForActivity(String activity) {
  switch (activity) {
    case 'Unprotected':
    case 'Protected':
      return 'male';
    default:
      return null;
  }
}

String? _buildIntimacyNotes(
  String notes,
  String activity,
  Set<String> selectedDetails,
) {
  final detailText = selectedDetails.isEmpty ? '' : selectedDetails.join(', ');
  final buffer = StringBuffer();
  if (notes.isNotEmpty) {
    buffer.write(notes);
  }
  if (detailText.isNotEmpty) {
    if (buffer.isNotEmpty) {
      buffer.write(' | ');
    }
    buffer.write('details: $detailText');
  }
  if (activity == 'Birth Control') {
    if (buffer.isNotEmpty) {
      buffer.write(' | ');
    }
    buffer.write('birth control');
  }
  final result = buffer.toString().trim();
  return result.isEmpty ? null : result;
}

class _IntimacySectionCard extends StatelessWidget {
  const _IntimacySectionCard({required this.title, required this.child});

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

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
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
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDF577E) : colors.bgSurface,
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
            border: Border.all(
              color: selected ? const Color(0xFFDF577E) : colors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: TextStyle(fontSize: dims.scaleText(30))),
              SizedBox(height: dims.scaleSpace(18)),
              Text(
                label,
                textAlign: TextAlign.center,
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

class _IntimacyChip extends StatelessWidget {
  const _IntimacyChip({
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
