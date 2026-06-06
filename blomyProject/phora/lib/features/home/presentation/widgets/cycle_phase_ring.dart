import 'dart:math' as math;

import 'package:flutter/material.dart';

class CyclePhaseRing extends StatelessWidget {
  const CyclePhaseRing({
    super.key,
    required this.currentPhase,
    required this.fertileToday,
    required this.nextPeriodDate,
    required this.nextOvulationDate,
    required this.size,
    required this.strokeWidth,
    this.child,
    this.backgroundColor = const Color(0xFFFFF6F0),
  });

  final String currentPhase;
  final bool fertileToday;
  final DateTime? nextPeriodDate;
  final DateTime? nextOvulationDate;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Color backgroundColor;

  static const Color menstrual = Color(0xFFFF8A4C);
  static const Color follicular = Color(0xFF52C79A);
  static const Color ovulation = Color(0xFF67AEE8);
  static const Color luteal = Color(0xFFB96BD6);
  static const Color white = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF4A2C1A);

  @override
  Widget build(BuildContext context) {
    final edgePadding = size * 0.04;
    final indicatorSize = size * 0.054;
    final activeBadgeSize = size * 0.09;
    final safeStrokeWidth = strokeWidth.clamp(12.0, size * 0.16);
    final ringRadius = (size / 2) - edgePadding - (safeStrokeWidth / 2);
    final center = Offset(size / 2, size / 2);

    final currentSegment = _CycleRingSegment.fromPhase(currentPhase);
    final indicatorPoint = _pointOnCircle(
      center,
      ringRadius,
      _segmentMidAngle(currentSegment, ringRadius),
    );
    final indicatorColor = currentSegment.gradient.last;
    final ovulationPoint = _pointOnCircle(
      center,
      ringRadius,
      _segmentMidAngle(_CycleRingSegment.ovulation, ringRadius),
    );
    final periodPoint = _pointOnCircle(
      center,
      ringRadius,
      _segmentMidAngle(_CycleRingSegment.menstrual, ringRadius),
    );

    return Semantics(
      label:
          'Cycle phase ring. Current phase: $currentPhase. '
          'Next period: ${nextPeriodDate?.toIso8601String() ?? 'unknown'}. '
          'Next ovulation: ${nextOvulationDate?.toIso8601String() ?? 'unknown'}.',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _CyclePhaseRingPainter(
                strokeWidth: safeStrokeWidth,
                backgroundColor: backgroundColor,
              ),
            ),
            Positioned(
              left: indicatorPoint.dx - (indicatorSize / 2),
              top: indicatorPoint.dy - (indicatorSize / 2),
              child: Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  color: white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Icon(
                    Icons.navigation_rounded,
                    size: indicatorSize * 0.52,
                    color: indicatorColor,
                  ),
                ),
              ),
            ),
            if (fertileToday)
              _PhaseBadge(
                point: ovulationPoint,
                size: activeBadgeSize,
                icon: Icons.wb_sunny_rounded,
                iconColor: const Color(0xFF4298EF),
              ),
            if (currentSegment == _CycleRingSegment.menstrual)
              _PhaseBadge(
                point: periodPoint,
                size: activeBadgeSize,
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFFFF638C),
              ),
            if (child != null)
              SizedBox.square(
                dimension: ringRadius * 2 - (safeStrokeWidth * 0.78),
                child: Center(child: child),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({
    required this.point,
    required this.size,
    required this.icon,
    required this.iconColor,
  });

  final Offset point;
  final double size;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: point.dx - (size / 2),
      top: point.dy - (size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: CyclePhaseRing.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.52),
      ),
    );
  }
}

class _CyclePhaseRingPainter extends CustomPainter {
  const _CyclePhaseRingPainter({
    required this.strokeWidth,
    required this.backgroundColor,
  });

