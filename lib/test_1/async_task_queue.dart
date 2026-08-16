import 'dart:async';

/// Exception thrown when a task is cancelled or superseded by debouncing.
class TaskCancelledException implements Exception {
  final String message;

  TaskCancelledException([this.message = 'Task was cancelled']);

  @override
  String toString() => 'TaskCancelledException: $message';
}

class _QueuedTask<T> {
  final String key;
  final Future<T> Function() task;
  final Completer<T> completer;
  final int retries;
  final Duration? debounce;
  Timer? debounceTimer;
  bool isCancelled = false;

  _QueuedTask({
    required this.key,
    required this.task,
    required this.completer,
    required this.retries,
    this.debounce,
  });

  void cancel([String message = 'Task was cancelled']) {
    if (isCancelled || completer.isCompleted) return;
    isCancelled = true;
    debounceTimer?.cancel();
    debounceTimer = null;
    completer.completeError(TaskCancelledException(message));
  }

  Future<void> run() async {
    int attempts = 0;
    while (true) {
      if (isCancelled) return;
      try {
        final result = await task();
        if (!isCancelled && !completer.isCompleted) {
          completer.complete(result);
        }
        return;
      } catch (error, stackTrace) {
        attempts++;
        if (attempts <= retries && !isCancelled) {
          final backoffMs = 50 * (1 << (attempts - 1));
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        } else {
          if (!isCancelled && !completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
          return;
        }
      }
    }
  }
}

/// A queue that manages concurrent asynchronous operations with key-based debouncing,
/// cancellation, and retry logic.
class AsyncTaskQueue {
  final int maxConcurrentTasks;
  int _runningTasks = 0;

  final Map<String, _QueuedTask<dynamic>> _debouncingTasks = {};
  final List<_QueuedTask<dynamic>> _waitingQueue = [];

  AsyncTaskQueue({required this.maxConcurrentTasks})
      : assert(maxConcurrentTasks > 0, 'maxConcurrentTasks must be greater than 0');

  /// Enqueues a [task] with a specified [key].
  ///
  /// If [debounce] is provided and greater than [Duration.zero], the task will wait
  /// for the debounce period before entering the execution queue. If another task
  /// with the same [key] is enqueued before execution starts, the previous task
  /// is cancelled with a [TaskCancelledException].
  ///
  /// If the task fails, it will be retried up to [retries] times with exponential backoff.
  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    final completer = Completer<T>();

    // Cancel any currently debouncing task with the same key
    if (_debouncingTasks.containsKey(key)) {
      final existing = _debouncingTasks.remove(key);
      existing?.cancel('Task replaced by debounce');
    }

    final queuedTask = _QueuedTask<T>(
      key: key,
      task: task,
      completer: completer,
      retries: retries,
      debounce: debounce,
    );

    if (debounce != null && debounce > Duration.zero) {
      _debouncingTasks[key] = queuedTask;
      queuedTask.debounceTimer = Timer(debounce, () {
        _debouncingTasks.remove(key);
        if (!queuedTask.isCancelled) {
          _waitingQueue.add(queuedTask);
          _processQueue();
        }
      });
    } else {
      _waitingQueue.add(queuedTask);
      _processQueue();
    }

    return completer.future;
  }

  /// Cancels a pending or debouncing task with the specified [key].
  void cancelTask(String key) {
    final debounced = _debouncingTasks.remove(key);
    debounced?.cancel('Task was manually cancelled');

    _waitingQueue.removeWhere((task) {
      if (task.key == key) {
        task.cancel('Task was manually cancelled');
        return true;
      }
      return false;
    });
  }

  /// Cancels all pending and debouncing tasks in the queue.
  void cancelAll() {
    for (final task in _debouncingTasks.values) {
      task.cancel('Task cancelled by cancelAll');
    }
    _debouncingTasks.clear();

    for (final task in _waitingQueue) {
      task.cancel('Task cancelled by cancelAll');
    }
    _waitingQueue.clear();
  }

  void _processQueue() {
    while (_runningTasks < maxConcurrentTasks && _waitingQueue.isNotEmpty) {
      final nextTask = _waitingQueue.removeAt(0);
      if (nextTask.isCancelled) continue;

      _runningTasks++;
      nextTask.run().whenComplete(() {
        _runningTasks--;
        _processQueue();
      });
    }
  }
}
