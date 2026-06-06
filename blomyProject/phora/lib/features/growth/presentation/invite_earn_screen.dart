import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/growth/domain/growth_models.dart';
import 'package:phora/features/growth/growth_providers.dart';
import 'package:phora/features/growth/services/growth_analytics_service.dart';
import 'package:share_plus/share_plus.dart';

class InviteEarnScreen extends ConsumerStatefulWidget {
  const InviteEarnScreen({super.key});

  @override
  ConsumerState<InviteEarnScreen> createState() => _InviteEarnScreenState();
}

class _InviteEarnScreenState extends ConsumerState<InviteEarnScreen> {
  final _claimCodeController = TextEditingController();
  bool _sharing = false;
  bool _claiming = false;

  @override
  void dispose() {
    _claimCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final referralAsync = ref.watch(referralStatusProvider);
    final dims = context.dims;
    final colors = context.phora.colors;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.inviteAndEarnTitle)),
      body: referralAsync.when(
        data: (status) {
          if (status == null) {
            return Center(child: Text(context.l10n.signInToViewReferrals));
          }
          final progress =
              status.rewardProgressTarget == 0
                  ? 0.0
                  : (status.qualifiedInvitesCount %
                          status.rewardProgressTarget) /
                      status.rewardProgressTarget;
          return ListView(
            padding: EdgeInsets.all(dims.scaleSpace(20)),
            children: [
              Container(
                padding: EdgeInsets.all(dims.scaleSpace(20)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB783E8), Color(0xFFF0A5C8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock 30 days of premium for every 5 qualified invites',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(14)),
                    Text(
                      'Referral code',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(6)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            status.referralCode,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            final copiedMsg = context.l10n.referralCodeCopied;
                            await Clipboard.setData(
                              ClipboardData(text: status.referralCode),
                            );
                            if (!mounted) return;
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text(copiedMsg)),
                            );
                          },
                          color: Colors.white,
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    SizedBox(height: dims.scaleSpace(14)),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    SizedBox(height: dims.scaleSpace(10)),
                    Text(
                      '${status.qualifiedInvitesCount} qualified invites • ${status.invitesUntilNextReward} to next reward',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(height: dims.scaleSpace(20)),
              _StatCard(
                title: 'Premium earned',
                value: '${status.totalPremiumDaysEarned} days',
                subtitle:
                    '${status.rewardedMilestones} reward milestone(s) granted',
              ),
              SizedBox(height: dims.scaleSpace(12)),
              _StatCard(
                title: 'Invite link',
                value: status.inviteLink,
                subtitle: 'Deep-link attribution is attached automatically.',
              ),
              SizedBox(height: dims.scaleSpace(16)),
              FilledButton.icon(
                onPressed: _sharing ? null : () => _shareInvite(status),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(_sharing ? 'Preparing…' : 'Invite a friend'),
              ),
              if ((status.claimedInviterName ?? '').isNotEmpty) ...[
                SizedBox(height: dims.scaleSpace(20)),
                Container(
                  padding: EdgeInsets.all(dims.scaleSpace(16)),
                  decoration: BoxDecoration(
                    color: colors.bgCard,
                    borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    'You joined using ${status.claimedInviterName}’s referral code.',
                  ),
                ),
              ],
              SizedBox(height: dims.scaleSpace(24)),
              Text(
                'Claim a referral code',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: dims.scaleSpace(10)),
              TextField(
                controller: _claimCodeController,
                decoration: const InputDecoration(
                  hintText: 'Enter a friend’s code',
                ),
              ),
              SizedBox(height: dims.scaleSpace(12)),
              OutlinedButton(
                onPressed: _claiming ? null : _claimCode,
                child: Text(_claiming ? 'Claiming…' : 'Claim referral code'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _shareInvite(ReferralStatusModel status) async {
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Join me on Vyla and use my referral code ${status.referralCode} to get started: ${status.inviteLink}',
          subject: 'Join me on Vyla',
        ),
      );
      await ref.read(growthAnalyticsServiceProvider).track(
        'invite_shared',
        <String, Object?>{'referral_code': status.referralCode},
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  Future<void> _claimCode() async {
    final code = _claimCodeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _claiming = true);
    try {
      await ref
          .read(referralStatusProvider.notifier)
          .claimReferralCode(referralCode: code, source: 'manual_entry');
      _claimCodeController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Referral code claimed')));
    } finally {
      if (mounted) {
        setState(() => _claiming = false);
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    return Container(
      padding: EdgeInsets.all(dims.scaleSpace(16)),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: dims.scaleSpace(6)),
          Text(subtitle),
        ],
      ),
    );
  }
}
