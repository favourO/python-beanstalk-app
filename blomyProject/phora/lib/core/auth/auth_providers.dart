import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/app/env.dart';
import 'package:phora/core/auth/token_store.dart';
import 'package:phora/core/preferences/app_preferences.dart';
import 'package:phora/features/auth/data/auth_repository.dart';
import 'package:phora/features/auth/domain/app_session.dart';
import 'package:phora/features/onboarding/data/onboarding_repository.dart';
import 'package:phora/features/onboarding/domain/onboarding_status.dart';
import 'package:phora/features/subscription/data/subscription_repository.dart';
import 'package:phora/features/subscription/domain/feature_access.dart';
import 'package:phora/features/subscription/domain/subscription_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

const _sessionRestoreTimeout = Duration(seconds: 8);
const _sessionRestoreOverallTimeout = Duration(seconds: 10);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
final appPreferencesProvider = Provider<AppPreferences>((ref) {
  throw StateError('appPreferencesProvider must be initialized via bootstrap');
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  final isApplePlatform =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  return GoogleSignIn(
    scopes: const ['email', 'profile'],
    clientId:
        isApplePlatform && kGoogleClientId.isNotEmpty ? kGoogleClientId : null,
    serverClientId:
        kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
  );
});

final sessionCleanupProvider = Provider<SessionCleanup>((ref) {
  return SessionCleanup(
    tokenStore: ref.watch(tokenStoreProvider),
    preferences: ref.watch(appPreferencesProvider),
    googleSignIn: ref.watch(googleSignInProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(apiClientProvider));
});

final lastPaywallFailureProvider = StateProvider<FeatureGateFailure?>(
  (ref) => null,
);

final paymentSuccessGraceUntilProvider = StateProvider<DateTime?>(
  (ref) => null,
);

final pendingEmailVerificationProvider = NotifierProvider<
  PendingEmailVerificationController,
  PendingEmailVerificationState
>(PendingEmailVerificationController.new);

class PendingEmailVerificationController
    extends Notifier<PendingEmailVerificationState> {
  @override
  PendingEmailVerificationState build() =>
      const PendingEmailVerificationState();

  void setPending({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String country,
    String? birthDate,
    required String accountType,
    String signupMethod = 'email',
  }) {
    state = PendingEmailVerificationState(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      country: country,
      birthDate: birthDate ?? '',
      accountType: accountType,
      signupMethod: signupMethod,
    );
  }

  void setPendingLogin({required String email, required String password}) {
    state = PendingEmailVerificationState(email: email, password: password);
  }

  void clear() {
    state = const PendingEmailVerificationState();
  }
}

class PendingEmailVerificationState {
  const PendingEmailVerificationState({
    this.email = '',
    this.password = '',
    this.firstName = '',
    this.lastName = '',
    this.country = '',
    this.birthDate = '',
    this.accountType = 'email',
    this.signupMethod = 'email',
  });

  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String country;
  final String birthDate;
  final String accountType;
  final String signupMethod;
}

final emailSignUpControllerProvider =
    AsyncNotifierProvider.autoDispose<EmailSignUpController, void>(
      EmailSignUpController.new,
    );

class EmailSignUpController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String country,
    DateTime? birthDate,
    String accountType = 'email',
    String signupMethod = 'email',
    required bool termsAccepted,
    required bool privacyPolicyAccepted,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            country: country,
            birthDate: birthDate,
            accountType: accountType,
            signupMethod: signupMethod,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted,
          );
      ref
          .read(pendingEmailVerificationProvider.notifier)
          .setPending(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            country: country,
            birthDate: birthDate?.toIso8601String(),
            accountType: accountType,
            signupMethod: signupMethod,
          );
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final resendEmailVerificationControllerProvider =
    AsyncNotifierProvider.autoDispose<ResendEmailVerificationController, void>(
      ResendEmailVerificationController.new,
    );

class ResendEmailVerificationController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> resend({required String email}) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .resendVerificationOtp(email: email);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final verifyEmailControllerProvider =
    AsyncNotifierProvider.autoDispose<VerifyEmailController, void>(
      VerifyEmailController.new,
    );

