# Test 1: Algorithmic Synthesis & Edge-Case Handling (Dart)

## Objective
Evaluate the model's ability to write production-grade, asynchronous Dart code with precise concurrency control, state management, and edge-case resilience without using external packages.

---

## Scenario: Concurrent Debounced Async Task Queue (`AsyncTaskQueue`)

You need to build an asynchronous task manager in pure Dart that queues tasks, debounces execution per task key, enforces a maximum concurrency limit, supports task cancellation, and handles failures with retry policies.

---

## Prompt to Give to the Model

```markdown
Write a pure Dart class named `AsyncTaskQueue` that manages concurrent asynchronous operations with key-based debouncing and cancellation.

### Requirements:
1. **Concurrency Limit**: The constructor must accept `int maxConcurrentTasks`. At no point should more than `maxConcurrentTasks` be running simultaneously.
2. **Key-Based Debouncing**:
   - `Future<T> enqueue<T>({required String key, required Future<T> Function() task, Duration? debounce})`
   - If a new task with the same `key` is enqueued within the `debounce` window before execution starts, the previous task with that key must be cancelled and replaced by the new task.
   - The Future returned for the cancelled task should complete with a `TaskCancelledException`.
3. **Cancellation Token**:
   - Provide a method `cancelTask(String key)` to manually cancel a pending or debouncing task.
   - Provide `cancelAll()` to cancel all pending tasks and reject their Futures.
4. **Retry Logic**:
   - Accept an optional `int retries = 0` in `enqueue`.
   - If `task()` throws an exception, retry up to `retries` times with exponential backoff before bubbling the error up to the caller.
5. **No External Packages**: Use only `dart:async` primitives (`Completer`, `Timer`, `StreamController`, etc.).

Provide the complete, self-contained implementation with clean documentation and exception definitions.
```

---

## Hidden Test Suite (Dart Unit Tests)

Use the following `test/async_task_queue_test.dart` to validate the model's output:

```dart
import 'dart:async';
import 'package:test/test.dart';
import 'path_to_model_solution/async_task_queue.dart';

void main() {
  group('AsyncTaskQueue Evaluation', () {
    late AsyncTaskQueue queue;

    setUp(() {
      queue = AsyncTaskQueue(maxConcurrentTasks: 2);
    });

    test('1. Enforces concurrency limit (max 2 concurrent tasks)', () async {
      int activeTasks = 0;
      int maxSeenActive = 0;

      Future<void> makeTask(int id) async {
        await queue.enqueue(
          key: 'task_$id',
          task: () async {
            activeTasks++;
            if (activeTasks > maxSeenActive) maxSeenActive = activeTasks;
            await Future.delayed(const Duration(milliseconds: 50));
            activeTasks--;
          },
        );
      }

      await Future.wait([makeTask(1), makeTask(2), makeTask(3), makeTask(4)]);
      expect(maxSeenActive, lessThanOrEqualTo(2));
    });

    test('2. Debounces rapid invocations with matching keys', () async {
      final results = <String>[];

      final f1 = queue.enqueue(
        key: 'search',
        debounce: const Duration(milliseconds: 100),
        task: () async => 'Result 1',
      );

      await Future.delayed(const Duration(milliseconds: 30));

      final f2 = queue.enqueue(
        key: 'search',
        debounce: const Duration(milliseconds: 100),
        task: () async => 'Result 2',
      );

      expect(f1, throwsA(isA<TaskCancelledException>()));
      expect(await f2, equals('Result 2'));
    });

    test('3. Edge Case: Enqueue with duration 0 or null executes normally', () async {
      final res = await queue.enqueue(
        key: 'immediate',
        task: () async => 42,
      );
      expect(res, equals(42));
    });

    test('4. Retries failed tasks with backoff', () async {
      int attempts = 0;

      final res = await queue.enqueue(
        key: 'retry_test',
        retries: 2,
        task: () async {
          attempts++;
          if (attempts < 3) throw Exception('Temporary failure');
          return 'Success on attempt $attempts';
        },
      );

      expect(attempts, equals(3));
      expect(res, equals('Success on attempt 3'));
    });

    test('5. Manual cancelAll rejects pending items', () async {
      final f1 = queue.enqueue(
        key: 'pending_1',
        debounce: const Duration(milliseconds: 200),
        task: () async => 'Done',
      );

      queue.cancelAll();

      expect(f1, throwsA(isA<TaskCancelledException>()));
    });
  });
}
```

---

## Evaluation Rubric & Scoring (Pass Criteria)

| Metric | Score Weight | Pass Criteria |
|---|---|---|
| **Functional Correctness** | 50% | Passes all 5 unit tests without unhandled exceptions or state leaks. |
| **Concurrency Guarding** | 20% | Correctly uses `Completer` or queue locking to guarantee `maxConcurrentTasks` is never exceeded. |
| **Debounce & Timer Safety** | 15% | Properly disposes active `Timer` instances when new tasks arrive with the same key. |
| **Error Propagation** | 15% | Exceptions in tasks complete the `Completer` with error rather than crashing the queue loop. |
