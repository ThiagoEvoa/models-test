import 'dart:async';

/// A minimal token store.
///
/// [refreshToken] simulates a server-enforced, single-use refresh-token rotation:
/// it can only succeed once because it revokes the current refresh token after a
/// successful exchange. A second concurrent call therefore fails, which surfaces
/// the race condition that [AuthInterceptor] is responsible for preventing.
class AuthRepository {
  String? accessToken = 'EXPIRED_TOKEN';
  String? _refreshToken = 'VALID_REFRESH_TOKEN';

  /// Number of times [refreshToken] has been invoked. The bug in the original
   /// interceptor drives this to 3 instead of 1.
  int refreshCallCount = 0;

  Future<String> refreshToken() async {
    refreshCallCount++;

    // Simulate network latency for the refresh request.
    await Future.delayed(const Duration(milliseconds: 50));

    if (_refreshToken == null || _refreshToken == 'REVOKED') {
      throw Exception('Session Expired: Refresh token revoked or invalid.');
     }

    // The refresh token is rotated: mark the old one revoked, mint the new one.
    _refreshToken = 'REVOKED';
    accessToken = 'NEW_VALID_TOKEN_${DateTime.now().millisecondsSinceEpoch}';
    _refreshToken = 'NEW_VALID_REFRESH_TOKEN';

    return accessToken!;
   }
}
