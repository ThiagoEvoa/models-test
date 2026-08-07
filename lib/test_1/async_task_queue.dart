import 'dart:async';

/// Exception thrown when a task is cancelled.
class TaskCancelledException implements Exception {
  final String? message;
  TaskCancelledException([this.message]);

  @override
  String toString() =>
      message != null ? 'TaskCancelledException: $message' : 'TaskCancelledException';
}

/// Entry representing a pending or debouncing task in the queue.
class _TaskEntry<T> {
  final String key;
  final Future<T> Function() task;
  final int retries;
  final Completer<T> completer;
  Timer? debounceTimer;
  bool cancelled;

  _TaskEntry({
    required this.key,
    required this.task,
    required this.retries,
    required this.completer,
    this.debounceTimer,
    this.cancelled = false,
  });
}

/// Manages concurrent asynchronous operations with key-based debouncing
/// and cancellation support.
class AsyncTaskQueue {
  final int maxConcurrentTasks;

  int _runningCount = 0;
  final List<_TaskEntry> _pendingQueue = [];
  final Map<String, _TaskEntry> _debouncing = {};

  AsyncTaskQueue({required this.maxConcurrentTasks});

  /// Enqueues a task with optional key-based debouncing and retry logic.
  ///
  /// If a task with the same [key] is already debouncing, it will be cancelled
  /// and replaced by this new task.
  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    // Cancel any existing debouncing entry for this key
    if (_debouncing.containsKey(key)) {
      final existing = _debouncing[key]!;
      existing.debounceTimer?.cancel();
      existing.cancelled = true;
      if (!existing.completer.isCompleted) {
        existing.completer.completeError(TaskCancelledException());
      }
      _debouncing.remove(key);
    }

    final completer = Completer<T>();

    final entry = _TaskEntry<T>(
      key: key,
      task: task,
      retries: retries,
      completer: completer,
    );

    if (debounce != null && debounce > Duration.zero) {
      _debouncing[key] = entry;
      entry.debounceTimer = Timer(debounce, () {
        _debouncing.remove(key);
        if (!entry.cancelled) {
          _enqueueEntry(entry);
        }
      });
    } else {
      _enqueueEntry(entry);
    }

    return completer.future;
  }

  /// Manually cancel a pending or debouncing task by key.
  void cancelTask(String key) {
    // Cancel debouncing task
    if (_debouncing.containsKey(key)) {
      final entry = _debouncing[key]!;
      entry.debounceTimer?.cancel();
      entry.cancelled = true;
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(TaskCancelledException());
      }
      _debouncing.remove(key);
    }

    // Cancel pending tasks in queue
    _pendingQueue.where((e) => e.key == key).toList().forEach((entry) {
      entry.cancelled = true;
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(TaskCancelledException());
      }
    });
    _pendingQueue.removeWhere((e) => e.key == key);
  }

  /// Cancel all pending and debouncing tasks.
  void cancelAll() {
    // Cancel all debouncing tasks
    for (final entry in _debouncing.values) {
      entry.debounceTimer?.cancel();
      entry.cancelled = true;
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(TaskCancelledException());
      }
    }
    _debouncing.clear();

    // Cancel all pending tasks
    for (final entry in List.of(_pendingQueue)) {
      entry.cancelled = true;
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(TaskCancelledException());
      }
    }
    _pendingQueue.clear();
  }

  void _enqueueEntry(_TaskEntry entry) {
    _pendingQueue.add(entry);
    _tryRunNext();
  }

  void _tryRunNext() {
    while (_runningCount < maxConcurrentTasks && _pendingQueue.isNotEmpty) {
      final entry = _pendingQueue.removeAt(0);
      if (entry.cancelled || entry.completer.isCompleted) continue;
      _runningCount++;
      _executeEntry(entry);
    }
  }

  Future<void> _executeEntry(_TaskEntry entry) async {
    try {
      final result = await _runWithRetries(entry.task, entry.retries);
      if (!entry.completer.isCompleted) {
        entry.completer.complete(result);
      }
    } catch (e) {
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(e);
      }
    } finally {
      _runningCount--;
      _tryRunNext();
    }
  }

  Future<T> _runWithRetries<T>(Future<T> Function() task, int retries) async {
    int attempt = 0;
    while (true) {
      try {
        return await task();
      } catch (e) {
        if (attempt < retries) {
          attempt++;
          final backoffMs = (1 << attempt) * 50; // exponential backoff
          await Future.delayed(Duration(milliseconds: backoffMs));
        } else {
          rethrow;
        }
      }
    }
  }
}
