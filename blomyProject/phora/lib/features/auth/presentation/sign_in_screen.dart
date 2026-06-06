import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/onboarding/presentation/widgets/onboarding_components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(emailLoginControllerProvider);
    final googleAuthState = ref.watch(googleAuthControllerProvider);
    final appleAuthState = ref.watch(appleAuthControllerProvider);
    final isSigningIn =
        loginState.isLoading ||
        googleAuthState.isLoading ||
        appleAuthState.isLoading;
    final colors = context.phora.colors;
    final dims = context.dims;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final showAppleAuth = defaultTargetPlatform != TargetPlatform.android;

    return Scaffold(
      body: Stack(
        children: [
          DecoratedBox(
            decoration: authBackgroundDecoration(context),
            child: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  dims.scaleWidth(24),
                  dims.scaleSpace(12),
                  dims.scaleWidth(24),
                  dims.scaleSpace(18),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.sizeOf(context).height -
                        dims.scaleHeight(90),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: dims.scaleSpace(8)),
                      const AuthBrandBadge(size: 126),
                      SizedBox(height: dims.scaleSpace(8)),
                      Text(
                        context.l10n.signInSubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: dims.scaleText(13),
                          color:
                              isLight
                                  ? const Color(0xFFA06A52)
                                  : const Color(0xFFD6B8A7),
                          height: 1.45,
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(24)),
                      AuthFieldLabel(label: context.l10n.emailLabel),
                      SizedBox(height: dims.scaleSpace(10)),
                      AuthTextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        hintText: context.l10n.emailHint,
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          color: const Color(0xFFFF9A63),
                          size: dims.scaleText(23),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(18)),
                      AuthFieldLabel(label: context.l10n.passwordLabel),
                      SizedBox(height: dims.scaleSpace(10)),
                      AuthTextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        hintText: context.l10n.passwordHintMinimum,
                        onSubmitted:
                            (_) => _handleEmailSignIn(
                              context,
                              loginState.isLoading,
                            ),
                        prefixIcon: Icon(
                          Icons.lock_outline_rounded,
                          color: const Color(0xFFFF9A63),
                          size: dims.scaleText(23),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFFFF9A63),
                          ),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(20)),
                      OnboardingPrimaryButton(
                        label: context.l10n.signInButtonLabel,
                        onPressed:
                            loginState.isLoading
                                ? null
                                : () => _handleEmailSignIn(
                                  context,
                                  loginState.isLoading,
                                ),
                      ),
                      SizedBox(height: dims.scaleSpace(6)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: Text(
                            context.l10n.forgotPasswordLabel,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFFF8A4C),
                              fontSize: dims.scaleText(13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(18)),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color:
                                  isLight
                                      ? const Color(0xFFFFE0CE)
                                      : const Color(0xFF3B2C3E),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: dims.scaleWidth(16),
                            ),
                            child: Text(
                              context.l10n.authContinueWithLabel,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color:
                                    isLight
                                        ? const Color(0xFF8C5A42)
                                        : const Color(0xFFD6B8A7),
                                fontSize: dims.scaleText(13),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color:
                                  isLight
                                      ? const Color(0xFFFFE0CE)
                                      : const Color(0xFF3B2C3E),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: dims.scaleSpace(16)),
                      Row(
                        children: [
                          if (showAppleAuth) ...[
                            Expanded(
                              child: AuthSocialButton(
                                icon: Icon(
                                  Icons.apple,
                                  size: dims.scaleText(24),
                                  color:
                                      isLight
                                          ? const Color(0xFF4A2C1A)
                                          : const Color(0xFFFFF3E8),
                                ),
                                onTap: () {
                                  if (appleAuthState.isLoading) return;
                                  ref
                                      .read(
                                        appleAuthControllerProvider.notifier,
                                      )
                                      .signIn()
                                      .then((didLogin) {
                                        if (!context.mounted) return;
                                        if (didLogin) {
                                          context.go('/splash');
                                          return;
                                        }
                                        showAuthError(
                                          context,
                                          ref
                                                  .read(
                                                    appleAuthControllerProvider,
                                                  )
                                                  .error ??
                                              context.l10n.signInAppleError,
                                        );
                                      });
                                },
                              ),
                            ),
                            SizedBox(width: dims.scaleWidth(12)),
                          ],
                          Expanded(
                            child: AuthSocialButton(
                              icon: const _GoogleIcon(),
                              onTap: () {
                                if (googleAuthState.isLoading) return;
                                ref
                                    .read(googleAuthControllerProvider.notifier)
                                    .signIn()
                                    .then((didLogin) {
                                      if (!context.mounted) return;
                                      if (didLogin) {
                                        context.go('/splash');
                                        return;
                                      }
                                      showAuthError(
                                        context,
                                        ref
                                                .read(
                                                  googleAuthControllerProvider,
                                                )
                                                .error ??
                                            context.l10n.signInGoogleError,
                                      );
                                    });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: dims.scaleSpace(20)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            context.l10n.signInNoAccountPrompt,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontSize: dims.scaleText(14),
                              color:
                                  isLight
                                      ? const Color(0xFF8C5A42)
                                      : const Color(0xFFD6B8A7),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/sign-up'),
                            child: Text(
                              context.l10n.signUpLinkLabel,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                fontSize: dims.scaleText(14),
                                color: const Color(0xFFFF8A4C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isSigningIn)
            Positioned.fill(
              child: ColoredBox(
                color: colors.bg.withValues(alpha: 0.82),
                child: IgnorePointer(
                  child: PhoraLoadingView(
                    message: context.l10n.signingInLoadingLabel,
                    size: 88,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleEmailSignIn(BuildContext context, bool isLoading) async {
    if (isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      showAuthError(context, context.l10n.signInEmptyCredentialsError);
      return;
    }
    final didLogin = await ref
        .read(emailLoginControllerProvider.notifier)
        .signIn(email: email, password: password);
    if (!context.mounted) return;
    if (didLogin) {
      context.go('/splash');
      return;
    }
    final loginError = ref.read(emailLoginControllerProvider).error;
    if (loginError is PendingVerificationFailure) {
      final verificationEmail =
          loginError.email.isEmpty ? email : loginError.email;
      ref
          .read(pendingEmailVerificationProvider.notifier)
          .setPendingLogin(email: verificationEmail, password: password);
      context.push(
        '/verify-email?email=${Uri.encodeComponent(verificationEmail)}',
      );
      return;
    }
    showAuthError(context, loginError ?? context.l10n.signInUnableError);
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Text(
      'G',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: dims.scaleText(20),
        fontWeight: FontWeight.w800,
        color: const Color(0xFF4285F4),
      ),
    );
  }
}
