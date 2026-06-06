import 'package:flutter/material.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/growth/domain/growth_models.dart';

class InsightShareCard extends StatelessWidget {
  const InsightShareCard({super.key, required this.card});

  final ShareInsightCardModel card;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final accent = switch (card.accent) {
      'pink' => const Color(0xFFF6A4D6),
      'rose' => const Color(0xFFF4B8AF),
      'plum' => const Color(0xFFC79CF4),
      _ => const Color(0xFFE3C2FF),
    };
    return Container(
      padding: EdgeInsets.all(dims.scaleSpace(16)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: dims.scaleWidth(34),
            height: dims.scaleWidth(6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            ),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          Text(
            card.title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            card.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          if ((card.subtitle ?? '').isNotEmpty) ...[
            SizedBox(height: dims.scaleSpace(8)),
            Text(
              card.subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
