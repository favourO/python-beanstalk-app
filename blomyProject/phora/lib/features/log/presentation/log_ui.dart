import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LogSectionHeader extends StatelessWidget {
  const LogSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.screenHeaderStyle(
            context,
            dims,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: dims.scaleSpace(10)),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: dims.scaleText(15),
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class LogPageHeader extends StatelessWidget {
  const LogPageHeader({
    super.key,
    required this.title,
    this.backRoute = '/log',
    this.trailing,
  });

  final String title;
  final String backRoute;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
          onTap: () => context.go(backRoute),
          child: Container(
            width: dims.scaleWidth(48),
            height: dims.scaleWidth(48),
            decoration: BoxDecoration(
              color: colors.bgCard,
              borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
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
          title,
          style: AppTheme.screenHeaderStyle(
            context,
            dims,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class LogPageScaffold extends StatelessWidget {
  const LogPageScaffold({
    super.key,
    required this.header,
    required this.child,
    this.backgroundColor,
  });

  final Widget header;
  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        backgroundColor ?? (isDark ? colors.bg : const Color(0xFFFFFBF7));

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                dims.scaleWidth(18),
                dims.scaleSpace(14),
                dims.scaleWidth(18),
                dims.scaleSpace(14),
              ),
              child: Align(alignment: Alignment.centerLeft, child: header),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  dims.scaleWidth(18),
                  0,
                  dims.scaleWidth(18),
                  dims.scaleSpace(28),
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
