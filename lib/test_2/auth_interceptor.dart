import 'dart:async';
import 'api_client.dart';
import 'auth_repository.dart';

class AuthInterceptor {
  final ApiClient apiClient;
  final AuthRepository authRepository;

  Future<String>? _refreshFuture;

  AuthInterceptor(this.apiClient, this.authRepository);

  Future<Map<String, dynamic>> executeRequest(String endpoint) async {
    final initialToken = authRepository.accessToken;
    try {
      return await apiClient.get(endpoint, token: initialToken);
    } on UnauthorizedException {
      final newToken = await _refreshToken(initialToken);
      return await apiClient.get(endpoint, token: newToken);
    }
  }

  Future<String> _refreshToken(String? failedToken) async {
    if (_refreshFuture != null) {
      return await _refreshFuture!;
    }

    if (authRepository.accessToken != failedToken &&
        authRepository.accessToken != null) {
      return authRepository.accessToken!;
    }

    final future = authRepository.refreshToken();
    _refreshFuture = future;
    try {
      return await future;
    } finally {
      if (_refreshFuture == future) {
        _refreshFuture = null;
      }
    }
  }
}
