import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/growth/data/growth_repository.dart';
import 'package:phora/features/growth/domain/growth_models.dart';
import 'package:phora/features/insights/domain/cycle_stats.dart';
import 'package:phora/features/insights/insights_providers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthDataScreen extends ConsumerStatefulWidget {
  const HealthDataScreen({super.key});

  @override
  ConsumerState<HealthDataScreen> createState() => _HealthDataScreenState();
}

class _HealthDataScreenState extends ConsumerState<HealthDataScreen> {
  int _cycleCount = 3;
  bool _includeLhHistory = true;
  bool _includeTemperatureChart = true;
  bool _includeSymptomSummary = true;
  bool _loadingConfig = true;
  bool _submitting = false;
  String _audience = 'doctor';
  String _method = 'pdf_report';
  String? _loadError;
  ShareGenerateResultModel? _generatedResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config =
          await ref.read(growthRepositoryProvider).getCycleReportConfig();
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _loadError = null;
        _audience =
            config.defaultAudience.isNotEmpty
                ? config.defaultAudience
                : _audience;
        _method =
            config.defaultMethod.isNotEmpty ? config.defaultMethod : _method;
        if (config.defaultCycleCount > 0) {
          _cycleCount = config.defaultCycleCount;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _loadError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: SafeArea(
        child: Stack(
          children: [
            if (!isDark) const _CycleReportBackdrop(),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(16),
                    dims.scaleSpace(10),
                    dims.scaleWidth(16),
                    0,
                  ),
                  child: _CycleReportTopBar(onBack: () => context.go('/you')),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(14),
                      dims.scaleSpace(18),
                      dims.scaleWidth(14),
                      dims.scaleSpace(28),
                    ),
                    child: _buildBody(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final dims = context.dims;
    final l10n = context.l10n;
    final cycleStatsAsync = ref.watch(cycleStatsProvider);
    final reportCycleCount = _reportCycleCount(cycleStatsAsync.valueOrNull);

    if (_loadingConfig) {
      return Padding(
        padding: EdgeInsets.only(top: dims.scaleSpace(56)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (cycleStatsAsync.isLoading && !cycleStatsAsync.hasValue) {
      return Padding(
        padding: EdgeInsets.only(top: dims.scaleSpace(56)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null && _generatedResult == null) {
      return Padding(
        padding: EdgeInsets.only(top: dims.scaleSpace(40)),
        child: Column(
          children: [
            Text(
              l10n.healthDataLoadErrorTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: dims.scaleSpace(8)),
            Text(
              _loadError!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: dims.scaleSpace(16)),
            _PrimaryButton(label: l10n.retryLabel, onTap: _loadConfig),
          ],
        ),
      );
    }

    final generatedResult = _generatedResult;
    if (generatedResult != null) {
      return _GeneratedState(
        result: generatedResult,
        onSaveToFiles: () => _sharePdf(generatedResult),
        onOpenIn: () => _openGeneratedReport(generatedResult),
        onDone: () => context.go('/you'),
      );
    }

    return Column(
      children: [
        _SectionCard(
          title: context.l10n.healthDataReportOptionsTitle,
          icon: Icons.query_stats_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChoiceRow(
                label: context.l10n.healthDataCyclesToIncludeLabel,
                child: Wrap(
                  spacing: dims.scaleWidth(10),
                  runSpacing: dims.scaleSpace(10),
                  children: [
                    _CycleChip(
                      label: context.l10n.healthDataCycleCountLabel(
                        reportCycleCount,
                      ),
                      selected: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: dims.scaleSpace(18)),
              _CompactToggleRow(
                icon: Icons.show_chart_rounded,
                label: context.l10n.healthDataIncludeLhHistory,
                subtitle: l10n.healthDataIncludeLhHistorySubtitle,
                value: _includeLhHistory,
                onChanged: (value) => setState(() => _includeLhHistory = value),
              ),
              _CompactToggleRow(
                icon: Icons.device_thermostat_rounded,
                label: context.l10n.healthDataIncludeTemperatureChart,
                subtitle: l10n.healthDataIncludeTemperatureChartSubtitle,
                value: _includeTemperatureChart,
                onChanged:
                    (value) => setState(() => _includeTemperatureChart = value),
              ),
              _CompactToggleRow(
                icon: Icons.star_border_rounded,
                label: context.l10n.healthDataIncludeSymptomSummary,
                subtitle: l10n.healthDataIncludeSymptomSummarySubtitle,
                value: _includeSymptomSummary,
                onChanged:
                    (value) => setState(() => _includeSymptomSummary = value),
              ),
            ],
          ),
        ),
        SizedBox(height: dims.scaleSpace(16)),
        _SectionCard(
          title: context.l10n.healthDataReportIncludesTitle,
          icon: Icons.fact_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._buildIncludedItems(context, reportCycleCount),
              SizedBox(height: dims.scaleSpace(12)),
              _PrivacyCallout(),
            ],
          ),
        ),
        SizedBox(height: dims.scaleSpace(18)),
        _PrimaryButton(
          label:
              _submitting
                  ? l10n.generatingLabel
                  : context.l10n.healthDataGeneratePdfLabel,
          onTap: _submitting ? null : _generateReport,
        ),
      ],
    );
  }

  int _reportCycleCount(CycleStats? stats) {
    final trackedCycles = stats?.trackedCycles ?? 0;
    if (trackedCycles > 0) {
      return trackedCycles;
    }
    final periodRangeCount = stats?.periodRanges.length ?? 0;
    if (periodRangeCount > 0) {
      return periodRangeCount;
    }
    return stats == null ? _cycleCount : 0;
  }

  List<Widget> _buildIncludedItems(BuildContext context, int cycleCount) {
    final items = <String>[
      context.l10n.healthDataIncludedCycleLengths(cycleCount),
      context.l10n.healthDataIncludedAverageCycleLength,
      if (_includeLhHistory) context.l10n.healthDataIncludedLhHistory,
      if (_includeTemperatureChart)
        context.l10n.healthDataIncludedTemperatureChart,
      if (_includeSymptomSummary) context.l10n.healthDataIncludedSymptomSummary,
      context.l10n.healthDataIncludedOvulationAccuracy,
    ];

    return [
      for (var i = 0; i < items.length; i++) ...[
        _IncludedItemRow(label: items[i]),
        if (i != items.length - 1) const _DashedDivider(),
      ],
    ];
  }

  Future<void> _generateReport() async {
    setState(() => _submitting = true);
    try {
      final cycleCount = _reportCycleCount(
        ref.read(cycleStatsProvider).valueOrNull,
      );
      final result = await ref
          .read(growthRepositoryProvider)
          .generateCycleReport(
            sectionIds: _selectedSectionIds(),
            audience: _audience,
            method: _method,
            cycleCount: cycleCount,
          );
      if (!mounted) return;
      setState(() => _generatedResult = result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  List<String> _selectedSectionIds() {
    return <String>[
      'cycle_overview',
      'period_details',
      'trends_insights',
      if (_includeSymptomSummary) 'symptoms',
    ];
  }

  Future<void> _sharePdf(ShareGenerateResultModel result) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${result.reportFileName}');
    final bytes = base64Decode(result.reportPdfBase64);
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        text: '${result.title}\n${result.subtitle}',
        subject: result.title,
        files: [XFile(file.path)],
        sharePositionOrigin: _sharePositionOrigin(),
      ),
    );
  }

  Future<void> _openGeneratedReport(ShareGenerateResultModel result) async {
    final secureLink = result.secureLinkUrl.trim();
    if (secureLink.startsWith('http://') || secureLink.startsWith('https://')) {
      final launched = await launchUrl(
        Uri.parse(secureLink),
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return;
      }
    }
    await _sharePdf(result);
  }

  Rect _sharePositionOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay != null && overlay.hasSize) {
      return overlay.localToGlobal(Offset.zero) & overlay.size;
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }
}

class _CycleReportBackdrop extends StatelessWidget {
  const _CycleReportBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -44,
            left: -52,
            child: Container(
              width: 236,
              height: 236,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x14F7C8AD), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          Positioned(top: 54, right: 6, child: const _LeafDecoration()),
          const Positioned(top: 132, right: 86, child: _Sparkle(size: 10)),
          const Positioned(top: 152, right: 48, child: _Sparkle(size: 7)),
          const Positioned(top: 118, right: 22, child: _Sparkle(size: 6)),
        ],
      ),
    );
  }
}

class _LeafDecoration extends StatelessWidget {
  const _LeafDecoration();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 118,
        height: 108,
        child: CustomPaint(painter: _LeafDecorationPainter()),
      ),
    );
  }
}

