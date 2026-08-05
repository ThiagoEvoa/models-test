# Test 3: Vulnerability, Security & Performance Review (Flutter)

## Prompt to Give to the Model

Perform a senior-level Flutter code review on `user_feed_screen.dart` below.

### Code to Audit (`user_feed_screen.dart`):

```dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserFeedScreen extends StatefulWidget {
  final String rawFeedJson;

  const UserFeedScreen({Key? key, required this.rawFeedJson}) : super(key: key);

  @override
  _UserFeedScreenState createState() => _UserFeedScreenState();
}

class _UserFeedScreenState extends State<UserFeedScreen> {
  static const String apiSecretKey = "sk_live_99a8b7c6d5e4f3a2b1c0_SECRET";
  
  late StreamSubscription _liveFeedSubscription;
  List<Map<String, dynamic>> _processedFeed = [];
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _saveAuthToken("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...");
    
    _liveFeedSubscription = Stream.periodic(Duration(seconds: 1), (i) => i).listen((event) {
      setState(() {
        _counter = event;
      });
    });
  }

  Future<void> _saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_auth_token', token);
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> parsedList = jsonDecode(widget.rawFeedJson);
    final sortedList = parsedList.map((e) => Map<String, dynamic>.from(e)).toList();
    sortedList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    _processedFeed = sortedList;

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
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text(item['title'] ?? ''),
              subtitle: Text("Score: ${item['score']}"),
            ),
          );
        },
      ),
    );
  }
}
```

### Task Instructions:
1. **Audit Report**: Provide a code review report in markdown identifying all security vulnerabilities, memory leaks, and performance anti-patterns present in the code.
2. **Refactored Code**: Provide a fully refactored, production-ready Flutter widget at `lib/test_3/user_feed_screen_refactored.dart` that resolves every issue identified. Include an abstract `SecureStorageContract` for secure token storage.

### CRITICAL INSTRUCTIONS FOR THE MODEL:
- Do NOT write any unit tests, widget tests, or test files. The test suite is already provided in the repository.
- Output ONLY the audit markdown report and the refactored widget implementation at `lib/test_3/user_feed_screen_refactored.dart`.
