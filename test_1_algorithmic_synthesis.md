# Test 1: Algorithmic Synthesis & Edge-Case Handling (Dart)

## Prompt to Give to the Model

Write a pure Dart class named `AsyncTaskQueue` inside `lib/test_1/async_task_queue.dart` that manages concurrent asynchronous operations with key-based debouncing and cancellation.

### Requirements:
1. **Concurrency Limit**: The constructor must accept `int maxConcurrentTasks`. At no point should more than `maxConcurrentTasks` be running simultaneously.
2. **Key-Based Debouncing**:
   - `Future<T> enqueue<T>({required String key, required Future<T> Function() task, Duration? debounce, int retries = 0})`
   - If a new task with the same `key` is enqueued within the `debounce` window before execution starts, the previous task with that key must be cancelled and replaced by the new task.
   - The Future returned for the cancelled task should complete with a `TaskCancelledException`.
3. **Cancellation Token**:
   - Provide a method `cancelTask(String key)` to manually cancel a pending or debouncing task.
   - Provide `cancelAll()` to cancel all pending tasks and reject their Futures with `TaskCancelledException`.
4. **Retry Logic**:
   - Accept an optional `int retries = 0` in `enqueue`.
   - If `task()` throws an exception, retry up to `retries` times with exponential backoff before bubbling the error up to the caller.
5. **No External Packages**: Use only `dart:async` primitives (`Completer`, `Timer`, `StreamController`, etc.).

### CRITICAL INSTRUCTIONS FOR THE MODEL:
- Do NOT write any unit tests, integration tests, or test files. The test suite is already provided in the repository.
- Provide ONLY the implementation code file at `lib/test_1/async_task_queue.dart`.
