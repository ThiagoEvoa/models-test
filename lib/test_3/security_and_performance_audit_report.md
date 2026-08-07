# Security & Performance Audit Report: `user_feed_screen.dart`

## Executive Summary
A comprehensive security and performance audit was conducted on `user_feed_screen.dart`. The review identified severe security vulnerabilities (hardcoded credentials, insecure token storage), critical memory leaks (unmanaged stream subscriptions), and major performance anti-patterns (JSON parsing and sorting inside the `build` method).

---

## 1. Security Vulnerabilities

### 1.1 Hardcoded Secret Key (High Severity)
- **Location**: Line 25 (`static const String apiSecretKey = "sk_live_99a8b7c6d5e4f3a2b1c0_SECRET";`)
- **Issue**: Hardcoding sensitive production API secrets or private keys directly in client application source code allows malicious actors to decompile/reverse-engineer the application package (APK/IPA) and extract the key.
- **Remediation**: Remove API keys from application source code. Store secrets in secure server environments or retrieve ephemeral tokens dynamically over TLS.

### 1.2 Insecure Token Storage (High Severity)
- **Location**: Lines 43–46 (`_saveAuthToken` using `SharedPreferences`)
- **Issue**: `SharedPreferences` stores data in plain-text XML (Android) or Plist (iOS) files on device storage. On rooted or jailbroken devices, or via unencrypted backups, sensitive JWT tokens can be easily stolen.
- **Remediation**: Use platform-backed secure storage solutions (such as iOS Keychain and Android KeyStore via an abstract `SecureStorageContract`) for sensitive tokens.

---

## 2. Memory Leaks & Resource Management

### 2.1 Missing StreamSubscription Cancellation (High Severity)
- **Location**: Lines 27 & 36–40 (`_liveFeedSubscription = Stream.periodic(...).listen(...)`)
- **Issue**: The widget subscribes to a periodic stream in `initState()`, but does not implement the `dispose()` lifecycle method to cancel `_liveFeedSubscription`.
- **Impact**: When the widget is popped or removed from the tree, the stream subscription continues running in memory indefinitely, causing memory leaks and unneeded CPU consumption.
- **Remediation**: Implement `dispose()` and call `_liveFeedSubscription?.cancel()`.

### 2.2 Unchecked `setState` on Unmounted Widget (Medium Severity)
- **Location**: Lines 37–39 (`setState(() { _counter = event; });`)
- **Issue**: Calling `setState` without verifying `if (mounted)` can throw runtime exceptions if an async stream event fires after the widget has been unmounted.
- **Remediation**: Wrap `setState` calls with `if (mounted)`.

---

## 3. Performance Anti-Patterns

### 3.1 Heavy JSON Parsing and Sorting in `build()` Method (High Severity)
- **Location**: Lines 50–53 (`jsonDecode(widget.rawFeedJson)` & `sortedList.sort(...)`)
- **Issue**: Flutter calls the `build()` method frequently (in this case, every second when `_counter` updates). Executing `jsonDecode` and sorting operations inside `build()` causes UI jank, high CPU usage, and constant heap allocations.
- **Remediation**: Move JSON decoding and sorting out of `build()` into `initState()` and `didUpdateWidget()`.

### 3.2 State Mutation During `build()` (Medium Severity)
- **Location**: Line 53 (`_processedFeed = sortedList;`)
- **Issue**: Mutating widget state fields during the `build()` phase breaks the Flutter widget lifecycle design contract and can lead to unpredictable side effects or re-entrant build loops.
- **Remediation**: Store state in response to events or lifecycle hooks, keeping `build()` pure.

### 3.3 Missing `const` Widget Constructors (Low Severity)
- **Location**: Line 65 (`Icon(Icons.star, color: Colors.amber)`)
- **Issue**: Non-const instantiated widgets are unnecessarily recreated on every rebuild frame.
- **Remediation**: Mark immutable subwidgets with the `const` keyword.
