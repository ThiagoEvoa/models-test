import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

/// Contract defining secure key-value storage operations.
abstract class SecureStorageContract {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
}

/// Immutable, type-safe representation of a feed item.
class FeedItem {
  final String title;
  final int score;

  const FeedItem({
    required this.title,
    required this.score,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      title: json['title'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Refactored, production-ready UserFeedScreen addressing security,
/// memory leak, and performance concerns.
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
  List<FeedItem> _processedFeed = [];
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _processFeedData();
    _initLiveFeedStream();
  }

  @override
  void didUpdateWidget(covariant UserFeedScreenRefactored oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawFeedJson != widget.rawFeedJson) {
      _processFeedData();
    }
  }

  void _processFeedData() {
    try {
      final dynamic decoded = jsonDecode(widget.rawFeedJson);
      if (decoded is List) {
        final items = <FeedItem>[];
        for (final element in decoded) {
          if (element is Map) {
            items.add(FeedItem.fromJson(Map<String, dynamic>.from(element)));
          }
        }
        items.sort((a, b) => b.score.compareTo(a.score));
        _processedFeed = items;
      } else {
        _processedFeed = [];
      }
    } catch (_) {
      _processedFeed = [];
    }
  }

  void _initLiveFeedStream() {
    _liveFeedSubscription = Stream.periodic(
      const Duration(seconds: 1),
      (i) => i + 1,
    ).listen((event) {
      if (mounted) {
        setState(() {
          _counter = event;
        });
      }
    });
  }

  @override
  void dispose() {
    _liveFeedSubscription?.cancel();
    _liveFeedSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Live Feed ($_counter)'),
      ),
      body: _processedFeed.isEmpty
          ? const Center(child: Text('No feed items available'))
          : ListView.builder(
              itemCount: _processedFeed.length,
              itemBuilder: (context, index) {
                final item = _processedFeed[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(item.title),
                    subtitle: Text('Score: ${item.score}'),
                  ),
                );
              },
            ),
    );
  }
}
