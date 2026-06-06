import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/features/insights/domain/cycle_stats.dart';
import 'package:phora/features/insights/insights_providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.phora.colors;
    final dims = context.dims;
    final cycleStats = ref.watch(cycleStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: SafeArea(
        child: Stack(
          children: [
            if (!isDark) const _InsightsBackdrop(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(20),
                    dims.scaleSpace(12),
                    dims.scaleWidth(20),
                    0,
                  ),
                  child: _InsightsTopBar(
                    title: l10n.insightsTitle,
                    subtitle: cycleStats.maybeWhen(
                      data:
                          (stats) => l10n.insightsBasedOnTrackedCycles(
                            stats.trackedCycles,
                          ),
                      orElse: () => l10n.insightsBasedOnTrackedCycleData,
                    ),
                  ),
                ),
                Expanded(
                  child: cycleStats.when(
                    loading:
                        () => PhoraLoadingView(
                          message: l10n.insightsLoadingMessage,
                        ),
                    error:
                        (error, stackTrace) =>
                            _InsightsMessageState(message: error.toString()),
                    data:
                        (stats) => SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            dims.scaleWidth(20),
                            dims.scaleSpace(18),
                            dims.scaleWidth(20),
                            dims.scaleSpace(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GridView.count(
                                crossAxisCount: 2,
                                crossAxisSpacing: dims.scaleWidth(12),
                                mainAxisSpacing: dims.scaleSpace(12),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                childAspectRatio: 1.22,
                                children: [
                                  _StatCard(
                                    label: l10n.insightsAverageCycleLabel,
                                    value: _formatMetric(
                                      stats.averageCycleLengthDays,
                                    ),
                                    suffix: l10n.insightsDaysSuffix,
                                    icon: Icons.calendar_month_outlined,
                                  ),
                                  _StatCard(
                                    label: l10n.insightsPeriodLabel,
                                    value: _formatMetric(
                                      stats.averagePeriodLengthDays,
                                    ),
                                    suffix: l10n.insightsDaysSuffix,
                                    icon: Icons.water_drop_outlined,
                                  ),
                                  _StatCard(
                                    label: l10n.insightsTrackedLabel,
                                    value: stats.trackedCycles.toString(),
                                    suffix: l10n.insightsCyclesSuffix,
                                    icon: Icons.check_circle_outline_rounded,
                                  ),
                                  _StatCard(
                                    label: l10n.insightsRegularityLabel,
                                    value: stats.regularityPercentLabel,
                                    suffix: l10n.insightsPercentSuffix,
                                    valueColor: const Color(0xFF32B977),
                                    icon: Icons.query_stats_rounded,
                                    iconColor: const Color(0xFF32B977),
                                  ),
                                ],
                              ),
                              SizedBox(height: dims.scaleSpace(16)),
                              _ChartCard(
                                title: l10n.insightsTemperatureTrendTitle,
                                icon: Icons.device_thermostat_outlined,
                                contentHeight: 190,
                                child: _TemperatureTrendChart(
                                  points: stats.temperatureTrend,
                                ),
                              ),
                              SizedBox(height: dims.scaleSpace(16)),
                              _ChartCard(
                                title: l10n.insightsSymptomPatternsTitle,
                                icon: Icons.spa_outlined,
                                child: Column(
                                  children: [
                                    _PatternTile(
                                      label: l10n.insightsMostCommonLabel,
                                      value:
                                          stats.symptomPatterns.mostCommon ??
                                          l10n.insightsNoDataYet,
                                    ),
                                    SizedBox(height: dims.scaleSpace(10)),
                                    _PatternTile(
                                      label: l10n.insightsEnergyDipsLabel,
                                      value:
                                          stats.symptomPatterns.energyDips ??
                                          l10n.insightsNoDataYet,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsBackdrop extends StatelessWidget {
  const _InsightsBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -20,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1FFFAE8C), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 130,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x14FF8A4C), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          const Positioned(
            right: 26,
            top: 182,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0x19FF8A4C),
              size: 22,
            ),
          ),
          const Positioned(
            right: 48,
            top: 228,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0x12FF8A4C),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsTopBar extends StatelessWidget {
  const _InsightsTopBar({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: isDark ? colors.bgElevated : const Color(0xFFFFF4ED),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go('/today'),
            child: Padding(
              padding: EdgeInsets.all(dims.scaleWidth(16)),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: dims.scaleText(20),
                color: isDark ? colors.textPrimary : const Color(0xFF5A2A18),
              ),
            ),
          ),
        ),
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
                  title,
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
                  subtitle,
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

String _formatMetric(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

class _InsightsMessageState extends StatelessWidget {
  const _InsightsMessageState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(dims.scaleWidth(24)),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    this.valueColor,
    this.iconColor = const Color(0xFFFF7C45),
  });

  final String label;
  final String value;
  final String suffix;
  final IconData icon;
  final Color? valueColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(dims.scaleWidth(14)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
        boxShadow:
            isDark
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x0FC78862),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsightIconBadge(icon: icon, iconColor: iconColor),
          SizedBox(height: dims.scaleSpace(10)),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(12.5),
              height: 1.2,
              color: isDark ? colors.textSecondary : const Color(0xFF7F6357),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: dims.scaleText(30),
                    height: 1,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w500,
                    color:
                        valueColor ??
                        (isDark ? colors.textPrimary : const Color(0xFF2D170F)),
                  ),
                ),
                TextSpan(
                  text: ' $suffix',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    fontWeight: FontWeight.w700,
                    color:
                        valueColor ??
                        (isDark
                            ? colors.textSecondary
                            : const Color(0xFF8F766A)),
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

class _InsightIconBadge extends StatelessWidget {
  const _InsightIconBadge({required this.icon, required this.iconColor});

  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: dims.scaleWidth(36),
      height: dims.scaleWidth(36),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : iconColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: dims.scaleText(18), color: iconColor),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    required this.icon,
    this.contentHeight,
  });

  final String title;
  final Widget child;
  final IconData icon;
  final double? contentHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(14),
        dims.scaleWidth(16),
        dims.scaleSpace(16),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InsightIconBadge(icon: icon, iconColor: const Color(0xFFFF7C45)),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(16),
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF2D170F),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(14)),
          Container(
            width: double.infinity,
            constraints:
                contentHeight != null
                    ? BoxConstraints(
                      minHeight: dims.scaleHeight(contentHeight!),
                    )
                    : null,
            padding: EdgeInsets.all(dims.scaleWidth(16)),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? colors.bgSurface
                      : const Color(0xFFFFF8F4).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
              border: Border.all(
                color: isDark ? colors.border : const Color(0xFFF5E5DC),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _TemperatureTrendChart extends StatelessWidget {
  const _TemperatureTrendChart({required this.points});

  final List<CycleStatsPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    if (points.isEmpty) {
      final l10n = context.l10n;
      return Center(
        child: Text(
          l10n.insightsNoTemperatureTrendYet,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: dims.scaleText(13),
            height: 1.35,
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _TrendLinePainter(
        points: points,
        colors: const [Color(0xFF9D7AE1), Color(0xFF65CAE8), Color(0xFFD1C85F)],
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  const _TrendLinePainter({required this.points, required this.colors});

  final List<CycleStatsPoint> points;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    final minValue = points
        .map((point) => point.value)
        .reduce((a, b) => a < b ? a : b);
    final maxValue = points
        .map((point) => point.value)
        .reduce((a, b) => a > b ? a : b);
    final spread =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;

    final chartPoints = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x =
          points.length == 1
              ? size.width * 0.5
              : size.width * (i / (points.length - 1));
      final normalized = (points[i].value - minValue) / spread;
      final y = size.height * (0.82 - (normalized * 0.56));
      chartPoints.add(Offset(x, y));
    }

    final path = Path()..moveTo(chartPoints.first.dx, chartPoints.first.dy);
    for (var i = 1; i < chartPoints.length; i++) {
      path.lineTo(chartPoints[i].dx, chartPoints[i].dy);
    }

    final paint =
        Paint()
          ..shader = LinearGradient(
            colors: colors,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.points != points;
  }
}

class _PatternTile extends StatelessWidget {
  const _PatternTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(14),
        vertical: dims.scaleSpace(12),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white,
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF2D170F),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(10),
                  vertical: dims.scaleSpace(6),
                ),
                decoration: BoxDecoration(
                  color: isDark ? colors.bgSurface : const Color(0xFFFFF2EA),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: dims.scaleText(11.5),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF6B2F),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(10)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: dims.scaleWidth(12),
              vertical: dims.scaleSpace(10),
            ),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? colors.bgSurface
                      : const Color(0xFFFFFBF7).withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
              border: Border.all(
                color: isDark ? colors.border : const Color(0xFFF5E5DC),
              ),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(13),
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
