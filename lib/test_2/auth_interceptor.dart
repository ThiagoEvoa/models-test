import 'dart:async';
import 'api_client.dart';
import 'auth_repository.dart';

class AuthInterceptor {
  final ApiClient apiClient;
  final AuthRepository authRepository;
  Future<String>? _refreshFuture;

  AuthInterceptor(this.apiClient, this.authRepository);

  Future<Map<String, dynamic>> executeRequest(String endpoint) async {
    try {
      final currentToken = authRepository.accessToken;
      return await apiClient.get(endpoint, token: currentToken);
    } on UnauthorizedException {
      // Handle concurrent refresh calls by synchronizing on a single future
      if (_refreshFuture == null) {
        _refreshFuture = authRepository.refreshToken().catchError((e) {
          _refreshFuture = null; // Reset if refresh fails to allow retry later
          rethrow;
        }).then((token) {
          _refreshFuture = null; // Clear after successful refresh
          return token;
        });
      }

      final newToken = await _refreshFuture;
      return await apiClient.get(endpoint, token: newToken);
    }
  }
}