class VerifyEmailController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> verify({required String email, required String otpCode}) async {
    state = const AsyncLoading();
    try {
      final pending = ref.read(pendingEmailVerificationProvider);
      var session = await ref
          .read(authRepositoryProvider)
          .verifyEmail(email: email, otpCode: otpCode);
      if (session == null) {
        final signInEmail = pending.email.isNotEmpty ? pending.email : email;
        if (signInEmail.isEmpty || pending.password.isEmpty) {
          throw 'Email verified, but automatic sign-in could not continue. Please sign in manually.';
        }
        session = await ref
            .read(authRepositoryProvider)
            .signInWithEmail(email: signInEmail, password: pending.password);
      }
      ref.read(authSessionProvider.notifier).setSession(session);
      ref.invalidate(onboardingStatusProvider);
      ref.invalidate(currentSubscriptionProvider);
      ref.read(pendingEmailVerificationProvider.notifier).clear();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final emailLoginControllerProvider =
    AsyncNotifierProvider.autoDispose<EmailLoginController, void>(
      EmailLoginController.new,
    );

final googleAuthControllerProvider =
    AsyncNotifierProvider.autoDispose<GoogleAuthController, void>(
      GoogleAuthController.new,
    );

final appleAuthControllerProvider =
    AsyncNotifierProvider.autoDispose<AppleAuthController, void>(
      AppleAuthController.new,
    );

class EmailLoginController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password);
      ref.read(authSessionProvider.notifier).setSession(session);
      ref.invalidate(onboardingStatusProvider);
      ref.invalidate(currentSubscriptionProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

class GoogleAuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn() async {
    state = const AsyncLoading();
    try {
      final idToken = await _authenticate(promptForAccountSelection: true);
      final session = await ref
          .read(authRepositoryProvider)
          .googleLogin(idToken: idToken);
      ref.read(authSessionProvider.notifier).setSession(session);
      ref.invalidate(onboardingStatusProvider);
      ref.invalidate(currentSubscriptionProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      await _clearGoogleSession();
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> signUp({
    required String firstName,
    required String lastName,
    required String country,
    required String accountType,
    DateTime? birthDate,
    required bool termsAccepted,
    required bool privacyPolicyAccepted,
  }) async {
    state = const AsyncLoading();
    try {
      final idToken = await _authenticate(promptForAccountSelection: true);
      final session = await ref
          .read(authRepositoryProvider)
          .googleSignup(
            idToken: idToken,
            firstName: firstName,
            lastName: lastName,
            country: country,
            accountType: accountType,
            birthDate: birthDate,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted,
            registrationPlatform: _googlePlatformLabel(),
          );
      ref.read(authSessionProvider.notifier).setSession(session);
      ref.invalidate(onboardingStatusProvider);
      ref.invalidate(currentSubscriptionProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      if (_isExistingSignupConflict(error)) {
        await _clearGoogleSession();
      }
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<String> _authenticate({bool promptForAccountSelection = false}) async {
    final googleSignIn = ref.read(googleSignInProvider);
    if (kGoogleServerClientId.isEmpty) {
      throw 'Google sign-in is not configured. Missing GOOGLE_SERVER_CLIENT_ID.';
    }
    if ((defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) &&
        kGoogleClientId.isEmpty) {
      throw 'Google sign-in is not configured. Missing GOOGLE_CLIENT_ID for Apple platforms.';
    }

    if (promptForAccountSelection) {
      await _clearGoogleSession();
    }

    final GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signIn();
    } on PlatformException catch (error) {
      throw _mapGooglePlatformException(error);
    }
    if (account == null) {
      throw 'Google sign-in was cancelled.';
    }
    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw 'Google did not return an ID token.';
    }
    return idToken;
  }

  String _googlePlatformLabel() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      _ => 'flutter',
    };
  }

  Future<void> _clearGoogleSession() async {
    final googleSignIn = ref.read(googleSignInProvider);
    try {
      await googleSignIn.disconnect();
    } catch (_) {}
    try {
      await googleSignIn.signOut();
    } catch (_) {}
  }

  bool _isExistingSignupConflict(Object error) {
    if (error is ApiFailure) {
      final message = error.message.toLowerCase();
      return message.contains('email already registered') ||
          message.contains('account with this email already exists');
    }
    final message = error.toString().toLowerCase();
    return message.contains('email already registered') ||
        message.contains('account with this email already exists') ||
        message.contains('409');
  }

  Object _mapGooglePlatformException(PlatformException error) {
    final details =
        [
          error.code,
          error.message,
          error.details,
        ].whereType<Object>().join(' ').toLowerCase();
    if (defaultTargetPlatform == TargetPlatform.android &&
        error.code == 'sign_in_failed' &&
        details.contains('api')) {
      return StateError(
        'Google sign-in is not configured for this Android app. Add an '
        'Android OAuth client in Firebase for package com.vyla.health with '
        'this debug SHA-1: '
        '26:06:FD:35:5C:A7:4B:F8:3B:3A:69:25:23:96:96:34:66:C0:28:95, '
        'then download the updated google-services.json.',
      );
    }
    return error;
  }
}

class AppleAuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn() async {
    state = const AsyncLoading();
    try {
      final idToken = await _authenticate();
      final session = await ref
          .read(authRepositoryProvider)
          .appleLogin(idToken: idToken, signupMethod: 'apple');
      ref.read(authSessionProvider.notifier).setSession(session);
      ref.invalidate(onboardingStatusProvider);
      ref.invalidate(currentSubscriptionProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(_mapAppleAuthError(error), stackTrace);
      return false;
    }
  }

  Future<bool> signUp({
    required String firstName,
    required String lastName,
    required String country,
    required String accountType,
    DateTime? birthDate,
    required bool termsAccepted,
    required bool privacyPolicyAccepted,
  }) async {
    state = const AsyncLoading();
    try {
      final idToken = await _authenticate();
      final session = await ref
          .read(authRepositoryProvider)
          .appleSignup(
            idToken: idToken,
            firstName: firstName,
            lastName: lastName,
            country: country,
            accountType: accountType,
            birthDate: birthDate,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted,
            registrationClient: 'flutter',
            registrationPlatform: _applePlatformLabel(),
          );
      ref.read(authSessionProvider.notifier).setSession(session);
      ref.invalidate(onboardingStatusProvider);
      ref.invalidate(currentSubscriptionProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(_mapAppleAuthError(error), stackTrace);
      return false;
    }
  }

  Future<String> _authenticate() async {
    if (!(defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS)) {
      throw 'Apple sign-in is only available on Apple platforms.';
    }
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw 'Apple did not return an identity token.';
    }
    return idToken;
  }

  String _applePlatformLabel() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      _ => 'ios',
    };
  }

  String _mapAppleAuthError(Object error) {
    if (error is SignInWithAppleAuthorizationException) {
      return switch (error.code) {
        AuthorizationErrorCode.canceled => 'Apple sign-in was cancelled.',
        AuthorizationErrorCode.notInteractive =>
          'Apple sign-in is not available right now. Please try again.',
        AuthorizationErrorCode.invalidResponse =>
          'Apple sign-in returned an invalid response. Please try again.',
        AuthorizationErrorCode.notHandled =>
          'Apple sign-in is not configured on this device yet.',
        AuthorizationErrorCode.failed =>
          'Apple sign-in failed. Make sure your device is signed in to Apple ID and try again.',
        AuthorizationErrorCode.unknown =>
          'Apple sign-in is unavailable. Make sure your device is signed in to Apple ID and try again.',
      };
    }
    if (error is SignInWithAppleCredentialsException) {
      return 'Apple sign-in is unavailable. Please check your Apple ID setup and try again.';
    }
    return error.toString();
  }
}

final forgotPasswordFlowProvider =
    NotifierProvider<ForgotPasswordFlowController, ForgotPasswordFlowState>(
      ForgotPasswordFlowController.new,
    );

class ForgotPasswordFlowController extends Notifier<ForgotPasswordFlowState> {
  @override
  ForgotPasswordFlowState build() => const ForgotPasswordFlowState();

