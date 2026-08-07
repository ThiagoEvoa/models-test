# Code Review Audit Report: `user_feed_screen.dart`

**Reviewer:** Senior Flutter Architect  
**Date:** 2026-08-07  
**Severity Legend:** 🔴 Critical · 🟠 High · 🟡 Medium · 🟢 Low

---

## 1. Security Vulnerabilities

### 🔴 CRITICAL — Hardcoded API Secret in Source Code
```dart
static const String apiSecretKey = "sk_live_99a8b7c6d5e4f3a2b1c0_SECRET";
```
**Issue:** A live API secret is embedded directly in the widget class. It will be compiled into the binary and can be extracted by decompiling the app (e.g., via `strings` or APK/IPA inspection).  
**Fix:** Remove secrets from client-side code entirely. Secrets that must exist client-side should be injected at build time via environment variables or fetched from a secure backend endpoint, never hardcoded.

### 🔴 CRITICAL — JWT Stored in `SharedPreferences` (Insecure Storage)
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('jwt_auth_token', token);
```
**Issue:** `SharedPreferences` stores data in plain text on disk (XML on Android, plist on iOS). On rooted/jailbroken devices this is trivially readable. JWT auth tokens are high-value targets and must be stored in secure storage (`flutter_secure_storage` on mobile, which uses Keychain/Keystore).  
**Fix:** Use an abstracted `SecureStorageContract` so the storage mechanism is swappable and testable, backed by `flutter_secure_storage` in production.

### 🟠 HIGH — Hardcoded JWT Value Passed to Storage
```dart
_saveAuthToken("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...");
```
**Issue:** A hardcoded (possibly real) JWT is being written to storage unconditionally in `initState`. Real tokens should come from authentication flows, not be embedded in UI code.  
**Fix:** Tokens should be provided externally (e.g., via constructor injection or a service layer), not hardcoded in the widget.

---

## 2. Memory Leaks

### 🔴 CRITICAL — `StreamSubscription` Never Cancelled
```dart
late StreamSubscription _liveFeedSubscription;

_liveFeedSubscription = Stream.periodic(...).listen((event) { ... });
```
**Issue:** `_liveFeedSubscription` is created in `initState` but `dispose()` is never overridden. The subscription to `Stream.periodic` keeps a reference to `_UserFeedScreenState`, preventing garbage collection and continuing to call `setState` on a disposed widget, which throws `"setState() called after dispose()"`.  
**Fix:** Override `dispose()` and call `_liveFeedSubscription.cancel()`.

---

## 3. Performance Anti-Patterns

### 🔴 CRITICAL — Expensive Computation Inside `build()`
```dart
@override
Widget build(BuildContext context) {
  final List<dynamic> parsedList = jsonDecode(widget.rawFeedJson); // O(n) JSON decode
  final sortedList = parsedList.map(...).toList();
  sortedList.sort(...); // O(n log n) sort
  _processedFeed = sortedList;
  ...
}
```
**Issue:** `build()` can be called many times per second (on every `setState`, layout, orientation change, etc.). Performing JSON decoding and sorting on every build is a severe performance regression that will cause jank, especially on large feeds. Mutating state (`_processedFeed`) inside `build()` is also an anti-pattern that can cause subtle bugs.  
**Fix:** Process the feed once in `initState` (or when the input changes via `didUpdateWidget`) and cache the result. Never mutate state inside `build()`.

### 🟡 MEDIUM — `Stream.periodic` Rebuilds Entire Widget Tree on Every Tick
```dart
Stream.periodic(Duration(seconds: 1), (i) => i).listen((event) {
  setState(() { _counter = event; });
});
```
**Issue:** Calling `setState` every second triggers a full rebuild of the `Scaffold`, `AppBar`, and `ListView`. Only the counter in the `AppBar` title changes. This is wasteful at scale.  
**Fix:** Extract the counter display into a focused widget or use `ValueNotifier` + `ValueListenableBuilder` / `AnimatedBuilder` to scope rebuilds to the smallest subtree.

### 🟢 LOW — `_UserFeedScreenState` Class Name is Public Despite Private Intent
```dart
class _UserFeedScreenState extends State<UserFeedScreen> {
```
**Issue:** While this is syntactically valid, the private leading underscore convention is correct, but the `apiSecretKey` field is `static const` on the private state class — a structural smell indicating misplaced concerns.  
**Fix:** Secrets and configuration should not live on State objects.

---

## Summary Table

| # | Issue | Category | Severity |
|---|-------|----------|----------|
| 1 | Hardcoded live API secret in source | Security | 🔴 Critical |
| 2 | JWT stored in plain-text SharedPreferences | Security | 🔴 Critical |
| 3 | Hardcoded JWT value passed to storage | Security | 🟠 High |
| 4 | StreamSubscription never cancelled | Memory Leak | 🔴 Critical |
| 5 | JSON decode + sort inside `build()` | Performance | 🔴 Critical |
| 6 | setState every second rebuilds full tree | Performance | 🟡 Medium |
| 7 | Secrets/config on State class | Architecture | 🟢 Low |

---

## Refactored File

See `lib/test_3/user_feed_screen_refactored.dart`.
