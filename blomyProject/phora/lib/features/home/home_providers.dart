import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/features/home/data/home_repository.dart';
import 'package:phora/features/home/domain/home_dashboard.dart';

final homeDashboardProvider =
    AsyncNotifierProvider<HomeDashboardController, HomeDashboard>(
      HomeDashboardController.new,
    );

final homeDashboardOfflineProvider = StateProvider<bool>((ref) => false);
final homeDashboardCachedAtProvider = StateProvider<DateTime?>((ref) => null);

class HomeDashboardController extends AsyncNotifier<HomeDashboard> {
  @override
  Future<HomeDashboard> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      throw StateError('Sign in to view your dashboard.');
    }
    final result = await ref.watch(homeRepositoryProvider).getHomeDashboard();
    _applyConnectivityState(result);
    return result.dashboard;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(homeRepositoryProvider).getHomeDashboard();
      _applyConnectivityState(result);
      return result.dashboard;
    });
  }

  void _applyConnectivityState(HomeDashboardFetchResult result) {
    ref.read(homeDashboardOfflineProvider.notifier).state = result.fromCache;
    ref.read(homeDashboardCachedAtProvider.notifier).state = result.cachedAt;
  }
}
