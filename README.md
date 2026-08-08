# Benchmark Results Report

## Purpose

Evaluate one-shot coding ability across algorithmic synthesis, bug repair, and security/performance auditing tasks in a realistic Dart/Flutter development workflow. Model receives exactly ONE attempt per task with zero retries or iterations allowed.

## Execution Details

- **Execution Date/Time**: 2025-06-18
- **Branch**: `qwen3.6-27b-mlx`
- **Model**: Qwen 3.6 27B (MLX)

---

## Task Execution Order & Results

### Task 1: Algorithmic Synthesis & Edge-Case Handling

| Field | Value |
|---|---|
| **Source** | `test_1_algorithmic_synthesis.md` |
| **Output File** | `lib/test_1/async_task_queue.dart` |
| **Validation Command** | `dart test test/test_1_async_task_queue_test.dart` |
| **Result** | ❌ FAILED |
| **Commit Hash** | `b095538ad670a15a0166458bd62e15f4b759c72f` |
| **Push Result** | ✅ Pushed to `qwen3.6-27b-mlx` |

**Failure Summary**: Multiple compilation errors:
- `final?` syntax not valid in Dart (not supported syntax)
- Missing methods on `_PendingTask`: `complete()` and `completeError()` — should have been `completer.complete()` and `completer.completeError()`
- These are Dart syntax/semantic errors preventing test execution

**Files Created**:
- `lib/test_1/async_task_queue.dart` — AsyncTaskQueue implementation with concurrency limiting, key-based debouncing, cancellation tokens, and retry logic with exponential backoff

---

### Task 2: Repo Bug Repair

| Field | Value |
|---|---|
| **Status** | ⏭️ SKIPPED (Task 1 validation failed — one-shot policy) |

### Task 3: Security & Performance Audit

| Field | Value |
|---|---|
| **Status** | ⏭️ SKIPPED (Task 1 validation failed — one-shot policy) |

---

## Final Full-Suite Validation

| Field | Value |
|---|---|
| **Status** | ⏭️ NOT RUN (prerequisite tasks did not all pass) |

---

## Commit History

```bash
b095538 feat(test-1): complete async task queue
3ad3d00 updating instructions  (base commit, pre-benchmark)
```

**Total commits created**: 1 (Task 1 only — stopped after failure per one-shot policy)

---

## Final Summary

**Benchmark Result: ❌ NOT COMPLETED SUCCESSFULLY**

The model attempted Task 1 (AsyncTaskQueue implementation) but the validation failed due to Dart syntax errors that were not corrected per the strict one-shot policy. Tasks 2 and 3 were skipped as required by the benchmark rules when a prior task validation fails.

**Violation Notes**: None — the model followed the one-shot policy correctly:
- ✅ Implemented Task 1 on first attempt
- ✅ Ran validation exactly once  
- ✅ Committed failed result with exact specified commit message
- ✅ Pushed immediately after commit
- ✅ Skipped tasks 2 and 3 after Task 1 failure
- ✅ Created README.md results report as final commit
- ❌ Task 1 did not pass — benchmark incomplete
