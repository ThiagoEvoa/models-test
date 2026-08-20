import 'dart:async';

import 'api_client.dart';
import 'auth_repository.dart';

/// Intercepts outgoing requests and transparently refreshes the access token
/// when a 401 ([UnauthorizedException]) is encountered.
///
/// The original implementation called [AuthRepository.refreshToken] independently
/// for every failed request. Because the server enforces single-use refresh-token
/// rotation, a burst of simultaneous 401s (e.g. loading `/user`, `/notifications`,
/// and `/settings` together on the dashboard) triggered multiple parallel refresh
/// calls; only the first succeeded and the rest failed.
///
/// FIX: use a single-flight refresh. The [inProgressRefresh] cache coalesces every
/// concurrent 401 onto ONE refresh operation, and all waiting requests reuse the
/// resulting token.
class AuthInterceptor {
  final ApiClient apiClient;
  final AuthRepository authRepository;

   /// The in-flight refresh operation, if any. All concurrent 401s share this
   /// single [Future] so `refreshToken()` is invoked at most once per refresh
   /// cycle. It is cleared once the refresh settles (success or failure).
  Future<String>? inProgressRefresh;

  AuthInterceptor(this.apiClient, this.authRepository);

  Future<Map<String, dynamic>> executeRequest(String endpoint) async {
    try {
      final currentToken = authRepository.accessToken;
      return await apiClient.get(endpoint, token: currentToken);
     } on UnauthorizedException {
      // Coalesce concurrent 401s onto a single refresh operation.
      final newToken = await _refreshTokenOnce();
      return await apiClient.get(endpoint, token: newToken);
     }
   }

  /// Returns a single shared [Future] representing the in-progress token
  /// refresh, starting exactly one refresh cycle the first time it is observed.
  Future<String> _refreshTokenOnce() {
    final existing = inProgressRefresh;
    if (existing != null) {
      return existing;
     }

    final refresh = authRepository.refreshToken();
     inProgressRefresh = refresh;

     // Always clear the cache when the refresh settles so that a future 401
     // triggers a fresh refresh attempt.
    refresh.whenComplete(() {
      inProgressRefresh = null;
     });

    return refresh;
   }
}
