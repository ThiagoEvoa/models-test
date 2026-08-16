import 'dart:async';

/// Exception completed onto a queue task's future when the task is cancelled:
/// by being superseded by a newer task with the same key (debounce), by
/// [AsyncTaskQueue.cancelTask], or by [AsyncTaskQueue.cancelAll].
class TaskCancelledException implements Exception {
  TaskCancelledException(this.key);

  final String key;

  @override
  String toString() => 'TaskCancelledException(key: $key)';
}

/// Manages concurrent asynchronous operations with a hard concurrency cap,
/// key-based debouncing, manual cancellation, and retry-with-backoff.
///
/// Pure `dart:async` only -- no external packages.
class AsyncTaskQueue {
  AsyncTaskQueue({required int maxConcurrentTasks})
      : _maxConcurrentTasks = maxConcurrentTasks,
        assert(maxConcurrentTasks > 0, 'maxConcurrentTasks must be > 0');

  final int _maxConcurrentTasks;

  /// Tasks whose debounce window has elapsed, waiting for a free slot.
  final Queue<_PendingTask> _readyQueue = Queue<_PendingTask>();

  /// Tasks still inside their debounce window (waiting for the timer to fire).
  final Map<String, _PendingTask> _debouncing = <String, _PendingTask>{};

  /// Number of tasks currently executing `task()`.
  int _running = 0;

  /// Enqueue a task under [key].
  ///
  /// If [debounce] is non-null and greater than zero, any already-pending task
  /// sharing [key] is cancelled (its future completes with
  /// [TaskCancelledException]) and replaced by this one, which waits for its
  /// own debounce window before running. A null/zero debounce runs as soon as a
  /// concurrency slot is free.
  ///
  /// On error the task is retried up to [retries] times with exponential
  /// backoff before the underlying error is surfaced to the caller.
  Future<T> enqueue<T>(
    String key, {
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    // Supersede any not-yet-started task sharing this key (debouncing OR
    // already debounce-elapsed and waiting for a slot).
    _supersede(key);

    final pending = _PendingTask<T>(key, task, retries);
    final hasDebounce = debounce != null && debounce > Duration.zero;

    if (hasDebounce) {
      pending.armDebounce(debounce!, () {
        _debouncing.remove(key);
        _readyQueue.add(pending);
        _tryStartNext();
      });
      _debouncing[key] = pending;
    } else {
      _readyQueue.add(pending);
      _tryStartNext();
    }
    return pending.future;
  }

  /// Cancel the pending (debouncing or slot-waiting) task with [key],
  /// completing its future with [TaskCancelledException].
  void cancelTask(String key) {
    final debouncing = _debouncing.remove(key);
    if (debouncing != null) {
      debouncing.cancel();
      return;
    }
    final removed = <_PendingTask>[];
    for (final task in _readyQueue.toList()) {
      if (task.key == key) {
        removed.add(task);
      }
    }
    for (final task in removed) {
      _readyQueue.remove(task);
      task.cancel();
    }
  }

  /// Cancel every pending (debouncing or slot-waiting) task and reject their
  /// futures with [TaskCancelledException].
  void cancelAll() {
    for (final task in _debouncing.values.toList()) {
      task.cancel();
    }
    _debouncing.clear();
    for (final task in _readyQueue.toList()) {
      task.cancel();
    }
    _readyQueue.clear();
  }

  /// Cancel and drop every not-yet-started task that shares [key].
  void _supersede(String key) {
    final debouncing = _debouncing.remove(key);
    if (debouncing != null) {
      debouncing.cancel();
    }
    for (final task in _readyQueue.toList()) {
      if (task.key == key) {
        _readyQueue.remove(task);
        task.cancel();
      }
    }
  }

  /// Start as many ready tasks as there are free slots.
  void _tryStartNext() {
    while (_running < _maxConcurrentTasks && _readyQueue.isNotEmpty) {
      final pending = _readyQueue.removeFirst();
      _start(pending);
    }
  }

  void _start(_PendingTask pending) {
    if (pending.isCancelled) {
      return;
    }
    pending.markStarted();
    _running++;
    _run(pending);
  }

  Future<void> _run(_PendingTask pending) async {
    var attempt = 0;
    Object? lastError;
    var didSucceed = false;

    while (true) {
      attempt++;
      if (pending.isCancelled) {
        break;
      }
      try {
        final result = await pending.task();
        if (!pending.isCancelled) {
          pending.complete(result);
        }
        didSucceed = true;
        break;
      } on TaskCancelledException {
        lastError = TaskCancelledException(pending.key);
        break;
      } catch (error) {
        lastError = error;
        if (attempt >= pending.retries + 1) {
          break; // Retries exhausted.
        }
        final backoff = const Duration(milliseconds: 16) * (1 << (attempt - 1));
        await Future.delayed(backoff);
      }
    }

    if (!didSucceed && !pending.isCancelled) {
      pending.fail(lastError ?? Exception('Task failed'));
    }

    _running--;
    _tryStartNext();
  }
}

class _PendingTask<T> {
  _PendingTask(this.key, this.task, this.retries);

  final String key;
  final Future<T> Function() task;
  final int retries;

  bool isCancelled = false;
  Timer? _debounceTimer;
  final Completer<T> completer = Completer<T>();

  Future<T> get future => completer.future;

  void armDebounce(Duration debounce, void Function() onFire) {
    _debounceTimer = Timer(debounce, onFire);
  }

  void markStarted() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Complete the future with [TaskCancelledException]. Idempotent.
  void cancel() {
    if (isCancelled) {
      return;
    }
    isCancelled = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (!completer.isCompleted) {
      completer.completeError(TaskCancelledException(key));
    }
  }

  void complete(T value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  void fail(Object error, [StackTrace? stack]) {
    if (!completer.isCompleted) {
      completer.completeError(error, stack ?? StackTrace.current);
    }
  }
}
