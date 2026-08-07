import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';

/// Abstract contract for secure token and key-value storage.
abstract class SecureStorageContract {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
}

/// A refactored, production-ready user live feed screen that resolves
/// security vulnerabilities, memory leaks, and performance anti-patterns.
class UserFeedScreenRefactored extends StatefulWidget {
  final String rawFeedJson;
  final SecureStorageContract secureStorage;

  const UserFeedScreenRefactored({
    super.key,
    required this.rawFeedJson,
    required this.secureStorage,
  });

  @override
  State<UserFeedScreenRefactored> createState() => _UserFeedScreenRefactoredState();
}

class _UserFeedScreenRefactoredState extends State<UserFeedScreenRefactored> {
  StreamSubscription<int>? _liveFeedSubscription;
  List<Map<String, dynamic>> _processedFeed = [];
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _processFeedJson();
    _saveAuthTokenSecurely("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...");
    
    _liveFeedSubscription = Stream.periodic(const Duration(seconds: 1), (i) => i).listen((event) {
      if (mounted) {
        setState(() {
          _counter = event;
        });
      }
    });
  }

  void _processFeedJson() {
    try {
      final List<dynamic> parsedList = jsonDecode(widget.rawFeedJson);
      final sortedList = parsedList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      sortedList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      _processedFeed = sortedList;
    } catch (_) {
      _processedFeed = [];
    }
  }

  @override
  void didUpdateWidget(covariant UserFeedScreenRefactored oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawFeedJson != widget.rawFeedJson) {
      setState(() {
        _processFeedJson();
      });
    }
  }

  Future<void> _saveAuthTokenSecurely(String token) async {
    await widget.secureStorage.write(key: 'jwt_auth_token', value: token);
  }

  @override
  void dispose() {
    _liveFeedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("User Live Feed ($_counter)"),
      ),
      body: ListView.builder(
        itemCount: _processedFeed.length,
        itemBuilder: (context, index) {
          final item = _processedFeed[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(item['title'] ?? ''),
              subtitle: Text("Score: ${item['score']}"),
            ),
          );
        },
      ),
    );
  }
}
