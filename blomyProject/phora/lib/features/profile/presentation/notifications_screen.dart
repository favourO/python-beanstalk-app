import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/i18n/formatters.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/notifications/notification_destination.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/design_tokens.dart';
import 'package:phora/features/profile/domain/notification_models.dart';
import 'package:phora/features/profile/profile_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _refresh() async {
    await ref.read(notificationHistoryProvider.notifier).refresh();
  }

  void _markRead(AppNotification notification) {
    if (notification.isRead) return;
    ref.read(notificationHistoryProvider.notifier).markRead(notification.id);
  }

  void _openNotification(AppNotification notification) {
    _markRead(notification);
    final destination = notificationDestinationFromData({
      'notification_type': notification.notificationType,
      if (notification.actionUrl != null) 'action_url': notification.actionUrl,
      if (notification.payload != null) ...notification.payload!,
    });
    if (destination != '/notifications') {
      context.go(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyAsync = ref.watch(notificationHistoryProvider);
    final allNotifs =
        historyAsync.valueOrNull?.items ?? const <AppNotification>[];
    final filtered = allNotifs;
    final pageBackground = isDark ? colors.bg : const Color(0xFFFFFBF7);

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            if (!isDark) const _NotificationsBackdrop(),
            RefreshIndicator(
              onRefresh: _refresh,
              color: colors.accentPrimary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context, dims)),
                  SliverToBoxAdapter(
                    child: _buildHistoryView(
                      context,
                      dims,
                      colors,
                      isDark,
                      historyAsync,
                      filtered,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppDimensions dims) {
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(20),
        dims.scaleSpace(10),
        dims.scaleWidth(20),
        dims.scaleSpace(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.pop(),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: dims.scaleSpace(8)),
              child: Column(
                children: [
                  Text(
                    context.l10n.notificationsTitle,
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
                    context.l10n.notificationsSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: dims.scaleText(13),
                      height: 1.45,
                      color:
                          isDark
                              ? colors.textSecondary
                              : const Color(0xFF7F6357),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          _CircleIconButton(
            icon: Icons.settings_outlined,
            onTap: () => context.go('/you/manage-notifications'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView(
    BuildContext context,
    AppDimensions dims,
    AppColors colors,
    bool isDark,
    AsyncValue<NotificationHistory?> historyAsync,
    List<AppNotification> filtered,
  ) {
    return historyAsync.when(
      data:
          (_) =>
              filtered.isEmpty
                  ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(20),
                      dims.scaleSpace(8),
                      dims.scaleWidth(20),
                      dims.scaleSpace(32),
                    ),
                    child: const _EmptyHistoryCard(),
                  )
                  : _buildGroupedList(context, dims, colors, isDark, filtered),
      loading:
          () => Padding(
            padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(48)),
            child: PhoraLoadingView(
              message: context.l10n.notificationsLoadingHistory,
              size: 52,
            ),
          ),
      error:
          (error, _) => Padding(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(20),
              dims.scaleSpace(8),
              dims.scaleWidth(20),
              dims.scaleSpace(12),
            ),
            child: _ErrorState(
              message: error.toString(),
              onRetry:
                  () =>
                      ref.read(notificationHistoryProvider.notifier).refresh(),
            ),
          ),
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    AppDimensions dims,
    AppColors colors,
    bool isDark,
    List<AppNotification> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayItems = <AppNotification>[];
    final yesterdayItems = <AppNotification>[];
    final earlierItems = <AppNotification>[];

    for (final n in notifications) {
      if (n.createdAt == null) {
        todayItems.add(n);
        continue;
      }
      final d = DateTime(
        n.createdAt!.year,
        n.createdAt!.month,
        n.createdAt!.day,
      );
      final diff = today.difference(d).inDays;
      if (diff == 0) {
        todayItems.add(n);
      } else if (diff == 1) {
        yesterdayItems.add(n);
      } else {
        earlierItems.add(n);
      }
    }

    final sections = <(String, List<AppNotification>)>[];
    if (todayItems.isNotEmpty) {
      sections.add((context.l10n.notificationsSectionToday, todayItems));
    }
    if (yesterdayItems.isNotEmpty) {
      sections.add((
        context.l10n.notificationsSectionYesterday,
        yesterdayItems,
      ));
    }
    if (earlierItems.isNotEmpty) {
      sections.add((context.l10n.notificationsSectionEarlier, earlierItems));
    }

    final cardColor =
        isDark ? colors.bgCard : Colors.white.withValues(alpha: 0.9);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(20),
        dims.scaleSpace(4),
        dims.scaleWidth(20),
        dims.scaleSpace(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            sections.map((section) {
              final (label, items) = section;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: dims.scaleSpace(18)),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: dims.scaleText(12),
                      fontWeight: FontWeight.w600,
                      color: colors.textTertiary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(8)),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
                      border: Border.all(
                        color: isDark ? colors.border : const Color(0xFFF0E1D7),
                      ),
                      boxShadow:
                          isDark
                              ? null
                              : const [
                                BoxShadow(
                                  color: Color(0x08C78862),
                                  blurRadius: 24,
                                  offset: Offset(0, 12),
                                ),
                              ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        dims.scaleRadius(28) - 1,
                      ),
                      child: Material(
                        color: cardColor,
                        child: Column(
                          children: List.generate(items.length * 2 - 1, (i) {
                            if (i.isOdd) {
                              return Divider(
                                height: 1,
                                thickness: 1,
                                color:
                                    isDark
                                        ? colors.border.withValues(alpha: 0.8)
                                        : const Color(0xFFF0E1D7),
                                indent: dims.scaleWidth(74),
                              );
                            }
                            final n = items[i ~/ 2];
                            return _NotificationRow(
                              notification: n,
                              onTap: () => _openNotification(n),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
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
            icon,
            size: dims.scaleText(20),
            color: isDark ? colors.textPrimary : const Color(0xFF5A2A18),
          ),
        ),
      ),
    );
  }
}

class _NotificationsBackdrop extends StatelessWidget {
  const _NotificationsBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            top: -80,
            left: -70,
            child: _SoftGlow(size: 220, color: Color(0x18FF8E54)),
          ),
          Positioned(
            bottom: 60,
            right: -90,
            child: _SoftGlow(size: 260, color: Color(0x16C15786)),
          ),
          Positioned(top: 112, right: 18, child: _NotificationFloralAccent()),
        ],
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, const Color(0x00FFFFFF)]),
      ),
    );
  }
}

