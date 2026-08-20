# Test 3 — Security, Memory & Performance Audit

**Source audited:** `user_feed_screen.dart`
**Refactored output:** `lib/test_3/user_feed_screen_refactored.dart`
**Auditor:** Senior Flutter Developer (automated benchmark run)

## 1. Security Vulnerabilities

### 1.1 Hardcoded live API secret in source  ⛔ CRITICAL
```dart
static const String apiSecretKey = "sk_live_99a8b7c6d5e4f3a2b1c0_SECRET";
```
- A live secret key is compiled into the binary/client and is exposed to anyone
  who can read the app package or the repository. It can be extracted and abused.
- **Fix:** Remove the constant entirely. Secrets must live on the server / in a
  secrets manager and never ship to the client.

### 1.2 Hardcoded / leaked JWT access token  ⛔ CRITICAL
```dart
_saveAuthToken("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...");
```
- An access token (JWT) is hardcoded and saved on every launch. Even a
  placeholder JWT in source is a bad habit; a real one is a credential leak.
- **Fix:** No token is embedded. The refactored widget accepts an optional
  `authToken` and persists it **through the secure store** (`SecureStorageContract`)
  only, with no hardcoded fallback.

### 1.3 Token persisted in plaintext `SharedPreferences`  ⛔ HIGH
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('jwt_auth_token', token);
```
- Access/JWT tokens stored in plaintext `SharedPreferences` are world-readable by
  other processes / backups and can be exfiltrated.
- **Fix:** Introduced an abstract `SecureStorageContract` abstraction and route all
  token I/O through it. Implementations must use platform secure primitives
  (iOS Keychain / Android EncryptedSharedPreferences). The original
  `shared_preferences` dependency is dropped from this file.

## 2. Memory Leaks / Resource Management

### 2.1 Stream subscription never cancelled  ⛔ HIGH
```dart
_liveFeedSubscription = Stream.periodic(Duration(seconds: 1), (i) => i).listen(...);
```
- `Stream.periodic(...)` creates a repeating timer that outlives the widget. The
  subscription is never `cancel()`-ed in `dispose`, so timers + listener closures
  accumulate for every created/disposed screen — a classic leak that prevents
  garbage collection and keeps firing `setState` after the widget is gone.
- **Fix:** The subscription field is **always cancelled in `dispose()`**. The
  live feed is injected as `Stream<int>? liveFeed` (defaulting to an empty
  stream), so production code supplies a controlled stream and there are no
  dangling `Stream.periodic` timers.

### 2.2 `setState` after widget dispose / unmounted  ⛔ MEDIUM
- The stream `listen` callback calls `setState(() => _counter = event);` with no
  `mounted` guard, and `_saveAuthToken` (async) can complete after the widget is
  disposed → `setState` on an inactive element throws / is lost.
- **Fix:** Every async path (stream events, storage restore) is guarded with
  `if (!mounted) return;` before `setState`.

## 3. Performance Anti-Patterns

### 3.1 JSON decoding + sorting on every `build`  ⛔ HIGH
```dart
Widget build(BuildContext context) {
  final parsedList = jsonDecode(widget.rawFeedJson);
  final sortedList = parsedList.map(...).toList();
  sortedList.sort(...);
  _processedFeed = sortedList;
  ...
}
```
- `build` runs on every state change (including the 1 Hz stream counter updates
  from §1). Re-decoding JSON and re-sorting the whole feed on each frame is
  O(n log n) + JSON parse on the hot path → jank and wasted CPU.
- **Fix:** The feed is parsed and sorted **once** in `initState` and cached in a
  `late final List<Map<String, dynamic>> _processedFeed`. `build` only iterates
  the cached list.

### 3.2 Unbounded live counter driving rebuilds  ⚠️ MEDIUM
- The app-bar increments `_counter` every second via `setState`, forcing a full
  rebuild of the screen (including the `ListView.builder`) for a value used only
  for a label.
- **Fix:** Counter updates remain, but the body's work (the list) is decoupled
  from that rebuild by caching the parsed feed; the label-only update no longer
  re-parses JSON.

## 4. Robustness / Crash Risks

| Issue | Location | Fix |
| --- | --- | --- |
| `jsonDecode` can throw `FormatException` on bad input | `build` | Wrapped in try/catch in `_buildFeed`; malformed JSON yields an empty feed instead of crashing. |
| `(b['score'] as int)` throws on null / non-int / string scores | `build` sort | Replaced with a null-safe `_asInt` helper (`int`/`num`/`String` → `int?`). |
| `item['title'] as ...` / potential nulls | `TileList` | `item['title']?.toString() ?? ''` and `subtitle: null` when score missing. |
| `Map.from` on non-map entries | sort source | Filtered via `whereType<Map<dynamic, dynamic>>()` before mapping. |

## 5. Summary of Fixes in Refactor

1. Removed all hardcoded secrets and tokens.
2. Introduced `abstract interface class SecureStorageContract` for secure token I/O.
3. Cancel the live-feed subscription in `dispose` (eliminates the leak).
4. Guard every `setState`-in-a-callback with `mounted`.
5. Parse + sort the feed once in `initState`; cache it; `build` does no JSON work.
6. Hardened JSON parsing (catch `FormatException`, tolerate missing/odd scores,
   filter to maps) so bad input cannot crash the screen.
7. Injected the live-feed `Stream` (default empty) instead of a hardcoded
   `Stream.periodic`, removing dangling timers while keeping the feature swappable.

The refactored widget is fully type-safe, null-safe, and passes the provided
widget test without crashing.
