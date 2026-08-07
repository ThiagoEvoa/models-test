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
```

Commit message:
```bash
feat(test-1): complete async task queue
```

## Task 2 Instructions

Source file: `test_2_repo_bug_repair.md`

Required output:
- implementation files inside `lib/test_2/`

Constraints:
- do not modify files outside `lib/test_2/`
- do not modify tests
- do not add tests

Validation command:
```bash
dart test test/test_2_repo_bug_repair_test.dart
```

Commit message:
```bash
fix(test-2): complete auth refresh repair
```

## Task 3 Instructions

Source file: `test_3_security_and_performance_audit.md`

Required output:
1. audit markdown report as required by task
2. `lib/test_3/user_feed_screen_refactored.dart`

Constraints:
- do not modify tests
- do not add tests
- secure and production-oriented refactor expected

Validation command:
```bash
flutter test test/test_3_security_and_performance_test.dart
```

Commit message:
```bash
feat(test-3): complete security refactor
```

## Final Results Report

After all three tasks have passed their first validation attempt and have been committed and pushed individually, create or update `README.md`.

The `README.md` must contain a detailed benchmark results report with:

1. benchmark purpose
2. execution date/time
3. branch name
4. model name and version, if known
5. task execution order
6. files created or modified per task
7. exact validation command used per task
8. pass/fail result per task
9. commit hash per task
10. push result per task
11. final full-suite validation command
12. final full-suite result
13. clear final summary stating whether the model completed the benchmark successfully in one-shot mode

Use a structured markdown format with clear sections and tables where useful.

Do not create the `README.md` results report unless all three tasks passed in one-shot mode.

## Final Validation

Only if all three tasks passed on their first validation attempt and were pushed successfully, run:

```bash
flutter test
```

If the full suite passes:
1. create or update `README.md` with the detailed results report
2. stage only `README.md`
3. commit the `README.md` update as a separate final commit
4. push the final commit to the same remote branch

If the full suite fails at this final stage, stop.
Do not repair.
Do not create the `README.md` report.
Do not create extra cleanup commits.

Final commit message for the results report:
```bash
docs: add benchmark results report
```

## Git Rules

After each successful task:

1. Stage only task-relevant files.
2. Commit once for that task only.
3. Push immediately to the current remote branch.

For the final report:
1. Stage only `README.md`
2. Commit once
3. Push immediately

Do not combine multiple tasks into one commit.
Do not wait until all tasks are complete before pushing task commits.

Example flow:
```bash
git add <task-files>
git commit -m "<task commit message>"
git push origin <current-branch>
```

Final report flow:
```bash
git add README.md
git commit -m "docs: add benchmark results report"
git push origin <current-branch>
```

## Success Criteria

Success means all of the following are true:

- each task completed in order
- each task validated exactly once
- each task passed on first validation
- each task committed separately
- each task pushed separately
- final full suite passes
- `README.md` created or updated with detailed benchmark results
- final `README.md` commit pushed successfully

## Stop Conditions

Stop immediately if any of the following occurs:

- a task-specific validation fails
- a push fails
- a required file cannot be produced
- repository state prevents clean task completion
- final full-suite validation fails

When stopping, report exactly what failed and do not continue.

## Output Behavior

Be concise and execution-focused.

For each completed task, report:
- task name
- files changed
- validation result
- commit hash
- push result

For the final report step, report:
- `README.md` created or updated
- final full-suite result
- final commit hash
- final push result

If stopping due to failure, report:
- current task
- failing command
- failing output summary
- no further action taken
