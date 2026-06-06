import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/onboarding/presentation/widgets/onboarding_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resetState = ref.watch(resetPasswordControllerProvider);
    final dims = context.dims;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final flow = ref.watch(forgotPasswordFlowProvider);
    final activeEmail = widget.email.isNotEmpty ? widget.email : flow.email;

    return Scaffold(
      body: DecoratedBox(
        decoration: authBackgroundDecoration(context),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(24),
              dims.scaleSpace(28),
              dims.scaleWidth(24),
              dims.scaleSpace(24),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.sizeOf(context).height - dims.scaleHeight(90),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: dims.scaleSpace(12)),
                  const AuthBrandBadge(size: 116),
                  SizedBox(height: dims.scaleSpace(22)),
                  Text(
                    context.l10n.resetPasswordTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: dims.scaleText(40),
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                      color:
                          isLight
                              ? const Color(0xFF4A2C1A)
                              : const Color(0xFFFFF3E8),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(10)),
                  Text(
                    context.l10n.resetPasswordSubtitle(
                      activeEmail.isEmpty
                          ? context.l10n.yourAccountLabel
                          : activeEmail,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: dims.scaleText(14),
                      color:
                          isLight
                              ? const Color(0xFFA06A52)
                              : const Color(0xFFD6B8A7),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(34)),
                  AuthFieldLabel(label: context.l10n.newPasswordLabel),
                  SizedBox(height: dims.scaleSpace(10)),
                  AuthTextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    hintText: context.l10n.passwordHintMinimum,
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: const Color(0xFFFF9A63),
                      size: dims.scaleText(23),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFFF9A63),
                      ),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(22)),
                  AuthFieldLabel(
                    label: context.l10n.confirmPasswordTitleCaseLabel,
                  ),
                  SizedBox(height: dims.scaleSpace(10)),
                  AuthTextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    hintText: context.l10n.confirmPasswordHint,
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: const Color(0xFFFF9A63),
                      size: dims.scaleText(23),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFFF9A63),
                      ),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(24)),
                  OnboardingPrimaryButton(
                    label:
                        resetState.isLoading
                            ? context.l10n.updatingLabel
                            : context.l10n.updatePasswordLabel,
                    onPressed: () async {
                      if (resetState.isLoading) return;
                      if (_passwordController.text !=
                          _confirmPasswordController.text) {
                        showAuthError(
                          context,
                          context.l10n.signUpPasswordsMismatchError,
                        );
                        return;
                      }
                      final code = flow.otpCode;
                      if (code == null || code.isEmpty) {
                        showAuthError(
                          context,
                          context.l10n.resetCodeMissingError,
                        );
                        return;
                      }
                      final didReset = await ref
                          .read(resetPasswordControllerProvider.notifier)
                          .resetPassword(
                            email: activeEmail,
                            code: code,
                            newPassword: _passwordController.text,
                          );
                      if (!context.mounted) return;
                      if (didReset) {
                        context.go('/sign-in');
                        return;
                      }
                      showAuthError(
                        context,
                        ref.read(resetPasswordControllerProvider).error ??
                            context.l10n.unableToResetPasswordError,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
