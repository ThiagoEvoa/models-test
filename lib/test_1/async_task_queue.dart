import 'dart:async';

class TaskCancelledException implements Exception {
  final String key;
  TaskCancelledException(this.key);
  @override
  String toString() => 'TaskCancelledException: $key';
}

enum _TaskState { debouncing, queued, running }

class _PendingTask<T> {
  final Future<T> Function() task;
  final Completer<T> completer;
  final int maxRetries;
  final String key;
  _TaskState state = _TaskState.debouncing;
  Timer? debounceTimer;
  bool cancelled = false;

  _PendingTask({
    required this.key,
    required this.task,
    required this.completer,
    required this.maxRetries,
  });

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    debounceTimer?.cancel();
    completer.completeError(TaskCancelledException(key));
  }
}

class AsyncTaskQueue {
  final int maxConcurrentTasks;
  final Map<String, _PendingTask<dynamic>> _debouncing = {};
  final List<_PendingTask<dynamic>> _queue = [];
  int _active = 0;

  AsyncTaskQueue({required this.maxConcurrentTasks});

  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    final completer = Completer<T>();

    // No debouncing needed: queue or execute immediately
    if (debounce == null || debounce.duration == Duration.zero) {
      final pending = _PendingTask(
        key: key,
        task: () => task() as Future<T>,
        completer: completer,
        maxRetries: retries,
      );
      pending.state = _TaskState.queued;

      // Cancel any debouncing task with same key
      if (_debouncing.containsKey(key)) {
        _debouncing[key]!.cancel();
        _debouncing.remove(key);
      }

      _queue.add(pending);
      _tryExecute();
      return completer.future as Future<T>;
    }

    // Has debouncing: cancel existing task with same key if it's still debouncing
    if (_debouncing[key]?.state == _TaskState.debouncing) {
      _debouncing[key]!.cancel();
    }

    final pending = _PendingTask(
      key: key,
      task: () => task() as Future<T>,
      completer: completer,
      maxRetries: retries,
    );

    pending.debounceTimer = Timer(debounce!, () {
      if (pending.cancelled) return;
      _debouncing.remove(key);
      _queue.add(pending);
      _tryExecute();
    });

    _debouncing[key] = pending;
    return completer.future as Future<T>;
  }

  void cancelTask(String key) {
    final debouncing = _debouncing[key];
    if (debouncing != null && debouncing.state == _TaskState.debouncing) {
      debouncing.cancel();
      _debouncing.remove(key);
      return;
    }

    // Cancel if in queue
    for (final t in _queue.toList()) {
      if (t.key == key && !t.cancelled) {
        t.cancel();
      }
    }
  }

  void cancelAll() {
    for (final entry in _debouncing.values) {
      entry.cancel();
    }
    _debouncing.clear();

    for (final task in _queue.toList()) {
      if (!task.cancelled) {
        task.cancel();
      }
    }
  }

  void _tryExecute() {
    while (_active < maxConcurrentTasks && _queue.isNotEmpty) {
      final pending = _queue.removeAt(0);
      if (pending.cancelled) continue;

      pending.state = _TaskState.running;
      _active++;

      _runTask(pending).then((_) {
        _active--;
        _tryExecute();
      });
    }
  }

  Future<void> _runTask<T>(_PendingTask<T> pending) async {
    int attemptsLeft = pending.maxRetries;
    Exception? lastError;

    while (true) {
      if (pending.cancelled) return;

      try {
        final result = await pending.task();
        if (!pending.cancelled) {
          pending.completer.complete(result);
        }
        return;
      } catch (e) {
        lastError = e as Exception;
        if (attemptsLeft > 0 && !pending.cancelled) {
          attemptsLeft--;
          final delay = Duration(milliseconds: 100 * (1 << (pending.maxRetries - attemptsLeft)));
          await Future.delayed(delay);
        } else {
          if (!pending.cancelled) {
            pending.completer.completeError(lastError!);
          }
          return;
        }
      }
    }
  }
}
