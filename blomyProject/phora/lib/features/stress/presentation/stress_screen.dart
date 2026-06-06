import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StressScreen extends StatelessWidget {
  const StressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
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
                    onTap: () => context.go('/today'),
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
                    context.l10n.stressImpactTitle,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StressCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.stressBurdenLabel,
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(
                              fontSize: dims.scaleText(12),
                              color: colors.textTertiary,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '0.42',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displaySmall?.copyWith(
                                    fontSize: dims.scaleText(40),
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: ' /1.0',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.copyWith(
                                    fontSize: dims.scaleText(18),
                                    fontWeight: FontWeight.w700,
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          Text(
                            context.l10n.stressBurdenDescription,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontSize: dims.scaleText(15),
                              color: colors.textSecondary,
                              height: 1.55,
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          _BurdenScale(value: 0.42),
                        ],
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(18)),
                    _StressCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.stressContributingFactorsTitle,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontSize: dims.scaleText(18),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          _FactorRow(
                            label: context.l10n.stressFactorHrvLabel,
                            value: '-1.2 σ',
                            progress: 0.60,
                            color: Color(0xFFF6C247),
                          ),
                          SizedBox(height: 14),
                          _FactorRow(
                            label: context.l10n.stressFactorRhrLabel,
                            value: '+0.8 σ',
                            progress: 0.40,
                            color: Color(0xFFF6C247),
                          ),
                          SizedBox(height: 14),
                          _FactorRow(
                            label: context.l10n.stressFactorSleepLabel,
                            value: context.l10n.stressNormalLabel,
                            progress: 0.20,
                            color: Color(0xFF5DA8FF),
                          ),
                          SizedBox(height: 14),
                          _FactorRow(
                            label: context.l10n.stressFactorSelfReportedLabel,
                            value: context.l10n.stressModerateLabel,
                            progress: 0.50,
                            color: Color(0xFFF6C247),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(18)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(dims.scaleWidth(20)),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2618),
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(24),
                        ),
                        border: Border.all(color: const Color(0xFF6F5622)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.stressPredictedImpactTitle,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontSize: dims.scaleText(18),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: context.l10n.stressConfidenceLabel,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.copyWith(
                                    fontSize: dims.scaleText(16),
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      context.l10n.stressPredictedImpactSuffix,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(
                                    fontSize: dims.scaleText(16),
                                    color: Colors.white.withValues(alpha: 0.88),
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(16)),
                          Text(
                            context.l10n.stressPredictedImpactDescription,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontSize: dims.scaleText(15),
                              color: Colors.white.withValues(alpha: 0.68),
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(18)),
                    _StressCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.stressLast30DaysTitle,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontSize: dims.scaleText(18),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          Container(
                            width: double.infinity,
                            height: dims.scaleHeight(160),
                            padding: EdgeInsets.all(dims.scaleWidth(18)),
                            decoration: BoxDecoration(
                              color: colors.bgSurface,
                              borderRadius: BorderRadius.circular(
                                dims.scaleRadius(18),
                              ),
                            ),
                            child: const _StressTrendChart(),
                          ),
                          SizedBox(height: dims.scaleSpace(14)),
                          Row(
                            children: [
                              const _LegendDot(color: Color(0xFFF6C247)),
                              SizedBox(width: 6),
                              Text(
                                context.l10n.stressBurdenLegend,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontSize: dims.scaleText(14),
                                  color: colors.textSecondary,
                                ),
                              ),
                              SizedBox(width: dims.scaleWidth(18)),
                              const _LegendDot(color: Color(0xFF65CAE8)),
                              SizedBox(width: 6),
                              Text(
                                context.l10n.stressOvulationDaysLegend,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontSize: dims.scaleText(14),
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(18)),
                    _StressCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.stressCycleCorrelationTitle,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontSize: dims.scaleText(18),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          Text(
                            context.l10n.stressCycleCorrelationIntro,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontSize: dims.scaleText(16),
                              color: colors.textSecondary,
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(12)),
                          ...[
                            context.l10n.stressCycleCorrelationItemOne,
                            context.l10n.stressCycleCorrelationItemTwo,
                            context.l10n.stressCycleCorrelationItemThree,
                          ].map(
                            (item) => Padding(
                              padding: EdgeInsets.only(
                                bottom: dims.scaleSpace(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: dims.scaleSpace(5),
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

class _StressCard extends StatelessWidget {
  const _StressCard({required this.child});

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

class _BurdenScale extends StatelessWidget {
  const _BurdenScale({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
          child: SizedBox(
            height: dims.scaleHeight(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: colors.bgSurface),
                ),
                FractionallySizedBox(
                  widthFactor: value,
                  alignment: Alignment.centerLeft,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFFF6C247)),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: dims.scaleSpace(8)),
        Row(
          children: [
            Text(
              context.l10n.stressLowLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              context.l10n.stressModerateLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              context.l10n.stressHighLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(16),
                  color: colors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: dims.scaleText(16),
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: dims.scaleSpace(8)),
        ClipRRect(
          borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
          child: SizedBox(
            height: dims.scaleHeight(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: colors.bgSurface),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(decoration: BoxDecoration(color: color)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StressTrendChart extends StatelessWidget {
  const _StressTrendChart();

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return CustomPaint(
      painter: _StressTrendPainter(
        stressColor: const Color(0xFFF6C247),
        ovulationColor: const Color(0xFF65CAE8),
        textColor: colors.textTertiary,
      ),
      child: Center(
        child: Text(
          context.l10n.stressTrendChartPlaceholder,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: dims.scaleText(12),
            color: colors.textTertiary,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _StressTrendPainter extends CustomPainter {
  const _StressTrendPainter({
    required this.stressColor,
    required this.ovulationColor,
    required this.textColor,
  });

  final Color stressColor;
  final Color ovulationColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stressPaint =
        Paint()
          ..color = stressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    final ovulationPaint =
        Paint()
          ..color = ovulationColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    final stressPoints = [
      Offset(size.width * 0.06, size.height * 0.72),
      Offset(size.width * 0.18, size.height * 0.64),
      Offset(size.width * 0.32, size.height * 0.48),
      Offset(size.width * 0.48, size.height * 0.42),
      Offset(size.width * 0.62, size.height * 0.36),
      Offset(size.width * 0.78, size.height * 0.52),
      Offset(size.width * 0.92, size.height * 0.60),
    ];

    final stressPath =
        Path()..moveTo(stressPoints.first.dx, stressPoints.first.dy);
    for (var i = 1; i < stressPoints.length; i++) {
      final previous = stressPoints[i - 1];
      final current = stressPoints[i];
      final controlX = (previous.dx + current.dx) / 2;
      stressPath.quadraticBezierTo(
        controlX,
        previous.dy,
        current.dx,
        current.dy,
      );
    }
    canvas.drawPath(stressPath, stressPaint);

    for (final dx in [size.width * 0.28, size.width * 0.68]) {
      canvas.drawLine(
        Offset(dx, size.height * 0.18),
        Offset(dx, size.height * 0.86),
        ovulationPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StressTrendPainter other) {
    return other.stressColor != stressColor ||
        other.ovulationColor != ovulationColor ||
        other.textColor != textColor;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: dims.scaleWidth(14),
      height: dims.scaleHeight(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
    );
  }
}
