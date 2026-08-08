# instructions.md

Read this file completely, then execute it without asking for clarification.

> **CRITICAL: This benchmark evaluates ONE-SHOT coding ability. You get exactly ONE attempt per task. Do NOT retry, repair, fix up, or iterate on any task or commit. Any form of retry or iteration is a benchmark failure.**

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

**This is the most important rule in this benchmark.** Treat each task as a one-shot attempt. There are zero second chances.

1. Implement the task.
2. Run the task-specific validation command **exactly once**.
3. Commit and push the task **regardless of whether validation passes or fails**.
4. If the validation fails, stop after pushing and do not continue to the next task.

Do not repair failed attempts.
Do not retry failed tasks.
Do not continue to the next task after a failed validation.
Do not go back and fix a previous task after moving on.
Do not create additional commits for a task that was already committed.
Do not update, amend, or create follow-up commits for any previously pushed commit.

### Expected Commit Count

The total number of commits you create on this branch must be **exactly**:

- **1 commit per completed task** (using the exact commit message specified)
- **1 final commit** for `README.md` (using `docs: add benchmark results report`)

If all 3 tasks pass: exactly **4 commits** total.
If you stop after task N fails: exactly **N + 1 commits** total (N task commits + 1 README commit).

Any other number of commits is a benchmark violation.

### Anti-Patterns (Violations)

The following behaviors are **explicit benchmark failures**. Do not do any of these:

1. **Iterative self-correction**: Creating multiple commits that update, fix, or revise the same file or the same task output. Example: committing `README.md`, then committing "update README", then "fix README" — this is a violation.
2. **Skipping task commits**: Jumping straight to the `README.md` report without first committing the task implementation files. Every task must produce exactly one task commit before the final README commit.
3. **Out-of-order execution**: Committing the `README.md` report before completing all reachable tasks, then continuing to execute more tasks afterward. The README commit must always be the **very last commit**.
4. **Continuing after failure**: Running validation, seeing it fail, then modifying code and re-running validation. You run validation once. If it fails, you commit what you have and stop.
5. **Amending or squashing**: Using `git commit --amend`, `git rebase`, or any history-rewriting command.
6. **Non-standard commit messages**: Using any commit message other than the exact ones specified per task.
7. **Extra cleanup commits**: Creating commits like "pushing leftovers", "final cleanup", "fix typo", etc.

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
4. Regardless of the validation result:
   - stage only files relevant to that task
   - create exactly one commit for that task
   - push that commit to the current remote branch immediately
5. If validation failed, stop after pushing. Do not begin the next task.
6. Only if validation passed and push succeeded, begin the next task.

## Task 1 Instructions

Source file: `test_1_algorithmic_synthesis.md`

Required output:
- `lib/test_1/async_task_queue.dart`

Constraints:
- pure Dart only
- no external packages beyond what task allows
- do not add tests

Validation command (run exactly once, do not re-run):
```bash
dart test test/test_1_async_task_queue_test.dart
```

Commit message (use this exact message, no other):
```bash
feat(test-1): complete async task queue
```

> **ONE-SHOT REMINDER**: Implement → validate once → commit → push. If validation fails, commit and push anyway, then skip to the README report. Do not fix or retry.

## Task 2 Instructions

Source file: `test_2_repo_bug_repair.md`

Required output:
- implementation files inside `lib/test_2/`

Constraints:
- do not modify files outside `lib/test_2/`
- do not modify tests
- do not add tests

Validation command (run exactly once, do not re-run):
```bash
dart test test/test_2_repo_bug_repair_test.dart
```

Commit message (use this exact message, no other):
```bash
fix(test-2): complete auth refresh repair
```

> **ONE-SHOT REMINDER**: Implement → validate once → commit → push. If validation fails, commit and push anyway, then skip to the README report. Do not fix or retry.

## Task 3 Instructions

Source file: `test_3_security_and_performance_audit.md`

Required output:
1. audit markdown report as required by task
2. `lib/test_3/user_feed_screen_refactored.dart`

Constraints:
- do not modify tests
- do not add tests
- secure and production-oriented refactor expected

Validation command (run exactly once, do not re-run):
```bash
flutter test test/test_3_security_and_performance_test.dart
```

Commit message (use this exact message, no other):
```bash
feat(test-3): complete security refactor
```

> **ONE-SHOT REMINDER**: Implement → validate once → commit → push. If validation fails, commit and push anyway, then skip to the README report. Do not fix or retry.

## Final Results Report

**The `README.md` commit must be the very last commit on the branch. No commits may come after it.**

After all tasks have been attempted (regardless of pass or fail), create or update `README.md`.
Do not create the `README.md` commit until all reachable tasks have been committed and pushed.
Do not create any commits after the `README.md` commit. Once `README.md` is committed and pushed, the benchmark run is over.

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
11. final full-suite validation command (if reached)
12. final full-suite result (if reached)
13. clear final summary stating whether the model completed the benchmark successfully in one-shot mode

Use a structured markdown format with clear sections and tables where useful.

Always create the `README.md` results report, even if one or more tasks failed.

## Final Validation

Only if all three tasks passed on their first validation attempt and were pushed successfully, run:

```bash
flutter test
```

Regardless of the full suite result:
1. create or update `README.md` with the detailed results report (including the final suite result)
2. stage only `README.md`
3. commit the `README.md` update as a separate final commit
4. push the final commit to the same remote branch
5. **STOP. Do not create any more commits. The benchmark is complete.**

Do not repair failed tasks or retry.
Do not create extra cleanup commits.
Do not update `README.md` after it has been committed — no "update", "fix", or "amend" commits.

Final commit message for the results report (use this exact message, no other):
```bash
docs: add benchmark results report
```

This must be the **last commit** on the branch. Any commit after this is a benchmark violation.

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

Success means **all** of the following are true:

- each task completed in order
- each task validated exactly once (not zero times, not twice — exactly once)
- each task passed on first validation
- each task committed separately with exactly the specified commit message
- each task pushed separately and immediately after commit
- final full suite passes
- `README.md` created or updated with detailed benchmark results
- final `README.md` commit pushed successfully
- total commit count matches expected (see "Expected Commit Count" above)
- `README.md` commit is the last commit on the branch
- no iterative, fix-up, amend, or cleanup commits exist

## Stop Conditions

Stop immediately (after committing and pushing the current task) if any of the following occurs:

- a task-specific validation fails
- a required file cannot be produced
- repository state prevents clean task completion

**When stopping due to a failed validation:**
1. Commit the task (with the failed implementation) using the exact specified commit message.
2. Push that commit.
3. Skip all remaining tasks — do not attempt them.
4. Create and push the `README.md` report as the very last commit.
5. **STOP. Do not go back. Do not fix anything. Do not create additional commits.**

Always push whatever was completed before stopping.
Always create and push the `README.md` report as the final step, even when stopping early.
Only stop without pushing if a push itself fails.

When stopping, report exactly what failed and do not continue to the next task.

## Commit Count Self-Check

Before pushing the final `README.md` commit, verify your commit count:

```bash
git rev-list --count <base-commit>..HEAD
```

Where `<base-commit>` is the commit that existed before you started (the tip of the branch when you began).

- If all 3 tasks were attempted: count must be **3** (about to become 4 with README).
- If stopped after task N failure: count must be **N** (about to become N+1 with README).

If the count does not match, you have violated the one-shot policy. Do not attempt to fix it — just note the discrepancy in your `README.md` report and stop.

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
- confirmation that the task was still committed and pushed
- confirmation that `README.md` was created and pushed as the final step
