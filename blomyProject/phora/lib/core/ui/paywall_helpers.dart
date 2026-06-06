import 'package:phora/features/subscription/domain/subscription_models.dart';

sealed class PaywallReasonParser {
  static PaywallReason parse(String? raw) {
    return switch (raw) {
      'stress_monitoring_premium' => PaywallReason.stressMonitoringPremium,
      'ai_chat_premium' => PaywallReason.aiChatPremium,
      'ovulation_shift_premium_plus' ||
      'ovulation_shift_premium' => PaywallReason.ovulationShiftPremium,
      _ => PaywallReason.genericUpgrade,
    };
  }
}