class _LeafDecorationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke =
        Paint()
          ..color = const Color(0x30F39A73)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;

    final stem =
        Path()
          ..moveTo(size.width * 0.18, size.height * 0.92)
          ..quadraticBezierTo(
            size.width * 0.32,
            size.height * 0.6,
            size.width * 0.48,
            size.height * 0.24,
          )
          ..quadraticBezierTo(
            size.width * 0.62,
            size.height * 0.54,
            size.width * 0.82,
            size.height * 0.12,
          );
    canvas.drawPath(stem, stroke);

    void leaf(double x, double y, double w, double h, bool left) {
      final path =
          Path()
            ..moveTo(x, y)
            ..quadraticBezierTo(left ? x - w : x + w, y - h * 0.45, x, y - h)
            ..quadraticBezierTo(
              left ? x + w * 0.2 : x - w * 0.2,
              y - h * 0.45,
              x,
              y,
            );
      canvas.drawPath(path, stroke);
    }

    leaf(size.width * 0.3, size.height * 0.72, 12, 26, true);
    leaf(size.width * 0.42, size.height * 0.58, 13, 30, false);
    leaf(size.width * 0.52, size.height * 0.44, 15, 34, true);
    leaf(size.width * 0.68, size.height * 0.48, 13, 28, false);
    leaf(size.width * 0.76, size.height * 0.3, 14, 34, true);
    leaf(size.width * 0.88, size.height * 0.2, 11, 24, false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome_rounded,
      size: size,
      color: const Color(0x24F39A73),
    );
  }
}

