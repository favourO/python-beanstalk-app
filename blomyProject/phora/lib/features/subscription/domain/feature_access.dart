import 'package:phora/features/onboarding/domain/onboarding_status.dart';
import 'package:phora/features/subscription/domain/subscription_models.dart';

class FeatureAccess {
  const FeatureAccess({
    required this.canUseStress,
    required this.canUseAiChat,
    required this.canUseFullPrediction,
    required this.canUseOvulationShift,
    required this.canUsePersonalLstm,
    required this.canUseMultipleWearables,
    required this.canUseClinicianReport,
    required this.aiMonthlyMessageLimit,
  });

  final bool canUseStress;
  final bool canUseAiChat;
  final bool canUseFullPrediction;
  final bool canUseOvulationShift;
  final bool canUsePersonalLstm;
  final bool canUseMultipleWearables;
  final bool canUseClinicianReport;
  final int? aiMonthlyMessageLimit;
}

abstract final class FeatureAccessResolver {
  static FeatureAccess resolve({
    required SubscriptionState subscription,
    required OnboardingStatus? onboardingStatus,
  }) {
    final onboardingComplete = onboardingStatus?.isComplete ?? false;
    final tier = subscription.tier;

    return FeatureAccess(
      canUseStress: onboardingComplete && tier != SubscriptionTier.free,
      canUseAiChat: onboardingComplete && tier != SubscriptionTier.free,
      canUseFullPrediction: onboardingComplete && tier != SubscriptionTier.free,
      canUseOvulationShift: tier != SubscriptionTier.free,
      canUsePersonalLstm: tier != SubscriptionTier.free,
      canUseMultipleWearables: tier != SubscriptionTier.free,
      canUseClinicianReport: false,
      aiMonthlyMessageLimit: switch (tier) {
        SubscriptionTier.free => 0,
        SubscriptionTier.premium => null,
      },
    );
  }
}