  void setEmail(String email) {
    state = state.copyWith(email: email);
  }

  void setResetSessionToken(String resetSessionToken) {
    state = state.copyWith(otpCode: resetSessionToken);
  }

  void clear() {
    state = const ForgotPasswordFlowState();
  }
}

class ForgotPasswordFlowState {
  const ForgotPasswordFlowState({this.email = '', this.otpCode});

  final String email;
  final String? otpCode;

  ForgotPasswordFlowState copyWith({String? email, String? otpCode}) {
    return ForgotPasswordFlowState(
      email: email ?? this.email,
      otpCode: otpCode ?? this.otpCode,
    );
  }
}

final forgotPasswordRequestControllerProvider =
    AsyncNotifierProvider.autoDispose<ForgotPasswordRequestController, void>(
      ForgotPasswordRequestController.new,
    );

class ForgotPasswordRequestController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> sendCode(String email) async {
    state = const AsyncLoading();
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .requestPasswordResetCode(email: email);
      ref.read(forgotPasswordFlowProvider.notifier).setEmail(email);
      state = const AsyncData(null);
      return message;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }
}

final forgotPasswordVerifyControllerProvider =
    AsyncNotifierProvider.autoDispose<ForgotPasswordVerifyController, void>(
      ForgotPasswordVerifyController.new,
    );

