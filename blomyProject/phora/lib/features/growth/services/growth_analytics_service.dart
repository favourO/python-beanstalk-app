import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final growthAnalyticsServiceProvider = Provider<GrowthAnalyticsService>((ref) {
  return GrowthAnalyticsService(FirebaseAnalytics.instance);
});

class GrowthAnalyticsService {
  const GrowthAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> track(String name, Map<String, Object?> parameters) async {
    await _analytics.logEvent(
      name: name,
      parameters: Map<String, Object>.fromEntries(
        parameters.entries
            .where((entry) => entry.value != null)
            .map((entry) => MapEntry(entry.key, entry.value!)),
      ),
    );
  }
}
