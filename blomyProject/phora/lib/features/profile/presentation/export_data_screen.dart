import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/design_tokens.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  bool _includeCycleHistory = true;
  bool _includeLogs = true;
  bool _includePredictions = true;
  bool _includeChatHistory = false;
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final gradients = context.phora.gradients;
    final dims = context.dims;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                dims.scaleWidth(24),
                dims.scaleSpace(18),
                dims.scaleWidth(24),
                dims.scaleSpace(18),
              ),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
                    onTap: () => context.go('/you'),
                    child: Container(
                      width: dims.scaleWidth(48),
                      height: dims.scaleWidth(48),
                      decoration: BoxDecoration(
                        color: colors.bgCard,
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(16),
                        ),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: colors.textPrimary,
                        size: dims.scaleText(22),
                      ),
                    ),
                  ),
                  SizedBox(width: dims.scaleWidth(16)),
                  Text(
                    context.l10n.exportMyDataTitle,
                    style: AppTheme.screenHeaderStyle(
                      context,
                      dims,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  dims.scaleWidth(24),
                  0,
                  dims.scaleWidth(24),
                  dims.scaleSpace(28),
                ),
                child:
                    _requested
                        ? _ExportRequestedState(gradients: gradients)
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.exportMyDataSubtitle,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                fontSize: dims.scaleText(15),
                                color: colors.textSecondary,
                                height: 1.55,
                              ),
                            ),
                            SizedBox(height: dims.scaleSpace(22)),
                            _ExportCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.exportChooseIncludeTitle,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.copyWith(
                                      fontSize: dims.scaleText(16),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: dims.scaleSpace(18)),
                                  _ExportToggleRow(
                                    label: context.l10n.exportCycleHistoryLabel,
                                    subtitle:
                                        context.l10n.exportCycleHistorySubtitle,
                                    value: _includeCycleHistory,
                                    onChanged: (value) {
                                      setState(
                                        () => _includeCycleHistory = value,
                                      );
                                    },
                                  ),
                                  _ExportToggleRow(
                                    label: context.l10n.exportDailyLogsLabel,
                                    subtitle:
                                        context.l10n.exportDailyLogsSubtitle,
                                    value: _includeLogs,
                                    onChanged: (value) {
                                      setState(() => _includeLogs = value);
                                    },
                                  ),
                                  _ExportToggleRow(
                                    label: context.l10n.exportPredictionsLabel,
                                    subtitle:
                                        context.l10n.exportPredictionsSubtitle,
                                    value: _includePredictions,
                                    onChanged: (value) {
                                      setState(
                                        () => _includePredictions = value,
                                      );
                                    },
                                  ),
                                  _ExportToggleRow(
                                    label: context.l10n.exportBloomHistoryLabel,
                                    subtitle:
                                        context.l10n.exportBloomHistorySubtitle,
                                    value: _includeChatHistory,
                                    onChanged: (value) {
                                      setState(
                                        () => _includeChatHistory = value,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: dims.scaleSpace(18)),
                            _ExportCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.exportFormatTitle,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.copyWith(
                                      fontSize: dims.scaleText(16),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: dims.scaleSpace(16)),
                                  _FormatRow(
                                    title: context.l10n.exportJsonArchiveTitle,
                                    subtitle:
                                        context.l10n.exportJsonArchiveSubtitle,
                                    badge: context.l10n.recommendedLabel,
                                  ),
                                  SizedBox(height: dims.scaleSpace(12)),
                                  _FormatRow(
                                    title: context.l10n.exportCsvBundleTitle,
                                    subtitle:
                                        context.l10n.exportCsvBundleSubtitle,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: dims.scaleSpace(18)),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(dims.scaleWidth(18)),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D1D1E),
                                borderRadius: BorderRadius.circular(
                                  dims.scaleRadius(22),
                                ),
                                border: Border.all(
                                  color: const Color(0xFF7A4144),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🔒 ${context.l10n.exportSensitiveTitle}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      fontSize: dims.scaleText(16),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: dims.scaleSpace(10)),
                                  Text(
                                    context.l10n.exportSensitiveSubtitle,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.copyWith(
                                      fontSize: dims.scaleText(15),
                                      color: Colors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                      height: 1.55,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: dims.scaleSpace(26)),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradients.primary,
                                ),
                                borderRadius: BorderRadius.circular(
                                  dims.scaleRadius(20),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    dims.scaleRadius(20),
                                  ),
                                  onTap:
                                      () => setState(() => _requested = true),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: dims.scaleSpace(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        context.l10n.requestExportLabel,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge?.copyWith(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportRequestedState extends StatelessWidget {
  const _ExportRequestedState({required this.gradients});

  final AppGradients gradients;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(dims.scaleWidth(28)),
          decoration: BoxDecoration(
            color: const Color(0xFF162B21),
            borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
            border: Border.all(color: const Color(0xFF2D6A4F)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: Colors.white,
                size: dims.scaleText(52),
              ),
              SizedBox(height: dims.scaleSpace(12)),
              Text(
                context.l10n.exportRequestedTitle,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: dims.scaleText(20),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: dims.scaleSpace(10)),
              Text(
                context.l10n.exportRequestedSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(15),
                  color: Colors.white.withValues(alpha: 0.76),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: dims.scaleSpace(24)),
        _ExportCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.exportWhatNextTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: dims.scaleText(18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: dims.scaleSpace(16)),
              ...[
                context.l10n.exportWhatNextItemOne,
                context.l10n.exportWhatNextItemTwo,
                context.l10n.exportWhatNextItemThree,
              ].map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: dims.scaleSpace(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: dims.scaleSpace(4),
                          right: dims.scaleWidth(10),
                        ),
                        child: Icon(
                          Icons.circle,
                          size: dims.scaleText(7),
                          color: colors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            fontSize: dims.scaleText(15),
                            color: colors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: dims.scaleSpace(24)),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradients.primary),
            borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
              onTap: () => context.go('/you'),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(16)),
                child: Center(
                  child: Text(
                    context.l10n.doneLabel,
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
    );
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.child});

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
      child: child,
    );
  }
}

class _ExportToggleRow extends StatelessWidget {
  const _ExportToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Padding(
      padding: EdgeInsets.only(bottom: dims.scaleSpace(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(14),
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({required this.title, required this.subtitle, this.badge});

  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(15),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(14),
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: dims.scaleWidth(10),
                vertical: dims.scaleSpace(6),
              ),
              decoration: BoxDecoration(
                color: colors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
              ),
              child: Text(
                badge!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: dims.scaleText(12),
                  color: colors.accentPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
