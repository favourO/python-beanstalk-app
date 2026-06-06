import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('de', 'AT'),
    Locale('de', 'CH'),
    Locale('de', 'DE'),
    Locale('en'),
    Locale('en', 'AU'),
    Locale('en', 'CA'),
    Locale('en', 'GB'),
    Locale('en', 'US'),
    Locale('es'),
    Locale('es', '419'),
    Locale('es', 'ES'),
    Locale('fr'),
    Locale('fr', 'CA'),
    Locale('fr', 'FR'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('pt', 'PT'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Vyla'**
  String get appName;

  /// No description provided for @languageScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageScreenTitle;

  /// No description provided for @languageScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in settings.'**
  String get languageScreenSubtitle;

  /// No description provided for @useDeviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use device language'**
  String get useDeviceLanguage;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languageSectionTitle;

  /// No description provided for @currentLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Current language'**
  String get currentLanguageLabel;

  /// No description provided for @profileLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguageTitle;

  /// No description provided for @profileLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language'**
  String get profileLanguageSubtitle;

  /// No description provided for @systemLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Use device language'**
  String get systemLanguageLabel;

  /// No description provided for @onboardingNextLabel.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNextLabel;

  /// No description provided for @onboardingGetStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStartedLabel;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Feel more in sync with your cycle'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track symptoms, understand phase changes, and get thoughtful guidance in one calm space.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Data,\nYour Control'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'We can\'t identify you, can\'t sell your data, and have never received a law enforcement request.'**
  String get onboardingPrivacySubtitle;

  /// No description provided for @onboardingPrivacyFeatureEncryption.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted with AES-256'**
  String get onboardingPrivacyFeatureEncryption;

  /// No description provided for @onboardingPrivacyFeatureNoSelling.
  ///
  /// In en, this message translates to:
  /// **'Zero advertising, zero data selling'**
  String get onboardingPrivacyFeatureNoSelling;

  /// No description provided for @onboardingPrivacyFeatureLocalMode.
  ///
  /// In en, this message translates to:
  /// **'Optional local-only mode'**
  String get onboardingPrivacyFeatureLocalMode;

  /// No description provided for @onboardingSkipLabel.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkipLabel;

  /// No description provided for @onboardingPhasesTitle.
  ///
  /// In en, this message translates to:
  /// **'Every phase,\ndecoded.'**
  String get onboardingPhasesTitle;

  /// No description provided for @onboardingPhasesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From the first day of your period to the days\nafter ovulation, Vyla maps where you are\nand what to expect'**
  String get onboardingPhasesSubtitle;

  /// No description provided for @onboardingRhythmTitle.
  ///
  /// In en, this message translates to:
  /// **'Know your\nrhythm.'**
  String get onboardingRhythmTitle;

  /// No description provided for @onboardingRhythmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Vyla learns the patterns of your body,\ngiving you clarity, not just a calendar.'**
  String get onboardingRhythmSubtitle;

  /// No description provided for @onboardingPhaseMenstrualTitle.
  ///
  /// In en, this message translates to:
  /// **'Menstrual'**
  String get onboardingPhaseMenstrualTitle;

  /// No description provided for @onboardingPhaseMenstrualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rest · renewal'**
  String get onboardingPhaseMenstrualSubtitle;

  /// No description provided for @onboardingPhaseMenstrualDays.
  ///
  /// In en, this message translates to:
  /// **'Day 1–5'**
  String get onboardingPhaseMenstrualDays;

  /// No description provided for @onboardingPhaseFollicularTitle.
  ///
  /// In en, this message translates to:
  /// **'Follicular'**
  String get onboardingPhaseFollicularTitle;

  /// No description provided for @onboardingPhaseFollicularSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Energy · renewal'**
  String get onboardingPhaseFollicularSubtitle;

  /// No description provided for @onboardingPhaseFollicularDays.
  ///
  /// In en, this message translates to:
  /// **'Day 6–13'**
  String get onboardingPhaseFollicularDays;

  /// No description provided for @onboardingPhaseOvulationTitle.
  ///
  /// In en, this message translates to:
  /// **'Ovulation'**
  String get onboardingPhaseOvulationTitle;

  /// No description provided for @onboardingPhaseOvulationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Peak fertility'**
  String get onboardingPhaseOvulationSubtitle;

  /// No description provided for @onboardingPhaseOvulationDays.
  ///
  /// In en, this message translates to:
  /// **'Day 14–16'**
  String get onboardingPhaseOvulationDays;

  /// No description provided for @onboardingPhaseLutealTitle.
  ///
  /// In en, this message translates to:
  /// **'Luteal'**
  String get onboardingPhaseLutealTitle;

  /// No description provided for @onboardingPhaseLutealSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rest · renewal'**
  String get onboardingPhaseLutealSubtitle;

  /// No description provided for @onboardingPhaseLutealDays.
  ///
  /// In en, this message translates to:
  /// **'Day 17–28'**
  String get onboardingPhaseLutealDays;

  /// No description provided for @onboardingAiBadge.
  ///
  /// In en, this message translates to:
  /// **'Vyla Agent'**
  String get onboardingAiBadge;

  /// No description provided for @onboardingAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Your health,\nanswered.'**
  String get onboardingAiTitle;

  /// No description provided for @onboardingAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your body. Vyla Agent\ndraws on your personal data and evidence\nbased health knowledge to guide you.'**
  String get onboardingAiSubtitle;

  /// No description provided for @onboardingAiQuestion.
  ///
  /// In en, this message translates to:
  /// **'Why do I feel low energy\nbefore my period?'**
  String get onboardingAiQuestion;

  /// No description provided for @onboardingAiResponse.
  ///
  /// In en, this message translates to:
  /// **'In the luteal phase, progesterone\nrises and oestrogen drops - your\nbody is preparing to shed. Your logs\nshow this pattern across 3 cycles.'**
  String get onboardingAiResponse;

  /// No description provided for @onboardingStartTrackingLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking'**
  String get onboardingStartTrackingLabel;

  /// No description provided for @privacyChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Your\nPrivacy Level'**
  String get privacyChoiceTitle;

  /// No description provided for @privacyChoiceEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'With Email'**
  String get privacyChoiceEmailTitle;

  /// No description provided for @privacyChoiceEmailBadge.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED'**
  String get privacyChoiceEmailBadge;

  /// No description provided for @privacyChoiceEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'Account recovery, notifications, multi-device sync'**
  String get privacyChoiceEmailDescription;

  /// No description provided for @privacyChoiceEmailCta.
  ///
  /// In en, this message translates to:
  /// **'Sign Up with Email'**
  String get privacyChoiceEmailCta;

  /// No description provided for @privacyChoiceExistingAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get privacyChoiceExistingAccountPrompt;

  /// No description provided for @signInLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInLinkLabel;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your cycle, bloom with confidence'**
  String get signInSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get emailHint;

  /// No description provided for @signInButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButtonLabel;

  /// No description provided for @signInEmptyCredentialsError.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password.'**
  String get signInEmptyCredentialsError;

  /// No description provided for @signInUnableError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in.'**
  String get signInUnableError;

  /// No description provided for @forgotPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLabel;

  /// No description provided for @authContinueWithLabel.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get authContinueWithLabel;

  /// No description provided for @signInAppleError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in with Apple.'**
  String get signInAppleError;

  /// No description provided for @signInGoogleError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in with Google.'**
  String get signInGoogleError;

  /// No description provided for @signInNoAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get signInNoAccountPrompt;

  /// No description provided for @signUpLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUpLinkLabel;

  /// No description provided for @signingInLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingInLoadingLabel;

  /// No description provided for @signUpNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter your name to continue.'**
  String get signUpNameRequiredError;

  /// No description provided for @signUpCountryRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Tell us where you live to continue.'**
  String get signUpCountryRequiredError;

  /// No description provided for @signUpBirthDateRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Select your birth date to continue.'**
  String get signUpBirthDateRequiredError;

  /// No description provided for @signUpAcceptTermsError.
  ///
  /// In en, this message translates to:
  /// **'Accept the Terms of Service and Privacy Policy.'**
  String get signUpAcceptTermsError;

  /// No description provided for @signUpCompleteProfileError.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile details before continuing.'**
  String get signUpCompleteProfileError;

  /// No description provided for @signUpAppleError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign up with Apple.'**
  String get signUpAppleError;

  /// No description provided for @signUpExistingAccountError.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in instead.'**
  String get signUpExistingAccountError;

  /// No description provided for @signUpGoogleError.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign up with Google.'**
  String get signUpGoogleError;

  /// No description provided for @signUpCompleteProfileFirstError.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile details first.'**
  String get signUpCompleteProfileFirstError;

  /// No description provided for @signUpEmailRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get signUpEmailRequiredError;

  /// No description provided for @signUpEmailInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get signUpEmailInvalidError;

  /// No description provided for @signUpPasswordRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Create a password to continue.'**
  String get signUpPasswordRequiredError;

  /// No description provided for @signUpPasswordLengthError.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters for your password.'**
  String get signUpPasswordLengthError;

  /// No description provided for @signUpConfirmPasswordRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password to continue.'**
  String get signUpConfirmPasswordRequiredError;

  /// No description provided for @signUpPasswordsMismatchError.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get signUpPasswordsMismatchError;

  /// No description provided for @signUpCreateAccountError.
  ///
  /// In en, this message translates to:
  /// **'Unable to create account.'**
  String get signUpCreateAccountError;

  /// No description provided for @cancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelLabel;

  /// No description provided for @doneLabel.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneLabel;

  /// No description provided for @signUpSelectBirthDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Select your birth date'**
  String get signUpSelectBirthDateLabel;

  /// No description provided for @signUpStepLabel.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String signUpStepLabel(int current, int total);

  /// No description provided for @signUpNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your name?'**
  String get signUpNameTitle;

  /// No description provided for @signUpNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will use this to personalize your Vyla experience.'**
  String get signUpNameSubtitle;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Sarah Chen'**
  String get fullNameHint;

  /// No description provided for @signUpNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the name you want to see in your daily check-ins and cycle insights.'**
  String get signUpNameHelp;

  /// No description provided for @signUpCountryTitle.
  ///
  /// In en, this message translates to:
  /// **'Where do you live?'**
  String get signUpCountryTitle;

  /// No description provided for @signUpCountrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps us localize your experience and keep notifications accurate.'**
  String get signUpCountrySubtitle;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryLabel;

  /// No description provided for @countryHint.
  ///
  /// In en, this message translates to:
  /// **'Select your country'**
  String get countryHint;

  /// No description provided for @signUpCountryHelp.
  ///
  /// In en, this message translates to:
  /// **'Your country helps us match plans, billing, reminders, and regional health guidance.'**
  String get signUpCountryHelp;

  /// No description provided for @signUpBirthDateTitle.
  ///
  /// In en, this message translates to:
  /// **'When were you born?'**
  String get signUpBirthDateTitle;

  /// No description provided for @signUpBirthDateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cycles change over time. This helps us tailor the app to you.'**
  String get signUpBirthDateSubtitle;

  /// No description provided for @birthDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get birthDateLabel;

  /// No description provided for @signUpBirthDateHelp.
  ///
  /// In en, this message translates to:
  /// **'We use this to adapt predictions and the educational content you see over time.'**
  String get signUpBirthDateHelp;

  /// No description provided for @signUpMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'How would you like to sign up?'**
  String get signUpMethodTitle;

  /// No description provided for @signUpMethodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the method you want to use for your Vyla account.'**
  String get signUpMethodSubtitle;

  /// No description provided for @signUpEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up with email'**
  String get signUpEmailTitle;

  /// No description provided for @signUpEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use email to secure your account and verify your identity.'**
  String get signUpEmailSubtitle;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordHintMinimum.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHintMinimum;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordHint;

  /// No description provided for @signUpVerificationHelp.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit verification code to this email after signup.'**
  String get signUpVerificationHelp;

  /// No description provided for @creatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creatingLabel;

  /// No description provided for @createAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountLabel;

  /// No description provided for @iHaveAnAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'I have an account'**
  String get iHaveAnAccountLabel;

  /// No description provided for @creatingAccountLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get creatingAccountLoadingLabel;

  /// No description provided for @signUpWithAppleLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Apple'**
  String get signUpWithAppleLabel;

  /// No description provided for @signUpWithGoogleLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Google'**
  String get signUpWithGoogleLabel;

  /// No description provided for @signUpWithEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign up with email'**
  String get signUpWithEmailLabel;

  /// No description provided for @signUpProfileSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile so far'**
  String get signUpProfileSummaryTitle;

  /// No description provided for @consentAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get consentAgreePrefix;

  /// No description provided for @termsOfServiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfServiceLabel;

  /// No description provided for @consentAndLabel.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get consentAndLabel;

  /// No description provided for @privacyPolicyTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitleLabel;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send a 6-digit reset code'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendCodeLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sendCodeLoadingLabel;

  /// No description provided for @sendCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCodeLabel;

  /// No description provided for @forgotPasswordUnableToSendCodeError.
  ///
  /// In en, this message translates to:
  /// **'Unable to send code.'**
  String get forgotPasswordUnableToSendCodeError;

  /// No description provided for @rememberedPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Remembered your password? '**
  String get rememberedPasswordPrompt;

  /// No description provided for @forgotPasswordVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Reset Code'**
  String get forgotPasswordVerifyTitle;

  /// No description provided for @forgotPasswordVerifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to {email}'**
  String forgotPasswordVerifySubtitle(String email);

  /// No description provided for @yourEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'your email'**
  String get yourEmailLabel;

  /// No description provided for @editEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit email'**
  String get editEmailLabel;

  /// No description provided for @verifyingLabel.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifyingLabel;

  /// No description provided for @verifyContinueLabel.
  ///
  /// In en, this message translates to:
  /// **'Verify & Continue'**
  String get verifyContinueLabel;

  /// No description provided for @invalidCodeError.
  ///
  /// In en, this message translates to:
  /// **'Invalid code.'**
  String get invalidCodeError;

  /// No description provided for @resendCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCodeLabel;

  /// No description provided for @unableToResendCodeError.
  ///
  /// In en, this message translates to:
  /// **'Unable to resend code.'**
  String get unableToResendCodeError;

  /// No description provided for @resendCodeInLabel.
  ///
  /// In en, this message translates to:
  /// **'Resend code in 0:{seconds}'**
  String resendCodeInLabel(String seconds);

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for {account}'**
  String resetPasswordSubtitle(String account);

  /// No description provided for @yourAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'your account'**
  String get yourAccountLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordTitleCaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordTitleCaseLabel;

  /// No description provided for @updatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get updatingLabel;

  /// No description provided for @updatePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordLabel;

  /// No description provided for @resetCodeMissingError.
  ///
  /// In en, this message translates to:
  /// **'Reset code missing. Go back and enter the code again.'**
  String get resetCodeMissingError;

  /// No description provided for @unableToResetPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Unable to reset password.'**
  String get unableToResetPasswordError;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {email} to finish creating your Vyla account.'**
  String verifyEmailSubtitle(String email);

  /// No description provided for @verifyEmailButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmailButtonLabel;

  /// No description provided for @accountVerifiedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account verified successfully.'**
  String get accountVerifiedSuccess;

  /// No description provided for @unableToVerifyEmailError.
  ///
  /// In en, this message translates to:
  /// **'Unable to verify email.'**
  String get unableToVerifyEmailError;

  /// No description provided for @resendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Resending...'**
  String get resendingLabel;

  /// No description provided for @resendCodeButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCodeButtonLabel;

  /// No description provided for @resendUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Resend is unavailable. Start sign up again.'**
  String get resendUnavailableError;

  /// No description provided for @exportMyDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get exportMyDataTitle;

  /// No description provided for @exportMyDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Request a portable export of your Vyla account data. We\'ll prepare a secure archive you can download later.'**
  String get exportMyDataSubtitle;

  /// No description provided for @exportChooseIncludeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what to include'**
  String get exportChooseIncludeTitle;

  /// No description provided for @exportCycleHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Cycle history'**
  String get exportCycleHistoryLabel;

  /// No description provided for @exportCycleHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cycles, period dates, and phase summaries'**
  String get exportCycleHistorySubtitle;

  /// No description provided for @exportDailyLogsLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily logs'**
  String get exportDailyLogsLabel;

  /// No description provided for @exportDailyLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'LH, temperature, symptoms, mucus, intimacy'**
  String get exportDailyLogsSubtitle;

  /// No description provided for @exportPredictionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Predictions & insights'**
  String get exportPredictionsLabel;

  /// No description provided for @exportPredictionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fertility predictions and generated summaries'**
  String get exportPredictionsSubtitle;

  /// No description provided for @exportBloomHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Bloom chat history'**
  String get exportBloomHistoryLabel;

  /// No description provided for @exportBloomHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Questions and assistant responses'**
  String get exportBloomHistorySubtitle;

  /// No description provided for @exportFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Export format'**
  String get exportFormatTitle;

  /// No description provided for @exportJsonArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'JSON archive'**
  String get exportJsonArchiveTitle;

  /// No description provided for @exportJsonArchiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Machine-readable export for portability'**
  String get exportJsonArchiveSubtitle;

  /// No description provided for @recommendedLabel.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommendedLabel;

  /// No description provided for @exportCsvBundleTitle.
  ///
  /// In en, this message translates to:
  /// **'CSV bundle'**
  String get exportCsvBundleTitle;

  /// No description provided for @exportCsvBundleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spreadsheet-friendly files for review'**
  String get exportCsvBundleSubtitle;

  /// No description provided for @exportSensitiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensitive export'**
  String get exportSensitiveTitle;

  /// No description provided for @exportSensitiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exports may include personal health data. Download and store the file somewhere private.'**
  String get exportSensitiveSubtitle;

  /// No description provided for @requestExportLabel.
  ///
  /// In en, this message translates to:
  /// **'Request Export'**
  String get requestExportLabel;

  /// No description provided for @exportRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Export requested'**
  String get exportRequestedTitle;

  /// No description provided for @exportRequestedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll prepare your archive and notify you when it is ready to download.'**
  String get exportRequestedSubtitle;

  /// No description provided for @exportWhatNextTitle.
  ///
  /// In en, this message translates to:
  /// **'What happens next'**
  String get exportWhatNextTitle;

  /// No description provided for @exportWhatNextItemOne.
  ///
  /// In en, this message translates to:
  /// **'We package your requested records into a secure archive.'**
  String get exportWhatNextItemOne;

  /// No description provided for @exportWhatNextItemTwo.
  ///
  /// In en, this message translates to:
  /// **'You will be able to download it from a protected link.'**
  String get exportWhatNextItemTwo;

  /// No description provided for @exportWhatNextItemThree.
  ///
  /// In en, this message translates to:
  /// **'The link will expire automatically for safety.'**
  String get exportWhatNextItemThree;

  /// No description provided for @currentPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get currentPlanLabel;

  /// No description provided for @planFreeLabel.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get planFreeLabel;

  /// No description provided for @planPremiumLabel.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get planPremiumLabel;

  /// No description provided for @planPremiumPlusLabel.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get planPremiumPlusLabel;

  /// No description provided for @planClinicianLabel.
  ///
  /// In en, this message translates to:
  /// **'Clinician'**
  String get planClinicianLabel;

  /// No description provided for @subscriptionStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subscriptionStatusActive;

  /// No description provided for @subscriptionStatusTrial.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get subscriptionStatusTrial;

  /// No description provided for @subscriptionStatusPastDue.
  ///
  /// In en, this message translates to:
  /// **'Past due'**
  String get subscriptionStatusPastDue;

  /// No description provided for @subscriptionStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get subscriptionStatusCanceled;

  /// No description provided for @subscriptionStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get subscriptionStatusInactive;

  /// No description provided for @postSignupTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalise your experience'**
  String get postSignupTitle;

  /// No description provided for @postSignupPeriodLengthError.
  ///
  /// In en, this message translates to:
  /// **'Select how many days your period usually lasts.'**
  String get postSignupPeriodLengthError;

  /// No description provided for @postSignupLastPeriodError.
  ///
  /// In en, this message translates to:
  /// **'Select the first and last day of your last period.'**
  String get postSignupLastPeriodError;

  /// No description provided for @postSignupGoalError.
  ///
  /// In en, this message translates to:
  /// **'Select the goal that fits you best.'**
  String get postSignupGoalError;

  /// No description provided for @postSignupConditionsError.
  ///
  /// In en, this message translates to:
  /// **'Select any matching conditions, or choose None.'**
  String get postSignupConditionsError;

  /// No description provided for @postSignupStepLabel.
  ///
  /// In en, this message translates to:
  /// **'Step {step}'**
  String postSignupStepLabel(int step);

  /// No description provided for @postSignupStep1Title.
  ///
  /// In en, this message translates to:
  /// **'What is your period length?'**
  String get postSignupStep1Title;

  /// No description provided for @postSignupStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Typically, it lasts 2-8 days. The more cycle data you provide, the more accurate your predictions will be.'**
  String get postSignupStep1Subtitle;

  /// No description provided for @postSignupStep2Title.
  ///
  /// In en, this message translates to:
  /// **'When was your last period?'**
  String get postSignupStep2Title;

  /// No description provided for @postSignupStep2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the first and last period date.'**
  String get postSignupStep2Subtitle;

  /// No description provided for @postSignupStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your goals.'**
  String get postSignupStep3Title;

  /// No description provided for @postSignupStep3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Vyla can personalize tracking and predictions around what matters most to you.'**
  String get postSignupStep3Subtitle;

  /// No description provided for @postSignupStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Almost there! We need a bit more information.'**
  String get postSignupStep4Title;

  /// No description provided for @postSignupStep4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Select which sounds like you. You can select multiple options.'**
  String get postSignupStep4Subtitle;

  /// No description provided for @savingLabel.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingLabel;

  /// No description provided for @finishLabel.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishLabel;

  /// No description provided for @saveLabelAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabelAction;

  /// No description provided for @postSignupSelectRange.
  ///
  /// In en, this message translates to:
  /// **'Select a range'**
  String get postSignupSelectRange;

  /// No description provided for @postSignupDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String postSignupDaysLabel(int count);

  /// No description provided for @postSignupPeriodLengthHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the slider to estimate how many days bleeding usually lasts.'**
  String get postSignupPeriodLengthHelp;

  /// No description provided for @postSignupPredictionQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Prediction quality'**
  String get postSignupPredictionQualityTitle;

  /// No description provided for @postSignupPredictionQualityDescription.
  ///
  /// In en, this message translates to:
  /// **'Accurate period length helps Vyla sharpen reminders and cycle predictions from the start.'**
  String get postSignupPredictionQualityDescription;

  /// No description provided for @postSignupSelectFirstDayPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select the first day of your last period.'**
  String get postSignupSelectFirstDayPrompt;

  /// No description provided for @postSignupSelectedSingle.
  ///
  /// In en, this message translates to:
  /// **'Selected: {date}'**
  String postSignupSelectedSingle(String date);

  /// No description provided for @postSignupSelectedRange.
  ///
  /// In en, this message translates to:
  /// **'Selected: {start} to {end}'**
  String postSignupSelectedRange(String start, String end);

  /// No description provided for @goalCycleTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle tracking'**
  String get goalCycleTrackingTitle;

  /// No description provided for @goalCycleTrackingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build a clearer view of your rhythm and symptoms.'**
  String get goalCycleTrackingSubtitle;

  /// No description provided for @goalAvoidPregnancyTitle.
  ///
  /// In en, this message translates to:
  /// **'TTA (Trying to Avoid Pregnancy)'**
  String get goalAvoidPregnancyTitle;

  /// No description provided for @goalAvoidPregnancySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track fertile days and plan with more confidence.'**
  String get goalAvoidPregnancySubtitle;

  /// No description provided for @goalTryingToConceiveTitle.
  ///
  /// In en, this message translates to:
  /// **'TTC (Trying to Conceive)'**
  String get goalTryingToConceiveTitle;

  /// No description provided for @goalTryingToConceiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spot fertile windows and improve timing.'**
  String get goalTryingToConceiveSubtitle;

  /// No description provided for @goalPregnancyTitle.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get goalPregnancyTitle;

  /// No description provided for @goalPregnancySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stay aware of cycle history during early pregnancy.'**
  String get goalPregnancySubtitle;

  /// No description provided for @conditionHormoneImbalance.
  ///
  /// In en, this message translates to:
  /// **'Hormone imbalance'**
  String get conditionHormoneImbalance;

  /// No description provided for @conditionIrregularCycle.
  ///
  /// In en, this message translates to:
  /// **'Irregular cycle'**
  String get conditionIrregularCycle;

  /// No description provided for @conditionPcos.
  ///
  /// In en, this message translates to:
  /// **'PCOS'**
  String get conditionPcos;

  /// No description provided for @conditionMiscarriageHistory.
  ///
  /// In en, this message translates to:
  /// **'Miscarriage history'**
  String get conditionMiscarriageHistory;

  /// No description provided for @conditionBirthControl.
  ///
  /// In en, this message translates to:
  /// **'Just came off from birth control'**
  String get conditionBirthControl;

  /// No description provided for @conditionNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get conditionNone;

  /// No description provided for @stressImpactTitle.
  ///
  /// In en, this message translates to:
  /// **'Stress Impact'**
  String get stressImpactTitle;

  /// No description provided for @stressBurdenLabel.
  ///
  /// In en, this message translates to:
  /// **'7-DAY STRESS BURDEN'**
  String get stressBurdenLabel;

  /// No description provided for @stressBurdenDescription.
  ///
  /// In en, this message translates to:
  /// **'Moderate stress burden detected. This may influence your cycle timing.'**
  String get stressBurdenDescription;

  /// No description provided for @stressContributingFactorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contributing factors'**
  String get stressContributingFactorsTitle;

  /// No description provided for @stressFactorHrvLabel.
  ///
  /// In en, this message translates to:
  /// **'HRV (below baseline)'**
  String get stressFactorHrvLabel;

  /// No description provided for @stressFactorRhrLabel.
  ///
  /// In en, this message translates to:
  /// **'RHR (above baseline)'**
  String get stressFactorRhrLabel;

  /// No description provided for @stressFactorSleepLabel.
  ///
  /// In en, this message translates to:
  /// **'Sleep fragmentation'**
  String get stressFactorSleepLabel;

  /// No description provided for @stressFactorSelfReportedLabel.
  ///
  /// In en, this message translates to:
  /// **'Self-reported stress'**
  String get stressFactorSelfReportedLabel;

  /// No description provided for @stressNormalLabel.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get stressNormalLabel;

  /// No description provided for @stressModerateLabel.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get stressModerateLabel;

  /// No description provided for @stressPredictedImpactTitle.
  ///
  /// In en, this message translates to:
  /// **'Predicted cycle impact'**
  String get stressPredictedImpactTitle;

  /// No description provided for @stressConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Moderate confidence'**
  String get stressConfidenceLabel;

  /// No description provided for @stressPredictedImpactSuffix.
  ///
  /// In en, this message translates to:
  /// **' that ovulation may be delayed 1–3 days this cycle.'**
  String get stressPredictedImpactSuffix;

  /// No description provided for @stressPredictedImpactDescription.
  ///
  /// In en, this message translates to:
  /// **'Your fertile window has been widened accordingly. This is an association, not a certainty.'**
  String get stressPredictedImpactDescription;

  /// No description provided for @stressLast30DaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get stressLast30DaysTitle;

  /// No description provided for @stressBurdenLegend.
  ///
  /// In en, this message translates to:
  /// **'Stress burden'**
  String get stressBurdenLegend;

  /// No description provided for @stressOvulationDaysLegend.
  ///
  /// In en, this message translates to:
  /// **'Ovulation days'**
  String get stressOvulationDaysLegend;

  /// No description provided for @stressCycleCorrelationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle correlation'**
  String get stressCycleCorrelationTitle;

  /// No description provided for @stressCycleCorrelationIntro.
  ///
  /// In en, this message translates to:
  /// **'Over your last 6 cycles:'**
  String get stressCycleCorrelationIntro;

  /// No description provided for @stressCycleCorrelationItemOne.
  ///
  /// In en, this message translates to:
  /// **'High stress weeks: ovulation averaged 18 days later'**
  String get stressCycleCorrelationItemOne;

  /// No description provided for @stressCycleCorrelationItemTwo.
  ///
  /// In en, this message translates to:
  /// **'Low stress weeks: ovulation averaged on day 14.2'**
  String get stressCycleCorrelationItemTwo;

  /// No description provided for @stressCycleCorrelationItemThree.
  ///
  /// In en, this message translates to:
  /// **'Correlation strength: r = 0.61'**
  String get stressCycleCorrelationItemThree;

  /// No description provided for @stressLowLabel.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get stressLowLabel;

  /// No description provided for @stressHighLabel.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get stressHighLabel;

  /// No description provided for @stressTrendChartPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'[Stress burden trend chart: 0–1 scale, 7-day rolling average]'**
  String get stressTrendChartPlaceholder;

  /// No description provided for @logCervicalMucusTitle.
  ///
  /// In en, this message translates to:
  /// **'Cervical Mucus'**
  String get logCervicalMucusTitle;

  /// No description provided for @logConsistencyTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Consistency & Type'**
  String get logConsistencyTypeTitle;

  /// No description provided for @logMucusDryNoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Dry / None'**
  String get logMucusDryNoneLabel;

  /// No description provided for @logMucusDryNoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No mucus present'**
  String get logMucusDryNoneSubtitle;

  /// No description provided for @logMucusStickyLabel.
  ///
  /// In en, this message translates to:
  /// **'Sticky'**
  String get logMucusStickyLabel;

  /// No description provided for @logMucusStickySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Thick, white or cloudy'**
  String get logMucusStickySubtitle;

  /// No description provided for @logMucusCreamyLabel.
  ///
  /// In en, this message translates to:
  /// **'Creamy'**
  String get logMucusCreamyLabel;

  /// No description provided for @logMucusCreamySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lotion-like, white or yellow'**
  String get logMucusCreamySubtitle;

  /// No description provided for @logMucusEggWhiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Egg White (Fertile)'**
  String get logMucusEggWhiteLabel;

  /// No description provided for @logMucusEggWhiteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear, stretchy, slippery'**
  String get logMucusEggWhiteSubtitle;

  /// No description provided for @logMucusWateryLabel.
  ///
  /// In en, this message translates to:
  /// **'Watery'**
  String get logMucusWateryLabel;

  /// No description provided for @logMucusWaterySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Thin, clear, wet'**
  String get logMucusWaterySubtitle;

  /// No description provided for @logAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get logAmountTitle;

  /// No description provided for @logAmountLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get logAmountLightLabel;

  /// No description provided for @logAmountModerateLabel.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get logAmountModerateLabel;

  /// No description provided for @logAmountHeavyLabel.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get logAmountHeavyLabel;

  /// No description provided for @logNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get logNotesTitle;

  /// No description provided for @logAdditionalObservationsHint.
  ///
  /// In en, this message translates to:
  /// **'Any additional observations...'**
  String get logAdditionalObservationsHint;

  /// No description provided for @logCervicalMucusSaved.
  ///
  /// In en, this message translates to:
  /// **'Cervical mucus saved.'**
  String get logCervicalMucusSaved;

  /// No description provided for @saveMucusLogLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Mucus Log'**
  String get saveMucusLogLabel;

  /// No description provided for @logPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Period Log'**
  String get logPeriodTitle;

  /// No description provided for @logPeriodFlowIntensityTitle.
  ///
  /// In en, this message translates to:
  /// **'Flow Intensity'**
  String get logPeriodFlowIntensityTitle;

  /// No description provided for @logPeriodFlowSpottingLabel.
  ///
  /// In en, this message translates to:
  /// **'Spotting'**
  String get logPeriodFlowSpottingLabel;

  /// No description provided for @logPeriodFlowMediumLabel.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get logPeriodFlowMediumLabel;

  /// No description provided for @logPeriodFlowColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Flow Color'**
  String get logPeriodFlowColorTitle;

  /// No description provided for @logPeriodColorBrownLabel.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get logPeriodColorBrownLabel;

  /// No description provided for @logPeriodColorRedLabel.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get logPeriodColorRedLabel;

  /// No description provided for @logPeriodColorDarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get logPeriodColorDarkLabel;

  /// No description provided for @logPeriodSymptomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Period Symptoms'**
  String get logPeriodSymptomsTitle;

  /// No description provided for @logPeriodNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add any additional notes...'**
  String get logPeriodNotesHint;

  /// No description provided for @logPeriodSaved.
  ///
  /// In en, this message translates to:
  /// **'Period log saved.'**
  String get logPeriodSaved;

  /// No description provided for @savePeriodLogLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Period Log'**
  String get savePeriodLogLabel;

  /// No description provided for @logSymptomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get logSymptomsTitle;

  /// No description provided for @logSymptomsEnergyLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Energy Level'**
  String get logSymptomsEnergyLevelTitle;

  /// No description provided for @logScaleLowLabel.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get logScaleLowLabel;

  /// No description provided for @logScaleHighLabel.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get logScaleHighLabel;

  /// No description provided for @logSymptomsMoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get logSymptomsMoodTitle;

  /// No description provided for @logMoodHappyLabel.
  ///
  /// In en, this message translates to:
  /// **'Happy'**
  String get logMoodHappyLabel;

  /// No description provided for @logMoodSadLabel.
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get logMoodSadLabel;

  /// No description provided for @logMoodAnxiousLabel.
  ///
  /// In en, this message translates to:
  /// **'Anxious'**
  String get logMoodAnxiousLabel;

  /// No description provided for @logMoodIrritableLabel.
  ///
  /// In en, this message translates to:
  /// **'Irritable'**
  String get logMoodIrritableLabel;

  /// No description provided for @logMoodCalmLabel.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get logMoodCalmLabel;

  /// No description provided for @logMoodEnergeticLabel.
  ///
  /// In en, this message translates to:
  /// **'Energetic'**
  String get logMoodEnergeticLabel;

  /// No description provided for @logSymptomsPhysicalSymptomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Physical Symptoms'**
  String get logSymptomsPhysicalSymptomsTitle;

  /// No description provided for @logSymptomCrampsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cramps'**
  String get logSymptomCrampsLabel;

  /// No description provided for @logSymptomBloatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Bloating'**
  String get logSymptomBloatingLabel;

  /// No description provided for @logSymptomHeadacheLabel.
  ///
  /// In en, this message translates to:
  /// **'Headache'**
  String get logSymptomHeadacheLabel;

  /// No description provided for @logSymptomFatigueLabel.
  ///
  /// In en, this message translates to:
  /// **'Fatigue'**
  String get logSymptomFatigueLabel;

  /// No description provided for @logSymptomBackPainLabel.
  ///
  /// In en, this message translates to:
  /// **'Back Pain'**
  String get logSymptomBackPainLabel;

  /// No description provided for @logSymptomNauseaLabel.
  ///
  /// In en, this message translates to:
  /// **'Nausea'**
  String get logSymptomNauseaLabel;

  /// No description provided for @logSymptomBreastTendernessLabel.
  ///
  /// In en, this message translates to:
  /// **'Breast Tenderness'**
  String get logSymptomBreastTendernessLabel;

  /// No description provided for @logSymptomAcneLabel.
  ///
  /// In en, this message translates to:
  /// **'Acne'**
  String get logSymptomAcneLabel;

  /// No description provided for @logSymptomCravingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cravings'**
  String get logSymptomCravingsLabel;

  /// No description provided for @logSymptomsPainLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Pain Level'**
  String get logSymptomsPainLevelTitle;

  /// No description provided for @logScaleNoneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get logScaleNoneLabel;

  /// No description provided for @logScaleSevereLabel.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get logScaleSevereLabel;

  /// No description provided for @logSymptomsSleepQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep Quality'**
  String get logSymptomsSleepQualityTitle;

  /// No description provided for @logSleepPoorLabel.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get logSleepPoorLabel;

  /// No description provided for @logSleepFairLabel.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get logSleepFairLabel;

  /// No description provided for @logSleepGoodLabel.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get logSleepGoodLabel;

  /// No description provided for @logSleepGreatLabel.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get logSleepGreatLabel;

  /// No description provided for @logSymptomsNotesHint.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today?'**
  String get logSymptomsNotesHint;

  /// No description provided for @logSymptomsSaved.
  ///
  /// In en, this message translates to:
  /// **'Symptoms saved.'**
  String get logSymptomsSaved;

  /// No description provided for @saveSymptomsLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Symptoms'**
  String get saveSymptomsLabel;

  /// No description provided for @logTemperatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get logTemperatureTitle;

  /// No description provided for @logTemperatureWatchConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Apple Watch Connected'**
  String get logTemperatureWatchConnectedTitle;

  /// No description provided for @logTemperatureWatchConnectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wrist temperature tracked automatically.\nManual entry optional for comparison.'**
  String get logTemperatureWatchConnectedSubtitle;

  /// No description provided for @logTemperatureBbtTitle.
  ///
  /// In en, this message translates to:
  /// **'Basal Body Temperature'**
  String get logTemperatureBbtTitle;

  /// No description provided for @logTemperatureNormalRangeNote.
  ///
  /// In en, this message translates to:
  /// **'Normal range: 36.1°C - 36.4°C (follicular)'**
  String get logTemperatureNormalRangeNote;

  /// No description provided for @logTemperatureMeasurementTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement Time'**
  String get logTemperatureMeasurementTimeTitle;

  /// No description provided for @logTemperatureQualityFactorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Quality Factors'**
  String get logTemperatureQualityFactorsTitle;

  /// No description provided for @logTemperatureSameTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Same time as yesterday?'**
  String get logTemperatureSameTimeLabel;

  /// No description provided for @logTemperatureSleepLabel.
  ///
  /// In en, this message translates to:
  /// **'Uninterrupted sleep (5+ hrs)?'**
  String get logTemperatureSleepLabel;

  /// No description provided for @logTemperatureBeforeGettingUpLabel.
  ///
  /// In en, this message translates to:
  /// **'Measured before getting up?'**
  String get logTemperatureBeforeGettingUpLabel;

  /// No description provided for @logTemperatureSaved.
  ///
  /// In en, this message translates to:
  /// **'Temperature saved.'**
  String get logTemperatureSaved;

  /// No description provided for @saveTemperatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Temperature'**
  String get saveTemperatureLabel;

  /// No description provided for @logIntimacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Intimacy'**
  String get logIntimacyTitle;

  /// No description provided for @logIntimacyPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Privacy Matters'**
  String get logIntimacyPrivacyTitle;

  /// No description provided for @logIntimacyPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'This data is private, encrypted, and used only to improve ovulation predictions.'**
  String get logIntimacyPrivacySubtitle;

  /// No description provided for @logIntimacyActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get logIntimacyActivityTitle;

  /// No description provided for @logIntimacyUnprotectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unprotected'**
  String get logIntimacyUnprotectedLabel;

  /// No description provided for @logIntimacyProtectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get logIntimacyProtectedLabel;

  /// No description provided for @logIntimacyBirthControlLabel.
  ///
  /// In en, this message translates to:
  /// **'Birth Control'**
  String get logIntimacyBirthControlLabel;

  /// No description provided for @logIntimacyOtherLabel.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get logIntimacyOtherLabel;

  /// No description provided for @logIntimacyTimeOptionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Time (Optional)'**
  String get logIntimacyTimeOptionalTitle;

  /// No description provided for @logIntimacyDetailsOptionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Additional Details (Optional)'**
  String get logIntimacyDetailsOptionalTitle;

  /// No description provided for @logIntimacyDetailOrgasmLabel.
  ///
  /// In en, this message translates to:
  /// **'Orgasm'**
  String get logIntimacyDetailOrgasmLabel;

  /// No description provided for @logIntimacyDetailPainfulLabel.
  ///
  /// In en, this message translates to:
  /// **'Painful'**
  String get logIntimacyDetailPainfulLabel;

  /// No description provided for @logIntimacyDetailDryLabel.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get logIntimacyDetailDryLabel;

  /// No description provided for @logIntimacyDetailBleedingLabel.
  ///
  /// In en, this message translates to:
  /// **'Bleeding'**
  String get logIntimacyDetailBleedingLabel;

  /// No description provided for @logIntimacyNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Any notes...'**
  String get logIntimacyNotesHint;

  /// No description provided for @logIntimacySaved.
  ///
  /// In en, this message translates to:
  /// **'Intimacy log saved.'**
  String get logIntimacySaved;

  /// No description provided for @saveIntimacyLogLabel.
  ///
  /// In en, this message translates to:
  /// **'Save Intimacy Log'**
  String get saveIntimacyLogLabel;

  /// No description provided for @logDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Log'**
  String get logDailyTitle;

  /// No description provided for @logDailyAllSavedLabel.
  ///
  /// In en, this message translates to:
  /// **'All saved'**
  String get logDailyAllSavedLabel;

  /// No description provided for @logDailySaveRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Save remaining ({count})'**
  String logDailySaveRemainingLabel(int count);

  /// No description provided for @logDailySaved.
  ///
  /// In en, this message translates to:
  /// **'Today\'s log saved.'**
  String get logDailySaved;

  /// No description provided for @logSuggestedTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested today'**
  String get logSuggestedTodayLabel;

  /// No description provided for @logLhPhotoValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Run a valid LH strip analysis before saving photo mode.'**
  String get logLhPhotoValidationMessage;

  /// No description provided for @logSectionEmptyValidationMessage.
  ///
  /// In en, this message translates to:
  /// **'Add something in this section before saving.'**
  String get logSectionEmptyValidationMessage;

  /// No description provided for @logSectionSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'{section} saved.'**
  String logSectionSavedMessage(String section);

  /// No description provided for @logSaveSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Save {section}'**
  String logSaveSectionLabel(String section);

  /// No description provided for @logLhImagePrepareError.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the LH image right now.'**
  String get logLhImagePrepareError;

  /// No description provided for @logLhInvalidStripMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm that this is a valid LH strip image.'**
  String get logLhInvalidStripMessage;

  /// No description provided for @logLhAnalysisCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Analysis complete. Review the suggested result below.'**
  String get logLhAnalysisCompleteMessage;

  /// No description provided for @logLhImageAnalysisError.
  ///
  /// In en, this message translates to:
  /// **'Could not analyse the LH image right now.'**
  String get logLhImageAnalysisError;

  /// No description provided for @logImageSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Select image source'**
  String get logImageSourceTitle;

  /// No description provided for @logTakePhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get logTakePhotoLabel;

  /// No description provided for @logUploadFromLibraryLabel.
  ///
  /// In en, this message translates to:
  /// **'Upload from Library'**
  String get logUploadFromLibraryLabel;

  /// No description provided for @logDailyFlowColourTitle.
  ///
  /// In en, this message translates to:
  /// **'Flow colour'**
  String get logDailyFlowColourTitle;

  /// No description provided for @logDailyColorPinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get logDailyColorPinkLabel;

  /// No description provided for @logDailySymptomTenderBreastsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tender Breasts'**
  String get logDailySymptomTenderBreastsLabel;

  /// No description provided for @logDailySymptomsNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add context if you want...'**
  String get logDailySymptomsNotesHint;

  /// No description provided for @logDailyWearableDetectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connected device detected. Manual entry is optional and useful for comparison.'**
  String get logDailyWearableDetectedMessage;

  /// No description provided for @logDailyBbtTitle.
  ///
  /// In en, this message translates to:
  /// **'BBT'**
  String get logDailyBbtTitle;

  /// No description provided for @logDailySelectTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get logDailySelectTimeLabel;

  /// No description provided for @logDailyEntryMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Entry method'**
  String get logDailyEntryMethodTitle;

  /// No description provided for @logDailyPhotoAnalysisLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo Analysis'**
  String get logDailyPhotoAnalysisLabel;

  /// No description provided for @logDailyManualLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get logDailyManualLabel;

  /// No description provided for @logDailyPhotoAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo analysis'**
  String get logDailyPhotoAnalysisTitle;

  /// No description provided for @logDailyPreviewStripMessage.
  ///
  /// In en, this message translates to:
  /// **'Preview your strip image, then process it for LH analysis'**
  String get logDailyPreviewStripMessage;

  /// No description provided for @logDailyTakeOrUploadStripMessage.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or upload a strip image for analysis'**
  String get logDailyTakeOrUploadStripMessage;

  /// No description provided for @logDailyAnalysisBeforeSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'We will show the analysis result before you save this section. You can still override the suggested result.'**
  String get logDailyAnalysisBeforeSaveMessage;

  /// No description provided for @logDailyStripPhotoTipsMessage.
  ///
  /// In en, this message translates to:
  /// **'Best results come from a clear, evenly lit strip photo.'**
  String get logDailyStripPhotoTipsMessage;

  /// No description provided for @logDailyCouldNotPreviewImage.
  ///
  /// In en, this message translates to:
  /// **'Could not preview this image'**
  String get logDailyCouldNotPreviewImage;

  /// No description provided for @logDailyChooseAnotherImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose another image'**
  String get logDailyChooseAnotherImageLabel;

  /// No description provided for @logDailyTakeOrUploadStripPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Take or upload strip photo'**
  String get logDailyTakeOrUploadStripPhotoLabel;

  /// No description provided for @logDailyProcessImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Process image'**
  String get logDailyProcessImageLabel;

  /// No description provided for @logDailyAnalysisResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis result'**
  String get logDailyAnalysisResultTitle;

  /// No description provided for @logDailyResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get logDailyResultTitle;

  /// No description provided for @logDailyLhNegativeLabel.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get logDailyLhNegativeLabel;

  /// No description provided for @logDailyLhPeakLabel.
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get logDailyLhPeakLabel;

  /// No description provided for @logDailyTimeOfTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Time of test'**
  String get logDailyTimeOfTestTitle;

  /// No description provided for @logDailyBestTestedTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Best tested 10am–8pm'**
  String get logDailyBestTestedTimeHint;

  /// No description provided for @logDailySetTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Set time'**
  String get logDailySetTimeLabel;

  /// No description provided for @logDailyAnalysisReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis ready'**
  String get logDailyAnalysisReadyTitle;

  /// No description provided for @logDailyAnalysisNeededTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis needed'**
  String get logDailyAnalysisNeededTitle;

  /// No description provided for @logDailySuggestedResultLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested result: {result}'**
  String logDailySuggestedResultLabel(String result);

  /// No description provided for @logDailyProcessImageBeforeSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Process the image first. Save stays disabled until a valid result is returned.'**
  String get logDailyProcessImageBeforeSaveMessage;

  /// No description provided for @logDailyTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get logDailyTypeTitle;

  /// No description provided for @logDailyFertileSignDetectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Fertile sign detected'**
  String get logDailyFertileSignDetectedLabel;

  /// No description provided for @logDailyMucusDryNoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Dry/None'**
  String get logDailyMucusDryNoneLabel;

  /// No description provided for @logDailyAnythingElseHint.
  ///
  /// In en, this message translates to:
  /// **'Anything else you noticed...'**
  String get logDailyAnythingElseHint;

  /// No description provided for @logDailyPrivateTrackingMessage.
  ///
  /// In en, this message translates to:
  /// **'Private, encrypted, used only to improve ovulation predictions.'**
  String get logDailyPrivateTrackingMessage;

  /// No description provided for @logDailyAdditionalDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get logDailyAdditionalDetailsTitle;

  /// No description provided for @logDailyTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get logDailyTimeTitle;

  /// No description provided for @logDailyOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get logDailyOptionalLabel;

  /// No description provided for @logDailyOptionalNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional note...'**
  String get logDailyOptionalNoteHint;

  /// No description provided for @logDiscardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get logDiscardChangesTitle;

  /// No description provided for @logDiscardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved log edits. Leave this screen and lose them?'**
  String get logDiscardChangesMessage;

  /// No description provided for @logStayLabel.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get logStayLabel;

  /// No description provided for @logLeaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get logLeaveLabel;

  /// No description provided for @logSectionPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get logSectionPeriodTitle;

  /// No description provided for @logSectionSymptomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get logSectionSymptomsTitle;

  /// No description provided for @logSectionTemperatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get logSectionTemperatureTitle;

  /// No description provided for @logSectionLhTestTitle.
  ///
  /// In en, this message translates to:
  /// **'LH Test'**
  String get logSectionLhTestTitle;

  /// No description provided for @logSectionCervicalMucusTitle.
  ///
  /// In en, this message translates to:
  /// **'Cervical Mucus'**
  String get logSectionCervicalMucusTitle;

  /// No description provided for @logSectionIntimacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Intimacy'**
  String get logSectionIntimacyTitle;

  /// No description provided for @logUnsavedChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get logUnsavedChangesLabel;

  /// No description provided for @logSectionPeriodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Flow, colour and symptoms'**
  String get logSectionPeriodSubtitle;

  /// No description provided for @logSectionSymptomsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mood, pain, energy and sleep'**
  String get logSectionSymptomsSubtitle;

  /// No description provided for @logSectionTemperatureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'BBT, time and quality factors'**
  String get logSectionTemperatureSubtitle;

  /// No description provided for @logSectionLhTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photo analysis or manual result'**
  String get logSectionLhTestSubtitle;

  /// No description provided for @logSectionCervicalMucusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type, amount and notes'**
  String get logSectionCervicalMucusSubtitle;

  /// No description provided for @logSectionIntimacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Private tracking'**
  String get logSectionIntimacySubtitle;

  /// No description provided for @logSavedEnergyLabel.
  ///
  /// In en, this message translates to:
  /// **'Energy {count}'**
  String logSavedEnergyLabel(int count);

  /// No description provided for @logSavedPainLabel.
  ///
  /// In en, this message translates to:
  /// **'Pain {count}'**
  String logSavedPainLabel(int count);

  /// No description provided for @logLoggedPrivatelyLabel.
  ///
  /// In en, this message translates to:
  /// **'Logged privately'**
  String get logLoggedPrivatelyLabel;

  /// No description provided for @logTemperatureLutealRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Typical luteal range: about 36.4°C–37.0°C'**
  String get logTemperatureLutealRangeLabel;

  /// No description provided for @logTemperatureOvulationRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Ovulation often shows a rising shift after baseline'**
  String get logTemperatureOvulationRangeLabel;

  /// No description provided for @logTemperatureMenstrualRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Typical menstrual range: about 36.1°C–36.4°C'**
  String get logTemperatureMenstrualRangeLabel;

  /// No description provided for @logTemperatureFollicularRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Typical follicular range: about 36.1°C–36.4°C'**
  String get logTemperatureFollicularRangeLabel;

  /// No description provided for @logLhPickerUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Image picker is unavailable right now. Fully stop and rerun the app, then try again.'**
  String get logLhPickerUnavailableMessage;

  /// No description provided for @logLhChooseEntryMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Entry Method'**
  String get logLhChooseEntryMethodTitle;

  /// No description provided for @logLhImageAnalysisLabel.
  ///
  /// In en, this message translates to:
  /// **'Image Analysis'**
  String get logLhImageAnalysisLabel;

  /// No description provided for @logLhUploadStripPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload a strip photo'**
  String get logLhUploadStripPhotoSubtitle;

  /// No description provided for @logLhManualEntryLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get logLhManualEntryLabel;

  /// No description provided for @logLhSelectResultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the result yourself'**
  String get logLhSelectResultSubtitle;

  /// No description provided for @logLhSelectManualResultMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a manual LH result to continue.'**
  String get logLhSelectManualResultMessage;

  /// No description provided for @logLhSaved.
  ///
  /// In en, this message translates to:
  /// **'LH test saved.'**
  String get logLhSaved;

  /// No description provided for @logLhUploadStripMessage.
  ///
  /// In en, this message translates to:
  /// **'Upload an LH strip photo to continue.'**
  String get logLhUploadStripMessage;

  /// No description provided for @logLhUnreadableStripMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not read that LH strip. Please choose a result manually or try another image.'**
  String get logLhUnreadableStripMessage;

  /// No description provided for @logLhHistoryLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'History Logs'**
  String get logLhHistoryLogsTitle;

  /// No description provided for @logLhLoadingHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading LH history...'**
  String get logLhLoadingHistoryMessage;

  /// No description provided for @logLhEmptyHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'No LH tests logged yet. Tap + to add one.'**
  String get logLhEmptyHistoryMessage;

  /// No description provided for @logLhImageAnalysisSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Image analysis'**
  String get logLhImageAnalysisSourceLabel;

  /// No description provided for @logLhManualSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get logLhManualSourceLabel;

  /// No description provided for @logLhUploadStripPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Test Strip Photo'**
  String get logLhUploadStripPhotoTitle;

  /// No description provided for @logLhTakePhotoOrUploadLabel.
  ///
  /// In en, this message translates to:
  /// **'Take Photo or Upload'**
  String get logLhTakePhotoOrUploadLabel;

  /// No description provided for @logLhReplaceSelectedPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Replace Selected Photo'**
  String get logLhReplaceSelectedPhotoLabel;

  /// No description provided for @logLhAiWillAnalyzeLabel.
  ///
  /// In en, this message translates to:
  /// **'AI will analyze line intensity'**
  String get logLhAiWillAnalyzeLabel;

  /// No description provided for @logLhImageReadyLabel.
  ///
  /// In en, this message translates to:
  /// **'Image ready for LH strip analysis'**
  String get logLhImageReadyLabel;

  /// No description provided for @logLhImageTipMessage.
  ///
  /// In en, this message translates to:
  /// **'💡 Tip: Place strip on a white background in good lighting for best results'**
  String get logLhImageTipMessage;

  /// No description provided for @logLhNegativeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Test lighter than control'**
  String get logLhNegativeSubtitle;

  /// No description provided for @logLhLowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Slightly visible line'**
  String get logLhLowSubtitle;

  /// No description provided for @logLhHighSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Same as control'**
  String get logLhHighSubtitle;

  /// No description provided for @logLhPeakSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Darker than control'**
  String get logLhPeakSubtitle;

  /// No description provided for @logLhTestTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Time'**
  String get logLhTestTimeTitle;

  /// No description provided for @logLhBestTestedHint.
  ///
  /// In en, this message translates to:
  /// **'Best tested between 10am - 8pm'**
  String get logLhBestTestedHint;

  /// No description provided for @logLhEditTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit time'**
  String get logLhEditTimeLabel;

  /// No description provided for @logLhSaveButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Save LH Test'**
  String get logLhSaveButtonLabel;

  /// No description provided for @logLhImageAnalysisUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Image analysis is unavailable right now. Please choose your LH result manually.'**
  String get logLhImageAnalysisUnavailableMessage;

  /// No description provided for @logLhStripAnalysisUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'LH strip analysis is unavailable right now. Please choose your LH result manually.'**
  String get logLhStripAnalysisUnavailableMessage;

  /// No description provided for @logLhInvalidStripLabel.
  ///
  /// In en, this message translates to:
  /// **'Invalid strip'**
  String get logLhInvalidStripLabel;

  /// No description provided for @logLhUnreadableLabel.
  ///
  /// In en, this message translates to:
  /// **'Unreadable'**
  String get logLhUnreadableLabel;

  /// No description provided for @logLhUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get logLhUnknownLabel;

  /// No description provided for @logLhCycleDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Cycle day {count}'**
  String logLhCycleDayLabel(int count);

  /// No description provided for @logLhRatioLabel.
  ///
  /// In en, this message translates to:
  /// **'Ratio {value}'**
  String logLhRatioLabel(String value);

  /// No description provided for @logLhPositiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get logLhPositiveLabel;

  /// No description provided for @authGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get authGenericError;

  /// No description provided for @appShellHomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get appShellHomeLabel;

  /// No description provided for @appShellCalendarLabel.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get appShellCalendarLabel;

  /// No description provided for @appShellLogLabel.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get appShellLogLabel;

  /// No description provided for @appShellBloomLabel.
  ///
  /// In en, this message translates to:
  /// **'Bloom'**
  String get appShellBloomLabel;

  /// No description provided for @appShellProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get appShellProfileLabel;

  /// No description provided for @todayDashboardLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your home dashboard right now.'**
  String get todayDashboardLoadError;

  /// No description provided for @todayDashboardSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your dashboard.'**
  String get todayDashboardSignInRequired;

  /// No description provided for @todayFertilitySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Fertility'**
  String get todayFertilitySectionTitle;

  /// No description provided for @todayDailyInsightsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'My Daily Insights'**
  String get todayDailyInsightsSectionTitle;

  /// No description provided for @todayFitnessSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get todayFitnessSectionTitle;

  /// No description provided for @todayWearableSnapshotSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Wearable snapshot'**
  String get todayWearableSnapshotSectionTitle;

  /// No description provided for @todayQuickActionsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get todayQuickActionsSectionTitle;

  /// No description provided for @todayForYouSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get todayForYouSectionTitle;

  /// No description provided for @todayGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}'**
  String todayGreeting(String name);

  /// No description provided for @todayGreetingFallbackName.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get todayGreetingFallbackName;

  /// No description provided for @todayCountdownToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayCountdownToday;

  /// No description provided for @todayCountdownDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String todayCountdownDays(int count);

  /// No description provided for @todayConfidenceWithScore.
  ///
  /// In en, this message translates to:
  /// **'{label} {score}'**
  String todayConfidenceWithScore(String label, String score);

  /// No description provided for @todayCycleDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Cycle day {day}'**
  String todayCycleDayLabel(String day);

  /// No description provided for @todayPhaseLabel.
  ///
  /// In en, this message translates to:
  /// **'{phase} phase'**
  String todayPhaseLabel(String phase);

  /// No description provided for @todayNextPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Next period starts'**
  String get todayNextPeriodLabel;

  /// No description provided for @todayCountdownLabel.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get todayCountdownLabel;

  /// No description provided for @todayConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get todayConfidenceLabel;

  /// No description provided for @todayEditPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit period'**
  String get todayEditPeriodLabel;

  /// No description provided for @todayCardTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s'**
  String get todayCardTodayLabel;

  /// No description provided for @todayCardCycleDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Cycle Day'**
  String get todayCardCycleDayLabel;

  /// No description provided for @todayFoodWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Food + Workout'**
  String get todayFoodWorkoutTitle;

  /// No description provided for @todayEatRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Eat: {items}.'**
  String todayEatRecommendation(String items);

  /// No description provided for @todayTryRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Try: {items}.'**
  String todayTryRecommendation(String items);

  /// No description provided for @todayFertilityStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get todayFertilityStatusLabel;

  /// No description provided for @todayFertileTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Fertile Today'**
  String get todayFertileTodayLabel;

  /// No description provided for @todayNotFertileTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Not Fertile Today'**
  String get todayNotFertileTodayLabel;

  /// No description provided for @todayFertilityWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get todayFertilityWindowLabel;

  /// No description provided for @todayPredictedOvulationLabel.
  ///
  /// In en, this message translates to:
  /// **'Predicted ovulation'**
  String get todayPredictedOvulationLabel;

  /// No description provided for @todayMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get todayMethodLabel;

  /// No description provided for @todayWeekdaySun.
  ///
  /// In en, this message translates to:
  /// **'SUN'**
  String get todayWeekdaySun;

  /// No description provided for @todayWeekdayMon.
  ///
  /// In en, this message translates to:
  /// **'MON'**
  String get todayWeekdayMon;

  /// No description provided for @todayWeekdayTue.
  ///
  /// In en, this message translates to:
  /// **'TUE'**
  String get todayWeekdayTue;

  /// No description provided for @todayWeekdayWed.
  ///
  /// In en, this message translates to:
  /// **'WED'**
  String get todayWeekdayWed;

  /// No description provided for @todayWeekdayThu.
  ///
  /// In en, this message translates to:
  /// **'THU'**
  String get todayWeekdayThu;

  /// No description provided for @todayWeekdayFri.
  ///
  /// In en, this message translates to:
  /// **'FRI'**
  String get todayWeekdayFri;

  /// No description provided for @todayWeekdaySat.
  ///
  /// In en, this message translates to:
  /// **'SAT'**
  String get todayWeekdaySat;

  /// No description provided for @todayOvulationRangeIntro.
  ///
  /// In en, this message translates to:
  /// **'Ovulation will fall between -'**
  String get todayOvulationRangeIntro;

  /// No description provided for @todayIntensityLabel.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get todayIntensityLabel;

  /// No description provided for @todayRecoveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get todayRecoveryLabel;

  /// No description provided for @todayRecommendedFocusLabel.
  ///
  /// In en, this message translates to:
  /// **'Recommended Focus'**
  String get todayRecommendedFocusLabel;

  /// No description provided for @todayConnectWearableTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a wearable'**
  String get todayConnectWearableTitle;

  /// No description provided for @todayConnectWearableDescription.
  ///
  /// In en, this message translates to:
  /// **'Link a wearable to unlock sleep, heart rate, HRV, and temperature-based support signals.'**
  String get todayConnectWearableDescription;

  /// No description provided for @todayConnectDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Connect device'**
  String get todayConnectDeviceLabel;

  /// No description provided for @todayWearableLabel.
  ///
  /// In en, this message translates to:
  /// **'Wearable'**
  String get todayWearableLabel;

  /// No description provided for @todayConnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get todayConnectedLabel;

  /// No description provided for @todaySleepLabel.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get todaySleepLabel;

  /// No description provided for @todayRestingHeartRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate'**
  String get todayRestingHeartRateLabel;

  /// No description provided for @todayHrvLabel.
  ///
  /// In en, this message translates to:
  /// **'HRV'**
  String get todayHrvLabel;

  /// No description provided for @todayTemperatureDeltaLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature delta'**
  String get todayTemperatureDeltaLabel;

  /// No description provided for @todayLatestSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest sync'**
  String get todayLatestSyncLabel;

  /// No description provided for @todayDateRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String todayDateRangeLabel(String start, String end);

  /// No description provided for @todayPhaseMenstrual.
  ///
  /// In en, this message translates to:
  /// **'Menstrual'**
  String get todayPhaseMenstrual;

  /// No description provided for @todayPhaseFollicular.
  ///
  /// In en, this message translates to:
  /// **'Follicular'**
  String get todayPhaseFollicular;

  /// No description provided for @todayPhaseOvulatory.
  ///
  /// In en, this message translates to:
  /// **'Ovulatory'**
  String get todayPhaseOvulatory;

  /// No description provided for @todayPhaseLuteal.
  ///
  /// In en, this message translates to:
  /// **'Luteal'**
  String get todayPhaseLuteal;

  /// No description provided for @todayPhaseCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get todayPhaseCycle;

  /// No description provided for @todayConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get todayConfidenceLow;

  /// No description provided for @todayConfidenceModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get todayConfidenceModerate;

  /// No description provided for @todayConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get todayConfidenceHigh;

  /// No description provided for @connectedDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected Devices'**
  String get connectedDevicesTitle;

  /// No description provided for @connectedDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage wearable and health-data connections used for cycle insights and stress estimation.'**
  String get connectedDevicesSubtitle;

  /// No description provided for @connectedDevicesAppleWatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Apple Watch'**
  String get connectedDevicesAppleWatchTitle;

  /// No description provided for @connectedDevicesAppleWatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connected and syncing wrist temperature, HRV, resting heart rate, and sleep.'**
  String get connectedDevicesAppleWatchSubtitle;

  /// No description provided for @connectedDevicesLastSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Last sync: Today, 07:14'**
  String get connectedDevicesLastSyncLabel;

  /// No description provided for @connectedDevicesPhoneHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone Health Store'**
  String get connectedDevicesPhoneHealthTitle;

  /// No description provided for @connectedDevicesPhoneHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use phone-level health permissions as a backup source when wearable data is unavailable.'**
  String get connectedDevicesPhoneHealthSubtitle;

  /// No description provided for @connectedDevicesPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get connectedDevicesPermissionsTitle;

  /// No description provided for @connectedDevicesPermissionWristTemperature.
  ///
  /// In en, this message translates to:
  /// **'Wrist temperature'**
  String get connectedDevicesPermissionWristTemperature;

  /// No description provided for @connectedDevicesPermissionHrv.
  ///
  /// In en, this message translates to:
  /// **'Heart rate variability'**
  String get connectedDevicesPermissionHrv;

  /// No description provided for @connectedDevicesPermissionRestingHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate'**
  String get connectedDevicesPermissionRestingHeartRate;

  /// No description provided for @connectedDevicesPermissionSleepDuration.
  ///
  /// In en, this message translates to:
  /// **'Sleep duration and fragmentation'**
  String get connectedDevicesPermissionSleepDuration;

  /// No description provided for @connectedDevicesInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'Device sync improves prediction quality, but Vyla still works when you log data manually.'**
  String get connectedDevicesInfoMessage;

  /// No description provided for @connectedDevicesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Connected devices updated.'**
  String get connectedDevicesUpdated;

  /// No description provided for @healthDataCycleReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle Report'**
  String get healthDataCycleReportTitle;

  /// No description provided for @healthDataCycleReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate a comprehensive cycle report to share with your healthcare provider.'**
  String get healthDataCycleReportSubtitle;

  /// No description provided for @healthDataReportOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Report options'**
  String get healthDataReportOptionsTitle;

  /// No description provided for @healthDataCyclesToIncludeLabel.
  ///
  /// In en, this message translates to:
  /// **'NUMBER OF CYCLES TO INCLUDE'**
  String get healthDataCyclesToIncludeLabel;

  /// No description provided for @healthDataCycleCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} cycles'**
  String healthDataCycleCountLabel(int count);

  /// No description provided for @healthDataIncludeLhHistory.
  ///
  /// In en, this message translates to:
  /// **'Include LH history'**
  String get healthDataIncludeLhHistory;

  /// No description provided for @healthDataIncludeTemperatureChart.
  ///
  /// In en, this message translates to:
  /// **'Include temperature chart'**
  String get healthDataIncludeTemperatureChart;

  /// No description provided for @healthDataIncludeSymptomSummary.
  ///
  /// In en, this message translates to:
  /// **'Include symptom summary'**
  String get healthDataIncludeSymptomSummary;

  /// No description provided for @healthDataReportIncludesTitle.
  ///
  /// In en, this message translates to:
  /// **'Report will include'**
  String get healthDataReportIncludesTitle;

  /// No description provided for @healthDataPersonalHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Personal health data'**
  String get healthDataPersonalHealthTitle;

  /// No description provided for @healthDataPersonalHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This report contains your personal health data. Only share it with trusted healthcare providers.'**
  String get healthDataPersonalHealthSubtitle;

  /// No description provided for @healthDataGeneratePdfLabel.
  ///
  /// In en, this message translates to:
  /// **'Generate PDF report'**
  String get healthDataGeneratePdfLabel;

  /// No description provided for @healthDataIncludedCycleLengths.
  ///
  /// In en, this message translates to:
  /// **'Last {count} cycle lengths and dates'**
  String healthDataIncludedCycleLengths(int count);

  /// No description provided for @healthDataIncludedAverageCycleLength.
  ///
  /// In en, this message translates to:
  /// **'Average cycle length and variability'**
  String get healthDataIncludedAverageCycleLength;

  /// No description provided for @healthDataIncludedLhHistory.
  ///
  /// In en, this message translates to:
  /// **'LH surge detection history'**
  String get healthDataIncludedLhHistory;

  /// No description provided for @healthDataIncludedTemperatureChart.
  ///
  /// In en, this message translates to:
  /// **'Temperature chart showing biphasic pattern'**
  String get healthDataIncludedTemperatureChart;

  /// No description provided for @healthDataIncludedSymptomSummary.
  ///
  /// In en, this message translates to:
  /// **'Symptom tracking summary by phase'**
  String get healthDataIncludedSymptomSummary;

  /// No description provided for @healthDataIncludedOvulationAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Ovulation prediction accuracy'**
  String get healthDataIncludedOvulationAccuracy;

  /// No description provided for @healthDataReportGeneratedTitle.
  ///
  /// In en, this message translates to:
  /// **'Report generated'**
  String get healthDataReportGeneratedTitle;

  /// No description provided for @healthDataReportGeneratedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count}-cycle health summary ready to share'**
  String healthDataReportGeneratedSubtitle(int count);

  /// No description provided for @healthDataShareOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Share options'**
  String get healthDataShareOptionsTitle;

  /// No description provided for @healthDataSaveToFiles.
  ///
  /// In en, this message translates to:
  /// **'Save to Files'**
  String get healthDataSaveToFiles;

  /// No description provided for @healthDataCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get healthDataCopyLink;

  /// No description provided for @healthDataLinkExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expires in 1 hour'**
  String get healthDataLinkExpiry;

  /// No description provided for @healthDataOpenIn.
  ///
  /// In en, this message translates to:
  /// **'Open in...'**
  String get healthDataOpenIn;

  /// No description provided for @editProfileFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get editProfileFullNameLabel;

  /// No description provided for @editProfileDateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get editProfileDateOfBirthLabel;

  /// No description provided for @editProfileCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get editProfileCountryLabel;

  /// No description provided for @editProfilePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your password and sign-in settings.'**
  String get editProfilePasswordSubtitle;

  /// No description provided for @editProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get editProfileUpdated;

  /// No description provided for @editProfileSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get editProfileSaveChanges;

  /// No description provided for @calendarViewMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarViewMonthLabel;

  /// No description provided for @calendarViewYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get calendarViewYearLabel;

  /// No description provided for @calendarSelectedDaySummary.
  ///
  /// In en, this message translates to:
  /// **'Day {cycleDay} — {phase} phase'**
  String calendarSelectedDaySummary(int cycleDay, String phase);

  /// No description provided for @calendarLoggedDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Logged Data'**
  String get calendarLoggedDataTitle;

  /// No description provided for @calendarMoodLabel.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get calendarMoodLabel;

  /// No description provided for @calendarSymptomsLabel.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get calendarSymptomsLabel;

  /// No description provided for @calendarSleepLabel.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get calendarSleepLabel;

  /// No description provided for @calendarEnergyLabel.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get calendarEnergyLabel;

  /// No description provided for @calendarWeekdayMon.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get calendarWeekdayMon;

  /// No description provided for @calendarWeekdayTue.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get calendarWeekdayTue;

  /// No description provided for @calendarWeekdayWed.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get calendarWeekdayWed;

  /// No description provided for @calendarWeekdayThu.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get calendarWeekdayThu;

  /// No description provided for @calendarWeekdayFri.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get calendarWeekdayFri;

  /// No description provided for @calendarWeekdaySat.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get calendarWeekdaySat;

  /// No description provided for @calendarWeekdaySun.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get calendarWeekdaySun;

  /// No description provided for @calendarPhaseUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get calendarPhaseUnknown;

  /// No description provided for @calendarMoodMenstrual.
  ///
  /// In en, this message translates to:
  /// **'Restful, reflective'**
  String get calendarMoodMenstrual;

  /// No description provided for @calendarMoodFollicular.
  ///
  /// In en, this message translates to:
  /// **'Calm, balanced'**
  String get calendarMoodFollicular;

  /// No description provided for @calendarMoodOvulatory.
  ///
  /// In en, this message translates to:
  /// **'Social, energetic'**
  String get calendarMoodOvulatory;

  /// No description provided for @calendarMoodLuteal.
  ///
  /// In en, this message translates to:
  /// **'Calm, balanced'**
  String get calendarMoodLuteal;

  /// No description provided for @calendarMoodUnknown.
  ///
  /// In en, this message translates to:
  /// **'Steady, quiet'**
  String get calendarMoodUnknown;

  /// No description provided for @calendarSymptomsPresent.
  ///
  /// In en, this message translates to:
  /// **'Mild cramps, bloating'**
  String get calendarSymptomsPresent;

  /// No description provided for @calendarSymptomsNone.
  ///
  /// In en, this message translates to:
  /// **'No strong symptoms logged'**
  String get calendarSymptomsNone;

  /// No description provided for @calendarSleepMenstrual.
  ///
  /// In en, this message translates to:
  /// **'7.5 hours, restless'**
  String get calendarSleepMenstrual;

  /// No description provided for @calendarSleepFollicular.
  ///
  /// In en, this message translates to:
  /// **'8 hours, restored'**
  String get calendarSleepFollicular;

  /// No description provided for @calendarSleepOvulatory.
  ///
  /// In en, this message translates to:
  /// **'7.8 hours, light'**
  String get calendarSleepOvulatory;

  /// No description provided for @calendarSleepLuteal.
  ///
  /// In en, this message translates to:
  /// **'7.5 hours, restless'**
  String get calendarSleepLuteal;

  /// No description provided for @calendarSleepUnknown.
  ///
  /// In en, this message translates to:
  /// **'No sleep data'**
  String get calendarSleepUnknown;

  /// No description provided for @calendarEnergyMenstrual.
  ///
  /// In en, this message translates to:
  /// **'Low to medium energy'**
  String get calendarEnergyMenstrual;

  /// No description provided for @calendarEnergyFollicular.
  ///
  /// In en, this message translates to:
  /// **'Rising energy'**
  String get calendarEnergyFollicular;

  /// No description provided for @calendarEnergyOvulatory.
  ///
  /// In en, this message translates to:
  /// **'High energy'**
  String get calendarEnergyOvulatory;

  /// No description provided for @calendarEnergyLuteal.
  ///
  /// In en, this message translates to:
  /// **'Medium energy'**
  String get calendarEnergyLuteal;

  /// No description provided for @calendarEnergyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Energy not logged'**
  String get calendarEnergyUnknown;

  /// No description provided for @calendarNotesMenstrual.
  ///
  /// In en, this message translates to:
  /// **'Felt a bit bloated in the morning and had some mild cramps, but overall it was manageable.'**
  String get calendarNotesMenstrual;

  /// No description provided for @calendarNotesFollicular.
  ///
  /// In en, this message translates to:
  /// **'Energy felt steadier today. Focus and movement both came a little easier than usual.'**
  String get calendarNotesFollicular;

  /// No description provided for @calendarNotesOvulatory.
  ///
  /// In en, this message translates to:
  /// **'Felt more social and alert, with a lighter mood through most of the day.'**
  String get calendarNotesOvulatory;

  /// No description provided for @calendarNotesLuteal.
  ///
  /// In en, this message translates to:
  /// **'A little more sensitive and tired than usual, but still fairly balanced overall.'**
  String get calendarNotesLuteal;

  /// No description provided for @calendarNotesUnknown.
  ///
  /// In en, this message translates to:
  /// **'No notes logged for this day yet.'**
  String get calendarNotesUnknown;

  /// No description provided for @notificationsAndAlertsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications & Alerts'**
  String get notificationsAndAlertsLabel;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stay updated with your health, reminders and important updates.'**
  String get notificationsSubtitle;

  /// No description provided for @notificationsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsFilterAll;

  /// No description provided for @notificationsFilterReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notificationsFilterReminders;

  /// No description provided for @notificationsFilterInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get notificationsFilterInsights;

  /// No description provided for @notificationsFilterUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get notificationsFilterUpdates;

  /// No description provided for @notificationsFilterSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notificationsFilterSystem;

  /// No description provided for @notificationsSectionToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsSectionToday;

  /// No description provided for @notificationsSectionYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notificationsSectionYesterday;

  /// No description provided for @notificationsSectionEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsSectionEarlier;

  /// No description provided for @notificationsShowHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show history'**
  String get notificationsShowHistoryTooltip;

  /// No description provided for @notificationsSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationsSettingsTooltip;

  /// No description provided for @notificationsLoadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading notification settings...'**
  String get notificationsLoadingSettings;

  /// No description provided for @notificationsLoadingHistory.
  ///
  /// In en, this message translates to:
  /// **'Loading notification history...'**
  String get notificationsLoadingHistory;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle alerts, reminders, and health insights will appear here after delivery.'**
  String get notificationsEmptySubtitle;

  /// No description provided for @notificationsSectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get notificationsSectionSettings;

  /// No description provided for @notificationsGroupAllTitle.
  ///
  /// In en, this message translates to:
  /// **'All Notifications'**
  String get notificationsGroupAllTitle;

  /// No description provided for @notificationsGroupAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Master control for all notification types'**
  String get notificationsGroupAllSubtitle;

  /// No description provided for @notificationsAllEnabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable all notifications'**
  String get notificationsAllEnabledTitle;

  /// No description provided for @notificationsAllEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn push delivery on or off across categories'**
  String get notificationsAllEnabledSubtitle;

  /// No description provided for @notificationsGroupPredictionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Predictions & Forecasts'**
  String get notificationsGroupPredictionsTitle;

  /// No description provided for @notificationsGroupPredictionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle timing and fertile window updates'**
  String get notificationsGroupPredictionsSubtitle;

  /// No description provided for @notificationsPeriodApproachingTitle.
  ///
  /// In en, this message translates to:
  /// **'Period approaching'**
  String get notificationsPeriodApproachingTitle;

  /// No description provided for @notificationsPeriodApproachingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'3 days before expected start'**
  String get notificationsPeriodApproachingSubtitle;

  /// No description provided for @notificationsPeriodDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Period detected'**
  String get notificationsPeriodDetectedTitle;

  /// No description provided for @notificationsPeriodDetectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm when period starts'**
  String get notificationsPeriodDetectedSubtitle;

  /// No description provided for @notificationsFertileWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Fertile window'**
  String get notificationsFertileWindowTitle;

  /// No description provided for @notificationsFertileWindowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'1 day before fertility window starts'**
  String get notificationsFertileWindowSubtitle;

  /// No description provided for @notificationsOvulationPredictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ovulation predicted'**
  String get notificationsOvulationPredictedTitle;

  /// No description provided for @notificationsOvulationPredictedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On predicted ovulation day'**
  String get notificationsOvulationPredictedSubtitle;

  /// No description provided for @notificationsCycleDelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle delay alert'**
  String get notificationsCycleDelayTitle;

  /// No description provided for @notificationsCycleDelaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'When period is 3+ days late'**
  String get notificationsCycleDelaySubtitle;

  /// No description provided for @notificationsGroupHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Insights'**
  String get notificationsGroupHealthTitle;

  /// No description provided for @notificationsGroupHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Model-detected changes that may affect your cycle'**
  String get notificationsGroupHealthSubtitle;

  /// No description provided for @notificationsCyclePatternTitle.
  ///
  /// In en, this message translates to:
  /// **'Cycle pattern changes'**
  String get notificationsCyclePatternTitle;

  /// No description provided for @notificationsCyclePatternSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When ML detects irregularities'**
  String get notificationsCyclePatternSubtitle;

  /// No description provided for @notificationsUnusualSymptomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unusual symptoms'**
  String get notificationsUnusualSymptomsTitle;

  /// No description provided for @notificationsUnusualSymptomsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Severe or unexpected symptoms'**
  String get notificationsUnusualSymptomsSubtitle;

  /// No description provided for @notificationsStressAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stress alerts'**
  String get notificationsStressAlertsTitle;

  /// No description provided for @notificationsStressAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'High stress burden detected'**
  String get notificationsStressAlertsSubtitle;

  /// No description provided for @notificationsSleepQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep quality'**
  String get notificationsSleepQualityTitle;

  /// No description provided for @notificationsSleepQualitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Poor sleep detected (bangle only)'**
  String get notificationsSleepQualitySubtitle;

  /// No description provided for @notificationsGroupRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notificationsGroupRemindersTitle;

  /// No description provided for @notificationsGroupRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nudges to stay consistent with data capture'**
  String get notificationsGroupRemindersSubtitle;

  /// No description provided for @notificationsDailyCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily symptom check-in'**
  String get notificationsDailyCheckInTitle;

  /// No description provided for @notificationsDailyCheckInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sent at 8:00 PM'**
  String get notificationsDailyCheckInSubtitle;

  /// No description provided for @notificationsBangleSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Bangle sync'**
  String get notificationsBangleSyncTitle;

  /// No description provided for @notificationsBangleSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When not synced for 48 hours'**
  String get notificationsBangleSyncSubtitle;

  /// No description provided for @notificationsLhReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'LH test reminder'**
  String get notificationsLhReminderTitle;

  /// No description provided for @notificationsLhReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'During fertile window'**
  String get notificationsLhReminderSubtitle;

  /// No description provided for @notificationsGroupCriticalTitle.
  ///
  /// In en, this message translates to:
  /// **'Critical Alerts'**
  String get notificationsGroupCriticalTitle;

  /// No description provided for @notificationsGroupCriticalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'These stay available for time-sensitive health and device risks'**
  String get notificationsGroupCriticalSubtitle;

  /// No description provided for @notificationsHeavyBleedingTitle.
  ///
  /// In en, this message translates to:
  /// **'Heavy bleeding'**
  String get notificationsHeavyBleedingTitle;

  /// No description provided for @notificationsHeavyBleedingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unusually heavy flow detected'**
  String get notificationsHeavyBleedingSubtitle;

  /// No description provided for @notificationsPotentialPregnancyTitle.
  ///
  /// In en, this message translates to:
  /// **'Potential pregnancy'**
  String get notificationsPotentialPregnancyTitle;

  /// No description provided for @notificationsPotentialPregnancySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Period 14+ days late'**
  String get notificationsPotentialPregnancySubtitle;

  /// No description provided for @notificationsBatteryCriticalTitle.
  ///
  /// In en, this message translates to:
  /// **'Bangle battery critical'**
  String get notificationsBatteryCriticalTitle;

  /// No description provided for @notificationsBatteryCriticalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Battery below 5%'**
  String get notificationsBatteryCriticalSubtitle;

  /// No description provided for @notificationsQuietHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet Hours'**
  String get notificationsQuietHoursTitle;

  /// No description provided for @notificationsQuietHoursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pause routine notifications while you sleep'**
  String get notificationsQuietHoursSubtitle;

  /// No description provided for @notificationsStartTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get notificationsStartTimeLabel;

  /// No description provided for @notificationsEndTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get notificationsEndTimeLabel;

  /// No description provided for @notificationsAllowCriticalAlertsLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow critical alerts'**
  String get notificationsAllowCriticalAlertsLabel;

  /// No description provided for @notificationsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load notification settings'**
  String get notificationsLoadErrorTitle;

  /// No description provided for @retryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLabel;

  /// No description provided for @notificationsNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get notificationsNowLabel;

  /// No description provided for @notificationsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsTodayLabel;

  /// No description provided for @notificationsYesterdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notificationsYesterdayLabel;

  /// No description provided for @notificationsMinutesAgoLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} mins ago'**
  String notificationsMinutesAgoLabel(int count);

  /// No description provided for @editProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileLabel;

  /// No description provided for @healthDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Health Data'**
  String get healthDataLabel;

  /// No description provided for @connectedDevicesLabel.
  ///
  /// In en, this message translates to:
  /// **'Connected Devices'**
  String get connectedDevicesLabel;

  /// No description provided for @manageSubscriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscriptionLabel;

  /// No description provided for @appleWatchSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Apple Watch Sync'**
  String get appleWatchSyncLabel;

  /// No description provided for @darkModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkModeLabel;

  /// No description provided for @privacyPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyLabel;

  /// No description provided for @exportMyDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get exportMyDataLabel;

  /// No description provided for @deleteAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountLabel;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your name, email, date of birth, and body measurements will be permanently removed. Health logs are retained in anonymised form as required by law. This cannot be undone.'**
  String get deleteAccountConfirmBody;

  /// No description provided for @deleteAccountConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Yes, delete my account'**
  String get deleteAccountConfirmButton;

  /// No description provided for @deleteAccountConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get deleteAccountConfirmCancel;

  /// No description provided for @deleteAccountSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get deleteAccountSuccessMessage;

  /// No description provided for @signOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutLabel;

  /// No description provided for @accountSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get accountSectionLabel;

  /// No description provided for @preferencesSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferencesSectionLabel;

  /// No description provided for @privacyAndDataSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & DATA'**
  String get privacyAndDataSectionLabel;

  /// No description provided for @noEmailAvailable.
  ///
  /// In en, this message translates to:
  /// **'No email available'**
  String get noEmailAvailable;

  /// No description provided for @localeEnglishGlobal.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeEnglishGlobal;

  /// No description provided for @localeEnglishUk.
  ///
  /// In en, this message translates to:
  /// **'English (UK)'**
  String get localeEnglishUk;

  /// No description provided for @localeEnglishUs.
  ///
  /// In en, this message translates to:
  /// **'English (US)'**
  String get localeEnglishUs;

  /// No description provided for @localeEnglishCanada.
  ///
  /// In en, this message translates to:
  /// **'English (Canada)'**
  String get localeEnglishCanada;

  /// No description provided for @localeEnglishAustralia.
  ///
  /// In en, this message translates to:
  /// **'English (Australia)'**
  String get localeEnglishAustralia;

  /// No description provided for @localeSpanishGlobal.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get localeSpanishGlobal;

  /// No description provided for @localeSpanishSpain.
  ///
  /// In en, this message translates to:
  /// **'Spanish (Spain)'**
  String get localeSpanishSpain;

  /// No description provided for @localeSpanishLatam.
  ///
  /// In en, this message translates to:
  /// **'Spanish (Latin America)'**
  String get localeSpanishLatam;

  /// No description provided for @localeFrenchGlobal.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get localeFrenchGlobal;

  /// No description provided for @localeFrenchFrance.
  ///
  /// In en, this message translates to:
  /// **'French (France)'**
  String get localeFrenchFrance;

  /// No description provided for @localeFrenchCanada.
  ///
  /// In en, this message translates to:
  /// **'French (Canada)'**
  String get localeFrenchCanada;

  /// No description provided for @localeGermanGlobal.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get localeGermanGlobal;

  /// No description provided for @localeGermanGermany.
  ///
  /// In en, this message translates to:
  /// **'German (Germany)'**
  String get localeGermanGermany;

  /// No description provided for @localeGermanAustria.
  ///
  /// In en, this message translates to:
  /// **'German (Austria)'**
  String get localeGermanAustria;

  /// No description provided for @localeGermanSwitzerland.
  ///
  /// In en, this message translates to:
  /// **'German (Switzerland)'**
  String get localeGermanSwitzerland;

  /// No description provided for @localePortugueseGlobal.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get localePortugueseGlobal;

  /// No description provided for @localePortugueseBrazil.
  ///
  /// In en, this message translates to:
  /// **'Portuguese (Brazil)'**
  String get localePortugueseBrazil;

  /// No description provided for @localePortuguesePortugal.
  ///
  /// In en, this message translates to:
  /// **'Portuguese (Portugal)'**
  String get localePortuguesePortugal;

  /// No description provided for @acceptLabel.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptLabel;

  /// No description provided for @sendLabel.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendLabel;

  /// No description provided for @bloomTitle.
  ///
  /// In en, this message translates to:
  /// **'Vyla AI'**
  String get bloomTitle;

  /// No description provided for @bloomDataUsageNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Data usage notice'**
  String get bloomDataUsageNoticeTitle;

  /// No description provided for @bloomConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Vyla AI'**
  String get bloomConsentTitle;

  /// No description provided for @bloomDataUsageNoticeBody.
  ///
  /// In en, this message translates to:
  /// **'Vyla AI uses your cycle data to answer questions. Data is processed on Vyla\'s servers only.'**
  String get bloomDataUsageNoticeBody;

  /// No description provided for @bloomConsentBody.
  ///
  /// In en, this message translates to:
  /// **'Allow Vyla AI chat to use your information to answer your health needs.'**
  String get bloomConsentBody;

  /// No description provided for @bloomSuggestedQuestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'SUGGESTED QUESTIONS'**
  String get bloomSuggestedQuestionsTitle;

  /// No description provided for @bloomSuggestionCycleLong.
  ///
  /// In en, this message translates to:
  /// **'Why was my last cycle long?'**
  String get bloomSuggestionCycleLong;

  /// No description provided for @bloomSuggestionLhTesting.
  ///
  /// In en, this message translates to:
  /// **'When should I start LH testing?'**
  String get bloomSuggestionLhTesting;

  /// No description provided for @bloomSuggestionEggWhiteMucus.
  ///
  /// In en, this message translates to:
  /// **'What does egg-white mucus mean?'**
  String get bloomSuggestionEggWhiteMucus;

  /// No description provided for @bloomConversationHelper.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation and Vyla AI will keep the same thread for follow-up questions.'**
  String get bloomConversationHelper;

  /// No description provided for @bloomUsedDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Vyla is a prediction application not a medical device'**
  String get bloomUsedDataLabel;

  /// No description provided for @bloomSavedToLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved to your logs'**
  String get bloomSavedToLogsTitle;

  /// No description provided for @bloomThinkingLabel.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get bloomThinkingLabel;

  /// No description provided for @bloomMedicalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Not medical advice — consult your doctor for clinical questions'**
  String get bloomMedicalDisclaimer;

  /// No description provided for @bloomAskQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a question...'**
  String get bloomAskQuestionHint;

  /// No description provided for @bloomConsentRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Accept consent to use Vyla AI'**
  String get bloomConsentRequiredHint;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Cycle Stats'**
  String get insightsTitle;

  /// No description provided for @insightsBasedOnTrackedCycles.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} tracked cycles'**
  String insightsBasedOnTrackedCycles(int count);

  /// No description provided for @insightsBasedOnTrackedCycleData.
  ///
  /// In en, this message translates to:
  /// **'Based on your tracked cycle data'**
  String get insightsBasedOnTrackedCycleData;

  /// No description provided for @insightsLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading your cycle stats...'**
  String get insightsLoadingMessage;

  /// No description provided for @insightsAverageCycleLabel.
  ///
  /// In en, this message translates to:
  /// **'AVG CYCLE'**
  String get insightsAverageCycleLabel;

  /// No description provided for @insightsPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'PERIOD'**
  String get insightsPeriodLabel;

  /// No description provided for @insightsTrackedLabel.
  ///
  /// In en, this message translates to:
  /// **'TRACKED'**
  String get insightsTrackedLabel;

  /// No description provided for @insightsRegularityLabel.
  ///
  /// In en, this message translates to:
  /// **'REGULARITY'**
  String get insightsRegularityLabel;

  /// No description provided for @insightsDaysSuffix.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get insightsDaysSuffix;

  /// No description provided for @insightsCyclesSuffix.
  ///
  /// In en, this message translates to:
  /// **'cycles'**
  String get insightsCyclesSuffix;

  /// No description provided for @insightsPercentSuffix.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get insightsPercentSuffix;

  /// No description provided for @insightsTemperatureTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Temperature Trend'**
  String get insightsTemperatureTrendTitle;

  /// No description provided for @insightsHrvTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate Variability'**
  String get insightsHrvTitle;

  /// No description provided for @insightsSymptomPatternsTitle.
  ///
  /// In en, this message translates to:
  /// **'Symptom Patterns'**
  String get insightsSymptomPatternsTitle;

  /// No description provided for @insightsMostCommonLabel.
  ///
  /// In en, this message translates to:
  /// **'Most Common'**
  String get insightsMostCommonLabel;

  /// No description provided for @insightsEnergyDipsLabel.
  ///
  /// In en, this message translates to:
  /// **'Energy Dips'**
  String get insightsEnergyDipsLabel;

  /// No description provided for @insightsNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get insightsNoDataYet;

  /// No description provided for @insightsNoTemperatureTrendYet.
  ///
  /// In en, this message translates to:
  /// **'No temperature trend yet'**
  String get insightsNoTemperatureTrendYet;

  /// No description provided for @insightsNoHrvTrendYet.
  ///
  /// In en, this message translates to:
  /// **'No HRV trend yet'**
  String get insightsNoHrvTrendYet;

  /// No description provided for @deviceDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Device default'**
  String get deviceDefaultLabel;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account and preferences'**
  String get profileSubtitle;

  /// No description provided for @profileEditPersonalInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your personal information'**
  String get profileEditPersonalInfoSubtitle;

  /// No description provided for @profileCycleReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate and share your cycle report'**
  String get profileCycleReportSubtitle;

  /// No description provided for @profileConnectedDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your connected devices'**
  String get profileConnectedDevicesSubtitle;

  /// No description provided for @profileManageSubscriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View plan and billing details'**
  String get profileManageSubscriptionSubtitle;

  /// No description provided for @profileThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose theme and display'**
  String get profileThemeSubtitle;

  /// No description provided for @profilePrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your data and privacy'**
  String get profilePrivacySubtitle;

  /// No description provided for @profileTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read our terms and conditions'**
  String get profileTermsSubtitle;

  /// No description provided for @profileDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and data'**
  String get profileDeleteAccountSubtitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPasswordLabel;

  /// No description provided for @currentPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get currentPasswordHint;

  /// No description provided for @changePasswordNewHint.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get changePasswordNewHint;

  /// No description provided for @changePasswordConfirmNewLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get changePasswordConfirmNewLabel;

  /// No description provided for @changePasswordConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your new password'**
  String get changePasswordConfirmHint;

  /// No description provided for @changePasswordInfo.
  ///
  /// In en, this message translates to:
  /// **'Changing your password updates the sign-in password for this account immediately.'**
  String get changePasswordInfo;

  /// No description provided for @changePasswordFillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Fill in all password fields.'**
  String get changePasswordFillAllFields;

  /// No description provided for @changePasswordLengthError.
  ///
  /// In en, this message translates to:
  /// **'New password must be at least 8 characters.'**
  String get changePasswordLengthError;

  /// No description provided for @changePasswordUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to update password.'**
  String get changePasswordUpdateFailed;

  /// No description provided for @changePasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully.'**
  String get changePasswordUpdated;

  /// No description provided for @changePasswordHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your current password and choose a new one for this account.'**
  String get changePasswordHeroSubtitle;

  /// No description provided for @editProfileHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your details and manage your account'**
  String get editProfileHeaderSubtitle;

  /// No description provided for @editProfilePersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get editProfilePersonalInfo;

  /// No description provided for @editProfileAccountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account & Security'**
  String get editProfileAccountSecurity;

  /// No description provided for @editProfileEmailReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Email is managed from your sign-in account.'**
  String get editProfileEmailReadOnlyHint;

  /// No description provided for @editProfileNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your reminders and alerts.'**
  String get editProfileNotificationsSubtitle;

  /// No description provided for @editProfileSelectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get editProfileSelectDateOfBirth;

  /// No description provided for @editProfileSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your {field}'**
  String editProfileSheetSubtitle(String field);

  /// No description provided for @notSetLabel.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSetLabel;

  /// No description provided for @updateLabel.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateLabel;

  /// No description provided for @manageLabel.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manageLabel;

  /// No description provided for @healthDataLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load report settings.'**
  String get healthDataLoadErrorTitle;

  /// No description provided for @healthDataIncludeLhHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show LH surge detection history'**
  String get healthDataIncludeLhHistorySubtitle;

  /// No description provided for @healthDataIncludeTemperatureChartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show BBT chart and biphasic pattern'**
  String get healthDataIncludeTemperatureChartSubtitle;

  /// No description provided for @healthDataIncludeSymptomSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show tracked symptoms by phase'**
  String get healthDataIncludeSymptomSummarySubtitle;

  /// No description provided for @healthDataSecureLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Secure link copied'**
  String get healthDataSecureLinkCopied;

  /// No description provided for @healthDataReportSummaryCopied.
  ///
  /// In en, this message translates to:
  /// **'Report summary copied'**
  String get healthDataReportSummaryCopied;

  /// No description provided for @generatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generatingLabel;

  /// No description provided for @subscriptionLoadingPlans.
  ///
  /// In en, this message translates to:
  /// **'Loading subscription plans...'**
  String get subscriptionLoadingPlans;

  /// No description provided for @subscriptionPricingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Subscription pricing is not available for this country yet.'**
  String get subscriptionPricingUnavailable;

  /// No description provided for @subscriptionPaymentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payments are temporarily unavailable.'**
  String get subscriptionPaymentsUnavailable;

  /// No description provided for @subscriptionUnableToOpenCheckout.
  ///
  /// In en, this message translates to:
  /// **'Unable to open checkout.'**
  String get subscriptionUnableToOpenCheckout;

  /// No description provided for @sessionExpiredSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get sessionExpiredSignInAgain;

  /// No description provided for @subscriptionCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get subscriptionCancelTitle;

  /// No description provided for @subscriptionCancelPrompt.
  ///
  /// In en, this message translates to:
  /// **'This will stop renewal for your current Premium subscription. Your Premium access stays active until the current billing period ends.'**
  String get subscriptionCancelPrompt;

  /// No description provided for @subscriptionKeepPlan.
  ///
  /// In en, this message translates to:
  /// **'Keep plan'**
  String get subscriptionKeepPlan;

  /// No description provided for @subscriptionCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get subscriptionCancelAction;

  /// No description provided for @subscriptionCanceled.
  ///
  /// In en, this message translates to:
  /// **'Subscription canceled.'**
  String get subscriptionCanceled;

  /// No description provided for @subscriptionContinueFree.
  ///
  /// In en, this message translates to:
  /// **'Continue with Free'**
  String get subscriptionContinueFree;

  /// No description provided for @subscriptionCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get subscriptionCurrentPlan;

  /// No description provided for @subscriptionGetPremiumPlus.
  ///
  /// In en, this message translates to:
  /// **'Get Premium'**
  String get subscriptionGetPremiumPlus;

  /// No description provided for @subscriptionBestToStart.
  ///
  /// In en, this message translates to:
  /// **'BEST TO START'**
  String get subscriptionBestToStart;

  /// No description provided for @subscriptionYearlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get subscriptionYearlyLabel;

  /// No description provided for @subscriptionMonthlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get subscriptionMonthlyLabel;

  /// No description provided for @subscriptionYearLabelShort.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get subscriptionYearLabelShort;

  /// No description provided for @subscriptionMonthLabelShort.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get subscriptionMonthLabelShort;

  /// No description provided for @subscriptionSaveYearly.
  ///
  /// In en, this message translates to:
  /// **'Save yearly'**
  String get subscriptionSaveYearly;

  /// No description provided for @subscriptionSavePercent.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String subscriptionSavePercent(int percent);

  /// No description provided for @subscriptionTrustFooter.
  ///
  /// In en, this message translates to:
  /// **'Secure payments.\nCancel anytime.'**
  String get subscriptionTrustFooter;

  /// No description provided for @subscriptionManagementRenews.
  ///
  /// In en, this message translates to:
  /// **'Your {plan} plan renews at {amount} per {interval}.'**
  String subscriptionManagementRenews(
    String plan,
    String amount,
    String interval,
  );

  /// No description provided for @subscriptionManagementActive.
  ///
  /// In en, this message translates to:
  /// **'Your {plan} plan is active. You can upgrade from the plans above or cancel auto-renew here.'**
  String subscriptionManagementActive(String plan);

  /// No description provided for @subscriptionTrialEndingTitle.
  ///
  /// In en, this message translates to:
  /// **'Trial ending'**
  String get subscriptionTrialEndingTitle;

  /// No description provided for @subscriptionTrialEndingBody.
  ///
  /// In en, this message translates to:
  /// **'This route is ready for server-driven trial messaging and upgrade actions.'**
  String get subscriptionTrialEndingBody;

  /// No description provided for @subscriptionPaymentIssueTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment issue'**
  String get subscriptionPaymentIssueTitle;

  /// No description provided for @subscriptionPaymentIssueBody.
  ///
  /// In en, this message translates to:
  /// **'This route is the dedicated recovery point for failed renewals and payment retries.'**
  String get subscriptionPaymentIssueBody;

  /// No description provided for @subscriptionFinishingPayment.
  ///
  /// In en, this message translates to:
  /// **'Finishing payment...'**
  String get subscriptionFinishingPayment;

  /// No description provided for @subscriptionCheckoutCanceledTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout canceled'**
  String get subscriptionCheckoutCanceledTitle;

  /// No description provided for @subscriptionCheckoutCanceledBody.
  ///
  /// In en, this message translates to:
  /// **'Your checkout was canceled. You can pick another plan anytime.'**
  String get subscriptionCheckoutCanceledBody;

  /// No description provided for @subscriptionBackToPlans.
  ///
  /// In en, this message translates to:
  /// **'Back to plans'**
  String get subscriptionBackToPlans;

  /// No description provided for @paywallUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to continue'**
  String get paywallUpgradeTitle;

  /// No description provided for @paywallUpgradeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paywall routing is centralized so 402 responses map into a consistent upgrade flow instead of generic dialogs.'**
  String get paywallUpgradeSubtitle;

  /// No description provided for @paywallViewPlans.
  ///
  /// In en, this message translates to:
  /// **'View plans'**
  String get paywallViewPlans;

  /// No description provided for @paywallStressMonitoringRequiresPremium.
  ///
  /// In en, this message translates to:
  /// **'Stress monitoring requires Premium.'**
  String get paywallStressMonitoringRequiresPremium;

  /// No description provided for @paywallAiChatRequiresPremium.
  ///
  /// In en, this message translates to:
  /// **'Vyla AI chat requires Premium.'**
  String get paywallAiChatRequiresPremium;

  /// No description provided for @paywallOvulationShiftRequiresPremiumPlus.
  ///
  /// In en, this message translates to:
  /// **'Ovulation shift insights require Premium.'**
  String get paywallOvulationShiftRequiresPremiumPlus;

  /// No description provided for @paywallGenericUpgrade.
  ///
  /// In en, this message translates to:
  /// **'This feature requires an upgraded plan.'**
  String get paywallGenericUpgrade;

  /// No description provided for @inviteAndEarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite & earn'**
  String get inviteAndEarnTitle;

  /// No description provided for @signInToViewReferrals.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view referrals.'**
  String get signInToViewReferrals;

  /// No description provided for @referralCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied'**
  String get referralCodeCopied;

  /// No description provided for @scheduledPlanChangeCanceled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled plan change canceled.'**
  String get scheduledPlanChangeCanceled;

  /// No description provided for @subscriptionRenewalRestarted.
  ///
  /// In en, this message translates to:
  /// **'Subscription renewal restarted.'**
  String get subscriptionRenewalRestarted;

  /// No description provided for @backToHomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHomeLabel;

  /// No description provided for @choosePlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get choosePlanLabel;

  /// No description provided for @temperatureMethodOral.
  ///
  /// In en, this message translates to:
  /// **'Oral'**
  String get temperatureMethodOral;

  /// No description provided for @temperatureMethodVaginal.
  ///
  /// In en, this message translates to:
  /// **'Vaginal'**
  String get temperatureMethodVaginal;

  /// No description provided for @temperatureMethodWearable.
  ///
  /// In en, this message translates to:
  /// **'Wearable'**
  String get temperatureMethodWearable;

  /// No description provided for @temperatureMethodUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get temperatureMethodUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'de':
      {
        switch (locale.countryCode) {
          case 'AT':
            return AppLocalizationsDeAt();
          case 'CH':
            return AppLocalizationsDeCh();
          case 'DE':
            return AppLocalizationsDeDe();
        }
        break;
      }
    case 'en':
      {
        switch (locale.countryCode) {
          case 'AU':
            return AppLocalizationsEnAu();
          case 'CA':
            return AppLocalizationsEnCa();
          case 'GB':
            return AppLocalizationsEnGb();
          case 'US':
            return AppLocalizationsEnUs();
        }
        break;
      }
    case 'es':
      {
        switch (locale.countryCode) {
          case '419':
            return AppLocalizationsEs419();
          case 'ES':
            return AppLocalizationsEsEs();
        }
        break;
      }
    case 'fr':
      {
        switch (locale.countryCode) {
          case 'CA':
            return AppLocalizationsFrCa();
          case 'FR':
            return AppLocalizationsFrFr();
        }
        break;
      }
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
          case 'PT':
            return AppLocalizationsPtPt();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
