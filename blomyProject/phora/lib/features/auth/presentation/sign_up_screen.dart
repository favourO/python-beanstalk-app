import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/payments/payment_country_catalog.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/onboarding/presentation/widgets/onboarding_components.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({
    super.key,
    this.initialReferralCode,
    this.referralSource,
    this.referralDeepLinkId,
  });

  final String? initialReferralCode;
  final String? referralSource;
  final String? referralDeepLinkId;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  static const _stepCount = 5;
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 0;
  DateTime? _birthDate;
  String? _selectedCountry;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasAcceptedTerms = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final referralCode = widget.initialReferralCode?.trim();
    if (referralCode != null && referralCode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(appPreferencesProvider)
            .setPendingReferral(
              code: referralCode,
              source: widget.referralSource ?? 'deep_link',
              deepLinkId: widget.referralDeepLinkId,
            );
      });
    }
  }

  Future<void> _goToStep(int step) async {
    if (step < 0 || step >= _stepCount) return;
    await _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() => _currentStep = step);
  }

  Future<void> _handleBack() async {
    if (_currentStep == 0) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/sign-in');
      }
      return;
    }
    await _goToStep(_currentStep - 1);
  }

  Future<void> _handleContinue() async {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        showAuthError(context, context.l10n.signUpNameRequiredError);
        return;
      }
      await _goToStep(1);
      return;
    }

    if (_currentStep == 1) {
      if ((_selectedCountry ?? '').isEmpty) {
        showAuthError(context, context.l10n.signUpCountryRequiredError);
        return;
      }
      await _goToStep(2);
      return;
    }

    if (_currentStep == 2) {
      if (_birthDate == null) {
        showAuthError(context, context.l10n.signUpBirthDateRequiredError);
        return;
      }
      await _goToStep(3);
      return;
    }

    if (_currentStep == 3) {
      return;
    }

    await _submit();
  }

  Future<void> _goToEmailStep() async {
    await _goToStep(4);
  }

  void _handleAppleSignUp() {
    final fullName = _nameController.text.trim();
    final country = _selectedCountry?.trim() ?? '';
    if (!_hasAcceptedTerms) {
      showAuthError(context, context.l10n.signUpAcceptTermsError);
      return;
    }
    if (fullName.isEmpty || country.isEmpty) {
      showAuthError(context, context.l10n.signUpCompleteProfileError);
      return;
    }

    final nameParts =
        fullName
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : fullName;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    ref
        .read(appleAuthControllerProvider.notifier)
        .signUp(
          firstName: firstName,
          lastName: lastName,
          country: country,
          accountType: 'individual',
          birthDate: _birthDate,
          termsAccepted: _hasAcceptedTerms,
          privacyPolicyAccepted: _hasAcceptedTerms,
        )
        .then((didSignUp) async {
          if (!mounted) return;
          if (didSignUp) {
            await ref.read(appPreferencesProvider).setBillingCountry(country);
            if (!mounted) return;
            context.go('/splash');
            return;
          }
          showAuthError(
            context,
            ref.read(appleAuthControllerProvider).error ??
                context.l10n.signUpAppleError,
          );
        });
  }

  Future<void> _handleGoogleSignUp() async {
    if (!_hasAcceptedTerms) {
      showAuthError(context, context.l10n.signUpAcceptTermsError);
      return;
    }

    final fullName = _nameController.text.trim();
    final country = _selectedCountry?.trim() ?? '';
    if (fullName.isEmpty || country.isEmpty) {
      showAuthError(context, context.l10n.signUpCompleteProfileError);
      return;
    }

    final nameParts =
        fullName
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : fullName;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final didSignUp = await ref
        .read(googleAuthControllerProvider.notifier)
        .signUp(
          firstName: firstName,
          lastName: lastName,
          country: country,
          accountType: 'individual',
          birthDate: _birthDate,
          termsAccepted: _hasAcceptedTerms,
          privacyPolicyAccepted: _hasAcceptedTerms,
        );
    if (!mounted) return;
    if (didSignUp) {
      await ref.read(appPreferencesProvider).setBillingCountry(country);
      if (!mounted) return;
      context.go('/splash');
      return;
    }
    showAuthError(
      context,
      _googleSignupErrorMessage(ref.read(googleAuthControllerProvider).error),
    );
  }

  String _googleSignupErrorMessage(Object? error) {
    final message = error?.toString().trim() ?? '';
    final normalized = message.toLowerCase();
    if (normalized.contains('email already registered') ||
        normalized.contains('an account with this email already exists') ||
        normalized.contains('409')) {
      return context.l10n.signUpExistingAccountError;
    }
    return error?.toString() ?? context.l10n.signUpGoogleError;
  }

  Future<void> _submit() async {
    final signUpState = ref.read(emailSignUpControllerProvider);
    if (signUpState.isLoading) return;

    final fullName = _nameController.text.trim();
    final country = _selectedCountry?.trim() ?? '';
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || country.isEmpty) {
      showAuthError(context, context.l10n.signUpCompleteProfileFirstError);
      return;
    }
    if (email.isEmpty) {
      showAuthError(context, context.l10n.signUpEmailRequiredError);
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      showAuthError(context, context.l10n.signUpEmailInvalidError);
      return;
    }
    if (password.isEmpty) {
      showAuthError(context, context.l10n.signUpPasswordRequiredError);
      return;
    }
    if (password.length < 8) {
      showAuthError(context, context.l10n.signUpPasswordLengthError);
      return;
    }
    if (confirmPassword.isEmpty) {
      showAuthError(context, context.l10n.signUpConfirmPasswordRequiredError);
      return;
    }
    if (!_hasAcceptedTerms) {
      showAuthError(context, context.l10n.signUpAcceptTermsError);
      return;
    }
    if (password != confirmPassword) {
      showAuthError(context, context.l10n.signUpPasswordsMismatchError);
      return;
    }

    final nameParts =
        fullName
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : fullName;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final didSignUp = await ref
        .read(emailSignUpControllerProvider.notifier)
        .signUp(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          country: country,
          birthDate: _birthDate,
          signupMethod: 'email',
          termsAccepted: _hasAcceptedTerms,
          privacyPolicyAccepted: _hasAcceptedTerms,
        );
    if (!mounted) return;
    if (didSignUp) {
      await ref.read(appPreferencesProvider).setBillingCountry(country);
      if (!mounted) return;
      context.push('/verify-email?email=${Uri.encodeComponent(email)}');
      return;
    }
    showAuthError(
      context,
      ref.read(emailSignUpControllerProvider).error ??
          context.l10n.signUpCreateAccountError,
    );
  }

  Future<void> _pickBirthDate() async {
    final dims = context.dims;
    final colors = context.phora.colors;
    final initialDate = _birthDate ?? DateTime(2000, 1, 1);
    var draftDate = initialDate;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(28)),
        ),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: dims.scaleHeight(300),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(20),
                    dims.scaleSpace(14),
                    dims.scaleWidth(20),
                    dims.scaleSpace(8),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => context.pop(),
                        child: Text(context.l10n.cancelLabel),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() => _birthDate = draftDate);
                          context.pop();
                        },
                        child: Text(context.l10n.doneLabel),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initialDate,
                      maximumDate: DateTime.now(),
                      minimumDate: DateTime(1940, 1, 1),
                      onDateTimeChanged: (value) => draftDate = value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => _CountrySearchSheet(
            countries: supportedPaymentCountries,
            selectedCountry: _selectedCountry,
          ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedCountry = selected);
  }

  String _birthDateLabel(BuildContext context) {
    final value = _birthDate;
    if (value == null) return context.l10n.signUpSelectBirthDateLabel;
    return MaterialLocalizations.of(context).formatMediumDate(value);
  }

  String? get _profileSummaryBirthDate {
    final value = _birthDate;
    if (value == null) return null;
    return MaterialLocalizations.of(context).formatMediumDate(value);
  }

  @override
  Widget build(BuildContext context) {
    final signUpState = ref.watch(emailSignUpControllerProvider);
    final googleAuthState = ref.watch(googleAuthControllerProvider);
    final appleAuthState = ref.watch(appleAuthControllerProvider);
    final isSigningUp =
        signUpState.isLoading ||
        googleAuthState.isLoading ||
        appleAuthState.isLoading;
    final colors = context.phora.colors;
    final dims = context.dims;
    final inkColor = _signUpInkColor(context);
    final mutedColor = _signUpMutedColor(context);
    final showAppleAuth = defaultTargetPlatform != TargetPlatform.android;

    return Scaffold(
      body: Stack(
        children: [
          DecoratedBox(
            decoration: authBackgroundDecoration(context),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(20),
                      dims.scaleSpace(16),
                      dims.scaleWidth(20),
                      dims.scaleSpace(12),
                    ),
                    child: Row(
                      children: [
                        _RegistrationBackButton(onTap: _handleBack),
                        SizedBox(width: dims.scaleWidth(16)),
                        Expanded(
                          child: Row(
                            children: List.generate(_stepCount, (index) {
                              final isActive = index == _currentStep;
                              final isComplete = index < _currentStep;
                              return Expanded(
                                child: Container(
                                  height: dims.scaleHeight(4),
                                  margin: EdgeInsets.symmetric(
                                    horizontal: dims.scaleWidth(4),
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isActive || isComplete
                                            ? colors.accentPrimary
                                            : colors.borderStrong,
                                    borderRadius: BorderRadius.circular(
                                      dims.scaleRadius(999),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _RegistrationStepScaffold(
                          stepLabel: context.l10n.signUpStepLabel(1, 5),
                          hero: _StepHero(
                            backgroundColor: colors.phaseOvulatory,
                            icon: Icons.waving_hand_rounded,
                          ),
                          title: context.l10n.signUpNameTitle,
                          subtitle: context.l10n.signUpNameSubtitle,
                          body: _RegistrationPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AuthFieldLabel(
                                  label: context.l10n.fullNameLabel,
                                ),
                                SizedBox(height: dims.scaleSpace(12)),
                                TextField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  onSubmitted: (_) => _handleContinue(),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(
                                    color: inkColor,
                                    fontSize: dims.scaleText(17),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.l10n.fullNameHint,
                                  ),
                                ),
                                SizedBox(height: dims.scaleSpace(14)),
                                Text(
                                  context.l10n.signUpNameHelp,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: mutedColor,
                                    fontSize: dims.scaleText(13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _RegistrationStepScaffold(
                          stepLabel: context.l10n.signUpStepLabel(2, 5),
                          hero: _StepHero(
                            backgroundColor: colors.phaseLuteal,
                            icon: Icons.public_rounded,
                          ),
                          title: context.l10n.signUpCountryTitle,
                          subtitle: context.l10n.signUpCountrySubtitle,
                          body: _RegistrationPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AuthFieldLabel(
                                  label: context.l10n.countryLabel,
                                ),
                                SizedBox(height: dims.scaleSpace(12)),
                                _CountryPickerField(
                                  value: _selectedCountry,
                                  hint: context.l10n.countryHint,
                                  onTap: _pickCountry,
                                ),
                                SizedBox(height: dims.scaleSpace(14)),
                                Text(
                                  context.l10n.signUpCountryHelp,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: mutedColor,
                                    fontSize: dims.scaleText(13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _RegistrationStepScaffold(
                          stepLabel: context.l10n.signUpStepLabel(3, 5),
                          hero: _StepHero(
                            backgroundColor: colors.accentWarning,
                            icon: Icons.cake_rounded,
                          ),
                          title: context.l10n.signUpBirthDateTitle,
                          subtitle: context.l10n.signUpBirthDateSubtitle,
                          body: _RegistrationPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AuthFieldLabel(
                                  label: context.l10n.birthDateLabel,
                                ),
                                SizedBox(height: dims.scaleSpace(12)),
                                _DatePickerCard(
                                  label: _birthDateLabel(context),
                                  onTap: _pickBirthDate,
                                ),
                                SizedBox(height: dims.scaleSpace(14)),
                                Text(
                                  context.l10n.signUpBirthDateHelp,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: mutedColor,
                                    fontSize: dims.scaleText(13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _RegistrationStepScaffold(
                          stepLabel: context.l10n.signUpStepLabel(4, 5),
                          hero: const SizedBox.shrink(),
                          title: context.l10n.signUpMethodTitle,
                          subtitle: context.l10n.signUpMethodSubtitle,
                          body: _SignUpMethodStep(
                            showApple: showAppleAuth,
                            onApple:
                                appleAuthState.isLoading
                                    ? null
                                    : _handleAppleSignUp,
                            onGoogle:
                                googleAuthState.isLoading
                                    ? null
                                    : _handleGoogleSignUp,
                            onEmail: _goToEmailStep,
                            hasAcceptedTerms: _hasAcceptedTerms,
                            onConsentChanged: (value) {
                              setState(() => _hasAcceptedTerms = value);
                            },
                            profileName: _nameController.text.trim(),
                            country: _selectedCountry,
                            birthDate: _profileSummaryBirthDate,
                          ),
                        ),
                        _RegistrationStepScaffold(
                          stepLabel: context.l10n.signUpStepLabel(5, 5),
                          hero: _StepHero(
                            backgroundColor: colors.accentPrimary,
                            icon: Icons.alternate_email_rounded,
                          ),
                          title: context.l10n.signUpEmailTitle,
                          subtitle: context.l10n.signUpEmailSubtitle,
                          body: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProfileSummaryCard(
                                name: _nameController.text.trim(),
                                country: _selectedCountry,
                                birthDate: _profileSummaryBirthDate,
                              ),
                              SizedBox(height: dims.scaleSpace(18)),
                              _RegistrationPanel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthFieldLabel(
                                      label: context.l10n.emailLabel,
                                    ),
                                    SizedBox(height: dims.scaleSpace(12)),
                                    TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.copyWith(
                                        color: inkColor,
                                        fontSize: dims.scaleText(16),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: context.l10n.emailHint,
                                      ),
                                    ),
                                    SizedBox(height: dims.scaleSpace(16)),
                                    AuthFieldLabel(
                                      label: context.l10n.passwordLabel,
                                    ),
                                    SizedBox(height: dims.scaleSpace(12)),
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.copyWith(
                                        color: inkColor,
                                        fontSize: dims.scaleText(16),
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            context.l10n.passwordHintMinimum,
                                        suffixIcon: IconButton(
                                          onPressed: () {
                                            setState(
                                              () =>
                                                  _obscurePassword =
                                                      !_obscurePassword,
                                            );
                                          },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: dims.scaleSpace(16)),
                                    AuthFieldLabel(
                                      label: context.l10n.confirmPasswordLabel,
                                    ),
                                    SizedBox(height: dims.scaleSpace(12)),
                                    TextField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
                                      onSubmitted: (_) => _submit(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.copyWith(
                                        color: inkColor,
                                        fontSize: dims.scaleText(16),
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            context.l10n.confirmPasswordHint,
                                        suffixIcon: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: dims.scaleSpace(14)),
                                    Text(
                                      context.l10n.signUpVerificationHelp,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color: mutedColor,
                                        fontSize: dims.scaleText(13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: dims.scaleSpace(18)),
                              _ConsentCard(
                                value: _hasAcceptedTerms,
                                onChanged: (value) {
                                  setState(() => _hasAcceptedTerms = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(24),
                      dims.scaleSpace(12),
                      dims.scaleWidth(24),
                      dims.scaleSpace(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_currentStep != 3) ...[
                          OnboardingPrimaryButton(
                            label:
                                _currentStep == _stepCount - 1
                                    ? (signUpState.isLoading
                                        ? context.l10n.creatingLabel
                                        : context.l10n.createAccountLabel)
                                    : context.l10n.onboardingNextLabel,
                            onPressed: _handleContinue,
                          ),
                          SizedBox(height: dims.scaleSpace(14)),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.iHaveAnAccountLabel,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                fontSize: dims.scaleText(14),
                                color: mutedColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: dims.scaleWidth(8)),
                            GestureDetector(
                              onTap: () => context.go('/sign-in'),
                              child: Text(
                                context.l10n.signInLinkLabel,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(
                                  fontSize: dims.scaleText(14),
                                  color: colors.accentPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSigningUp)
            Positioned.fill(
              child: ColoredBox(
                color: colors.bg.withValues(alpha: 0.82),
                child: IgnorePointer(
                  child: PhoraLoadingView(
                    message: context.l10n.creatingAccountLoadingLabel,
                    size: 88,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SignUpMethodStep extends StatelessWidget {
  const _SignUpMethodStep({
    required this.showApple,
    required this.onApple,
    required this.onGoogle,
    required this.onEmail,
    required this.hasAcceptedTerms,
    required this.onConsentChanged,
    required this.profileName,
    required this.country,
    required this.birthDate,
  });

  final bool showApple;
  final VoidCallback? onApple;
  final VoidCallback? onGoogle;
  final VoidCallback onEmail;
  final bool hasAcceptedTerms;
  final ValueChanged<bool> onConsentChanged;
  final String profileName;
  final String? country;
  final String? birthDate;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: dims.scaleHeight(320)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileSummaryCard(
            name: profileName,
            country: country,
            birthDate: birthDate,
          ),
          SizedBox(height: dims.scaleSpace(18)),
          if (showApple) ...[
            _SignUpMethodButton(
              label: context.l10n.signUpWithAppleLabel,
              leading: const Icon(Icons.apple, color: Colors.white),
              onTap: onApple,
              style: _SignUpMethodButtonStyle.apple,
            ),
            SizedBox(height: dims.scaleSpace(14)),
          ],
          _SignUpMethodButton(
            label: context.l10n.signUpWithGoogleLabel,
            leading: const _GoogleWordmark(),
            onTap: onGoogle,
            style: _SignUpMethodButtonStyle.google,
          ),
          SizedBox(height: dims.scaleSpace(14)),
          _SignUpMethodButton(
            label: context.l10n.signUpWithEmailLabel,
            leading: const Icon(Icons.mail_outline_rounded),
            onTap: onEmail,
            style: _SignUpMethodButtonStyle.email,
          ),
          SizedBox(height: dims.scaleSpace(18)),
          _ConsentCard(value: hasAcceptedTerms, onChanged: onConsentChanged),
        ],
      ),
    );
  }
}

Color _signUpInkColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.light
      ? const Color(0xFF1C1B20)
      : const Color(0xFFF4EEF3);
}

Color _signUpMutedColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.light
      ? const Color(0xFF5F5B66)
      : const Color(0xFFD7CDD6);
}

class _RegistrationStepScaffold extends StatelessWidget {
  const _RegistrationStepScaffold({
    required this.stepLabel,
    required this.hero,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String stepLabel;
  final Widget hero;
  final String title;
  final String subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final inkColor = _signUpInkColor(context);
    final mutedColor = _signUpMutedColor(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(24),
        dims.scaleSpace(12),
        dims.scaleWidth(24),
        dims.scaleSpace(12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - dims.scaleHeight(250),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            SizedBox(height: dims.scaleSpace(28)),
            Text(
              stepLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.accentPrimary,
                fontSize: dims.scaleText(12),
                letterSpacing: 0.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: dims.scaleSpace(12)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: dims.scaleText(30),
                fontWeight: FontWeight.w800,
                color: inkColor,
                letterSpacing: -0.8,
              ),
            ),
            SizedBox(height: dims.scaleSpace(12)),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: dims.scaleText(15),
                color: mutedColor,
                height: 1.55,
              ),
            ),
            SizedBox(height: dims.scaleSpace(34)),
            body,
          ],
        ),
      ),
    );
  }
}

class _RegistrationPanel extends StatelessWidget {
  const _RegistrationPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: EdgeInsets.all(dims.scaleWidth(20)),
      decoration: BoxDecoration(
        color:
            isLight ? colors.bgElevated : colors.bgCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isLight ? colors.border : colors.borderStrong,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: isLight ? 0.05 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.name,
    required this.country,
    required this.birthDate,
  });

  final String name;
  final String? country;
  final String? birthDate;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final inkColor = _signUpInkColor(context);
    final chips = <String>[
      if (name.trim().isNotEmpty) name.trim(),
      if ((country ?? '').trim().isNotEmpty) country!.trim(),
      if ((birthDate ?? '').trim().isNotEmpty) birthDate!.trim(),
    ];

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return _RegistrationPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.signUpProfileSummaryTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: dims.scaleText(15),
              fontWeight: FontWeight.w700,
              color: inkColor,
            ),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          Wrap(
            spacing: dims.scaleWidth(10),
            runSpacing: dims.scaleSpace(10),
            children: chips.map((chip) => _ProfileChip(label: chip)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(12),
        vertical: dims.scaleSpace(8),
      ),
      decoration: BoxDecoration(
        color: colors.accentPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        border: Border.all(color: colors.accentPrimary.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: dims.scaleText(12),
          color: colors.accentPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountryPickerField extends StatelessWidget {
  const _CountryPickerField({
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final text = value?.trim();
    final hasValue = text != null && text.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        child: InputDecorator(
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: const Icon(Icons.search_rounded),
          ),
          child: Text(
            hasValue ? text : hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color:
                  hasValue
                      ? _signUpInkColor(context)
                      : _signUpMutedColor(context),
              fontSize: dims.scaleText(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountrySearchSheet extends StatefulWidget {
  const _CountrySearchSheet({
    required this.countries,
    required this.selectedCountry,
  });

  final List<String> countries;
  final String? selectedCountry;

  @override
  State<_CountrySearchSheet> createState() => _CountrySearchSheetState();
}

class _CountrySearchSheetState extends State<_CountrySearchSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredCountries {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.countries;
    return widget.countries
        .where((country) => country.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final countries = _filteredCountries;
    final selected = widget.selectedCountry?.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.48,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: isLight ? colors.bgElevated : colors.bgCard,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(dims.scaleRadius(28)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(height: dims.scaleSpace(10)),
                Container(
                  width: dims.scaleWidth(42),
                  height: dims.scaleHeight(4),
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(20),
                    dims.scaleSpace(18),
                    dims.scaleWidth(20),
                    dims.scaleSpace(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.countryLabel,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            color: _signUpInkColor(context),
                            fontSize: dims.scaleText(20),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: context.l10n.cancelLabel,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.scaleWidth(20),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search country',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon:
                          _query.isEmpty
                              ? null
                              : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(8)),
                Expanded(
                  child:
                      countries.isEmpty
                          ? Center(
                            child: Text(
                              'No countries found',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                color: _signUpMutedColor(context),
                                fontSize: dims.scaleText(15),
                              ),
                            ),
                          )
                          : ListView.separated(
                            controller: scrollController,
                            padding: EdgeInsets.fromLTRB(
                              dims.scaleWidth(12),
                              dims.scaleSpace(4),
                              dims.scaleWidth(12),
                              dims.scaleSpace(20),
                            ),
                            itemCount: countries.length,
                            separatorBuilder:
                                (_, __) =>
                                    Divider(height: 1, color: colors.border),
                            itemBuilder: (context, index) {
                              final country = countries[index];
                              final isSelected = country == selected;
                              return ListTile(
                                onTap: () => context.pop(country),
                                title: Text(
                                  country,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(
                                    color: _signUpInkColor(context),
                                    fontSize: dims.scaleText(16),
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                  ),
                                ),
                                trailing:
                                    isSelected
                                        ? Icon(
                                          Icons.check_rounded,
                                          color: colors.accentPrimary,
                                        )
                                        : null,
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConsentCard extends StatefulWidget {
  const _ConsentCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_ConsentCard> createState() => _ConsentCardState();
}

class _ConsentCardState extends State<_ConsentCard> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap =
        TapGestureRecognizer()
          ..onTap =
              () => launchUrl(
                Uri.parse('https://vyla.health/terms'),
                mode: LaunchMode.externalApplication,
              );
    _privacyTap =
        TapGestureRecognizer()
          ..onTap =
              () => launchUrl(
                Uri.parse('https://vyla.health/privacy'),
                mode: LaunchMode.externalApplication,
              );
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final mutedColor = _signUpMutedColor(context);

    return _RegistrationPanel(
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: dims.scaleSpace(2)),
              child: SizedBox(
                width: dims.scaleWidth(24),
                height: dims.scaleWidth(24),
                child: Checkbox(
                  value: widget.value,
                  onChanged: (next) => widget.onChanged(next ?? false),
                ),
              ),
            ),
            SizedBox(width: dims.scaleWidth(14)),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: dims.scaleText(14),
                    color: mutedColor,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: context.l10n.consentAgreePrefix),
                    TextSpan(
                      text: context.l10n.termsOfServiceLabel,
                      recognizer: _termsTap,
                      style: TextStyle(
                        color: colors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: context.l10n.consentAndLabel),
                    TextSpan(
                      text: context.l10n.privacyPolicyTitleLabel,
                      recognizer: _privacyTap,
                      style: TextStyle(
                        color: colors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SignUpMethodButtonStyle { apple, google, email }

class _SignUpMethodButton extends StatelessWidget {
  const _SignUpMethodButton({
    required this.label,
    required this.leading,
    required this.onTap,
    required this.style,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onTap;
  final _SignUpMethodButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isApple = style == _SignUpMethodButtonStyle.apple;
    final isGoogle = style == _SignUpMethodButtonStyle.google;

    final backgroundColor = switch (style) {
      _SignUpMethodButtonStyle.apple => Colors.black,
      _SignUpMethodButtonStyle.google => colors.bgElevated,
      _SignUpMethodButtonStyle.email => Colors.transparent,
    };
    final foregroundColor = switch (style) {
      _SignUpMethodButtonStyle.apple => Colors.white,
      _SignUpMethodButtonStyle.google => colors.textPrimary,
      _SignUpMethodButtonStyle.email => colors.accentPrimary,
    };
    final borderColor = switch (style) {
      _SignUpMethodButtonStyle.apple => Colors.black,
      _SignUpMethodButtonStyle.google => colors.borderStrong,
      _SignUpMethodButtonStyle.email => colors.accentPrimary,
    };

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        onTap: onTap,
        child: Container(
          height: dims.scaleHeight(56),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            border: Border.all(color: borderColor),
          ),
          padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(18)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: foregroundColor,
                  size: dims.scaleText(isApple ? 22 : 20),
                ),
                child: leading,
              ),
              SizedBox(width: dims.scaleWidth(isGoogle ? 10 : 12)),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                  fontSize: dims.scaleText(15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleWordmark extends StatelessWidget {
  const _GoogleWordmark();

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

class _RegistrationBackButton extends StatelessWidget {
  const _RegistrationBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Material(
      color: colors.bgCard,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: dims.scaleWidth(44),
          height: dims.scaleWidth(44),
          child: Icon(
            Icons.arrow_back_rounded,
            color: colors.textPrimary,
            size: dims.scaleText(20),
          ),
        ),
      ),
    );
  }
}

class _StepHero extends StatelessWidget {
  const _StepHero({required this.backgroundColor, required this.icon});

  final Color backgroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Center(
      child: Container(
        width: dims.scaleWidth(92),
        height: dims.scaleWidth(92),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.32),
              blurRadius: dims.scaleWidth(28),
              offset: Offset(0, dims.scaleHeight(12)),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: dims.scaleText(38)),
      ),
    );
  }
}

class _DatePickerCard extends StatelessWidget {
  const _DatePickerCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final inkColor = _signUpInkColor(context);
    final mutedColor = _signUpMutedColor(context);

    return Material(
      color: colors.bgCard,
      borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(20),
            vertical: dims.scaleSpace(18),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(16),
                    fontWeight: FontWeight.w700,
                    color: inkColor,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_month_rounded,
                color: mutedColor,
                size: dims.scaleText(22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
