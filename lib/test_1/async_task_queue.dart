import 'dart:async';

/// Exception thrown when a task is cancelled via debounce replacement or explicit cancellation.
class TaskCancelledException implements Exception {
  final String message;
  TaskCancelledException([this.message = 'Task was cancelled']);

  @override
  String toString() => 'TaskCancelledException: $message';
}

class _QueueEntry<T> {
  final String key;
  final Future<T> Function() task;
  final int retries;
  final Completer<T> completer;
  Timer? debounceTimer;

  _QueueEntry({
    required this.key,
    required this.task,
    required this.retries,
    required this.completer,
    this.debounceTimer,
  });

  void cancel() {
    debounceTimer?.cancel();
    if (!completer.isCompleted) {
      completer.completeError(TaskCancelledException());
    }
  }
}

/// Manages concurrent async operations with key-based debouncing and cancellation.
class AsyncTaskQueue {
  final int maxConcurrentTasks;

  /// Pending entries waiting in the queue (either debouncing or waiting for a slot).
  final Map<String, _QueueEntry> _pending = {};

  /// The FIFO queue of entries ready to execute (after debounce expired).
  final List<_QueueEntry> _readyQueue = [];

  /// Number of tasks currently running.
  int _running = 0;

  AsyncTaskQueue({required this.maxConcurrentTasks});

  /// Enqueue a task with optional debounce, retries, and a unique key.
  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    // Cancel any existing pending task with the same key.
    if (_pending.containsKey(key)) {
      _pending[key]!.cancel();
      _pending.remove(key);
    }

    final completer = Completer<T>();
    final entry = _QueueEntry<T>(
      key: key,
      task: task,
      retries: retries,
      completer: completer,
    );

    _pending[key] = entry;

    if (debounce != null && debounce > Duration.zero) {
      // Schedule execution after debounce window.
      entry.debounceTimer = Timer(debounce, () {
        _onDebounceExpired(entry);
      });
    } else {
      // No debounce — ready immediately.
      _onDebounceExpired(entry);
    }

    return completer.future;
  }

  void _onDebounceExpired(_QueueEntry entry) {
    // Remove from pending map (it's now ready to run or be queued).
    _pending.remove(entry.key);

    if (entry.completer.isCompleted) {
      // Already cancelled.
      return;
    }

    _readyQueue.add(entry);
    _tryRunNext();
  }

  void _tryRunNext() {
    while (_running < maxConcurrentTasks && _readyQueue.isNotEmpty) {
      final entry = _readyQueue.removeAt(0);
      if (entry.completer.isCompleted) {
        // Skip already-cancelled entries.
        continue;
      }
      _running++;
      _executeEntry(entry);
    }
  }

  void _executeEntry(_QueueEntry entry) {
    _runWithRetries(entry.task, entry.retries).then((result) {
      if (!entry.completer.isCompleted) {
        entry.completer.complete(result);
      }
    }).catchError((error) {
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(error);
      }
    }).whenComplete(() {
      _running--;
      _tryRunNext();
    });
  }

  Future<T> _runWithRetries<T>(Future<T> Function() task, int retries) async {
    int attempt = 0;
    while (true) {
      try {
        return await task();
      } catch (e) {
        if (attempt >= retries) {
          rethrow;
        }
        // Exponential backoff: 2^attempt * 50ms
        final delay = Duration(milliseconds: 50 * (1 << attempt));
        await Future.delayed(delay);
        attempt++;
      }
    }
  }

  /// Manually cancel a pending or debouncing task by key.
  void cancelTask(String key) {
    final entry = _pending.remove(key);
    entry?.cancel();
  }

  /// Cancel all pending/debouncing tasks and reject their futures.
  void cancelAll() {
    // Cancel debouncing entries.
    for (final entry in _pending.values) {
      entry.cancel();
    }
    _pending.clear();

    // Cancel ready-queued entries.
    for (final entry in _readyQueue) {
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(TaskCancelledException());
      }
    }
    _readyQueue.clear();
  }
}
