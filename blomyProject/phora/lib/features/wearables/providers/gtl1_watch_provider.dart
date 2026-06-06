import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/features/wearables/data/gtl1_watch_sync_repository.dart';
import 'package:phora_gtl1_watch/phora_gtl1_watch.dart';

final gtl1RealtimeStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return PhoraGtl1Watch.realtimeStream;
});

final gtl1DevicesProvider = FutureProvider<List<Gtl1WatchDevice>>((ref) async {
  final repository = ref.watch(gtl1WatchSyncRepositoryProvider);
  return repository.scanDevices();
});