class ForgotPasswordVerifyController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> verifyCode({required String email, required String otp}) async {
    state = const AsyncLoading();
    try {
      final resetSessionToken = await ref
          .read(authRepositoryProvider)
          .verifyPasswordResetCode(email: email, otp: otp);
      ref.read(forgotPasswordFlowProvider.notifier).setEmail(email);
      ref
          .read(forgotPasswordFlowProvider.notifier)
          .setResetSessionToken(resetSessionToken);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final resetPasswordControllerProvider =
    AsyncNotifierProvider.autoDispose<ResetPasswordController, void>(
      ResetPasswordController.new,
    );

class ResetPasswordController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(email: email, code: code, newPassword: newPassword);
      ref.read(forgotPasswordFlowProvider.notifier).clear();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final changePasswordControllerProvider =
    AsyncNotifierProvider.autoDispose<ChangePasswordController, String?>(
      ChangePasswordController.new,
    );

class ChangePasswordController extends AutoDisposeAsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      state = AsyncData(message);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final sendSetPasswordOtpControllerProvider =
    AsyncNotifierProvider.autoDispose<SendSetPasswordOtpController, void>(
      SendSetPasswordOtpController.new,
    );

class SendSetPasswordOtpController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> send() async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).sendSetPasswordOtp();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final setPasswordControllerProvider =
    AsyncNotifierProvider.autoDispose<SetPasswordController, String?>(
      SetPasswordController.new,
    );

class SetPasswordController extends AutoDisposeAsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<bool> setPassword({
    required String otpCode,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .setPasswordWithOtp(otpCode: otpCode, newPassword: newPassword);
      state = AsyncData(message);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionController, AppSession?>(
      AuthSessionController.new,
    );

class AuthSessionController extends AsyncNotifier<AppSession?> {
  @override
  Future<AppSession?> build() async {
    return _restoreSessionFromTokenStore(ref.read(tokenStoreProvider));
  }

  void setSession(AppSession? session) {
    state = AsyncData(session);
  }

  Future<void> clearSession() async {
    final authRepository = ref.read(authRepositoryProvider);

    await authRepository.signOut();
    await ref.read(sessionCleanupProvider).clearLocalSession();
    state = const AsyncData(null);
  }
}

Future<AppSession?> _restoreSessionFromTokenStore(TokenStore tokenStore) async {
  try {
    return await _doRestoreSession(
      tokenStore,
    ).timeout(_sessionRestoreOverallTimeout);
  } catch (_) {
    return null;
  }
}

Future<AppSession?> _doRestoreSession(TokenStore tokenStore) async {
  try {
    final accessToken = await tokenStore.readAccessToken().timeout(
      _sessionRestoreTimeout,
    );
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }
    final refreshToken = await tokenStore.readRefreshToken().timeout(
      _sessionRestoreTimeout,
    );
    final userId = await tokenStore.readUserId().timeout(
      _sessionRestoreTimeout,
    );
    final email = await tokenStore.readEmail().timeout(_sessionRestoreTimeout);

    return AppSession(
      userId: userId ?? 'persisted-user',
      mode: AuthMode.standard,
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
    );
  } catch (_) {
    return null;
  }
}

class SessionCleanup {
  SessionCleanup({
    required this.tokenStore,
    required this.preferences,
    required this.googleSignIn,
  });

  final TokenStore tokenStore;
  final AppPreferences preferences;
  final GoogleSignIn googleSignIn;

  Future<void> clearLocalSession() async {
    await tokenStore.clear();
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    await preferences.setPostSignupSetupPending(false);
    await preferences.setLastCycleLogPending(false);
    await preferences.setFreePlanSelected(false);
  }
}

final freePlanSelectionProvider =
    AsyncNotifierProvider<FreePlanSelectionController, bool>(
      FreePlanSelectionController.new,
    );

class FreePlanSelectionController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(appPreferencesProvider).getFreePlanSelected();
  }

