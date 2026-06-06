import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/design_tokens.dart';
import 'package:phora/features/auth/domain/app_session.dart';
import 'package:phora/features/profile/domain/user_profile.dart';
import 'package:phora/features/profile/profile_providers.dart';
import 'package:phora/features/subscription/domain/subscription_models.dart';

final _emailVisibleProvider = StateProvider<bool>((ref) => false);

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});

  @override
  ConsumerState<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends ConsumerState<YouScreen> {
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;

  bool get _isBusy => _isSigningOut || _isDeletingAccount;

  Future<void> _signOut() async {
    if (_isBusy) return;
    setState(() => _isSigningOut = true);
    try {
      await ref.read(authSessionProvider.notifier).clearSession();
      if (!mounted) return;
      context.go('/sign-in');
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_isBusy) return;
    setState(() => _isDeletingAccount = true);
    try {
      await _showDeleteAccountSheet(context, ref);
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final l10n = context.l10n;
    final subscription =
        ref.watch(currentSubscriptionProvider).valueOrNull ??
        SubscriptionState.free();
    final session = ref.watch(authSessionProvider).valueOrNull;
    final userProfile = ref.watch(currentUserProfileProvider).valueOrNull;
    final isEmailVisible = ref.watch(_emailVisibleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileName = _profileName(context, userProfile);
    final profileInitials = userProfile?.initials ?? 'V';
    final profileEmail = _profileEmail(session, userProfile);

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: SafeArea(
        child: Stack(
          children: [
            if (!isDark) const _ProfileBackdrop(),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(20),
                    dims.scaleSpace(12),
                    dims.scaleWidth(20),
                    0,
                  ),
                  child: const _ProfileTopBar(),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child:
                      _isBusy
                          ? LinearProgressIndicator(
                            key: const ValueKey('profile-action-progress'),
                            minHeight: dims.scaleHeight(3),
                            color:
                                _isDeletingAccount
                                    ? const Color(0xFFF07A7A)
                                    : const Color(0xFFFF7C45),
                            backgroundColor:
                                isDark
                                    ? colors.border
                                    : const Color(0xFFFFE4D6),
                          )
                          : SizedBox(
                            key: const ValueKey('profile-action-progress-off'),
                            height: dims.scaleHeight(3),
                          ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(20),
                      dims.scaleSpace(18),
                      dims.scaleWidth(20),
                      dims.scaleSpace(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileHeroCard(
                          profileName: profileName,
                          profileInitials: profileInitials,
                          profileEmail: profileEmail,
                          isEmailVisible: isEmailVisible,
                          planLabel: _planName(context, subscription.tier),
                          statusLabel: _statusLabel(context, subscription),
                          statusColor: _statusColor(colors, subscription),
                          onToggleEmail:
                              profileEmail.isEmpty
                                  ? null
                                  : () {
                                    ref
                                        .read(_emailVisibleProvider.notifier)
                                        .state = !isEmailVisible;
                                  },
                          onChangeLanguage: () => context.go('/you/language'),
                        ),
                        SizedBox(height: dims.scaleSpace(18)),
                        _ProfileSectionCard(
                          title: l10n.accountSectionLabel,
                          children: [
                            _ProfileActionTile(
                              icon: Icons.person_outline_rounded,
                              iconColor: const Color(0xFFFF7C45),
                              title: l10n.editProfileLabel,
                              subtitle: l10n.profileEditPersonalInfoSubtitle,
                              onTap: () => context.go('/you/edit-profile'),
                            ),
                            _ProfileSectionDivider(),
                            _ProfileActionTile(
                              icon: Icons.favorite_border_rounded,
                              iconColor: const Color(0xFFFF7C45),
                              title: l10n.healthDataCycleReportTitle,
                              subtitle: l10n.profileCycleReportSubtitle,
                              onTap: () => context.go('/you/health-data'),
                            ),
                            _ProfileSectionDivider(),
                            _ProfileActionTile(
                              icon: Icons.watch_outlined,
                              iconColor: const Color(0xFFFF7C45),
                              title: l10n.connectedDevicesLabel,
                              subtitle: l10n.profileConnectedDevicesSubtitle,
                              onTap: () => context.go('/you/connected-devices'),
                            ),
                            _ProfileSectionDivider(),
                            _ProfileActionTile(
                              icon: Icons.workspace_premium_outlined,
                              iconColor: const Color(0xFFFF7C45),
                              title: l10n.manageSubscriptionLabel,
                              subtitle: l10n.profileManageSubscriptionSubtitle,
                              onTap:
                                  () => context.go('/you/manage-subscription'),
                            ),
                            _ProfileSectionDivider(),
                            _ProfileActionTile(
                              icon: Icons.notifications_outlined,
                              iconColor: const Color(0xFFFF7C45),
                              title: 'Manage Notifications',
                              subtitle:
                                  'Blog posts, wearable reminders & updates',
                              onTap:
                                  () => context.go('/you/manage-notifications'),
                            ),
                          ],
                        ),
                        SizedBox(height: dims.scaleSpace(16)),
                        _ProfileSectionCard(
                          title: l10n.privacyAndDataSectionLabel,
                          children: [
                            _ProfileActionTile(
                              icon: Icons.verified_user_outlined,
                              iconColor: const Color(0xFFFF7C45),
                              title: l10n.privacyPolicyLabel,
                              subtitle: l10n.profilePrivacySubtitle,
                              onTap: () => context.push('/you/privacy-policy'),
                            ),
                            _ProfileSectionDivider(),
                            _ProfileActionTile(
                              icon: Icons.description_outlined,
                              iconColor: const Color(0xFFFF7C45),
                              title: l10n.termsOfServiceLabel,
                              subtitle: l10n.profileTermsSubtitle,
                              onTap: () => context.push('/you/terms'),
                            ),
                            _ProfileSectionDivider(),
                            _ProfileActionTile(
                              icon: Icons.delete_outline_rounded,
                              iconColor: const Color(0xFFF07A7A),
                              title: l10n.deleteAccountLabel,
                              subtitle: l10n.profileDeleteAccountSubtitle,
                              destructive: true,
                              isLoading: _isDeletingAccount,
                              onTap: _isBusy ? null : _deleteAccount,
                            ),
                          ],
                        ),
                        SizedBox(height: dims.scaleSpace(16)),
                        _LogoutCard(
                          isLoading: _isSigningOut,
                          onTap: _isBusy ? null : _signOut,
                        ),
                        SizedBox(height: dims.scaleSpace(24)),
                        const _AppVersionFooter(),
                        SizedBox(height: dims.scaleSpace(8)),
                      ],
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

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop();

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
          Positioned(
            right: 26,
            top: 182,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: const Color(0x19FF8A4C),
              size: 22,
            ),
          ),
          Positioned(
            right: 48,
            top: 228,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: const Color(0x12FF8A4C),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.profileTitle,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: dims.scaleText(32),
                  height: 1,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w500,
                  color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
                ),
              ),
              SizedBox(height: dims.scaleSpace(6)),
              Text(
                context.l10n.profileSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: dims.scaleText(13),
                  height: 1.35,
                  color:
                      isDark ? colors.textSecondary : const Color(0xFF7F6357),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profileName,
    required this.profileInitials,
    required this.profileEmail,
    required this.isEmailVisible,
    required this.planLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.onToggleEmail,
    required this.onChangeLanguage,
  });

  final String profileName;
  final String profileInitials;
  final String profileEmail;
  final bool isEmailVisible;
  final String planLabel;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback? onToggleEmail;
  final VoidCallback onChangeLanguage;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
        boxShadow:
            isDark
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x10C78862),
                    blurRadius: 32,
                    offset: Offset(0, 14),
                  ),
                ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: dims.scaleWidth(92),
            height: dims.scaleWidth(92),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    isDark
                        ? [const Color(0xFF47353C), const Color(0xFF251B23)]
                        : [const Color(0xFFFFE3D3), const Color(0xFFFFF1E6)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              profileInitials,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: dims.scaleText(30),
                fontWeight: FontWeight.w800,
                color: isDark ? colors.textPrimary : const Color(0xFF714232),
              ),
            ),
          ),
          SizedBox(width: dims.scaleWidth(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  profileName,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: dims.scaleText(24),
                    height: 1.05,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w500,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF2D170F),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(8)),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _displayEmail(
                          context,
                          profileEmail,
                          isVisible: isEmailVisible,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: dims.scaleText(13),
                          color:
                              isDark
                                  ? colors.textSecondary
                                  : const Color(0xFF7E736D),
                        ),
                      ),
                    ),
                    if (onToggleEmail != null) ...[
                      SizedBox(width: dims.scaleWidth(6)),
                      InkWell(
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(999),
                        ),
                        onTap: onToggleEmail,
                        child: Padding(
                          padding: EdgeInsets.all(dims.scaleWidth(4)),
                          child: Icon(
                            isEmailVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: dims.scaleText(16),
                            color:
                                isDark
                                    ? colors.textSecondary
                                    : const Color(0xFF8A7E78),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: dims.scaleSpace(12)),
                Wrap(
                  spacing: dims.scaleWidth(8),
                  runSpacing: dims.scaleSpace(8),
                  children: [
                    _HeroChip(
                      icon: Icons.workspace_premium_outlined,
                      label: planLabel,
                      textColor: const Color(0xFFFF6B2F),
                      backgroundColor: const Color(0xFFFFF2EA),
                    ),
                    _HeroChip(
                      label: statusLabel,
                      textColor: statusColor,
                      backgroundColor: statusColor.withValues(alpha: 0.12),
                    ),
                    _HeroIconButton(
                      icon: Icons.language_rounded,
                      onTap: onChangeLanguage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? colors.bgSurface : const Color(0xFFF7F0EB),
      borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(12),
            vertical: dims.scaleSpace(8),
          ),
          child: Icon(
            icon,
            size: dims.scaleText(18),
            color: isDark ? colors.textSecondary : const Color(0xFF846B61),
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.icon,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(12),
        vertical: dims.scaleSpace(8),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dims.scaleText(14), color: textColor),
            SizedBox(width: dims.scaleWidth(6)),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: dims.scaleText(12.5),
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(14),
        dims.scaleWidth(16),
        dims.scaleSpace(8),
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
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: dims.scaleText(11),
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textTertiary : const Color(0xFF8F766A),
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.destructive = false,
    this.isLoading = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool destructive;
  final bool isLoading;
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
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(10)),
          child: Row(
            children: [
              _LeadingBadge(icon: icon, iconColor: iconColor),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(14),
                        fontWeight: FontWeight.w700,
                        color:
                            destructive
                                ? const Color(0xFFF06F63)
                                : isDark
                                ? colors.textPrimary
                                : const Color(0xFF2F1C14),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(2)),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: dims.scaleText(12),
                        height: 1.35,
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF86736A),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(10)),
              if (isLoading)
                SizedBox(
                  width: dims.scaleText(20),
                  height: dims.scaleText(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        destructive
                            ? const Color(0xFFF07A7A)
                            : const Color(0xFFFF7C45),
                  ),
                )
              else
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

class _LeadingBadge extends StatelessWidget {
  const _LeadingBadge({required this.icon, required this.iconColor});

  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: dims.scaleWidth(36),
      height: dims.scaleWidth(36),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Icon(icon, size: dims.scaleText(18), color: iconColor),
    );
  }
}

