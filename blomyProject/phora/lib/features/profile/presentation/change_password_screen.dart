import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/profile/profile_providers.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  // Regular flow controllers
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  // Social / OTP flow
  late final TextEditingController _otpController;
  late final TextEditingController _socialNewPasswordController;
  late final TextEditingController _socialConfirmPasswordController;
  bool _hideSocialNewPassword = true;
  bool _hideSocialConfirmPassword = true;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _otpController = TextEditingController();
    _socialNewPasswordController = TextEditingController();
    _socialConfirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _socialNewPasswordController.dispose();
    _socialConfirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isSocialAccount {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    return profile?.accountMode == 'social';
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSocial = _isSocialAccount;

    final title = isSocial ? 'Set a Password' : context.l10n.updatePasswordLabel;
    final subtitle = isSocial
        ? 'Secure your account with a password.'
        : context.l10n.changePasswordHeroSubtitle;

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: SafeArea(
        child: Stack(
          children: [
            if (!isDark) const _ChangePasswordBackdrop(),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(20),
                    dims.scaleSpace(10),
                    dims.scaleWidth(20),
                    0,
                  ),
                  child: _PasswordTopBar(
                    title: title,
                    subtitle: subtitle,
                    onBack: _handleBackNavigation,
                  ),
                ),
                Expanded(
                  child: isSocial
                      ? _buildSocialFlow(context)
                      : _buildRegularFlow(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Regular (existing) flow ──────────────────────────────────────────────

  Widget _buildRegularFlow(BuildContext context) {
    final dims = context.dims;
    final l10n = context.l10n;
    final changeState = ref.watch(changePasswordControllerProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(20),
        dims.scaleSpace(18),
        dims.scaleWidth(20),
        dims.scaleSpace(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PasswordSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(title: l10n.currentPasswordLabel),
                SizedBox(height: dims.scaleSpace(10)),
                _PasswordField(
                  controller: _currentPasswordController,
                  hintText: l10n.currentPasswordHint,
                  obscureText: _hideCurrentPassword,
                  onToggle: () => setState(
                    () => _hideCurrentPassword = !_hideCurrentPassword,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                _FieldLabel(title: l10n.newPasswordLabel),
                SizedBox(height: dims.scaleSpace(10)),
                _PasswordField(
                  controller: _newPasswordController,
                  hintText: l10n.changePasswordNewHint,
                  obscureText: _hideNewPassword,
                  onToggle: () => setState(
                    () => _hideNewPassword = !_hideNewPassword,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                _FieldLabel(title: l10n.changePasswordConfirmNewLabel),
                SizedBox(height: dims.scaleSpace(10)),
                _PasswordField(
                  controller: _confirmPasswordController,
                  hintText: l10n.changePasswordConfirmHint,
                  obscureText: _hideConfirmPassword,
                  onToggle: () => setState(
                    () => _hideConfirmPassword = !_hideConfirmPassword,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(20)),
          _PasswordSectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _InfoBadge(icon: Icons.info_outline_rounded),
                SizedBox(width: dims.scaleWidth(12)),
                Expanded(
                  child: Text(
                    l10n.changePasswordInfo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: dims.scaleText(13),
                      height: 1.45,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? context.phora.colors.textSecondary
                          : const Color(0xFF7F6357),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: dims.scaleSpace(28)),
          _PrimaryActionButton(
            label: changeState.isLoading
                ? context.l10n.updatingLabel
                : context.l10n.updatePasswordLabel,
            isLoading: changeState.isLoading,
            onTap: changeState.isLoading ? null : _submitRegular,
          ),
        ],
      ),
    );
  }

  Future<void> _submitRegular() async {
    final messenger = ScaffoldMessenger.of(context);
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.changePasswordFillAllFields)),
      );
      return;
    }
    if (newPassword.length < 8) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.changePasswordLengthError)),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.signUpPasswordsMismatchError)),
      );
      return;
    }

    final didChange = await ref
        .read(changePasswordControllerProvider.notifier)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
    if (!mounted) return;
    if (!didChange) {
      final message =
          ref.read(changePasswordControllerProvider).error?.toString() ??
          context.l10n.changePasswordUpdateFailed;
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final message =
        ref.read(changePasswordControllerProvider).valueOrNull ??
        context.l10n.changePasswordUpdated;
    messenger.showSnackBar(SnackBar(content: Text(message)));
    _handleBackNavigation();
  }

  // ── Social / OTP flow ────────────────────────────────────────────────────

  Widget _buildSocialFlow(BuildContext context) {
    final dims = context.dims;
    final sendState = ref.watch(sendSetPasswordOtpControllerProvider);
    final setPassState = ref.watch(setPasswordControllerProvider);
    final isLoading = sendState.isLoading || setPassState.isLoading;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(20),
        dims.scaleSpace(18),
        dims.scaleWidth(20),
        dims.scaleSpace(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_otpSent) ...[
            _PasswordSectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _InfoBadge(icon: Icons.info_outline_rounded),
                  SizedBox(width: dims.scaleWidth(12)),
                  Expanded(
                    child: Text(
                      'Since you signed up with a social account, we\'ll verify your identity via a one-time code before setting a password.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: dims.scaleText(13),
                        height: 1.45,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? context.phora.colors.textSecondary
                            : const Color(0xFF7F6357),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: dims.scaleSpace(28)),
            _PrimaryActionButton(
              label: sendState.isLoading ? 'Sending…' : 'Send Verification Code',
              isLoading: sendState.isLoading,
              onTap: sendState.isLoading ? null : _sendOtp,
            ),
          ] else ...[
            _PasswordSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(title: 'Verification Code'),
                  SizedBox(height: dims.scaleSpace(10)),
                  _OtpField(controller: _otpController),
                  SizedBox(height: dims.scaleSpace(18)),
                  _FieldLabel(title: context.l10n.newPasswordLabel),
                  SizedBox(height: dims.scaleSpace(10)),
                  _PasswordField(
                    controller: _socialNewPasswordController,
                    hintText: context.l10n.changePasswordNewHint,
                    obscureText: _hideSocialNewPassword,
                    onToggle: () => setState(
                      () => _hideSocialNewPassword = !_hideSocialNewPassword,
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(18)),
                  _FieldLabel(title: context.l10n.changePasswordConfirmNewLabel),
                  SizedBox(height: dims.scaleSpace(10)),
                  _PasswordField(
                    controller: _socialConfirmPasswordController,
                    hintText: context.l10n.changePasswordConfirmHint,
                    obscureText: _hideSocialConfirmPassword,
                    onToggle: () => setState(
                      () => _hideSocialConfirmPassword =
                          !_hideSocialConfirmPassword,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: dims.scaleSpace(16)),
            Center(
              child: TextButton(
                onPressed: isLoading ? null : _sendOtp,
                child: Text(
                  'Resend code',
                  style: TextStyle(
                    color: const Color(0xFFFF7C45),
                    fontSize: dims.scaleText(13),
                  ),
                ),
              ),
            ),
            SizedBox(height: dims.scaleSpace(12)),
            _PrimaryActionButton(
              label: setPassState.isLoading ? context.l10n.updatingLabel : 'Set Password',
              isLoading: setPassState.isLoading,
              onTap: setPassState.isLoading ? null : _submitSocial,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendOtp() async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await ref
        .read(sendSetPasswordOtpControllerProvider.notifier)
        .send();
    if (!mounted) return;
    if (!sent) {
      final message =
          ref.read(sendSetPasswordOtpControllerProvider).error?.toString() ??
          'Failed to send verification code. Please try again.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    setState(() => _otpSent = true);
    messenger.showSnackBar(
      const SnackBar(content: Text('Verification code sent to your email.')),
    );
  }

  Future<void> _submitSocial() async {
    final messenger = ScaffoldMessenger.of(context);
    final otp = _otpController.text.trim();
    final newPassword = _socialNewPasswordController.text;
    final confirmPassword = _socialConfirmPasswordController.text;

    if (otp.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.changePasswordFillAllFields)),
      );
      return;
    }
    if (newPassword.length < 8) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.changePasswordLengthError)),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.signUpPasswordsMismatchError)),
      );
      return;
    }

    final didSet = await ref
        .read(setPasswordControllerProvider.notifier)
        .setPassword(otpCode: otp, newPassword: newPassword);
    if (!mounted) return;
    if (!didSet) {
      final message =
          ref.read(setPasswordControllerProvider).error?.toString() ??
          'Failed to set password. Please check your code and try again.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final message =
        ref.read(setPasswordControllerProvider).valueOrNull ?? 'Password set successfully.';
    messenger.showSnackBar(SnackBar(content: Text(message)));
    _handleBackNavigation();
  }

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/you/edit-profile');
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _PasswordTopBar extends StatelessWidget {
  const _PasswordTopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
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
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: dims.scaleText(32),
                    height: 1,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w500,
                    color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(10)),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    height: 1.45,
                    color: isDark ? colors.textSecondary : const Color(0xFF7F6357),
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

