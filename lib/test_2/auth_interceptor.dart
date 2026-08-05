import 'dart:async';
import 'api_client.dart';
import 'auth_repository.dart';

class AuthInterceptor {
  final ApiClient apiClient;
  final AuthRepository authRepository;

  Completer<String>? _refreshCompleter;

  AuthInterceptor(this.apiClient, this.authRepository);

  Future<Map<String, dynamic>> executeRequest(String endpoint) async {
    try {
      final currentToken = authRepository.accessToken;
      return await apiClient.get(endpoint, token: currentToken);
    } on UnauthorizedException {
      String newToken;

      if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
        newToken = await _refreshCompleter!.future;
      } else {
        _refreshCompleter = Completer<String>();
        try {
          newToken = await authRepository.refreshToken();
          _refreshCompleter!.complete(newToken);
        } catch (e, st) {
          _refreshCompleter!.completeError(e, st);
          rethrow;
        } finally {
          _refreshCompleter = null;
        }
      }

      return await apiClient.get(endpoint, token: newToken);
    }
  }
}
