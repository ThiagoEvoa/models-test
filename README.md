# models-test — Benchmark Results Report

## 1. Benchmark Purpose

One-shot, single-attempt coding benchmark that evaluates an autonomous model on a
realistic, strictly-segmented development workflow across three sequential tasks
(Dart algorithmic synthesis, repo bug repair, and a security/performance
audit/refactor). The defining constraint is the **one-shot policy**: each task is
implemented, validated **exactly once**, committed, and pushed. A failed
validation must **not** be repaired or retried — the failed attempt is committed
as-is, execution stops at that point, and the remaining tasks are skipped. A
final `README.md` results report is always produced as the very last commit.

## 2. Execution Date/Time

- **Run started (UTC):** 2026-08-16T10:04Z

## 3. Branch

- **Local & remote branch:** `qwen3.8-27b-mlx`
- **Remote:** `origin` → `https://github.com/ThiagoEvoa/models-test.git`
- **Base commit (branch tip before run):** `3ad3d00`

## 4. Model Name / Version

- **Branch-derived model identifier:** `qwen3.8-27b-mlx`
- Exact model version string: not known from within the runtime; the branch
   name is the authoritative benchmark identifier (`mlx` runtime variant, 27B
   parameter class).

## 5. Task Execution Order

Tasks are executed strictly in sequence, one at a time:

1. `test_1_algorithmic_synthesis.md`
2. `test_2_repo_bug_repair.md`
3. `test_3_security_and_performance_audit.md`

Execution **stopped after Task 1** because Task 1's sole validation attempt
failed. Per the one-shot policy, Tasks 2 and 3 were **not** attempted.

## 6. Files Created or Modified Per Task

| Task | Required Output | Files Changed |
|------|-----------------|---------------|
| 1 | `lib/test_1/async_task_queue.dart` | `lib/test_1/async_task_queue.dart` (created) |
| 2 | `lib/test_2/` implementation | **Not attempted** (stopped after Task 1 failure) |
| 3 | audit report + `lib/test_3/user_feed_screen_refactored.dart` | **Not attempted** (stopped after Task 1 failure) |
| Final | `README.md` | `README.md` (created/updated) |

## 7. Validation Commands Per Task

| Task | Exact Command |
|------|---------------|
| 1 | `dart test test/test_1_async_task_queue_test.dart` |
| 2 | `dart test test/test_2_repo_bug_repair_test.dart` (n/a — skipped) |
| 3 | `flutter test test/test_3_security_and_performance_test.dart` (n/a — skipped) |
| Final full-suite | `flutter test` (n/a — not reachable; required all 3 tasks to pass) |

## 8. Pass / Fail Result Per Task

| Task | Result |
|------|--------|
| 1 | **FAILED** on the single permitted validation attempt |
| 2 | **NOT RUN** (skipped per one-shot stop rule) |
| 3 | **NOT RUN** (skipped per one-shot stop rule) |

## 9. Commit Hash Per Task

| Task | Commit | Message |
|------|--------|---------|
| 1 | `4ed9788` | `feat(test-1): complete async task queue` |
| 2 | _(not created)_ | — |
| 3 | _(not created)_ | — |
| Final README | _(created below)_ | `docs: add benchmark results report` |

## 10. Push Result Per Task

| Task | Push |
|------|------|
| 1 | **SUCCESS** — `git push -u origin qwen3.8-27b-mlx` created new remote branch `origin/qwen3.8-27b-mlx` |
| 2 | n/a |
| 3 | n/a |

## 11. Final Full-Suite Validation

- **Command:** `flutter test`
- **Status:** **NOT RUN.** The full-suite command is only permitted when all
   three tasks pass on first attempt and are pushed. Task 1 failed its single
   attempt, so the full suite was not reached.

## 12. Final Full-Suite Result

N/A — not reachable.

## 13. Final Summary

**The model did NOT complete the benchmark successfully in one-shot mode.**

Task 1 (`AsyncTaskQueue`) was implemented at `lib/test_1/async_task_queue.dart`
but the implementation produced a **compile-time failure** on its single
permitted validation attempt:

- Root cause: `lib/test_1/async_task_queue.dart` used `Queue<_PendingTask>`
    (from `dart:collection`) but only imported `dart:async`, so `Queue` was
    unresolved. This cascade produced a load/compile error that prevented the
    5 test cases from running:
    - `Error: Type 'Queue' not found.` (line 27)
    - `Error: 'Queue' isn't a type.` / `Method not found: 'Queue'`
    - `Too few positional arguments: 1 required, 0 given.` at each
       `queue.enqueue(...)` call site in the test (the load error propagated to
       the test signature, causing the argument-count diagnostics).
- Validation outcome: `00:00 +0 -1: Some tests failed.` (loading
      `test/test_1_async_task_queue_test.dart` [E]).

Per the one-shot policy, the broken Task 1 was committed (`4ed9788`) and
pushed as-is. Because Task 1's single validation attempt failed, execution
stopped: Tasks 2 and 3 were **not** started, and the full suite was
**not** run. This `README.md` is the final commit.

### Commit-Count Self-Check

- Base commit: `3ad3d00`
- After Task 1: `git rev-list --count 3ad3d00..HEAD` = **1**
- Expected for a stop-after-Task-1-failure: `N + 1 = 1 + 1 = 2` total
     (1 task commit + 1 README report). This report is the 2nd commit,
     matching the expected count for the early-stop scenario.

### Anti-Pattern Compliance

- One single validation run per task: **yes** (Task 1 validated exactly once).
- No repair/retry of the failed attempt: **yes** (implementation was not
     re-edited after the failing validation).
- No amend / squash / history rewrite: **yes**.
- Exact commit messages used: **yes**.
- README is the last commit: **yes**.
