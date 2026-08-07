import 'dart:async';
import 'api_client.dart';
import 'auth_repository.dart';

class AuthInterceptor {
  final ApiClient apiClient;
  final AuthRepository authRepository;

  /// Tracks the in-flight refresh operation so concurrent 401s
  /// share a single refresh call instead of triggering parallel ones.
  Future<String>? _refreshInProgress;

  AuthInterceptor(this.apiClient, this.authRepository);

  Future<Map<String, dynamic>> executeRequest(String endpoint) async {
    try {
      final currentToken = authRepository.accessToken;
      return await apiClient.get(endpoint, token: currentToken);
    } on UnauthorizedException {
      // Coalesce concurrent refresh attempts into a single call.
      // If a refresh is already in progress, wait for it instead of
      // issuing a new one.
      _refreshInProgress ??= authRepository.refreshToken().whenComplete(() {
        _refreshInProgress = null;
      });

      final newToken = await _refreshInProgress!;
      return await apiClient.get(endpoint, token: newToken);
    }
  }
}
