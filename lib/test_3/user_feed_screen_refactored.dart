import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';

/// Abstract contract for secure token storage to avoid insecure SharedPreferences usage.
abstract class SecureStorageContract {
  Future<void> writeToken(String key, String value);
  Future<String?> readToken(String key);
}

class UserFeedScreen extends StatefulWidget {
  final String rawFeedJson;

  const UserFeedScreen({super.key, required this.rawFeedJson});

  @override
  State<UserFeedScreen> createState() => _UserFeedScreenState();
}

class _UserFeedScreenState extends State<UserFeedScreen> {
  late StreamSubscription<int> _liveFeedSubscription;
  List<Map<String, dynamic>> _processedFeed = [];
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
    
    // Timer for live feed updates
    _liveFeedSubscription = Stream.periodic(const Duration(seconds: 1), (i) => i).listen((event) {
      if (mounted) {
        setState(() {
          _counter = event;
        });
      }
    });
  }

  void _initializeData() {
    try {
      final List<dynamic> parsedList = jsonDecode(widget.rawFeedJson);
      final sortedList = parsedList
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      
      sortedList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      _processedFeed = sortedList;
    } catch (e) {
      debugPrint('Error parsing feed JSON: $e');
      _processedFeed = [];
    }
  }

  @override
  void dispose() {
    _liveFeedSubscription.cancel(); // Fix: Prevent memory leak
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
              title: Text(item['title']?.toString() ?? ''),
              subtitle: Text("Score: ${item['score']}"),
            ),
          );
        },
      ),
    );
  }
}
