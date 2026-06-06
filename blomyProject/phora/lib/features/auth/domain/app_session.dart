import 'package:phora/features/onboarding/domain/onboarding_status.dart';

enum AuthMode { standard }

class AppSession {
  const AppSession({
    required this.userId,
    required this.mode,
    required this.accessToken,
    this.refreshToken,
    this.email,
    this.showOnboardingFlow = false,
    this.showSubscriptionScreen = false,
    this.subscriptionSelected = false,
    this.subscriptionTier,
    this.subscriptionInterval,
    this.subscriptionActive = false,
    this.onboardingCompleted,
    this.onboardingCurrentStep,
    this.onboardingProgress,
  });

  final String userId;
  final AuthMode mode;
  final String accessToken;
  final String? refreshToken;
  final String? email;
  final bool showOnboardingFlow;
  final bool showSubscriptionScreen;
  final bool subscriptionSelected;
  final String? subscriptionTier;
  final String? subscriptionInterval;
  final bool subscriptionActive;
  final bool? onboardingCompleted;
  final int? onboardingCurrentStep;
  final OnboardingProgress? onboardingProgress;

  bool get isAuthenticated => accessToken.isNotEmpty;

  AppSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? email,
  }) {
    return AppSession(
      userId: userId,
      mode: mode,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      email: email ?? this.email,
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
}
