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
