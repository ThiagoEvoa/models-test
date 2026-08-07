import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

/// Abstract contract for secure token storage.
/// Implementations should use platform-appropriate secure storage
/// (e.g., Keychain on iOS, Keystore on Android).
abstract class SecureStorageContract {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
}

/// A production-ready, refactored version of UserFeedScreen.
///
/// Fixes applied:
/// - Removed hardcoded API secret (was a critical security vulnerability).
/// - Replaced SharedPreferences with an injected [SecureStorageContract]
///   so tokens are stored securely and the implementation is testable.
/// - Moved expensive JSON parsing and sorting out of build() into initState()
///   to avoid repeated O(n log n) work on every rebuild.
/// - Properly cancels the StreamSubscription in dispose() to prevent memory leaks.
/// - Scoped setState to only the counter update, with the feed data cached.
class UserFeedScreenRefactored extends StatefulWidget {
  final String rawFeedJson;

  /// Injected secure storage — use flutter_secure_storage in production.
  final SecureStorageContract secureStorage;

  /// Optional token to persist securely on init.
  final String? authToken;

  const UserFeedScreenRefactored({
    Key? key,
    required this.rawFeedJson,
    required this.secureStorage,
    this.authToken,
  }) : super(key: key);

  @override
  State<UserFeedScreenRefactored> createState() =>
      _UserFeedScreenRefactoredState();
}

class _UserFeedScreenRefactoredState
    extends State<UserFeedScreenRefactored> {
  StreamSubscription<int>? _liveFeedSubscription;
  List<Map<String, dynamic>> _processedFeed = [];
  int _counter = 0;

  @override
  void initState() {
    super.initState();

    // Parse and sort the feed once, not on every build.
    _processFeed(widget.rawFeedJson);

    // Persist token securely if provided, via the injected contract.
    if (widget.authToken != null) {
      widget.secureStorage.write(
        key: 'jwt_auth_token',
        value: widget.authToken!,
      );
    }

    // Subscribe to the periodic stream and cancel in dispose() to prevent leaks.
    _liveFeedSubscription =
        Stream.periodic(const Duration(seconds: 1), (i) => i).listen((event) {
      if (mounted) {
        setState(() {
          _counter = event;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant UserFeedScreenRefactored oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-process feed only when the input actually changes.
    if (oldWidget.rawFeedJson != widget.rawFeedJson) {
      _processFeed(widget.rawFeedJson);
    }
  }

  void _processFeed(String rawJson) {
    final List<dynamic> parsed = jsonDecode(rawJson);
    final List<Map<String, dynamic>> mapped =
        parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    mapped.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    _processedFeed = mapped;
  }

  @override
  void dispose() {
    // Cancel the subscription to prevent setState being called on a disposed widget.
    _liveFeedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Live Feed ($_counter)'),
      ),
      body: ListView.builder(
        itemCount: _processedFeed.length,
        itemBuilder: (context, index) {
          final item = _processedFeed[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(item['title'] as String? ?? ''),
              subtitle: Text('Score: ${item['score']}'),
            ),
          );
        },
      ),
    );
  }
}