  Future<void> selectFreePlan() async {
    await ref.read(appPreferencesProvider).setFreePlanSelected(true);
    state = const AsyncData(true);
  }

  Future<void> clear() async {
    await ref.read(appPreferencesProvider).setFreePlanSelected(false);
    state = const AsyncData(false);
  }
}

final onboardingSeenProvider =
    AsyncNotifierProvider<OnboardingSeenController, bool>(
      OnboardingSeenController.new,
    );

class OnboardingSeenController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(appPreferencesProvider).getHasSeenIntroFlow();
  }

  Future<void> markSeen() async {
    state = const AsyncData(true);
    await ref.read(appPreferencesProvider).setHasSeenIntroFlow(true);
  }
}

final onboardingStatusProvider =
    AsyncNotifierProvider<OnboardingStatusController, OnboardingStatus>(
      OnboardingStatusController.new,
    );

class OnboardingStatusController extends AsyncNotifier<OnboardingStatus> {
  @override
  Future<OnboardingStatus> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      return const OnboardingStatus.incomplete(currentStep: 'privacy_mode');
    }
    final backendProgress =
        session.onboardingProgress ?? await _fetchBackendProgress();
    if (session.onboardingCompleted == true ||
        backendProgress?.completed == true) {
      return const OnboardingStatus.complete();
    }
    if (session.showOnboardingFlow ||
        session.onboardingCompleted == false ||
        backendProgress != null) {
      final progress = (backendProgress ??
              OnboardingProgress(
                currentStep: session.onboardingCurrentStep ?? 1,
              ))
          .copyWith(
            currentStep:
                session.onboardingCurrentStep ??
                backendProgress?.currentStep ??
                1,
            completed:
                session.onboardingCompleted ??
                backendProgress?.completed ??
                false,
          );
      return OnboardingStatus.incompleteWithProgress(
        currentStep: 'post_signup_setup',
        progress: progress,
      );
    }
    final requiresPostSignupSetup =
        await ref.read(appPreferencesProvider).getPostSignupSetupPending();
    if (requiresPostSignupSetup) {
      return const OnboardingStatus.incomplete(
        currentStep: 'post_signup_setup',
      );
    }
    final requiresLastCycleLog =
        await ref.read(appPreferencesProvider).getLastCycleLogPending();
    if (requiresLastCycleLog) {
      return const OnboardingStatus.incomplete(currentStep: 'last_cycle_log');
    }
    return const OnboardingStatus.complete();
  }

  Future<void> requirePostSignupSetup() async {
    final preferences = ref.read(appPreferencesProvider);
    await preferences.setPostSignupSetupPending(true);
    state = const AsyncData(
      OnboardingStatus.incompleteWithProgress(
        currentStep: 'post_signup_setup',
        progress: OnboardingProgress(currentStep: 1),
      ),
    );
  }

  Future<void> completeCurrentFlow() async {
    final preferences = ref.read(appPreferencesProvider);
    await preferences.setPostSignupSetupPending(false);
    await preferences.setLastCycleLogPending(false);
    state = const AsyncData(OnboardingStatus.complete());
  }

  Future<void> requireLastCycleLog() async {
    final preferences = ref.read(appPreferencesProvider);
    await preferences.setPostSignupSetupPending(false);
    await preferences.setLastCycleLogPending(true);
    state = const AsyncData(
      OnboardingStatus.incomplete(currentStep: 'last_cycle_log'),
    );
  }

  Future<void> completeLastCycleLog() async {
    final preferences = ref.read(appPreferencesProvider);
    await preferences.setLastCycleLogPending(false);
    state = const AsyncData(OnboardingStatus.complete());
  }

  Future<void> reset() async {
    final preferences = ref.read(appPreferencesProvider);
    await preferences.setPostSignupSetupPending(false);
    await preferences.setLastCycleLogPending(false);
    state = const AsyncData(
      OnboardingStatus.incomplete(currentStep: 'privacy_mode'),
    );
  }

  Future<void> setBackendProgress(OnboardingProgress progress) async {
    final nextState =
        progress.completed
            ? const OnboardingStatus.complete()
            : OnboardingStatus.incompleteWithProgress(
              currentStep: 'post_signup_setup',
              progress: progress,
            );
    state = AsyncData(nextState);
  }

  Future<OnboardingProgress?> _fetchBackendProgress() async {
    try {
      return await ref
          .read(onboardingRepositoryProvider)
          .fetchProgress()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }
}

