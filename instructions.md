# instructions.md

Read this file completely, then execute it without asking for clarification.

## Objective

Complete this repository benchmark as an autonomous coding task.

You must complete tasks sequentially, one at a time, and push each completed task to the current remote branch before starting the next one.

This benchmark is intended to evaluate first-pass coding ability in a realistic development workflow. Optimize for correctness on the first attempt.

In addition to completing the tasks, you must create or update `README.md` with a detailed results report at the end of the run.

## Execution Order

Complete tasks in this exact order:

1. `test_1_algorithmic_synthesis.md`
2. `test_2_repo_bug_repair.md`
3. `test_3_security_and_performance_audit.md`

Do not skip, reorder, combine, or parallelize tasks.

## One-Shot Policy

Treat each task as a one-shot attempt.

1. Implement the task.
2. Run the task-specific validation command once.
3. If the validation passes, commit and push the task.
4. If the validation fails, stop immediately.

Do not repair failed attempts.
Do not retry failed tasks.
Do not continue to the next task after a failed validation.

## Global Rules

1. Read the current task markdown file fully before making changes.
2. Modify only files required for the current task.
3. Do not modify:
   - any test files
   - any task markdown prompt files
   - files for future tasks before their turn
   - unrelated repository files
4. Do not add extra files unless the task explicitly requires them, except for the required `README.md` results report.
5. Do not add new dependencies unless absolutely necessary.
6. Do not ask for clarification. Make reasonable assumptions and proceed.
7. Prefer minimal, correct, production-quality implementations.
8. Do not begin the next task until the current task has been:
   - implemented
   - validated successfully
   - committed
   - pushed to the remote branch

## Required Per-Task Workflow

For each task, follow this exact sequence:

1. Read the task markdown file.
2. Implement only the required output for that task.
3. Run the task-specific validation command exactly once.
4. If validation fails, stop immediately.
5. If validation succeeds:
   - stage only files relevant to that task
   - create exactly one commit for that task
   - push that commit to the current remote branch immediately
6. Only after push succeeds, begin the next task.

## Task 1 Instructions

Source file: `test_1_algorithmic_synthesis.md`

Required output:
- `lib/test_1/async_task_queue.dart`

Constraints:
- pure Dart only
- no external packages beyond what task allows
- do not add tests

Validation command:
```bash
dart test test/test_1_async_task_queue_test.dart
