import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/features/auth/domain/app_session.dart';
import 'package:phora/features/growth/data/growth_repository.dart';
import 'package:phora/features/growth/domain/growth_models.dart';
import 'package:phora/features/growth/services/growth_analytics_service.dart';

final shareInsightProvider = FutureProvider<ShareInsightModel>((ref) async {
  return ref.watch(growthRepositoryProvider).getShareInsight();
});

final shareInsightConfigProvider = FutureProvider<ShareInsightConfigModel>((
  ref,
) async {
  return ref.watch(growthRepositoryProvider).getShareInsightConfig();
});

final friendNetworkProvider =
    AsyncNotifierProvider<FriendNetworkController, FriendNetworkModel>(
      FriendNetworkController.new,
    );

class FriendNetworkController extends AsyncNotifier<FriendNetworkModel> {
  @override
  Future<FriendNetworkModel> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session?.isAuthenticated != true) {
      return const FriendNetworkModel(
        friends: <FriendConnectionModel>[],
        incomingRequests: <FriendConnectionModel>[],
        outgoingRequests: <FriendConnectionModel>[],
      );
    }
    return ref.watch(growthRepositoryProvider).getFriendNetwork();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(growthRepositoryProvider).getFriendNetwork(),
    );
  }

  Future<void> sendRequest(String email) async {
    await ref.read(growthRepositoryProvider).sendFriendRequest(email);
    await refresh();
  }

  Future<void> acceptRequest(String connectionId) async {
    await ref.read(growthRepositoryProvider).acceptFriendRequest(connectionId);
    await refresh();
  }

  Future<void> declineRequest(String connectionId) async {
    await ref.read(growthRepositoryProvider).declineFriendRequest(connectionId);
    await refresh();
  }

  Future<void> setComparisonPermission({
    required String friendId,
    required bool enabled,
  }) async {
    await ref
        .read(growthRepositoryProvider)
        .updateComparisonPermission(friendId: friendId, enabled: enabled);
    await refresh();
  }
}

final comparisonSummaryProvider =
    FutureProvider.family<ComparisonSummaryModel, String>((
      ref,
      friendId,
    ) async {
      return ref.watch(growthRepositoryProvider).getComparisonSummary(friendId);
    });

final referralStatusProvider =
    AsyncNotifierProvider<ReferralStatusController, ReferralStatusModel?>(
      ReferralStatusController.new,
    );

class ReferralStatusController extends AsyncNotifier<ReferralStatusModel?> {
  @override
  Future<ReferralStatusModel?> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session?.isAuthenticated != true) {
      return null;
    }
    return ref.watch(growthRepositoryProvider).getReferralStatus();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(growthRepositoryProvider).getReferralStatus(),
    );
  }

  Future<void> claimReferralCode({
    required String referralCode,
    String? source,
    String? deepLinkId,
  }) async {
    await ref
        .read(growthRepositoryProvider)
        .claimReferralCode(
          referralCode: referralCode,
          source: source,
          deepLinkId: deepLinkId,
        );
    await refresh();
  }
}

final pendingReferralClaimControllerProvider =
    AsyncNotifierProvider<PendingReferralClaimController, void>(
      PendingReferralClaimController.new,
    );

class PendingReferralClaimController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> claimIfNeeded(AppSession? session) async {
    if (session?.isAuthenticated != true) {
      return;
    }
    final preferences = ref.read(appPreferencesProvider);
    final code = await preferences.getPendingReferralCode();
    if (code == null || code.isEmpty) {
      return;
    }
    final source = await preferences.getPendingReferralSource();
    final deepLinkId = await preferences.getPendingReferralDeepLinkId();
    try {
      await ref
          .read(growthRepositoryProvider)
          .claimReferralCode(
            referralCode: code,
            source: source,
            deepLinkId: deepLinkId,
          );
      await preferences.clearPendingReferral();
      unawaited(
        ref.read(growthAnalyticsServiceProvider).track(
          'referral_claimed',
          <String, Object?>{'source': source ?? 'unknown'},
        ),
      );
      ref.invalidate(referralStatusProvider);
    } catch (_) {
      // Keep the code locally so a later authenticated session can retry.
    }
  }
}
