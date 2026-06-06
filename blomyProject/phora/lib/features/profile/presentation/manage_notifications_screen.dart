import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/design_tokens.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/features/profile/domain/notification_models.dart';
import 'package:phora/features/profile/profile_providers.dart';

class ManageNotificationsScreen extends ConsumerStatefulWidget {
  const ManageNotificationsScreen({super.key});

  @override
  ConsumerState<ManageNotificationsScreen> createState() =>
      _ManageNotificationsScreenState();
}

class _ManageNotificationsScreenState
    extends ConsumerState<ManageNotificationsScreen> {
  bool _isSaving = false;

  Future<void> _applyPatch({
    required NotificationSettings current,
    required NotificationSettings next,
    required Map<String, dynamic> patch,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(notificationSettingsProvider.notifier)
          .applyPatch(patch: patch, optimisticState: next);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: SafeArea(
        child: Stack(
          children: [
            if (!isDark) const _ManageNotificationsBackdrop(),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(20),
                    dims.scaleSpace(10),
                    dims.scaleWidth(20),
                    0,
                  ),
                  child: _NotifTopBar(
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/you');
                      }
                    },
                  ),
                ),
                Expanded(
                  child: settingsAsync.when(
                    data:
                        (settings) => _buildContent(
                          context,
                          dims,
                          colors,
                          isDark,
                          settings,
                        ),
                    loading:
                        () => Center(
                          child: PhoraLoadingView(
                            message: context.l10n.notificationsLoadingSettings,
                            size: 52,
                          ),
                        ),
                    error:
                        (error, _) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: colors.textTertiary,
                                size: 40,
                              ),
                              SizedBox(height: dims.scaleSpace(12)),
                              Text(
                                error.toString(),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                              SizedBox(height: dims.scaleSpace(16)),
                              FilledButton(
                                onPressed:
                                    () =>
                                        ref
                                            .read(
                                              notificationSettingsProvider
                                                  .notifier,
                                            )
                                            .refresh(),
                                child: Text(context.l10n.retryLabel),
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

  Widget _buildContent(
    BuildContext context,
    AppDimensions dims,
    AppColors colors,
    bool isDark,
    NotificationSettings settings,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(20),
        dims.scaleSpace(16),
        dims.scaleWidth(20),
        dims.scaleSpace(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Master toggle ───────────────────────────────────────────
          _NotifSectionCard(
            isDark: isDark,
            child: _NotifToggleTile(
              isDark: isDark,
              icon: Icons.notifications_active_outlined,
              iconColor: const Color(0xFFC15786),
              title: context.l10n.notificationsAllEnabledTitle,
              subtitle: context.l10n.notificationsAllEnabledSubtitle,
              value: settings.allNotifications,
              enabled: !_isSaving,
              onChanged:
                  (v) => _applyPatch(
                    current: settings,
                    next: settings.copyWith(allNotifications: v),
                    patch: {'all_notifications': v},
                  ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),

          // ── Blog & content ──────────────────────────────────────────
          _NotifSectionHeading(title: 'Blog & Content', isDark: isDark),
          SizedBox(height: dims.scaleSpace(10)),
          _NotifSectionCard(
            isDark: isDark,
            child: _NotifToggleTile(
              isDark: isDark,
              icon: Icons.article_outlined,
              iconColor: const Color(0xFF4A90D9),
              title: 'New Blog Posts',
              subtitle:
                  'Get notified when a new article is published on the Vyla blog.',
              value: settings.blogPosts,
              enabled: !_isSaving,
              onChanged:
                  (v) => _applyPatch(
                    current: settings,
                    next: settings.copyWith(blogPosts: v),
                    patch: {'blog_posts': v},
                  ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),

          // ── Wearable reminders ──────────────────────────────────────
          _NotifSectionHeading(title: 'Wearable Reminders', isDark: isDark),
          SizedBox(height: dims.scaleSpace(10)),
          _NotifSectionCard(
            isDark: isDark,
            child: Column(
              children: [
                _NotifToggleTile(
                  isDark: isDark,
                  icon: Icons.watch_outlined,
                  iconColor: const Color(0xFF58A66E),
                  title: 'Period & Ovulation Reminders',
                  subtitle:
                      'Receive a nudge to connect your Vyla Wear during your period and ovulation window.',
                  value: settings.wearableOvulationReminder,
                  enabled: !_isSaving,
                  onChanged:
                      (v) => _applyPatch(
                        current: settings,
                        next: settings.copyWith(wearableOvulationReminder: v),
                        patch: {'wearable_ovulation_reminder': v},
                      ),
                ),
                _NotifDivider(isDark: isDark),
                _NotifToggleTile(
                  isDark: isDark,
                  icon: Icons.sync_rounded,
                  iconColor: const Color(0xFF58A66E),
                  title: context.l10n.notificationsBangleSyncTitle,
                  subtitle: context.l10n.notificationsBangleSyncSubtitle,
                  value: settings.bangleSyncReminder,
                  enabled: !_isSaving,
                  onChanged:
                      (v) => _applyPatch(
                        current: settings,
                        next: settings.copyWith(bangleSyncReminder: v),
                        patch: {'bangle_sync_reminder': v},
                      ),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),

          // ── App & Updates ───────────────────────────────────────────
          _NotifSectionHeading(title: 'App & Updates', isDark: isDark),
          SizedBox(height: dims.scaleSpace(10)),
          _NotifSectionCard(
            isDark: isDark,
            child: Column(
              children: [
                _NotifToggleTile(
                  isDark: isDark,
                  icon: Icons.system_update_alt_rounded,
                  iconColor: const Color(0xFFFF7C45),
                  title: 'Update Reminders',
                  subtitle:
                      'Stay informed about new Vyla features and important app updates.',
                  value: settings.updateReminders,
                  enabled: !_isSaving,
                  onChanged:
                      (v) => _applyPatch(
                        current: settings,
                        next: settings.copyWith(updateReminders: v),
                        patch: {'update_reminders': v},
                      ),
                ),
                _NotifDivider(isDark: isDark),
                _NotifToggleTile(
                  isDark: isDark,
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: const Color(0xFFE1A23A),
                  title: 'Tips & Feature Guides',
                  subtitle:
                      'Helpful tips to get the most out of your Vyla experience.',
                  value: settings.bangleSyncReminder,
                  enabled: !_isSaving,
                  onChanged:
                      (v) => _applyPatch(
                        current: settings,
                        next: settings.copyWith(bangleSyncReminder: v),
                        patch: {'feature_tips': v},
                      ),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),

          // ── Info card ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(dims.scaleWidth(16)),
            decoration: BoxDecoration(
              color: isDark ? colors.bgElevated : const Color(0xFFFFF4ED),
              borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
              border: Border.all(
                color: isDark ? colors.border : const Color(0xFFFFE0CC),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: dims.scaleText(18),
                  color: const Color(0xFFFF7C45),
                ),
                SizedBox(width: dims.scaleWidth(10)),
                Expanded(
                  child: Text(
                    'Critical health alerts (heavy bleeding, potential pregnancy) are always enabled for your safety.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: dims.scaleText(12),
                      color:
                          isDark
                              ? colors.textSecondary
                              : const Color(0xFF7F6357),
                      height: 1.5,
                    ),
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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ManageNotificationsBackdrop extends StatelessWidget {
  const _ManageNotificationsBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            top: -80,
            left: -70,
            child: _ManageSoftGlow(size: 220, color: Color(0x18FF8E54)),
          ),
          Positioned(
            bottom: 60,
            right: -90,
            child: _ManageSoftGlow(size: 260, color: Color(0x16C15786)),
          ),
          Positioned(top: 112, right: 18, child: _ManageFloralAccent()),
        ],
      ),
    );
  }
}

class _ManageSoftGlow extends StatelessWidget {
  const _ManageSoftGlow({required this.size, required this.color});

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

class _ManageFloralAccent extends StatelessWidget {
  const _ManageFloralAccent();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      height: 150,
      child: CustomPaint(painter: _ManageFloralAccentPainter()),
    );
  }
}

class _ManageFloralAccentPainter extends CustomPainter {
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

class _NotifTopBar extends StatelessWidget {
  const _NotifTopBar({required this.onBack});

  final VoidCallback onBack;

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
            onTap: onBack,
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
                  'Manage Notifications',
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
                  'Choose what matters to you.',
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

class _NotifSectionHeading extends StatelessWidget {
  const _NotifSectionHeading({required this.title, required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: dims.scaleText(18),
        fontWeight: FontWeight.w700,
        color: isDark ? colors.textPrimary : const Color(0xFF21140F),
      ),
    );
  }
}

class _NotifSectionCard extends StatelessWidget {
  const _NotifSectionCard({required this.child, required this.isDark});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(14),
        vertical: dims.scaleSpace(4),
      ),
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
                    color: Color(0x08C78862),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
      ),
      child: child,
    );
  }
}

class _NotifDivider extends StatelessWidget {
  const _NotifDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? colors.border : const Color(0xFFF0E1D7),
    );
  }
}

class _NotifToggleTile extends StatelessWidget {
  const _NotifToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: dims.scaleWidth(40),
            height: dims.scaleWidth(40),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: dims.scaleText(20)),
          ),
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(15),
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF21140F),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(3)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(13),
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF7F6357),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(10)),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFC15786),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor:
                isDark ? colors.bgSurface : const Color(0xFFE8D5CC),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
