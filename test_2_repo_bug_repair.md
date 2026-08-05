# Test 2: Repository-Level Bug Repair & Patch Generation (Flutter/Dart)

## Prompt to Give to the Model

You are presented with a multi-file Flutter service architecture. Create the starter files in `lib/test_2/` and then repair the bug.

### Starter Files to Create:

1. **`lib/test_2/api_client.dart`**:
```dart
import 'dart:async';
import 'auth_repository.dart';

class ApiClient {
  final AuthRepository authRepository;

  ApiClient(this.authRepository);

  Future<Map<String, dynamic>> get(String endpoint, {String? token}) async {
    if (token == 'EXPIRED_TOKEN') {
      throw UnauthorizedException();
    }
    return {'data': 'Response from $endpoint'};
  }
}

class UnauthorizedException implements Exception {}
```

2. **`lib/test_2/auth_repository.dart`**:
```dart
import 'dart:async';

class AuthRepository {
  String? accessToken = 'EXPIRED_TOKEN';
  String? _refreshToken = 'VALID_REFRESH_TOKEN';

  int refreshCallCount = 0;

  Future<String> refreshToken() async {
    refreshCallCount++;
    await Future.delayed(const Duration(milliseconds: 50));

    if (_refreshToken == null || _refreshToken == 'REVOKED') {
      throw Exception('Session Expired: Refresh token revoked or invalid.');
    }

    _refreshToken = 'REVOKED';
    accessToken = 'NEW_VALID_TOKEN_${DateTime.now().millisecondsSinceEpoch}';
    _refreshToken = 'NEW_VALID_REFRESH_TOKEN';

    return accessToken!;
  }
}
```

3. **`lib/test_2/auth_interceptor.dart`**:
```dart
import 'dart:async';
import 'api_client.dart';
import 'auth_repository.dart';

class AuthInterceptor {
  final ApiClient apiClient;
  final AuthRepository authRepository;

  AuthInterceptor(this.apiClient, this.authRepository);

  Future<Map<String, dynamic>> executeRequest(String endpoint) async {
    try {
      final currentToken = authRepository.accessToken;
      return await apiClient.get(endpoint, token: currentToken);
    } on UnauthorizedException {
      // BUG: Simultaneous 401s trigger parallel refresh calls!
      final newToken = await authRepository.refreshToken();
      return await apiClient.get(endpoint, token: newToken);
    }
  }
}
```

### Bug Description:
When loading the App Dashboard, 3 API calls (`/user`, `/notifications`, `/settings`) execute concurrently using `AuthInterceptor.executeRequest()`. Since the `accessToken` is expired, all 3 requests throw `UnauthorizedException` at the same time.

Currently, `AuthInterceptor` calls `authRepository.refreshToken()` independently for each failed request. The server enforces strict single-use refresh token rotation, so the 2nd and 3rd refresh requests fail because the refresh token was already revoked by the 1st request.

### Requirements:
1. Modify `AuthInterceptor` in `lib/test_2/auth_interceptor.dart` so that if a token refresh is already in progress, concurrent requests wait for that single refresh operation to complete and reuse the new `accessToken`.
2. Do not modify `ApiClient` or `AuthRepository`.

### CRITICAL INSTRUCTIONS FOR THE MODEL:
- Do NOT write any unit tests, integration tests, or test files. The test suite is already provided in the repository.
- Provide ONLY the implementation files inside `lib/test_2/`.
