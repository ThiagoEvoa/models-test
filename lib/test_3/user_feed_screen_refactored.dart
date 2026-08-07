import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';

/// Abstract contract for secure token storage.
/// Implementations should use platform-secure mechanisms
/// (e.g., Keychain on iOS, Keystore on Android).
abstract class SecureStorageContract {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
}

/// A refactored, production-ready feed screen that resolves:
/// - Hardcoded API secret key (removed entirely)
/// - Insecure SharedPreferences token storage (replaced with SecureStorageContract)
/// - StreamSubscription memory leak (cancelled in dispose)
/// - JSON parsing inside build() (moved to initState)
/// - State mutation inside build() (eliminated)
/// - Missing JSON error handling (added try-catch with fallback)
/// - Unsafe type casting (added null-safe defaults)
class UserFeedScreenRefactored extends StatefulWidget {
  final String rawFeedJson;
  final SecureStorageContract secureStorage;

  const UserFeedScreenRefactored({
    Key? key,
    required this.rawFeedJson,
    required this.secureStorage,
  }) : super(key: key);

  @override
  _UserFeedScreenRefactoredState createState() =>
      _UserFeedScreenRefactoredState();
}

class _UserFeedScreenRefactoredState extends State<UserFeedScreenRefactored> {
  late StreamSubscription<int> _liveFeedSubscription;
  List<Map<String, dynamic>> _processedFeed = [];
  int _counter = 0;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    _parseFeedData();

    _liveFeedSubscription =
        Stream.periodic(const Duration(seconds: 1), (i) => i).listen((event) {
      if (mounted) {
        setState(() {
          _counter = event;
        });
      }
    });
  }

  /// Parses and sorts the JSON feed data once, outside of build().
  void _parseFeedData() {
    try {
      final List<dynamic> parsedList = jsonDecode(widget.rawFeedJson);
      final sortedList =
          parsedList.map((e) => Map<String, dynamic>.from(e)).toList();
      sortedList.sort((a, b) {
        final scoreB = (b['score'] as int?) ?? 0;
        final scoreA = (a['score'] as int?) ?? 0;
        return scoreB.compareTo(scoreA);
      });
      _processedFeed = sortedList;
      _parseError = null;
    } catch (e) {
      _processedFeed = [];
      _parseError = 'Failed to parse feed data.';
    }
  }

  @override
  void dispose() {
    _liveFeedSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Live Feed ($_counter)'),
      ),
      body: _parseError != null
          ? Center(child: Text(_parseError!))
          : ListView.builder(
              itemCount: _processedFeed.length,
              itemBuilder: (context, index) {
                final item = _processedFeed[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(item['title'] ?? ''),
                    subtitle: Text('Score: ${item['score'] ?? 0}'),
                  ),
                );
              },
            ),
    );
  }
}
