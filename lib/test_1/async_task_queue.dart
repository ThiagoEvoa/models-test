import 'dart:async';

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
  final Duration? debounceDuration;
  final int retries;
  Timer? debounceTimer;
  bool isCancelled = false;

  _QueuedTask({
    required this.key,
    required this.task,
    required this.completer,
    this.debounceDuration,
    this.retries = 0,
  });
}

class AsyncTaskQueue {
  final int maxConcurrentTasks;
  int _activeTasksCount = 0;

  final Map<String, _QueuedTask<dynamic>> _debouncingTasks = {};
  final List<_QueuedTask<dynamic>> _pendingQueue = [];

  AsyncTaskQueue({required this.maxConcurrentTasks}) {
    if (maxConcurrentTasks <= 0) {
      throw ArgumentError('maxConcurrentTasks must be greater than 0');
    }
  }

  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) {
    final completer = Completer<T>();

    if (_debouncingTasks.containsKey(key)) {
      final existingTask = _debouncingTasks.remove(key)!;
      existingTask.debounceTimer?.cancel();
      existingTask.isCancelled = true;
      if (!existingTask.completer.isCompleted) {
        existingTask.completer.completeError(
          TaskCancelledException('Cancelled due to debounce re-enqueue for key: $key'),
        );
      }
    }

    _pendingQueue.removeWhere((item) {
      if (item.key == key) {
        item.isCancelled = true;
        if (!item.completer.isCompleted) {
          item.completer.completeError(
            TaskCancelledException('Cancelled due to debounce re-enqueue for key: $key'),
          );
        }
        return true;
      }
      return false;
    });

    final queuedTask = _QueuedTask<T>(
      key: key,
      task: task,
      completer: completer,
      debounceDuration: debounce,
      retries: retries,
    );

    if (debounce != null && debounce > Duration.zero) {
      _debouncingTasks[key] = queuedTask;
      queuedTask.debounceTimer = Timer(debounce, () {
        if (_debouncingTasks[key] == queuedTask) {
          _debouncingTasks.remove(key);
          _scheduleTask(queuedTask);
        }
      });
    } else {
      _scheduleTask(queuedTask);
    }

    return completer.future;
  }

  void _scheduleTask(_QueuedTask<dynamic> task) {
    if (task.isCancelled) return;
    _pendingQueue.add(task);
    _processQueue();
  }

  void _processQueue() {
    while (_activeTasksCount < maxConcurrentTasks && _pendingQueue.isNotEmpty) {
      final nextTask = _pendingQueue.removeAt(0);
      if (nextTask.isCancelled) continue;

      _activeTasksCount++;
      _executeTask(nextTask);
    }
  }

  Future<void> _executeTask(_QueuedTask<dynamic> taskItem) async {
    int attempts = 0;
    final maxAttempts = taskItem.retries + 1;

    while (attempts < maxAttempts) {
      attempts++;
      if (taskItem.isCancelled) break;

      try {
        final result = await taskItem.task();
        if (!taskItem.isCancelled && !taskItem.completer.isCompleted) {
          taskItem.completer.complete(result);
        }
        break;
      } catch (e, st) {
        if (attempts >= maxAttempts) {
          if (!taskItem.isCancelled && !taskItem.completer.isCompleted) {
            taskItem.completer.completeError(e, st);
          }
        } else {
          final backoffMs = 50 * (1 << (attempts - 1));
          await Future.delayed(Duration(milliseconds: backoffMs));
        }
      }
    }

    _activeTasksCount--;
    _processQueue();
  }

  void cancelTask(String key) {
    if (_debouncingTasks.containsKey(key)) {
      final task = _debouncingTasks.remove(key)!;
      task.debounceTimer?.cancel();
      task.isCancelled = true;
      if (!task.completer.isCompleted) {
        task.completer.completeError(TaskCancelledException('Task $key manually cancelled.'));
      }
    }

    _pendingQueue.removeWhere((item) {
      if (item.key == key) {
        item.isCancelled = true;
        if (!item.completer.isCompleted) {
          item.completer.completeError(TaskCancelledException('Task $key manually cancelled.'));
        }
        return true;
      }
      return false;
    });
  }

  void cancelAll() {
    for (final key in _debouncingTasks.keys.toList()) {
      cancelTask(key);
    }
    for (final task in _pendingQueue.toList()) {
      task.isCancelled = true;
      if (!task.completer.isCompleted) {
        task.completer.completeError(TaskCancelledException('All tasks cancelled.'));
      }
    }
    _pendingQueue.clear();
  }
}