class _CycleReportTopBar extends StatelessWidget {
  const _CycleReportTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(onTap: onBack),
        SizedBox(width: dims.scaleWidth(12)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: dims.scaleSpace(8),
              right: dims.scaleWidth(56),
            ),
            child: Column(
              children: [
                Text(
                  context.l10n.healthDataCycleReportTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: dims.scaleText(32),
                    height: 1,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w500,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF2D170F),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(10)),
                Text(
                  context.l10n.healthDataCycleReportSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    height: 1.45,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF7F6357),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? colors.bgElevated : const Color(0xFFFFF4ED),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(dims.scaleWidth(16)),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: dims.scaleText(20),
            color: isDark ? colors.textPrimary : const Color(0xFF5A2A18),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    required this.icon,
  });

  final String title;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(16),
        dims.scaleWidth(16),
        dims.scaleSpace(16),
      ),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(dims.scaleRadius(26)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF5E7DE),
        ),
        boxShadow:
            isDark
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x0CC78862),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: dims.scaleWidth(42),
                height: dims.scaleWidth(42),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EC),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
                child: Icon(
                  icon,
                  size: dims.scaleText(20),
                  color: const Color(0xFFFF7C45),
                ),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(16),
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w600,
                  color: isDark ? colors.textPrimary : const Color(0xFF3D2921),
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(18)),
          child,
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: dims.scaleText(11),
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: isDark ? colors.textTertiary : const Color(0xFF8F8884),
          ),
        ),
        SizedBox(height: dims.scaleSpace(14)),
        child,
      ],
    );
  }
}

