import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/onboarding/presentation/widgets/onboarding_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestState = ref.watch(forgotPasswordRequestControllerProvider);
    final dims = context.dims;
    final isLight = Theme.of(context).brightness == Brightness.light;

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
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AuthBackButton(fallbackLocation: '/sign-in'),
                  ),
                  SizedBox(height: dims.scaleSpace(10)),
                  const AuthBrandBadge(size: 116),
                  SizedBox(height: dims.scaleSpace(22)),
                  Text(
                    context.l10n.forgotPasswordTitle,
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
                    context.l10n.forgotPasswordSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: dims.scaleText(14),
                      color:
                          isLight
                              ? const Color(0xFFA06A52)
                              : const Color(0xFFD6B8A7),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(38)),
                  AuthFieldLabel(label: context.l10n.emailLabel),
                  SizedBox(height: dims.scaleSpace(10)),
                  AuthTextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    hintText: context.l10n.emailHint,
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      color: const Color(0xFFFF9A63),
                      size: dims.scaleText(23),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(22)),
                  OnboardingPrimaryButton(
                    label:
                        requestState.isLoading
                            ? context.l10n.sendCodeLoadingLabel
                            : context.l10n.sendCodeLabel,
                    onPressed: () async {
                      if (requestState.isLoading) return;
                      final email = _emailController.text.trim();
                      if (email.isEmpty) {
                        showAuthError(
                          context,
                          context.l10n.signUpEmailRequiredError,
                        );
                        return;
                      }
                      if (!_emailPattern.hasMatch(email)) {
                        showAuthError(
                          context,
                          context.l10n.signUpEmailInvalidError,
                        );
                        return;
                      }
                      final successMessage = await ref
                          .read(
                            forgotPasswordRequestControllerProvider.notifier,
                          )
                          .sendCode(email);
                      if (!context.mounted) return;
                      if (successMessage != null) {
                        showAuthSuccess(context, successMessage);
                        context.push(
                          '/forgot-password/verify?email=${Uri.encodeComponent(email)}',
                        );
                        return;
                      }
                      showAuthError(
                        context,
                        ref
                                .read(forgotPasswordRequestControllerProvider)
                                .error ??
                            context.l10n.forgotPasswordUnableToSendCodeError,
                      );
                    },
                  ),
                  SizedBox(height: dims.scaleSpace(26)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.l10n.rememberedPasswordPrompt,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: dims.scaleText(15),
                          color:
                              isLight
                                  ? const Color(0xFF8C5A42)
                                  : const Color(0xFFD6B8A7),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/sign-in'),
                        child: Text(
                          context.l10n.signInLinkLabel,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            fontSize: dims.scaleText(15),
                            color: const Color(0xFFED4F86),
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
    );
  }
}
