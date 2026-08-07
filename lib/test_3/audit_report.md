# Security, Performance & Code Quality Audit Report

## File Audited
`user_feed_screen.dart`

---

## Issue 1: Hardcoded API Secret Key (CRITICAL — Security)

**Location:** Line 25 — `static const String apiSecretKey = "sk_live_99a8b7c6d5e4f3a2b1c0_SECRET";`

**Severity:** Critical

**Description:** A live API secret key is hardcoded directly in the client-side source code. This key will be compiled into the binary and can be trivially extracted via decompilation. This represents a complete compromise of the API key.

**Fix:** Remove the hardcoded key entirely. API secrets must never reside in client code. Use server-side proxying or secure environment injection.

---

## Issue 2: Insecure Token Storage via SharedPreferences (HIGH — Security)

**Location:** Lines 43–46 — `_saveAuthToken` stores JWT in `SharedPreferences`

**Severity:** High

**Description:** `SharedPreferences` stores data in plaintext on disk (XML on Android, plist on iOS). A JWT stored here is readable by any process with file access or on rooted/jailbroken devices.

**Fix:** Use a secure storage abstraction (e.g., `flutter_secure_storage` or platform keychain/keystore) injected via an abstract contract for testability.

---

## Issue 3: Memory Leak — StreamSubscription Never Cancelled (HIGH — Performance/Stability)

**Location:** Line 36 — `_liveFeedSubscription` is created but never cancelled

**Severity:** High

**Description:** The `Stream.periodic` subscription is created in `initState` but there is no `dispose()` override to cancel it. When the widget is removed from the tree, the subscription continues to fire, causing memory leaks and potential `setState` calls on a disposed state.

**Fix:** Override `dispose()` to cancel `_liveFeedSubscription`.

---

## Issue 4: JSON Parsing in `build()` (HIGH — Performance)

**Location:** Lines 50–53 — `jsonDecode` and sorting executed inside `build()`

**Severity:** High

**Description:** The `build()` method is called on every frame rebuild (every setState, every animation frame). Performing `jsonDecode`, `map`, `toList`, and `sort` operations inside `build()` is a severe performance anti-pattern that causes unnecessary recomputation and potential jank.

**Fix:** Parse and sort the JSON once during `initState` or when the data changes, and store the result in state.

---

## Issue 5: Mutating State Inside `build()` (MEDIUM — Correctness)

**Location:** Line 53 — `_processedFeed = sortedList;`

**Severity:** Medium

**Description:** Assigning to `_processedFeed` inside `build()` is a side effect during rendering. This violates the principle that `build()` should be a pure function. It may also cause subtle bugs during hot reload or framework-driven rebuilds.

**Fix:** Move data processing to `initState` or a dedicated method called from lifecycle hooks.

---

## Issue 6: Missing Error Handling for JSON Parsing (MEDIUM — Robustness)

**Location:** Line 50 — `jsonDecode(widget.rawFeedJson)` with no try-catch

**Severity:** Medium

**Description:** If `rawFeedJson` contains malformed JSON, the widget will throw an unhandled exception during `build()`, crashing the entire widget subtree.

**Fix:** Parse JSON safely with error handling and display a fallback UI on failure.

---

## Issue 7: Unsafe Type Casting (MEDIUM — Robustness)

**Location:** Line 52 — `(b['score'] as int)`

**Severity:** Medium

**Description:** A hard `as int` cast will throw a `TypeError` if the `score` field is null, missing, or a different type (e.g., `double`). No defensive null-checking is applied.

**Fix:** Use safe casting with fallback defaults (e.g., `(a['score'] as int?) ?? 0`).

---

## Summary

| # | Issue | Severity | Category |
|---|-------|----------|----------|
| 1 | Hardcoded API secret key | Critical | Security |
| 2 | Insecure token storage (SharedPreferences) | High | Security |
| 3 | StreamSubscription memory leak | High | Performance |
| 4 | JSON parsing inside build() | High | Performance |
| 5 | State mutation inside build() | Medium | Correctness |
| 6 | No JSON error handling | Medium | Robustness |
| 7 | Unsafe type casting | Medium | Robustness |
