import 'dart:async';

/// Exception thrown when a task in [AsyncTaskQueue] is cancelled due to
/// debouncing or explicit cancellation.
class TaskCancelledException implements Exception {
  final String message;
  TaskCancelledException([this.message = 'Task was cancelled']);

  @override
  String toString() => 'TaskCancelledException: $message';
}

/// A queue that manages concurrent asynchronous operations with key-based
/// debouncing, cancellation, and retry capabilities.
class AsyncTaskQueue {
  final int maxConcurrentTasks;

  int _activeTasks = 0;
  final Map<String, _TaskItem<dynamic>> _pendingTasks = {};
  final List<_TaskItem<dynamic>> _readyQueue = [];

  AsyncTaskQueue({required this.maxConcurrentTasks});

  /// Enqueues a task with a given [key].
  ///
  /// If another task with the same [key] is already pending or debouncing,
  /// the previous task will be cancelled with a [TaskCancelledException].
  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    // If a task with the same key is pending or debouncing, cancel it.
    if (_pendingTasks.containsKey(key)) {
      final existingTask = _pendingTasks.remove(key)!;
      _cancelItem(existingTask);
    }

    final completer = Completer<T>();
    final taskItem = _TaskItem<T>(
      key: key,
      task: task,
      debounce: debounce,
      retries: retries,
      completer: completer,
    );

    _pendingTasks[key] = taskItem;

    if (debounce != null && debounce > Duration.zero) {
      taskItem.timer = Timer(debounce, () {
        if (taskItem.isCancelled) return;
        _moveToReady(taskItem);
      });
    } else {
      _moveToReady(taskItem);
    }

    return completer.future;
  }

  void _moveToReady(_TaskItem<dynamic> item) {
    if (item.isCancelled) return;
    _readyQueue.add(item);
    _processQueue();
  }

  void _processQueue() {
    while (_activeTasks < maxConcurrentTasks && _readyQueue.isNotEmpty) {
      final item = _readyQueue.removeAt(0);
      if (item.isCancelled) continue;

      if (_pendingTasks[item.key] == item) {
        _pendingTasks.remove(item.key);
      }

      _activeTasks++;
      _runTask(item);
    }
  }

  Future<void> _runTask(_TaskItem<dynamic> item) async {
    try {
      int attempt = 0;
      while (true) {
        if (item.isCancelled) break;
        try {
          final result = await item.task();
          if (!item.isCancelled && !item.completer.isCompleted) {
            item.completer.complete(result);
          }
          break;
        } catch (e, st) {
          if (item.isCancelled) break;
          if (attempt >= item.retries) {
            if (!item.completer.isCompleted) {
              item.completer.completeError(e, st);
            }
            break;
          }
          attempt++;
          await Future.delayed(Duration(milliseconds: 50 * (1 << (attempt - 1))));
        }
      }
    } finally {
      _activeTasks--;
      _processQueue();
    }
  }

  /// Cancels a pending or debouncing task with the specified [key].
  void cancelTask(String key) {
    final item = _pendingTasks.remove(key);
    if (item != null) {
      _cancelItem(item);
    }
  }

  /// Cancels all pending or debouncing tasks.
  void cancelAll() {
    final items = _pendingTasks.values.toList();
    _pendingTasks.clear();
    for (final item in items) {
      _cancelItem(item);
    }
  }

  void _cancelItem(_TaskItem<dynamic> item) {
    item.timer?.cancel();
    item.isCancelled = true;
    _readyQueue.remove(item);
    if (!item.completer.isCompleted) {
      item.completer.completeError(TaskCancelledException());
    }
  }
}

class _TaskItem<T> {
  final String key;
  final Future<T> Function() task;
  final Duration? debounce;
  final int retries;
  final Completer<T> completer;
  Timer? timer;
  bool isCancelled = false;

  _TaskItem({
    required this.key,
    required this.task,
    required this.debounce,
    required this.retries,
    required this.completer,
  });
}
