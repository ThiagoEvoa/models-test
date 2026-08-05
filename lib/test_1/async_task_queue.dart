import 'dart:async';

class TaskCancelledException implements Exception {
  final String message;
  TaskCancelledException([this.message = 'Task was cancelled']);

  @override
  String toString() => 'TaskCancelledException: $message';
}

class AsyncTaskQueue {
  final int maxConcurrentTasks;

  AsyncTaskQueue({required this.maxConcurrentTasks});

  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() task,
    Duration? debounce,
    int retries = 0,
  }) async {
    throw UnimplementedError('Model must implement enqueue()');
  }

  void cancelTask(String key) {
    throw UnimplementedError('Model must implement cancelTask()');
  }

  void cancelAll() {
    throw UnimplementedError('Model must implement cancelAll()');
  }
}