class _ChangePasswordBackdrop extends StatelessWidget {
  const _ChangePasswordBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -30,
            left: -34,
            child: Container(
              width: 210,
              height: 210,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x19FFB08C), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 110,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x12FF8E54), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordSectionCard extends StatelessWidget {
  const _PasswordSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(18)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: dims.scaleText(14),
        fontWeight: FontWeight.w700,
        color: isDark ? colors.textPrimary : const Color(0xFF21140F),
      ),
    );
  }
}

class _OtpField extends StatelessWidget {
  const _OtpField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontSize: dims.scaleText(22),
        letterSpacing: 6,
        color: isDark ? colors.textPrimary : const Color(0xFF21140F),
      ),
      decoration: InputDecoration(
        hintText: '• • • • • •',
        filled: true,
        fillColor: isDark ? colors.bgSurface : const Color(0xFFFFF5EF),
        prefixIcon: const _InfoBadge(icon: Icons.shield_outlined),
        contentPadding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(18),
          vertical: dims.scaleSpace(16),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontSize: dims.scaleText(15),
        color: isDark ? colors.textPrimary : const Color(0xFF21140F),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: isDark ? colors.bgSurface : const Color(0xFFFFF5EF),
        prefixIcon: const _InfoBadge(icon: Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: const Color(0xFFFF7C45),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(18),
          vertical: dims.scaleSpace(16),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      margin: EdgeInsets.all(dims.scaleWidth(10)),
      width: dims.scaleWidth(28),
      height: dims.scaleWidth(28),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Icon(
        icon,
        color: const Color(0xFFFF7C45),
        size: dims.scaleText(18),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onTap,
    required this.isLoading,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A3D), Color(0xFFFF6A2E)],
        ),
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(18)),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: dims.scaleWidth(18),
                      height: dims.scaleWidth(18),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(16),
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
