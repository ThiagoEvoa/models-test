import 'package:flutter/material.dart';

abstract class SecureStorageContract {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
}

class UserFeedScreenRefactored extends StatelessWidget {
  final String rawFeedJson;
  final SecureStorageContract secureStorage;

  const UserFeedScreenRefactored({
    Key? key,
    required this.rawFeedJson,
    required this.secureStorage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError('Model must implement UserFeedScreenRefactored');
  }
}
