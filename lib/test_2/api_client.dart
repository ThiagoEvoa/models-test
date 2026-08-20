import 'dart:async';

import 'auth_repository.dart';

/// A minimal HTTP-style client placeholder.
///
/// When the supplied [token] is the sentinel `'EXPIRED_TOKEN'` it throws an
///[UnauthorizedException] to simulate a 401 response.
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

/// Thrown by [ApiClient.get] when the presented access token has expired.
class UnauthorizedException implements Exception {}
