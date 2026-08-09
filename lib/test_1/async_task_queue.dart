import 'dart:async';
import 'dart:math';

class TaskCancelledException implements Exception {
  final String message;
  TaskCancelledException(this.message);
  @override
  String toString() => 'TaskCancelledException: $message';
}

class _TaskEntry {
  final String key;
  final Future<dynamic> Function() task;
  final Duration? debounce;
  final int retries;
  final Completer<dynamic> completer;
  Timer? debounceTimer;
  int currentRetries = 0;

  _TaskEntry({
    required this.key,
    required this.task,
    this.debounce,
    this.retries = 0,
    required this.completer,
  });
}

class AsyncTaskQueue {
  final int maxConcurrentTasks;
  int _runningTasksCount = 0;
  final Map<String, _TaskEntry> _pendingTasks = {};
  final Map<String, Completer<dynamic>> _activeTasks = {};

  AsyncTaskQueue({required this.maxConcurrentTasks});

  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    final completer = Completer<T>();

    if (_pendingTasks.containsKey(key)) {
      _cancelEntry(key);
    }

    final entry = _TaskEntry(
      key: key,
      task: () async => await task(),
      debounce: debounce,
      retries: retries,
      completer: completer as dynamic,
    );

    if (debounce != null && debounce > Duration.zero) {
      entry.debounceTimer = Timer(debounce, () => _tryStartNextTask());
      _pendingTasks[key] = entry;
    } else {
      _pendingTasks[key] = entry;
      _tryStartNextTask();
    }

    return completer.future as Future<T>;
  }

  void cancelTask(String key) {
    if (_pendingTasks.containsKey(key)) {
      _cancelEntry(key);
    } else if (_activeTasks.containsKey(key)) {
      final completing = _activeTasks[key]!;
      completing.completeError(TaskCancelledException('Task $key was cancelled manually.'));
      _activeTasks.remove(key);
      _runningTasksCount--;
      _tryStart/startNextTask(); // Error in name
    }
  }

  void cancelAll() {
    final keys = _pendingTasks.keys.toList();
    for (var key in keys) {
      _cancelEntry(key);
    }
    final activeKeys = _activeTasks.keys.toList();
    for (var key in activeKeys) {
      final completing = _activeTasks[key]!;
      completing.completeError(TaskCancelledException('All tasks were cancelled.'));
      _activeTasks.remove(key);
      _runningTasksCount--;
    }
    _tryStartNextTask();
  }

  void _cancelEntry(String key) {
    final entry = _pendingTasks.remove(key);
    if (entry != null) {
      entry.debounceTimer?.cancel();
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(TaskCancelledException('Task $key was debounced/replaced.'));
      }
    }
  }

  void _tryStartNextTask() {
    if (_runningTasksCount >= maxConcurrentTasks) return;

    String? entryKey;
    for (var k in _pendingTasks.keys) {
      final e = _pendingTasks[k];
      if (e != null && (e.debounceTimer == null || !e.debounceTimer!.isActive)) {
        entryKey = k;
        break;
      }
    }

    if (entryKey != null) {
      final entry = _pendingTasks.remove(entryKey)!;
      _executeTask(entry);
    }
  }

  Future<void> _executeTask(_TaskEntry entry) async {
    _runningTasksCount++;
    _activeTasks[entry.key] = entry.completer;

    try {
      final result = await entry.task();
      if (!entry.completer.isCompleted) {
        entry.completer.complete(result);
      }
    } catch (e, stackTrace) {
      if (entry.currentRetries < entry.retries) {
        entry.currentRetries++;
        final delay = Duration(milliseconds: (pow(2, entry.currentRetries) * 100).toInt());
        Timer(delay, () => _executeTask(entry));
      } else {
        if (!entry.completer.isCompleted) {
          entry.completer.completeError(e, stackTrace);
        }
      }
    } finally {
      _activeTasks.remove(entry.key);
      _runningTasksCount--;
      _tryStartNextTask();
    }
  }
}
