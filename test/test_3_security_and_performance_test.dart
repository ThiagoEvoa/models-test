import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/test_3/user_feed_screen_refactored.dart';

class MockSecureStorage implements SecureStorageContract {
  final Map<String, String> storage = {};

  @override
  Future<String?> read({required String key}) async => storage[key];

  @override
  Future<void> write({required String key, required String value}) async {
    storage[key] = value;
  }
}

void main() {
  testWidgets('Test 3 Evaluation: Refactored UserFeedScreen renders correctly without crashing', (WidgetTester tester) async {
    final mockStorage = MockSecureStorage();
    const sampleJson = '[{"title": "Item A", "score": 10}, {"title": "Item B", "score": 50}]';

    await tester.pumpWidget(
      MaterialApp(
        home: UserFeedScreenRefactored(
          rawFeedJson: sampleJson,
          secureStorage: mockStorage,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('User Live Feed (0)'), findsOneWidget);
    expect(find.text('Item B'), findsOneWidget);
    expect(find.text('Item A'), findsOneWidget);
  });
}
