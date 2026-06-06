import 'dart:async';

import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/onboarding/presentation/widgets/onboarding_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordVerifyScreen extends ConsumerStatefulWidget {
  const ForgotPasswordVerifyScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ForgotPasswordVerifyScreen> createState() =>
      _ForgotPasswordVerifyScreenState();
}

class _ForgotPasswordVerifyScreenState
    extends ConsumerState<ForgotPasswordVerifyScreen> {
  static const _otpLength = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _isSubmittingOtp = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining == 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining -= 1);
    });
  }

  void _handleOtpChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (var i = 0; i < _otpLength; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final nextIndex =
          digits.length >= _otpLength ? _otpLength - 1 : digits.length;
      _focusNodes[nextIndex.clamp(0, _otpLength - 1)].requestFocus();
      setState(() {});
      _maybeAutoSubmit();
      return;
    }
    if (value.length == 1) {
      _controllers[index].text = value.replaceAll(RegExp(r'[^0-9]'), '');
      _controllers[index].selection = TextSelection.collapsed(
        offset: _controllers[index].text.length,
      );
    }
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
    _maybeAutoSubmit();
  }

  void _handleBackspace(int index, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return;
    }
    if (_controllers[index].text.isNotEmpty) {
      _controllers[index].clear();
      setState(() {});
      return;
    }
    if (index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  String get _otpValue =>
      _controllers.map((controller) => controller.text).join();

  String get _activeEmail {
    if (widget.email.isNotEmpty) {
      return widget.email;
    }
    return ref.read(forgotPasswordFlowProvider).email;
  }

  void _maybeAutoSubmit() {
    if (_otpValue.length != _otpLength || _isSubmittingOtp) {
      return;
    }
    unawaited(_submitVerification());
  }

  Future<void> _submitVerification() async {
    if (_isSubmittingOtp) return;
    final otp = _otpValue;
    if (otp.length != _otpLength) return;
    _isSubmittingOtp = true;
    try {
      final didVerify = await ref
          .read(forgotPasswordVerifyControllerProvider.notifier)
          .verifyCode(email: _activeEmail, otp: otp);
      if (!mounted) return;
      if (didVerify) {
        context.push(
          '/forgot-password/reset?email=${Uri.encodeComponent(_activeEmail)}',
        );
        return;
      }
      showAuthError(
        context,
        ref.read(forgotPasswordVerifyControllerProvider).error ??
            context.l10n.invalidCodeError,
      );
    } finally {
      _isSubmittingOtp = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final verifyState = ref.watch(forgotPasswordVerifyControllerProvider);
    final isPreviewFlow = ref.watch(authRepositoryProvider).isPreviewBackend;
    final dims = context.dims;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final canResend = _secondsRemaining == 0;
    final activeEmail =
        widget.email.isNotEmpty
            ? widget.email
            : ref.watch(forgotPasswordFlowProvider).email;

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
                    child: AuthBackButton(fallbackLocation: '/forgot-password'),
                  ),
                  SizedBox(height: dims.scaleSpace(10)),
                  const AuthBrandBadge(size: 116),
                  SizedBox(height: dims.scaleSpace(22)),
                  Text(
                    context.l10n.forgotPasswordVerifyTitle,
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
                    context.l10n.forgotPasswordVerifySubtitle(
                      activeEmail.isEmpty
                          ? context.l10n.yourEmailLabel
                          : activeEmail,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: dims.scaleText(14),
                      color:
                          isLight
                              ? const Color(0xFFA06A52)
                              : const Color(0xFFD6B8A7),
                      height: 1.55,
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(10)),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(
                            '/forgot-password?email=${Uri.encodeComponent(activeEmail)}',
                          );
                        }
                      },
                      child: Text(
                        context.l10n.editEmailLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: dims.scaleText(14),
                          color: const Color(0xFFFF8A4C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(34)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_otpLength, (index) {
                      return AuthOtpDigitField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        onChanged: (value) => _handleOtpChanged(index, value),
                        onKeyEvent: (event) => _handleBackspace(index, event),
                      );
                    }),
                  ),
                  SizedBox(height: dims.scaleSpace(22)),
                  OnboardingPrimaryButton(
                    label:
                        verifyState.isLoading
                            ? context.l10n.verifyingLabel
                            : context.l10n.verifyContinueLabel,
                    onPressed:
                        (isPreviewFlow || _otpValue.length == _otpLength)
                            ? () async {
                              if (verifyState.isLoading || _isSubmittingOtp) {
                                return;
                              }
                              if (isPreviewFlow && _otpValue.isEmpty) {
                                final didVerify = await ref
                                    .read(
                                      forgotPasswordVerifyControllerProvider
                                          .notifier,
                                    )
                                    .verifyCode(
                                      email: activeEmail,
                                      otp: '000000',
                                    );
                                if (!context.mounted) return;
                                if (didVerify) {
                                  context.push(
                                    '/forgot-password/reset?email=${Uri.encodeComponent(activeEmail)}',
                                  );
                                  return;
                                }
                                showAuthError(
                                  context,
                                  ref
                                          .read(
                                            forgotPasswordVerifyControllerProvider,
                                          )
                                          .error ??
                                      context.l10n.invalidCodeError,
                                );
                                return;
                              }
                              await _submitVerification();
                            }
                            : () {},
                  ),
                  SizedBox(height: dims.scaleSpace(22)),
                  Center(
                    child:
                        canResend
                            ? GestureDetector(
                              onTap: () async {
                                final successMessage = await ref
                                    .read(
                                      forgotPasswordRequestControllerProvider
                                          .notifier,
                                    )
                                    .sendCode(activeEmail);
                                if (!context.mounted) return;
                                if (successMessage != null) {
                                  showAuthSuccess(context, successMessage);
                                  _startCountdown();
                                  return;
                                }
                                showAuthError(
                                  context,
                                  ref
                                          .read(
                                            forgotPasswordRequestControllerProvider,
                                          )
                                          .error ??
                                      context.l10n.unableToResendCodeError,
                                );
                              },
                              child: Text(
                                context.l10n.resendCodeLabel,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(
                                  fontSize: dims.scaleText(15),
                                  color: const Color(0xFFED4F86),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                            : Text(
                              context.l10n.resendCodeInLabel(
                                _secondsRemaining.toString().padLeft(2, '0'),
                              ),
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                fontSize: dims.scaleText(15),
                                color:
                                    isLight
                                        ? const Color(0xFF8C5A42)
                                        : const Color(0xFFD6B8A7),
                              ),
                            ),
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
