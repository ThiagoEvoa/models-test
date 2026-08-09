# Security & Performance Audit Report: UserFeedScreen

## 1. Security Vulnerabilities
- **Hardcoded Secret**: `apiSecretKey` is hardcoded as a plain string in the class. This exposes credentials in the binary/source code. (Critical)
- **Insecure Storage**: Uses `SharedPreferences` for storing JWT auth tokens. `SharedPreferences` stores data in XML/Plaintext on disk, which is vulnerable to rooted devices or backup exports. Should use `flutter_secure_storage`. (High)

## 2. Memory Leaks
- **Missing Subscription Cancellation**: `_liveFeedSubscription` is created in `initState` but never cancelled in `dispose()`. This leads to a permanent memory leak and continuous state updates even after the widget is removed from the tree. (Critical)

## 3. Performance Anti-Patterns
- **JSON Decoding in Build Method**: `jsonDecode(widget.rawFeedJson)` and sorting logic are executed every time `build()` is called. Since `setState` is called every second by the timer, this expensive operation happens every second, causing frame drops (jank). (High)
- **State Mutation inside Build**: The line `_processedFeed = sortedList;` modifies state during the build process, which is an anti-pattern and can lead to unpredictable behavior or Flutter framework errors. (Medium)

## Summary of Fixes:
1. Move JSON parsing and sorting to `initState` or a dedicated method called once.
2. Implement `dispose()` to cancel the stream subscription.
3. Remove hardcoded secrets.
4. Replace `SharedPreferences` with an abstraction for secure storage.
