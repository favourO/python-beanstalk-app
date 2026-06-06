import 'dart:async';

class WearableSyncQueue {
  final Map<String, Future<void>> _inFlight = {};
  final Map<String, int> _retryCounts = {};

  int retryCount(String providerId) => _retryCounts[providerId] ?? 0;

  Future<void> enqueue(
    String providerId,
    Future<void> Function() task, {
    int maxRetries = 2,
  }) {
    final existing = _inFlight[providerId];
    if (existing != null) {
      return existing;
    }

    late Future<void> future;
    future = _runWithRetry(providerId, task, maxRetries).whenComplete(() {
      if (identical(_inFlight[providerId], future)) {
        _inFlight.remove(providerId);
      }
    });
    _inFlight[providerId] = future;
    return future;
  }

  Future<void> _runWithRetry(
    String providerId,
    Future<void> Function() task,
    int maxRetries,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await task();
        _retryCounts[providerId] = 0;
        return;
      } catch (error) {
        lastError = error;
        _retryCounts[providerId] = attempt + 1;
        if (attempt < maxRetries) {
          await Future<void>.delayed(
            Duration(milliseconds: 450 * (attempt + 1)),
          );
        }
      }
    }
    Error.throwWithStackTrace(lastError!, StackTrace.current);
  }
}