class _NotificationFloralAccent extends StatelessWidget {
  const _NotificationFloralAccent();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      height: 150,
      child: CustomPaint(painter: _NotificationFloralAccentPainter()),
    );
  }
}

class _NotificationFloralAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x26E9A27B)
          ..strokeCap = StrokeCap.round;

    final stem =
        Path()
          ..moveTo(size.width * 0.74, size.height)
          ..quadraticBezierTo(
            size.width * 0.62,
            size.height * 0.70,
            size.width * 0.56,
            size.height * 0.48,
          )
          ..quadraticBezierTo(
            size.width * 0.48,
            size.height * 0.22,
            size.width * 0.30,
            0,
          );
    canvas.drawPath(stem, stroke);

    final leafA =
        Path()
          ..moveTo(size.width * 0.58, size.height * 0.74)
          ..quadraticBezierTo(
            size.width * 0.28,
            size.height * 0.62,
            size.width * 0.14,
            size.height * 0.44,
          )
          ..quadraticBezierTo(
            size.width * 0.34,
            size.height * 0.52,
            size.width * 0.58,
            size.height * 0.74,
          );
    canvas.drawPath(leafA, stroke);

    final leafB =
        Path()
          ..moveTo(size.width * 0.58, size.height * 0.62)
          ..quadraticBezierTo(
            size.width * 0.84,
            size.height * 0.54,
            size.width * 0.92,
            size.height * 0.30,
          )
          ..quadraticBezierTo(
            size.width * 0.74,
            size.height * 0.42,
            size.width * 0.58,
            size.height * 0.62,
          );
    canvas.drawPath(leafB, stroke);

    void drawBloom(Offset center, double scale) {
      for (final angle in <double>[0, 1.2, 2.4]) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        final petal =
            Path()
              ..moveTo(0, 0)
              ..quadraticBezierTo(-14 * scale, -12 * scale, 0, -28 * scale)
              ..quadraticBezierTo(14 * scale, -12 * scale, 0, 0);
        canvas.drawPath(petal, stroke);
        canvas.restore();
      }
    }

    drawBloom(Offset(size.width * 0.28, size.height * 0.20), 0.95);
    drawBloom(Offset(size.width * 0.52, size.height * 0.42), 0.82);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Notification row ────────────────────────────────────────────────────────

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final style = _notifStyle(notification);
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(16),
          vertical: dims.scaleSpace(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: dims.scaleWidth(46),
                  height: dims.scaleWidth(46),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [style.iconBg, style.pillBg],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    style.icon,
                    color: style.accent,
                    size: dims.scaleText(20),
                  ),
                ),
                if (isUnread)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      width: dims.scaleWidth(9),
                      height: dims.scaleWidth(9),
                      decoration: BoxDecoration(
                        color: style.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: dims.scaleWidth(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontSize: dims.scaleText(14),
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w600,
                            color: colors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(width: dims.scaleWidth(10)),
                      Text(
                        _timeLabel(context, notification.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: dims.scaleText(11),
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: dims.scaleSpace(4)),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: dims.scaleText(13),
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(22)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgCard : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: colors.textTertiary,
            size: dims.scaleText(28),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          Text(
            context.l10n.notificationsEmptyTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: dims.scaleText(18),
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textPrimary : const Color(0xFF21140F),
            ),
          ),
          SizedBox(height: dims.scaleSpace(6)),
          Text(
            context.l10n.notificationsEmptySubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(13),
              color: isDark ? colors.textSecondary : const Color(0xFF7F6357),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(20)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgCard : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.notificationsLoadErrorTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: dims.scaleText(18),
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textPrimary : const Color(0xFF21140F),
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(14),
              color: isDark ? colors.textSecondary : const Color(0xFF7F6357),
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),
          FilledButton(
            onPressed: onRetry,
            child: Text(context.l10n.retryLabel),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _timeLabel(BuildContext context, DateTime? dateTime) {
  if (dateTime == null) return context.l10n.notificationsNowLabel;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final dayDiff = today.difference(thatDay).inDays;
  if (dayDiff == 0) {
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return context.l10n.notificationsNowLabel;
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  if (dayDiff == 1) return context.l10n.notificationsYesterdayLabel;
  return AppFormatters.formatDateShort(
    dateTime,
    localeTag: Localizations.localeOf(context).toLanguageTag(),
  );
}

_NotifStyle _notifStyle(AppNotification notification) {
  switch (notification.category) {
    case 'health_insights':
      return const _NotifStyle(
        accent: Color(0xFF58A66E),
        iconBg: Color(0xFFF1FAF3),
        pillBg: Color(0xFFEAF6ED),
        icon: Icons.spa_outlined,
      );
    case 'reminders':
      return const _NotifStyle(
        accent: Color(0xFFE1A23A),
        iconBg: Color(0xFFFCF5E7),
        pillBg: Color(0xFFF9EFD9),
        icon: Icons.article_outlined,
      );
    case 'critical_alerts':
      return const _NotifStyle(
        accent: Color(0xFFE15249),
        iconBg: Color(0xFFFCEDEC),
        pillBg: Color(0xFFF9E3E1),
        icon: Icons.warning_amber_rounded,
      );
    case 'updates':
      return const _NotifStyle(
        accent: Color(0xFF4A90D9),
        iconBg: Color(0xFFECF4FD),
        pillBg: Color(0xFFDAEBF9),
        icon: Icons.system_update_alt_rounded,
      );
    case 'system':
      return const _NotifStyle(
        accent: Color(0xFF7B68C8),
        iconBg: Color(0xFFF0EEFA),
        pillBg: Color(0xFFE4DFF7),
        icon: Icons.settings_outlined,
      );
    case 'predictions':
    default:
      return const _NotifStyle(
        accent: Color(0xFFCF6C83),
        iconBg: Color(0xFFFDF1F4),
        pillBg: Color(0xFFF9E8ED),
        icon: Icons.opacity_outlined,
      );
  }
}

class _NotifStyle {
  const _NotifStyle({
    required this.accent,
    required this.iconBg,
    required this.pillBg,
    required this.icon,
  });

  final Color accent;
  final Color iconBg;
  final Color pillBg;
  final IconData icon;
}