final currentSubscriptionProvider =
    AsyncNotifierProvider<CurrentSubscriptionController, SubscriptionState>(
      CurrentSubscriptionController.new,
    );

class CurrentSubscriptionController extends AsyncNotifier<SubscriptionState> {
  @override
  Future<SubscriptionState> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      return SubscriptionState.free();
    }
    try {
      return await ref
          .watch(subscriptionRepositoryProvider)
          .getCurrentSubscription()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return SubscriptionState.free();
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(subscriptionRepositoryProvider).getCurrentSubscription(),
    );
  }

  void setSubscriptionState(SubscriptionState nextState) {
    state = AsyncData(nextState);
  }

  Future<void> selectFreePlan() async {
    state = const AsyncData(
      SubscriptionState(
        tier: SubscriptionTier.free,
        status: SubscriptionStatus.active,
        isActive: true,
      ),
    );
  }
}

final featureAccessProvider = Provider<FeatureAccess>((ref) {
  final subscription =
      ref.watch(currentSubscriptionProvider).valueOrNull ??
      SubscriptionState.free();
  final onboarding = ref.watch(onboardingStatusProvider).valueOrNull;
  return FeatureAccessResolver.resolve(
    subscription: subscription,
    onboardingStatus: onboarding,
  );
});

final appBootstrapProvider =
    AsyncNotifierProvider<AppBootstrapController, AppBootstrapState>(
      AppBootstrapController.new,
    );

class AppBootstrapController extends AsyncNotifier<AppBootstrapState> {
  @override
  Future<AppBootstrapState> build() async {
    final session = await ref.watch(authSessionProvider.future);
    final onboarding = await ref.watch(onboardingStatusProvider.future);
    final subscription = await ref.watch(currentSubscriptionProvider.future);

    return AppBootstrapState(
      session: session,
      onboardingStatus: onboarding,
      subscriptionState: subscription,
    );
  }
}

class AppBootstrapState {
  const AppBootstrapState({
    required this.session,
    required this.onboardingStatus,
    required this.subscriptionState,
  });

  final AppSession? session;
  final OnboardingStatus onboardingStatus;
  final SubscriptionState subscriptionState;
}