class _CycleChip extends StatelessWidget {
  const _CycleChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: dims.scaleWidth(102),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(15)),
            decoration: BoxDecoration(
              color:
                  selected
                      ? (isDark ? colors.bgSurface : const Color(0xFFFFFCFA))
                      : (isDark ? colors.bgSurface : const Color(0xFFFFFBF8)),
              borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
              border: Border.all(
                color:
                    selected
                        ? const Color(0xFFFF7C45)
                        : (isDark ? colors.border : const Color(0xFFF4E5DC)),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(13.5),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected
                          ? const Color(0xFFFF7C45)
                          : (isDark
                              ? colors.textSecondary
                              : const Color(0xFF716B68)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactToggleRow extends StatelessWidget {
  const _CompactToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(top: dims.scaleSpace(10)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(12),
          vertical: dims.scaleSpace(11),
        ),
        decoration: BoxDecoration(
          color: isDark ? colors.bgSurface : const Color(0xFFFFFAF7),
          borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
          border: Border.all(
            color: isDark ? colors.border : const Color(0xFFF4E6DE),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: dims.scaleWidth(40),
              height: dims.scaleWidth(40),
              decoration: BoxDecoration(
                color: isDark ? colors.bgElevated : const Color(0xFFFFF4EE),
                borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
              ),
              child: Icon(
                icon,
                size: dims.scaleText(19),
                color: const Color(0xFFFF7C45),
              ),
            ),
            SizedBox(width: dims.scaleWidth(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: dims.scaleText(12.8),
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? colors.textPrimary : const Color(0xFF3A2A23),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(3)),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: dims.scaleText(11.5),
                      height: 1.35,
                      color:
                          isDark
                              ? colors.textSecondary
                              : const Color(0xFF8B817B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: dims.scaleWidth(10)),
            Transform.scale(
              scale: 0.92,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFFFF7C45),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor:
                    isDark ? colors.borderStrong : const Color(0xFFE8DCD3),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncludedItemRow extends StatelessWidget {
  const _IncludedItemRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(11)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: dims.scaleWidth(20),
            height: dims.scaleWidth(20),
            decoration: BoxDecoration(
              color: isDark ? colors.bgSurface : const Color(0xFFFFF4EE),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD4C2)),
            ),
            child: Icon(
              Icons.check_rounded,
              size: dims.scaleText(12),
              color: const Color(0xFFFF7C45),
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(12.6),
                height: 1.35,
                color: isDark ? colors.textSecondary : const Color(0xFF7F6357),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Padding(
      padding: EdgeInsets.only(left: dims.scaleWidth(31)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashWidth = dims.scaleWidth(4);
          final dashGap = dims.scaleWidth(4);
          final dashCount =
              (constraints.maxWidth / (dashWidth + dashGap)).floor();
          return Row(
            children: List.generate(
              dashCount,
              (_) => Container(
                width: dashWidth,
                height: 1,
                margin: EdgeInsets.only(right: dashGap),
                color: const Color(0xFFF3DCD0),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PrivacyCallout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(14)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EC),
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        border: Border.all(color: const Color(0xFFF3D4BF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.healthDataPersonalHealthTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: dims.scaleText(12.5),
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8B4B2B),
            ),
          ),
          SizedBox(height: dims.scaleSpace(6)),
          Text(
            context.l10n.healthDataPersonalHealthSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(11.5),
              height: 1.4,
              color: const Color(0xFF8B6E60),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8E57), Color(0xFFF56F7C)],
        ),
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(15)),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(13.5),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneratedState extends StatelessWidget {
  const _GeneratedState({
    required this.result,
    required this.onSaveToFiles,
    required this.onOpenIn,
    required this.onDone,
  });

  final ShareGenerateResultModel result;
  final VoidCallback onSaveToFiles;
  final VoidCallback onOpenIn;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(dims.scaleWidth(18)),
          decoration: BoxDecoration(
            color:
                isDark
                    ? colors.bgElevated
                    : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
            border: Border.all(
              color: isDark ? colors.border : const Color(0xFFF0E1D7),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: dims.scaleWidth(60),
                height: dims.scaleWidth(60),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1E8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: dims.scaleText(30),
                  color: const Color(0xFFFF7C45),
                ),
              ),
              SizedBox(height: dims.scaleSpace(12)),
              Text(
                context.l10n.healthDataReportGeneratedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: dims.scaleText(24),
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w500,
                  color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
                ),
              ),
              SizedBox(height: dims.scaleSpace(8)),
              Text(
                result.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: dims.scaleText(12.5),
                  height: 1.4,
                  color:
                      isDark ? colors.textSecondary : const Color(0xFF7F6357),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: dims.scaleSpace(16)),
        _SectionCard(
          title: context.l10n.healthDataShareOptionsTitle,
          icon: Icons.ios_share_rounded,
          child: Column(
            children: [
              _ShareRow(
                title: context.l10n.healthDataSaveToFiles,
                onTap: onSaveToFiles,
              ),
              SizedBox(height: dims.scaleSpace(10)),
              _ShareRow(title: context.l10n.healthDataOpenIn, onTap: onOpenIn),
            ],
          ),
        ),
        SizedBox(height: dims.scaleSpace(18)),
        _PrimaryButton(label: context.l10n.doneLabel, onTap: onDone),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(14),
            vertical: dims.scaleSpace(12),
          ),
          decoration: BoxDecoration(
            color: isDark ? colors.bgSurface : const Color(0xFFF8F1EC),
            borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: dims.scaleText(12.5),
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? colors.textPrimary
                                : const Color(0xFF2F1C14),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: dims.scaleText(20),
                color: isDark ? colors.textTertiary : const Color(0xFF9B8A81),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
