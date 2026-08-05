import 'dart:async';
import 'package:test/test.dart';
import '../lib/test_1/async_task_queue.dart';

void main() {
  group('AsyncTaskQueue Evaluation (Gemini 3.6 Flash Implementation)', () {
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
