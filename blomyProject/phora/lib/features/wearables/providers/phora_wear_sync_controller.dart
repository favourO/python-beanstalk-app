import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/features/home/home_providers.dart';
import 'package:phora/features/wearables/data/gtl1_watch_sync_repository.dart';
import 'package:phora/features/wearables/repositories/wearable_repository.dart';

final phoraWearSyncControllerProvider =
    NotifierProvider<PhoraWearSyncController, void>(
      PhoraWearSyncController.new,
    );

class PhoraWearSyncController extends Notifier<void> {
  static const syncInterval = Duration(minutes: 20);

  Timer? _timer;
  bool _syncing = false;

  @override
  void build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
  }

  Future<void> start() async {
    _timer?.cancel();
    final pairing =
        await ref.read(gtl1WatchSyncRepositoryProvider).getPairedPhoraWear();
    if (pairing == null) {
      return;
    }
    unawaited(syncNow());
    _timer = Timer.periodic(syncInterval, (_) {
      unawaited(syncNow());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncNow() async {
    if (_syncing) {
      return;
    }
    _syncing = true;
    try {
      await ref
          .read(gtl1WatchSyncRepositoryProvider)
          .syncPairedTodayAndUpload();
    } catch (_) {
      // The backend remains the source of truth for the last successful sync.
      // Failed watch availability should not wipe or replace that data.
    } finally {
      _syncing = false;
      ref.invalidate(homeDashboardProvider);
      ref.invalidate(wearableConnectionStatusesProvider);
    }
  }
}
