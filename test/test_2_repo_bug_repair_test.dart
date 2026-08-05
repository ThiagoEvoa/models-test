import 'package:test/test.dart';
import '../lib/test_2/api_client.dart';
import '../lib/test_2/auth_repository.dart';
import '../lib/test_2/auth_interceptor.dart';

void main() {
  group('Test 2 Evaluation: Multi-File Auth Refresh Token Race Condition', () {
    test('Concurrent requests resolve using single refresh token call', () async {
      final authRepo = AuthRepository();
      final apiClient = ApiClient(authRepo);
      final interceptor = AuthInterceptor(apiClient, authRepo);

      final results = await Future.wait([
        interceptor.executeRequest('/user'),
        interceptor.executeRequest('/notifications'),
        interceptor.executeRequest('/settings'),
      ]);

      expect(results.length, equals(3));
      expect(results[0]['data'], equals('Response from /user'));
      expect(results[1]['data'], equals('Response from /notifications'));
      expect(results[2]['data'], equals('Response from /settings'));
      
      // Verification: AuthRepository.refreshToken MUST be called exactly once
      expect(authRepo.refreshCallCount, equals(1));
    });
  });
}
