import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/features/profile/data/profile_repository.dart';
import 'package:phora/features/profile/domain/age_profile.dart';
import 'package:phora/features/profile/domain/notification_models.dart';
import 'package:phora/features/profile/domain/user_profile.dart';

final currentUserProfileProvider =
    AsyncNotifierProvider<CurrentUserProfileController, UserProfile?>(
      CurrentUserProfileController.new,
    );

class CurrentUserProfileController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      return null;
    }
    return ref.watch(profileRepositoryProvider).getUserProfile();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).getUserProfile(),
    );
  }
}

final ageProfileProvider = FutureProvider.autoDispose<AgeProfile?>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null || !session.isAuthenticated) return null;
  return ref.watch(profileRepositoryProvider).getAgeProfile();
});

final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsController, NotificationSettings>(
      NotificationSettingsController.new,
    );

final recentNotificationsProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final history = await ref.watch(notificationHistoryProvider.future);
  return history.items;
});

final notificationHistoryProvider =
    AsyncNotifierProvider<NotificationHistoryController, NotificationHistory>(
      NotificationHistoryController.new,
    );

class NotificationHistoryController extends AsyncNotifier<NotificationHistory> {
  @override
  Future<NotificationHistory> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      return const NotificationHistory.empty();
    }
    return ref.watch(profileRepositoryProvider).getNotificationHistory();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).getNotificationHistory(),
    );
  }

  Future<void> markAllRead() async {
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData(
        NotificationHistory(
          items: [
            for (final item in previous.items)
              AppNotification(
                id: item.id,
                notificationType: item.notificationType,
                title: item.title,
                body: item.body,
                category: item.category,
                priority: item.priority,
                createdAt: item.createdAt,
                isRead: true,
                actionUrl: item.actionUrl,
                payload: item.payload,
              ),
          ],
          unreadCount: 0,
        ),
      );
    }
    try {
      await ref.read(profileRepositoryProvider).markAllNotificationsRead();
      state = AsyncData(
        await ref.read(profileRepositoryProvider).getNotificationHistory(),
      );
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> markRead(String notificationId) async {
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData(
        NotificationHistory(
          items: [
            for (final item in previous.items)
              AppNotification(
                id: item.id,
                notificationType: item.notificationType,
                title: item.title,
                body: item.body,
                category: item.category,
                priority: item.priority,
                createdAt: item.createdAt,
                isRead: item.id == notificationId ? true : item.isRead,
                actionUrl: item.actionUrl,
                payload: item.payload,
              ),
          ],
          unreadCount:
              previous.items.any(
                    (item) => item.id == notificationId && !item.isRead,
                  )
                  ? (previous.unreadCount - 1).clamp(0, previous.items.length)
                  : previous.unreadCount,
        ),
      );
    }
    try {
      await ref
          .read(profileRepositoryProvider)
          .markNotificationRead(notificationId);
      state = AsyncData(
        await ref.read(profileRepositoryProvider).getNotificationHistory(),
      );
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }
}

class NotificationSettingsController
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null || !session.isAuthenticated) {
      return const NotificationSettings(
        allNotifications: true,
        periodApproaching: true,
        periodDetected: true,
        fertileWindowOpen: true,
        ovulationConfirmed: true,
        cycleDelayAlert: true,
        cyclePatternChange: true,
        unusualSymptom: true,
        stressAlert: true,
        sleepAlert: false,
        dailySymptomReminder: false,
        bangleSyncReminder: true,
        lhTestReminder: false,
        blogPosts: true,
        wearableOvulationReminder: true,
        updateReminders: true,
        quietHours: NotificationQuietHours(
          enabled: true,
          startTime: '22:00',
          endTime: '08:00',
          allowCriticalAlerts: true,
        ),
      );
    }
    return ref.watch(profileRepositoryProvider).getNotificationSettings();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).getNotificationSettings(),
    );
  }

  Future<void> applyPatch({
    required Map<String, dynamic> patch,
    required NotificationSettings optimisticState,
  }) async {
    final previous = state.valueOrNull;
    state = AsyncData(optimisticState);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateNotificationSettings(patch: patch);
      state = AsyncData(
        await ref.read(profileRepositoryProvider).getNotificationSettings(),
      );
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }
}
