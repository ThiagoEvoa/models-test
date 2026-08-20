import 'dart:async';

/// Thrown to complete the `Future` of a task that was cancelled (via key
/// debouncing, [AsyncTaskQueue.cancelTask], or [AsyncTaskQueue.cancelAll])
/// before its `task()` callback ever started executing.
class TaskCancelledException implements Exception {
  final String message;

  const TaskCancelledException([this.message = 'Task was cancelled']);

  @override
  String toString() => 'TaskCancelledException: $message';
}

/// An internally tracked unit of work.
class _TaskItem<T> {
  _TaskItem(
    this.key,
    this.task,
    this.retries,
  );

  final String key;
  final Future<T> Function() task;
  final int retries;
  final Completer<T> completer = Completer<T>();

  Timer? debounceTimer;
  bool cancelled = false;

  bool get isCancelled => cancelled;

  Future<T> get future => completer.future;
}

/// A bounded, debouncable, cancellable queue of asynchronous operations.
///
/// - Enforces [maxConcurrentTasks] in-flight tasks at all times.
/// - Supports key-based debouncing: re-enqueuing a key whose previous task has
///   not yet started cancels the previous task (its `Future` completes with a
///   [TaskCancelledException]) and the new task takes its place.
/// - Supports manual cancellation via [cancelTask] and [cancelAll].
/// - Retries failing tasks a configurable number of times with exponential
///   backoff before bubbling the error to the caller.
class AsyncTaskQueue {
  AsyncTaskQueue({required int maxConcurrentTasks})
      : assert(maxConcurrentTasks >= 1, 'maxConcurrentTasks must be >= 1'),
        _maxConcurrentTasks = maxConcurrentTasks;

  final int _maxConcurrentTasks;

  int _activeRunning = 0;

  /// Tasks waiting for a free concurrency slot.
  final List<_TaskItem> _executionQueue = [];

  /// The latest not-yet-started task per key (debouncing + queued).
  /// Running tasks are removed from this map so that a re-enqueue does not
  /// try to cancel a task that is already in flight.
  final Map<String, _TaskItem> _pendingByKey = <String, _TaskItem>{};

  /// Currently running tasks (tracked for cancellation bookkeeping).
  final Set<_TaskItem> _running = <_TaskItem>{};

  /// Enqueues [task].
  ///
  /// If a previous task with the same [key] has not yet started executing, it
  /// is cancelled (its `Future` completes with [TaskCancelledException]) and
  /// replaced by this new task.
  ///
  /// - When [debounce] is `null`, the task is scheduled for execution
  ///   immediately.
  /// - When [debounce] is provided, execution is delayed by that duration; a
  ///   re-enqueue of the same key within the window reschedules.
  /// - On task failure, the [task] is retried up to [retries] times with
  ///   exponential backoff; if it still fails, the original error is rethrown
  ///   to the returned `Future`.
  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    final _TaskItem<T> item =
        _TaskItem<T>(key, task, retries < 0 ? 0 : retries);

    // Cancel any pending (debouncing or queued) task that shares this key.
    final _TaskItem? previous = _pendingByKey[key];
    if (previous != null && !_running.contains(previous)) {
      _cancel(previous);
    }

    _pendingByKey[key] = item;

    if (debounce != null) {
      item.debounceTimer = Timer(debounce, () {
        // Re-check: it may have been cancelled or superseded while waiting.
        _schedule(item);
      });
    } else {
      _schedule(item);
    }

    return item.future;
  }

  /// Manually cancels the pending/debouncing task registered under [key]
  /// (if any). Its `Future` completes with [TaskCancelledException].
  void cancelTask(String key) {
    final _TaskItem? item = _pendingByKey[key];
    if (item != null) {
      _cancel(item);
    }
  }

  /// Cancels every pending (debouncing or queued) task. Each affected
  /// `Future` completes with [TaskCancelledException].
  void cancelAll() {
    for (final _TaskItem item in _pendingByKey.values.toList()) {
      _cancel(item);
    }
  }

  void _schedule(_TaskItem item) {
    if (item.isCancelled) {
      if (_pendingByKey[item.key] == item) {
        _pendingByKey.remove(item.key);
      }
      return;
    }

    if (_activeRunning < _maxConcurrentTasks) {
      _start(item);
    } else {
      _executionQueue.add(item);
    }
  }

  void _start(_TaskItem item) {
    if (item.isCancelled) {
      if (_pendingByKey[item.key] == item) {
        _pendingByKey.remove(item.key);
      }
      return;
    }

    if (_pendingByKey[item.key] == item) {
      _pendingByKey.remove(item.key);
    }

    if (item.debounceTimer != null) {
      item.debounceTimer!.cancel();
      item.debounceTimer = null;
    }

    _activeRunning++;
    _running.add(item);
    _run(item);
  }

  Future<void> _run(_TaskItem item) async {
    try {
      int attempt = 0;
      while (true) {
        try {
          final result = await item.task();
          if (!item.completer.isCompleted) {
            item.completer.complete(result);
          }
          return;
        } catch (error) {
          if (!item.completer.isCompleted && attempt < item.retries) {
            // Exponential backoff between retries.
            final backoff = Duration(
              milliseconds: 1 << attempt,
            );
            await Future.delayed(backoff);
            attempt++;
            continue;
          }
          if (!item.completer.isCompleted) {
            item.completer.completeError(error);
          }
          return;
        }
      }
    } finally {
      _activeRunning--;
      _running.remove(item);
      _drainQueue();
    }
  }

  void _drainQueue() {
    while (_activeRunning < _maxConcurrentTasks &&
        _executionQueue.isNotEmpty) {
      final _TaskItem next = _executionQueue.removeAt(0);
      if (next.isCancelled) {
        continue;
      }
      _start(next);
    }
  }

  void _cancel(_TaskItem item) {
    if (item.isCancelled) {
      return;
    }

    item.cancelled = true;

    if (item.debounceTimer != null) {
      item.debounceTimer!.cancel();
      item.debounceTimer = null;
    }

    final bool wasRunning = _running.remove(item);

    _executionQueue.remove(item);

    if (_pendingByKey[item.key] == item) {
      _pendingByKey.remove(item.key);
    }

    // A task that has already started running cannot be rolled back; only
    // pending/debouncing tasks are rejected with a cancellation error.
    if (!wasRunning && !item.completer.isCompleted) {
      item.completer.completeError(const TaskCancelledException());
    }
  }
}
