import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/subscription/domain/subscription_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.reason});

  final PaywallReason reason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.phora;
    final colors = tokens.colors;
    final dims = context.dims;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.paywallUpgradeTitle)),
      body: Padding(
        padding: EdgeInsets.all(dims.scaleWidth(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(dims.scaleWidth(24)),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: tokens.gradients.primary),
                borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
              ),
              child: Text(
                _messageFor(context, reason),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: dims.scaleText(24),
                ),
              ),
            ),
            SizedBox(height: dims.scaleSpace(12)),
            Text(
              context.l10n.paywallUpgradeSubtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.textSecondary,
                fontSize: dims.scaleText(16),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => context.go('/subscription'),
              child: Text(context.l10n.paywallViewPlans),
            ),
          ],
        ),
      ),
    );
  }

  String _messageFor(BuildContext context, PaywallReason value) {
    return switch (value) {
      PaywallReason.stressMonitoringPremium =>
        context.l10n.paywallStressMonitoringRequiresPremium,
      PaywallReason.aiChatPremium => context.l10n.paywallAiChatRequiresPremium,
      PaywallReason.ovulationShiftPremium =>
        context.l10n.paywallOvulationShiftRequiresPremiumPlus,
      PaywallReason.genericUpgrade => context.l10n.paywallGenericUpgrade,
    };
  }
}
