import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/api_interceptors.dart';
import 'package:phora/core/auth/token_store.dart';
import 'package:phora/features/auth/domain/app_session.dart';
import 'package:phora/features/onboarding/domain/onboarding_status.dart';
import 'package:dio/dio.dart';

const _sessionRestoreTimeout = Duration(seconds: 8);

class AuthRepository {
  AuthRepository({required this.apiClient, required this.tokenStore});

  final ApiClient apiClient;
  final TokenStore tokenStore;

  bool get isPreviewBackend =>
      apiClient.dio.options.baseUrl.contains('api.phora.local');

  Future<AppSession?> restoreSession() async {
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
      final email = await tokenStore.readEmail().timeout(
        _sessionRestoreTimeout,
      );
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

  Future<void> signUp({
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
    String registrationClient = 'mobile',
    String registrationAppVersion = '1.0.0',
  }) async {
    try {
      await apiClient.postJson(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'account_type': accountType,
          ..._registrationPayload(
            signupMethod: signupMethod,
            firstName: firstName,
            lastName: lastName,
            country: country,
            birthDate: birthDate,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted,
            registrationClient: registrationClient,
            registrationAppVersion: registrationAppVersion,
          ),
        },
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> resendVerificationOtp({required String email}) async {
    try {
      await apiClient.postJson(
        '/auth/resend-otp',
        data: {'email': email, 'purpose': 'signup_verification'},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AppSession?> verifyEmail({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await apiClient.postJson(
        '/auth/verify',
        data: {'email': email, 'code': otpCode},
      );
      final session = _sessionFromResponse(
        response,
        fallbackUserId: email,
        defaultMode: AuthMode.standard,
      );
      if (session != null) {
        await _persistSession(session);
      }
      return session;
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AppSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final data = <String, dynamic>{'email': email, 'password': password};

      final response = await apiClient.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: data,
        options: Options(extra: const {kSkipUnauthorizedLogoutKey: true}),
      );
      final responseData = response.data ?? <String, dynamic>{};
      if (response.statusCode == 202 &&
          responseData['requires_verification'] == true) {
        final verificationEmail =
            (responseData['email'] as String?)?.trim() ?? email;
        final message = (responseData['message'] as String?)?.trim();
        throw PendingVerificationFailure(
          email: verificationEmail.isEmpty ? email : verificationEmail,
          message:
              message?.isNotEmpty == true
                  ? message!
                  : 'Email not verified. A new verification code has been sent.',
        );
      }
      final session = _sessionFromResponse(
        responseData,
        fallbackUserId: email,
        defaultMode: AuthMode.standard,
      );
      if (session == null) {
        throw const UnexpectedApiFailure();
      }
      await _persistSession(session);
      return session;
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AppSession> socialLogin({
    required String idToken,
    required String provider,
    String? signupMethod,
    String? firstName,
    String? lastName,
    String? country,
    DateTime? birthDate,
    bool? termsAccepted,
    bool? privacyPolicyAccepted,
  }) async {
    try {
      final normalizedProvider = switch (provider) {
        'google.com' => 'google',
        'apple.com' => 'apple',
        'facebook.com' => 'facebook',
        _ => provider,
      };
      final response = await apiClient.postJson(
        '/auth/social-login',
        data: {
          'id_token': idToken,
          'provider': normalizedProvider,
          ..._registrationPayload(
            signupMethod: signupMethod,
            firstName: firstName,
            lastName: lastName,
            country: country,
            birthDate: birthDate,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted,
          ),
        },
      );
      final session = _sessionFromResponse(
        response,
        fallbackUserId: normalizedProvider,
        defaultMode: AuthMode.standard,
      );
      if (session == null) {
        throw const UnexpectedApiFailure();
      }
      await _persistSession(session);
      return session;
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AppSession> googleLogin({
    required String idToken,
    String? signupMethod,
    String? firstName,
    String? lastName,
    String? country,
    DateTime? birthDate,
    bool? termsAccepted,
    bool? privacyPolicyAccepted,
    String? accountType,
    String? registrationPlatform,
  }) async {
    try {
      final response = await apiClient.postJson(
        '/auth/google-login',
        data: {
          'id_token': idToken,
          if (accountType != null && accountType.isNotEmpty)
            'account_type': accountType,
          ..._registrationPayload(
            signupMethod: signupMethod,
            firstName: firstName,
            lastName: lastName,
            country: country,
            birthDate: birthDate,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted,
            registrationClient: 'flutter',
            registrationPlatform: registrationPlatform,
          ),
        },
      );
      final session = _sessionFromResponse(
        response,
        fallbackUserId: 'google-user',
        defaultMode: AuthMode.standard,
      );
      if (session == null) {
        throw const UnexpectedApiFailure();
      }
      await _persistSession(session);
      return session;
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AppSession> googleSignup({
    required String idToken,
    required String firstName,
    required String lastName,
    required String country,
    required String accountType,
    DateTime? birthDate,
    required bool termsAccepted,
    required bool privacyPolicyAccepted,
    String signupMethod = 'google',
    String registrationClient = 'flutter',
    String? registrationPlatform,
  }) async {
    try {
      final response = await apiClient.postJson(
        '/auth/google-signup',
        data: {
          'id_token': idToken,
          'account_type': accountType,
          ..._registrationPayload(
            signupMethod: signupMethod,
            firstName: firstName,
            lastName: lastName,
            country: country,
            birthDate: birthDate,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted,
            registrationClient: registrationClient,
            registrationPlatform: registrationPlatform,
          ),
        },
      );
      final session = _sessionFromResponse(
        response,
        fallbackUserId: 'google-user',
        defaultMode: AuthMode.standard,
      );
      if (session == null) {
        throw const UnexpectedApiFailure();
      }
      await _persistSession(session);
      return session;
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AppSession> appleLogin({
    required String idToken,
    String? signupMethod,
    String? firstName,
    String? lastName,
    String? country,
    String? accountType,
    DateTime? birthDate,
    bool? termsAccepted,
    bool? privacyPolicyAccepted,
    String registrationClient = 'flutter',
    String? registrationPlatform,
  }) async {
    try {
      final response = await apiClient.postJson(
        '/auth/apple-login',
        data: {
          'id_token': idToken,
          if (accountType != null && accountType.isNotEmpty)
            'account_type': accountType,
          ..._registrationPayload(
            signupMethod: signupMethod,
            firstName: firstName,
            lastName: lastName,
            country: country,
            birthDate: birthDate,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted,
            registrationClient: registrationClient,
            registrationPlatform: registrationPlatform,
          ),
        },
      );
      final session = _sessionFromResponse(
        response,
        fallbackUserId: 'apple-user',
        defaultMode: AuthMode.standard,
      );
      if (session == null) {
        throw const UnexpectedApiFailure();
      }
      await _persistSession(session);
      return session;
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AppSession> appleSignup({
    required String idToken,
    required String firstName,
    required String lastName,
    required String country,
    required String accountType,
    DateTime? birthDate,
    required bool termsAccepted,
    required bool privacyPolicyAccepted,
    String signupMethod = 'apple',
    String registrationClient = 'flutter',
    String? registrationPlatform,
  }) async {
    try {
      final response = await apiClient.postJson(
        '/auth/apple-signup',
        data: {
          'id_token': idToken,
          'account_type': accountType,
          ..._registrationPayload(
            signupMethod: signupMethod,
            firstName: firstName,
            lastName: lastName,
            country: country,
            birthDate: birthDate,
            termsAccepted: termsAccepted,
            privacyPolicyAccepted: privacyPolicyAccepted,
            registrationClient: registrationClient,
            registrationPlatform: registrationPlatform,
          ),
        },
      );
      final session = _sessionFromResponse(
        response,
        fallbackUserId: 'apple-user',
        defaultMode: AuthMode.standard,
      );
      if (session == null) {
        throw const UnexpectedApiFailure();
      }
      await _persistSession(session);
      return session;
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<String> requestPasswordResetCode({required String email}) async {
    final response = await _postAuth(
      '/auth/forgot-password',
      data: {'email': email},
    );
    final payload = _responsePayload(response);
    return _firstString(payload, const [
          ['message'],
          ['detail'],
        ]) ??
        _firstString(response, const [
          ['message'],
          ['detail'],
        ]) ??
        'If we find a matching account, we’ll send reset instructions.';
  }

  Future<String> verifyPasswordResetCode({
    required String email,
    required String otp,
  }) async {
    return otp;
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _postAuth(
      '/auth/reset-password',
      data: {'email': email, 'code': code, 'new_password': newPassword},
    );
  }

  Future<void> sendSetPasswordOtp() async {
    try {
      await dio.post(_versionedApiUrl('/auth/send-set-password-otp'));
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<String> setPasswordWithOtp({
    required String otpCode,
    required String newPassword,
  }) async {
    final response = await _postAuth(
      '/auth/set-password',
      data: {'otp_code': otpCode, 'new_password': newPassword},
    );
    final payload = _responsePayload(response);
    return _firstString(payload, const [
          ['message'],
          ['detail'],
        ]) ??
        _firstString(response, const [
          ['message'],
          ['detail'],
        ]) ??
        'Password set successfully.';
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _postAuth(
      '/auth/change-password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
    final payload = _responsePayload(response);
    return _firstString(payload, const [
          ['message'],
          ['detail'],
        ]) ??
        _firstString(response, const [
          ['message'],
          ['detail'],
        ]) ??
        'Password updated successfully.';
  }

  Future<void> saveHealthConditions({required List<String> conditions}) async {
    try {
      await dio.post(
        _versionedApiUrl('/api/v1/onboarding/health-conditions'),
        data: {'conditions': conditions},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> savePrivacyPreferences({
    required bool researchDataSharing,
    required bool healthAnalytics,
    required bool personalizedRecommendations,
    required bool productMessagingOptimization,
  }) async {
    try {
      await dio.post(
        _versionedApiUrl('/api/v1/onboarding/privacy-preferences'),
        data: {
          'research_data_sharing': researchDataSharing,
          'health_analytics': healthAnalytics,
          'personalized_recommendations': personalizedRecommendations,
          'product_messaging_optimization': productMessagingOptimization,
        },
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> signOut() async {
    try {
      await dio.post(_versionedApiUrl('/api/v1/auth/signout'));
    } on DioException catch (_) {
      // Local sign-out should still succeed even if remote revocation fails.
    } finally {
      await tokenStore.clear();
    }
  }

  Future<void> requestDeleteAccountOtp() async {
    try {
      await dio.post(_versionedApiUrl('/api/v1/user/account/delete-otp'));
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> deleteAccount({required String otpCode}) async {
    try {
      await dio.delete(
        _versionedApiUrl('/api/v1/user/account'),
        data: {'otp_code': otpCode},
      );
      await tokenStore.clear();
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<Map<String, dynamic>> _postAuth(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      return await apiClient.postJson(path, data: data);
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> _persistSession(AppSession session) async {
    await tokenStore.writeAccessToken(session.accessToken);
    if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      await tokenStore.writeRefreshToken(session.refreshToken!);
    }
    await tokenStore.writeUserId(session.userId);
    await tokenStore.writeAuthMode(session.mode.name);
    if (session.email != null && session.email!.isNotEmpty) {
      await tokenStore.writeEmail(session.email!);
    }
  }

  Dio get dio => apiClient.dio;

  String _versionedApiUrl(String path) {
    final baseUrl = dio.options.baseUrl;
    final match = RegExp(r'^(https?://[^/]+)').firstMatch(baseUrl);
    final origin = match?.group(1);
    if (origin == null) {
      return path;
    }
    return '$origin$path';
  }

  Map<String, dynamic> _registrationPayload({
    String? signupMethod,
    String? firstName,
    String? lastName,
    String? country,
    DateTime? birthDate,
    bool? termsAccepted,
    bool? privacyPolicyAccepted,
    String? registrationClient,
    String? registrationAppVersion,
    String? registrationPlatform,
  }) {
    final hasConsent = termsAccepted != null && privacyPolicyAccepted != null;
    final hasRegistrationContext =
        registrationClient != null &&
        (registrationAppVersion != null || registrationPlatform != null);
    return {
      if (signupMethod != null) 'signup_method': signupMethod,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (country != null) 'country': country,
      if (birthDate != null)
        'birth_date':
            '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
      if (hasConsent)
        'consents': {
          'terms_accepted': termsAccepted,
          'privacy_policy_accepted': privacyPolicyAccepted,
        },
      if (hasRegistrationContext)
        'registration_context': {
          'client': registrationClient,
          if (registrationAppVersion != null)
            'app_version': registrationAppVersion,
          if (registrationPlatform != null) 'platform': registrationPlatform,
        },
    };
  }

  AppSession? _sessionFromResponse(
    Map<String, dynamic> response, {
    required String fallbackUserId,
    required AuthMode defaultMode,
  }) {
    final payload = _responsePayload(response);
    final accessToken =
        _firstString(payload, const [
          ['access_token'],
          ['accessToken'],
          ['token'],
          ['jwt'],
          ['data', 'access_token'],
        ]) ??
        _firstString(response, const [
          ['access_token'],
          ['accessToken'],
          ['token'],
          ['jwt'],
        ]);

    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final refreshToken =
        _firstString(payload, const [
          ['refresh_token'],
          ['refreshToken'],
          ['data', 'refresh_token'],
        ]) ??
        _firstString(response, const [
          ['refresh_token'],
          ['refreshToken'],
        ]);

    final userId =
        _firstString(payload, const [
          ['user', 'id'],
          ['user', 'user_id'],
          ['user_id'],
          ['id'],
          ['sub'],
        ]) ??
        fallbackUserId;

    final email =
        _firstString(payload, const [
          ['user', 'email'],
          ['email'],
          ['data', 'user', 'email'],
        ]) ??
        _firstString(response, const [
          ['user', 'email'],
          ['email'],
        ]) ??
        (fallbackUserId.contains('@') ? fallbackUserId : null);

    final showOnboardingFlow =
        _firstBool(payload, const [
          ['show_onboarding_flow'],
          ['showOnboardingFlow'],
        ]) ??
        _firstBool(response, const [
          ['show_onboarding_flow'],
          ['showOnboardingFlow'],
        ]) ??
        false;
    final showSubscriptionScreen =
        _firstBool(payload, const [
          ['show_subscription_screen'],
          ['showSubscriptionScreen'],
          ['show_premium_screen'],
          ['showPremiumScreen'],
        ]) ??
        _firstBool(response, const [
          ['show_subscription_screen'],
          ['showSubscriptionScreen'],
          ['show_premium_screen'],
          ['showPremiumScreen'],
        ]) ??
        false;
    final subscriptionSelected =
        _firstBool(payload, const [
          ['subscription_selected'],
          ['subscriptionSelected'],
        ]) ??
        _firstBool(response, const [
          ['subscription_selected'],
          ['subscriptionSelected'],
        ]) ??
        false;
    final subscriptionTier =
        _firstString(payload, const [
          ['subscription_tier'],
          ['subscriptionTier'],
        ]) ??
        _firstString(response, const [
          ['subscription_tier'],
          ['subscriptionTier'],
        ]);
    final subscriptionInterval =
        _firstString(payload, const [
          ['subscription_interval'],
          ['subscriptionInterval'],
        ]) ??
        _firstString(response, const [
          ['subscription_interval'],
          ['subscriptionInterval'],
        ]);
    final subscriptionActive =
        _firstBool(payload, const [
          ['subscription_active'],
          ['subscriptionActive'],
        ]) ??
        _firstBool(response, const [
          ['subscription_active'],
          ['subscriptionActive'],
        ]) ??
        false;
    final onboardingCompleted =
        _firstBool(payload, const [
          ['onboarding_completed'],
          ['onboardingCompleted'],
        ]) ??
        _firstBool(response, const [
          ['onboarding_completed'],
          ['onboardingCompleted'],
        ]);
    final onboardingCurrentStep =
        _firstInt(payload, const [
          ['onboarding_current_step'],
          ['onboardingCurrentStep'],
        ]) ??
        _firstInt(response, const [
          ['onboarding_current_step'],
          ['onboardingCurrentStep'],
        ]);
    final onboardingProgressPayload =
        _firstMap(payload, const [
          ['onboarding_progress'],
          ['onboardingProgress'],
        ]) ??
        _firstMap(response, const [
          ['onboarding_progress'],
          ['onboardingProgress'],
        ]);
    final onboardingProgress =
        onboardingProgressPayload == null
            ? (onboardingCurrentStep == null && onboardingCompleted != false
                ? null
                : OnboardingProgress(
                  currentStep: onboardingCurrentStep,
                  completed: onboardingCompleted ?? false,
                ))
            : OnboardingProgress.fromJson({
              ...onboardingProgressPayload,
              if (!onboardingProgressPayload.containsKey('current_step') &&
                  onboardingCurrentStep != null)
                'current_step': onboardingCurrentStep,
              if (!onboardingProgressPayload.containsKey('completed') &&
                  onboardingCompleted != null)
                'completed': onboardingCompleted,
            });

    return AppSession(
      userId: userId,
      mode: defaultMode,
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
      showOnboardingFlow: showOnboardingFlow,
      showSubscriptionScreen: showSubscriptionScreen,
      subscriptionSelected: subscriptionSelected,
      subscriptionTier: subscriptionTier,
      subscriptionInterval: subscriptionInterval,
      subscriptionActive: subscriptionActive,
      onboardingCompleted: onboardingCompleted,
      onboardingCurrentStep: onboardingCurrentStep,
      onboardingProgress: onboardingProgress,
    );
  }

  Map<String, dynamic> _responsePayload(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return response;
  }

  String? _firstString(Map<String, dynamic> source, List<List<String>> paths) {
    for (final path in paths) {
      dynamic current = source;
      for (final key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      final parsed = _stringValue(current);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  int? _firstInt(Map<String, dynamic> source, List<List<String>> paths) {
    for (final path in paths) {
      dynamic current = source;
      for (final key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      if (current is int) {
        return current;
      }
      if (current is num) {
        return current.toInt();
      }
      if (current is String) {
        final parsed = int.tryParse(current);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _firstMap(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      dynamic current = source;
      for (final key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      if (current is Map<String, dynamic>) {
        return current;
      }
      if (current is Map) {
        return Map<String, dynamic>.from(current);
      }
    }
    return null;
  }

  bool? _firstBool(Map<String, dynamic> source, List<List<String>> paths) {
    for (final path in paths) {
      dynamic current = source;
      for (final key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      if (current is bool) {
        return current;
      }
    }
    return null;
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }
}
