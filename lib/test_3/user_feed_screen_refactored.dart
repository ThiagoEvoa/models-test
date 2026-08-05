import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Abstract contract for secure storage (e.g. FlutterSecureStorage wrapper)
abstract class SecureStorageContract {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
}

// Background isolate function for heavy JSON parsing and sorting
List<Map<String, dynamic>> _parseAndSortFeedInBackground(String rawJson) {
  final List<dynamic> parsedList = jsonDecode(rawJson);
  final sortedList = parsedList.map((e) => Map<String, dynamic>.from(e)).toList();
  sortedList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
  return sortedList;
}

class UserFeedScreenRefactored extends StatefulWidget {
  final String rawFeedJson;
  final SecureStorageContract secureStorage;

  const UserFeedScreenRefactored({
    Key? key,
    required this.rawFeedJson,
    required this.secureStorage,
  }) : super(key: key);

  @override
  State<UserFeedScreenRefactored> createState() => _UserFeedScreenRefactoredState();
}

class _UserFeedScreenRefactoredState extends State<UserFeedScreenRefactored> {
  StreamSubscription<int>? _liveFeedSubscription;
  List<Map<String, dynamic>> _processedFeed = [];
  bool _isLoadingFeed = true;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _processFeed();
    _subscribeToLiveFeed();
  }

  @override
  void didUpdateWidget(covariant UserFeedScreenRefactored oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawFeedJson != widget.rawFeedJson) {
      _processFeed();
    }
  }

  Future<void> _processFeed() async {
    setState(() {
      _isLoadingFeed = true;
    });

    // Run heavy JSON parsing and sorting off the UI thread via compute() / Isolate
    final results = await compute(_parseAndSortFeedInBackground, widget.rawFeedJson);

    if (mounted) {
      setState(() {
        _processedFeed = results;
        _isLoadingFeed = false;
      });
    }
  }

  void _subscribeToLiveFeed() {
    // Correct lifecycle management: cancel existing subscription if active
    _liveFeedSubscription?.cancel();
    _liveFeedSubscription = Stream.periodic(const Duration(seconds: 1), (i) => i).listen((event) {
      if (mounted) {
        setState(() {
          _counter = event;
        });
      }
    });
  }

  @override
  void dispose() {
    // Fix: Properly dispose stream subscription to prevent memory leaks
    _liveFeedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("User Live Feed ($_counter)"),
      ),
      body: _isLoadingFeed
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
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
