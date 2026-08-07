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
      _refreshFuture ??= authRepository.refreshToken().whenComplete(() {
        _refreshFuture = null;
      });
      final newToken = await _refreshFuture!;
      return await apiClient.get(endpoint, token: newToken);
    }
  }
}
