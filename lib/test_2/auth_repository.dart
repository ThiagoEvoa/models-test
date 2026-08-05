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
