import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

/// Abstract contract for storing sensitive key/value pairs (e.g. JWT access
/// tokens) in a platform-secure store.
///
/// Implementations MUST use the platform's secure storage primitives
/// (e.g. the iOS Keychain / Android EncryptedSharedPreferences) rather than
/// `SharedPreferences` in plaintext.
abstract interface class SecureStorageContract {
  /// Returns the stored value for [key], or `null` when absent.
  Future<String?> read({required String key});

  /// Persists [value] under [key].
  Future<void> write({required String key, required String value});
}

/// A `StatefulWidget` that renders a live user feed with a counter in the
/// app-bar.
///
/// This is a production-hardened rewrite of the original `user_feed_screen.dart`
/// that fixes the original's security, memory-leak, and performance issues:
///
/// - No hardcoded secrets or tokens are compiled into the widget.
/// - Sensitive token state is exchanged through [SecureStorageContract]
///   instead of being written to plaintext `SharedPreferences`.
/// - The live-feed [Stream] subscription is cancelled in [dispose], eliminating
///   the original memory / resource leak.
/// - The JSON is decoded and sorted ONCE in [initState] and cached, instead of
///   being re-parsed on every [build] (a performance anti-pattern).
/// - Async callbacks (storage, stream events) are guarded by `mounted` so they
///   never call `setState` on a detached element.
class UserFeedScreenRefactored extends StatefulWidget {
  /// Raw JSON array of feed items, e.g. `'[{"title":"A","score":10}]'`.
  final String rawFeedJson;

  /// Secure store used to persist/restore the auth token. When `null`, the
  /// widget simply renders the feed without touching storage.
  final SecureStorageContract? secureStorage;

  /// Optional pre-provisioned token to persist securely on first load.
  ///
  /// When provided, it is written to [secureStorage] via the secure contract.
  /// There is no hardcoded fallback.
  final String? authToken;

  /// Optional live-feed source. When `null`, an empty stream is used and the
  /// app-bar counter stays at `0` (no dangling timers / no auto timers).
  final Stream<int>? liveFeed;

  const UserFeedScreenRefactored({
    Key? key,
    required this.rawFeedJson,
    this.secureStorage,
    this.authToken,
    this.liveFeed,
    }) : super(key: key);

  @override
  State<UserFeedScreenRefactored> createState() =>
      _UserFeedScreenRefactoredState();
}

class _UserFeedScreenRefactoredState
    extends State<UserFeedScreenRefactored> {
  static const String _authTokenKey = 'jwt_auth_token';

  // Parsed + sorted feed, computed exactly once so `build` does no JSON work.
  late final List<Map<String, dynamic>> _processedFeed;

  // Live-feed subscription, always cancelled in `dispose`.
  StreamSubscription<int>? _liveFeedSubscription;

  int _counter = 0;
  String? _token;

  @override
  void initState() {
    super.initState();
    _processedFeed = _buildFeed(widget.rawFeedJson);

    // Subscribe to a controllable stream. When `liveFeed` is null we use an
    // empty stream, so no `Stream.periodic` timer is ever created and there is
    // nothing dangling to leak. The subscription IS always cancelled.
    _liveFeedSubscription =
        (widget.liveFeed ?? const Stream<int>.empty()).listen((event) {
      if (!mounted) return;
      setState(() => _counter = event);
    });

    _bootstrapToken();
  }

  List<Map<String, dynamic>> _buildFeed(String rawJson) {
    Object decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException {
      // Malformed JSON must never crash the screen.
      return const <Map<String, dynamic>>[];
    }

    if (decoded is! List) {
      return const <Map<String, dynamic>>[];
    }

    final sorted = decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList();

    // Sort by score descending, tolerating missing / non-int / string scores.
    sorted.sort((a, b) {
      final int? sa = _asInt(a['score']);
      final int? sb = _asInt(b['score']);
      if (sa == null && sb == null) return 0;
      if (sa == null) return 1;
      if (sb == null) return -1;
      return sb.compareTo(sa);
    });

    return sorted;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _bootstrapToken() async {
    final store = widget.secureStorage;
    if (store == null) return;

    try {
      final String? token = widget.authToken;
      if (token != null) {
        await store.write(key: _authTokenKey, value: token);
        if (!mounted) return;
        setState(() => _token = token);
        return;
      }

      final restored = await store.read(key: _authTokenKey);
      if (!mounted) return;
      setState(() => _token = restored);
    } catch (_) {
      // Storage failures must not crash the UI.
    }
  }

  @override
  void dispose() {
    // Always cancel the live-feed subscription to avoid a memory leak.
    _liveFeedSubscription?.cancel();
    _liveFeedSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Live Feed ($_counter)'),
        actions: [
          if (_token != null)
            IconButton(
              icon: const Icon(Icons.lock_open,
                  semanticLabel: 'Authenticated'),
              onPressed: () {},
            ),
        ],
      ),
      body: ListView.builder(
        key: const ValueKey('user-feed-list'),
        itemCount: _processedFeed.length,
        itemBuilder: (BuildContext context, int index) {
          // Safe indexing: list is cached and index is in-range by contract.
          final item = _processedFeed[index];
          final title = item['title']?.toString() ?? '';
          final score = item['score'];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(title),
              subtitle:
                  score == null ? null : Text('Score: ${score.toString()}'),
            ),
          );
        },
      ),
    );
  }
}
