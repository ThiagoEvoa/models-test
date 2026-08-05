# Test 2: Repository-Level Bug Repair & Patch Generation (Flutter)

## Objective
Evaluate the model's ability to navigate a multi-file Flutter codebase, trace a subtle asynchronous race condition across dependencies, and generate a unified `git diff` patch that fixes the bug without collateral breakage.

---

## Scenario: Multi-File Auth Refresh Token Race Condition

In this mini Flutter project, when multiple concurrent HTTP API requests fail due to an expired access token (401 Unauthorized), the `AuthInterceptor` attempts to refresh the access token via `AuthRepository`. 

Because the backend uses **Single-Use Refresh Token Rotation** (the old refresh token is invalidated as soon as it is consumed), firing simultaneous refresh requests causes all but the first call to fail with `401 Token Revoked`, which incorrectly forces the app to log the user out and redirect to the Login screen.

---

## Codebase Context (3 Files)

### File 1: `lib/src/services/api_client.dart`
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_repository.dart';

class ApiClient {
  final AuthRepository authRepository;

  ApiClient(this.authRepository);

  Future<Map<String, dynamic>> get(String endpoint, {String? token}) async {
    // Simulates an API call that returns 401 if token is expired
    if (token == 'EXPIRED_TOKEN') {
      throw UnauthorizedException();
    }
    return {'data': 'Response from $endpoint'};
  }
}

class UnauthorizedException implements Exception {}
```

### File 2: `lib/src/interceptors/auth_interceptor.dart`
```dart
import 'dart:async';
import '../services/api_client.dart';
import '../services/auth_repository.dart';

class AuthInterceptor {
  final ApiClient apiClient;
  final AuthRepository authRepository;

  AuthInterceptor(this.apiClient, this.authRepository);

  Future<Map<String, dynamic>> executeRequest(String endpoint) async {
    try {
      final currentToken = authRepository.accessToken;
      return await apiClient.get(endpoint, token: currentToken);
    } on UnauthorizedException {
      // BUG LOCATION: Simultaneous 401s trigger parallel refresh calls!
      final newToken = await authRepository.refreshToken();
      return await apiClient.get(endpoint, token: newToken);
    }
  }
}
```

### File 3: `lib/src/services/auth_repository.dart`
```dart
import 'dart:async';

class AuthRepository {
  String? accessToken = 'EXPIRED_TOKEN';
  String? _refreshToken = 'VALID_REFRESH_TOKEN';
  bool _isDisposed = false;

  int refreshCallCount = 0;

  Future<String> refreshToken() async {
    refreshCallCount++;
    await Future.delayed(const Duration(milliseconds: 50)); // Simulates network roundtrip

    if (_refreshToken == null || _refreshToken == 'REVOKED') {
      throw Exception('Session Expired: Refresh token revoked or invalid.');
    }

    // Backend invalidates old refresh token on use
    _refreshToken = 'REVOKED'; 
    accessToken = 'NEW_VALID_TOKEN_${DateTime.now().millisecondsSinceEpoch}';
    _refreshToken = 'NEW_VALID_REFRESH_TOKEN';

    return accessToken!;
  }
}
```

---

## Prompt to Give to the Model

```markdown
You are presented with a multi-file Flutter service architecture located in `lib/src/`.

### Bug Description:
When loading the App Dashboard, 3 API calls (`/user`, `/notifications`, `/settings`) execute concurrently using `AuthInterceptor.executeRequest()`. Since the `accessToken` is expired, all 3 requests throw `UnauthorizedException` at the same time.

Currently, `AuthInterceptor` calls `authRepository.refreshToken()` independently for each failed request. The server enforces strict single-use refresh token rotation, so the 2nd and 3rd refresh requests fail because the refresh token was already revoked by the 1st request.

### Requirements:
1. Modify `AuthInterceptor` (or add a Mutex / Mutex-Queuing mechanism in Dart) so that if a token refresh is already in progress, concurrent requests wait for that single refresh operation to complete and reuse the new `accessToken`.
2. Do not modify `ApiClient` or `AuthRepository`.
3. Provide your solution strictly as a valid Git diff (`git diff`) against `lib/src/interceptors/auth_interceptor.dart`. Do NOT output full file rewrites.
```

---

## Expected Model Output (Valid Git Patch)

```diff
--- a/lib/src/interceptors/auth_interceptor.dart
+++ b/lib/src/interceptors/auth_interceptor.dart
@@ -1,17 +1,29 @@
 import 'dart:async';
 import '../services/api_client.dart';
 import '../services/auth_repository.dart';

 class AuthInterceptor {
   final ApiClient apiClient;
   final AuthRepository authRepository;

+  Completer<String>? _refreshCompleter;

   AuthInterceptor(this.apiClient, this.authRepository);

   Future<Map<String, dynamic>> executeRequest(String endpoint) async {
     try {
       final currentToken = authRepository.accessToken;
       return await apiClient.get(endpoint, token: currentToken);
     } on UnauthorizedException {
-      final newToken = await authRepository.refreshToken();
+      String newToken;
+      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
+        newToken = await _refreshCompleter!.future;
+      } else {
+        _refreshCompleter = Completer<String>();
+        try {
+          newToken = await authRepository.refreshToken();
+          _refreshCompleter!.complete(newToken);
+        } catch (e, st) {
+          _refreshCompleter!.completeError(e, st);
+          rethrow;
+        } finally {
+          _refreshCompleter = null;
+        }
+      }
       return await apiClient.get(endpoint, token: newToken);
     }
   }
 }
```

---

## Verification Test Harness (Integration Test)

```dart
import 'package:test/test.dart';
import 'lib/src/services/api_client.dart';
import 'lib/src/services/auth_repository.dart';
import 'lib/src/interceptors/auth_interceptor.dart';

void main() {
  test('Concurrent requests resolve using single refresh token call', () async {
    final authRepo = AuthRepository();
    final apiClient = ApiClient(authRepo);
    final interceptor = AuthInterceptor(apiClient, authRepo);

    // Fire 3 requests simultaneously
    final results = await Future.wait([
      interceptor.executeRequest('/user'),
      interceptor.executeRequest('/notifications'),
      interceptor.executeRequest('/settings'),
    ]);

    expect(results.length, equals(3));
    expect(authRepo.refreshCallCount, equals(1)); // MUST only call backend once!
  });
}
```

---

## Evaluation Rubric & Scoring

| Criteria | Points | Requirement |
|---|---|---|
| **Git Diff Format** | 20% | Response is formatted as a valid `git diff` patch that can be applied with `git apply`. |
| **Race Condition Fix** | 40% | Uses `Completer<String>` or an asynchronous lock so subsequent callers await the pending token refresh. |
| **Single Refresh Invocations** | 20% | `authRepository.refreshCallCount` equals exactly `1` when tested against 3 parallel requests. |
| **Error & Reset Handling** | 20% | Correctly resets the completer/lock in a `finally` block so future auth errors can refresh again. |
