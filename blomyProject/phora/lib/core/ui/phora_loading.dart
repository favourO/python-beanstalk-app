import 'package:flutter/material.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';

class PhoraLoadingIndicator extends StatelessWidget {
  const PhoraLoadingIndicator({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final indicatorSize = dims.scaleWidth(size, min: 0.78, max: 1.2);
    final strokeWidth = dims.scaleWidth(5, min: 0.9, max: 1.2);

    return SizedBox(
      width: indicatorSize,
      height: indicatorSize,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        backgroundColor: colors.accentPrimary.withValues(alpha: 0.16),
      ),
    );
  }
}

class PhoraLoadingView extends StatelessWidget {
  const PhoraLoadingView({
    super.key,
    this.message,
    this.size = 84,
    this.spacing = 16,
  });

  final String? message;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhoraLoadingIndicator(size: size),
          if (message != null && message!.trim().isNotEmpty) ...[
            SizedBox(height: dims.scaleSpace(spacing)),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: dims.scaleText(15),
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