class _ProfileSectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(left: dims.scaleWidth(48)),
      child: Divider(
        height: 1,
        color: isDark ? colors.border : const Color(0xFFF2E6DE),
      ),
    );
  }
}

class _AppVersionFooter extends ConsumerWidget {
  const _AppVersionFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final version = ref.watch(_appVersionProvider).valueOrNull;

    return Center(
      child: Text(
        version != null ? 'Vyla v$version' : 'Vyla',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: dims.scaleText(11),
          color: isDark
              ? colors.textSecondary.withValues(alpha: 0.5)
              : const Color(0xFFBFA09A),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap, this.isLoading = false});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dims.scaleWidth(16),
              vertical: dims.scaleSpace(16),
            ),
            child: Row(
              children: [
                const _LeadingBadge(
                  icon: Icons.logout_rounded,
                  iconColor: Color(0xFFFF7C45),
                ),
                SizedBox(width: dims.scaleWidth(12)),
                Expanded(
                  child: Text(
                    isLoading ? 'Signing out...' : context.l10n.signOutLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: dims.scaleText(14),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFF7C45),
                    ),
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: dims.scaleText(20),
                    height: dims.scaleText(20),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF7C45),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: dims.scaleText(20),
                    color:
                        isDark ? colors.textTertiary : const Color(0xFF9B8A81),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showDeleteAccountSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  try {
    await ref.read(authRepositoryProvider).requestDeleteAccountOtp();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to send confirmation code. Please try again.'),
      ),
    );
    return;
  }
  if (!context.mounted) return;
  final otpCode = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DeleteAccountSheet(),
  );
  if (otpCode == null || otpCode.length < 4) return;
  try {
    await ref.read(authRepositoryProvider).deleteAccount(otpCode: otpCode);
    await ref.read(authSessionProvider.notifier).clearSession();
    if (!context.mounted) return;
    context.go('/sign-in');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.deleteAccountSuccessMessage)));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Something went wrong. Please try again.')),
    );
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  bool _loading = false;
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Container(
      margin: EdgeInsets.only(top: dims.scaleSpace(48)),
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(22),
        dims.scaleSpace(12),
        dims.scaleWidth(22),
        dims.scaleSpace(28),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(28)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: dims.scaleWidth(42),
              height: dims.scaleHeight(4),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(22)),
          Container(
            width: dims.scaleWidth(56),
            height: dims.scaleWidth(56),
            decoration: const BoxDecoration(
              color: Color(0x1AF07A7A),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_forever_rounded,
              color: const Color(0xFFF07A7A),
              size: dims.scaleText(28),
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),
          Text(
            l10n.deleteAccountConfirmTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: AppTheme.headingFontFamily,
              fontSize: dims.scaleText(22),
              fontWeight: FontWeight.w800,
              color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: dims.scaleSpace(10)),
          Text(
            '${l10n.deleteAccountConfirmBody}\n\nEnter the OTP sent to your email to confirm.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(13),
              height: 1.45,
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: dims.scaleSpace(20)),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: dims.scaleText(22),
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              filled: true,
              fillColor: isDark ? colors.bgSurface : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
                borderSide: const BorderSide(color: Color(0xFFF07A7A)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: dims.scaleSpace(22)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF07A7A),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
                ),
              ),
              onPressed:
                  _loading || _otpController.text.trim().length < 4
                      ? null
                      : () {
                        setState(() => _loading = true);
                        Navigator.of(context).pop(_otpController.text.trim());
                      },
              child:
                  _loading
                      ? SizedBox(
                        width: dims.scaleWidth(20),
                        height: dims.scaleWidth(20),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        l10n.deleteAccountConfirmButton,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: dims.scaleText(14),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(14)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
                ),
              ),
              onPressed: _loading ? null : () => Navigator.of(context).pop(),
              child: Text(
                l10n.deleteAccountConfirmCancel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: dims.scaleText(14),
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _profileName(BuildContext context, UserProfile? userProfile) {
  if (userProfile?.fullName.trim().isNotEmpty == true) {
    return userProfile!.fullName.trim();
  }
  return context.l10n.appName;
}

String _profileEmail(AppSession? session, UserProfile? userProfile) {
  if (userProfile?.email.trim().isNotEmpty == true) {
    return userProfile!.email.trim();
  }
  return session?.email?.trim() ?? '';
}

String _displayEmail(
  BuildContext context,
  String email, {
  required bool isVisible,
}) {
  if (email.isEmpty) {
    return context.l10n.noEmailAvailable;
  }
  if (isVisible) {
    return email;
  }

  final parts = email.split('@');
  if (parts.length != 2) {
    return '••••••••';
  }

  final localPart = parts.first;
  final domain = parts.last;
  final visiblePrefix = localPart.characters.take(2).toString();
  final maskedCount = (localPart.length - visiblePrefix.length).clamp(2, 8);
  return '$visiblePrefix${'•' * maskedCount}@$domain';
}

String _planName(BuildContext context, SubscriptionTier tier) {
  return switch (tier) {
    SubscriptionTier.free => context.l10n.planFreeLabel,
    SubscriptionTier.premium => context.l10n.planPremiumLabel,
  };
}

String _statusLabel(BuildContext context, SubscriptionState subscription) {
  if (subscription.redirectToHome || subscription.isActive) {
    return context.l10n.subscriptionStatusActive;
  }
  return switch (subscription.status) {
    SubscriptionStatus.trialing => context.l10n.subscriptionStatusTrial,
    SubscriptionStatus.pastDue => context.l10n.subscriptionStatusPastDue,
    SubscriptionStatus.canceled => context.l10n.subscriptionStatusCanceled,
    SubscriptionStatus.none => context.l10n.subscriptionStatusInactive,
    SubscriptionStatus.active => context.l10n.subscriptionStatusActive,
  };
}

Color _statusColor(AppColors colors, SubscriptionState subscription) {
  if (subscription.redirectToHome || subscription.isActive) {
    return colors.accentSuccess;
  }
  return switch (subscription.status) {
    SubscriptionStatus.trialing => colors.accentWarning,
    SubscriptionStatus.pastDue => colors.accentDanger,
    SubscriptionStatus.canceled ||
    SubscriptionStatus.none => colors.textTertiary,
    SubscriptionStatus.active => colors.accentSuccess,
  };
}
