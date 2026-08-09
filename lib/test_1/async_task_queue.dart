import 'dart:async';

class TaskCancelledException implements Exception {
  final String message;
  TaskCancelledException([this.message = 'Task was cancelled']);

  @override
  String toString() => 'TaskCancelledException: $message';
}

class AsyncTaskQueue {
  final int maxConcurrentTasks;
  int _runningCount = 0;
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Completer<void>> _pendingCancellers = {};
  final List<_TaskEntry> _queue = [];

  AsyncTaskQueue({required this.maxConcurrentTasks});

  static class _TaskEntry {
    final String key;
    final Future<dynamic> Function() task;
    final int retries;
    final Completer<dynamic> completer = Completer<dynamic>();

    _TaskEntry({required this.key, required this.task, required this.retries});
  }

  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    // Cancel any existing debouncing or pending task for this key
    _cancelExistingByKey(key);

    final completer = Completer<T>();

    if (debounce != null) {
      final timer = Timer(debounce, () {
        _debounceTimers.remove(key);
        _processEnqueue(key, task, retries, completer);
      });
      _debounceTimers[key] = timer;
    } else {
      _processEnqueue(key, task, retries, completer);
    }

    return completer.future;
  }

  void _processEnqueue<T>(String key, Future<T> Function() task, int retries, Completer<T> completer) {
    // Check if we should actually enqueue or if it was cancelled since logic started
    final entry = _TaskEntry(key: key, task: () => task(), retries: retries);
    
    // We need a way to map the generic T to dynamic for the queue
    _queue.add(_wrapEntry(entry, completer));
    _next();
  }

  // Helper to handle type casting in the internal queue
  dynamic _wrapEntry(_TaskEntry entry, Completer<dynamic> externalCompleter) {
    return entry; 
  }

  void _cancelExistingByKey(String key) {
    final timer = _debounceTimers.remove(key);
    timer?.cancel();

    // Cancel if it's in the queue but not yet running
    for (var i = 0; i < _queue.length; i++) {
      if (_queue[i].key == key) {
        final entry = _queue.removeAt(i);
        entry.completer.completeError(TaskCancelledException('Task with key $key cancelled by new enqueue'));
        break; 
      }
    }
  }

  void cancelTask(String key) {
    _cancelExistingByKey(key);
  }

  void cancelAll() {
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    while (_queue.isNotEmpty) {
      final entry = _queue.removeAt(0);
      entry.completer.completeError(TaskCancelledException('All tasks cancelled'));
    }
  }

  void _next() {
    if (_runningCount >= maxConcurrentTasks || _queue.isEmpty) return;

    final entry = _queue.removeAt(0);
    _runTask(entry);
  }

  Future<void> _runTask(_TaskEntry entry) async {
    _runningCount++;
    int attempt = 0;

    while (attempt <= entry.retries) {
      try {
        final result = await entry.task();
        entry.completer.complete(result);
        break;
      } catch (e) {
        attempt++;
        if (attempt > entry.retries) {
          entry.completer.completeError(e);
          break;
        }
        // Exponential backoff: 2^attempt * 100ms
        await Future.delayed(Duration(milliseconds: (1 << attempt) * 100));
      }
    }

    _runningCount--;
    _next();
  }

  // Fixed internal mapping for generics logic in a real implementation
  // Since we can't have generic _TaskEntry list with different T, we use dynamic
}

// Redefining TaskEntry to avoid static class errors and handle dynamics correctly
class _TaskEntry {
  final String key;
  final Future<dynamic> Function() task;
  final int retries;
  final Completer<dynamic> completer = Completer<dynamic>();

  _TaskEntry({required this.key, required this.task, required this.retries});
}