  final double strokeWidth;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerBadgePadding = size.width * 0.04;
    final radius = (size.width / 2) - outerBadgePadding - (strokeWidth / 2);
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final segmentCount = _CycleRingSegment.values.length;
    final gapRadians = 2 / radius;
    final totalGap = gapRadians * segmentCount;
    final sweep = ((2 * math.pi) - totalGap) / segmentCount;

    final basePaint =
        Paint()
          ..color = backgroundColor.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, basePaint);

    var start = -math.pi / 2;
    for (final segment in _CycleRingSegment.values) {
      final paint =
          Paint()
            ..shader = SweepGradient(
              startAngle: start,
              endAngle: start + sweep,
              colors: segment.gradient,
            ).createShader(arcRect)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round;

      canvas.drawArc(arcRect, start, sweep, false, paint);
      _drawCurvedText(
        canvas,
        center: center,
        radius: radius,
        text: segment.label,
        startAngle: start,
        sweepAngle: sweep,
        fontSize: size.width * 0.036,
      );

      start += sweep + gapRadians;
    }
  }

  void _drawCurvedText(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required String text,
    required double startAngle,
    required double sweepAngle,
    required double fontSize,
  }) {
    final style = TextStyle(
      color: CyclePhaseRing.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.45,
    );
    final painters =
        text
            .split('')
            .map(
              (char) => TextPainter(
                text: TextSpan(text: char, style: style),
                textDirection: TextDirection.ltr,
              )..layout(),
            )
            .toList();

    final textRadius = radius;
    final totalArc = painters.fold<double>(
      0,
      (sum, painter) => sum + (painter.width / textRadius),
    );
    final kerningArc = (text.length - 1) * 0.0045;
    final textSweep = totalArc + kerningArc;
    final angle = startAngle + ((sweepAngle - textSweep) / 2);

    var currentAngle = angle;
    for (final painter in painters) {
      final charArc = painter.width / textRadius;
      final charAngle = currentAngle + (charArc / 2);
      final offset = Offset(
        center.dx + textRadius * math.cos(charAngle),
        center.dy + textRadius * math.sin(charAngle),
      );

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(charAngle + (math.pi / 2));
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();

      currentAngle += charArc + 0.0045;
    }
  }

  @override
  bool shouldRepaint(covariant _CyclePhaseRingPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

enum _CycleRingSegment {
  menstrual(
    label: 'MENSTRUAL',
    gradient: [CyclePhaseRing.menstrual, Color(0xFFFFB183)],
  ),
  follicular(
    label: 'FOLLICULAR',
    gradient: [Color(0xFF9DE0B8), CyclePhaseRing.follicular],
  ),
  ovulation(
    label: 'OVULATION',
    gradient: [Color(0xFF8DC5F3), CyclePhaseRing.ovulation],
  ),
  luteal(label: 'LUTEAL', gradient: [Color(0xFFD7A4EB), CyclePhaseRing.luteal]);

  const _CycleRingSegment({required this.label, required this.gradient});

  final String label;
  final List<Color> gradient;

  static _CycleRingSegment fromPhase(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'menstrual' || 'menstruation' => _CycleRingSegment.menstrual,
      'follicular' => _CycleRingSegment.follicular,
      'ovulation' || 'ovulatory' => _CycleRingSegment.ovulation,
      'luteal' => _CycleRingSegment.luteal,
      _ => _CycleRingSegment.follicular,
    };
  }
}

Offset _pointOnCircle(Offset center, double radius, double angle) {
  return Offset(
    center.dx + radius * math.cos(angle),
    center.dy + radius * math.sin(angle),
  );
}

double _segmentMidAngle(_CycleRingSegment segment, double radius) {
  const segmentCount = 4;
  final gapRadians = 2 / radius;
  final totalGap = gapRadians * segmentCount;
  final sweep = ((2 * math.pi) - totalGap) / segmentCount;
  return -math.pi / 2 +
      (segment.index * (sweep + gapRadians)) +
      (sweep / 2);
}
