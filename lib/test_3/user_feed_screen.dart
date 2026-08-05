// ignore_for_file: unused_field
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
  // FLAW 1: Hardcoded API Secret Key in Client Code
  static const String apiSecretKey = "sk_live_99a8b7c6d5e4f3a2b1c0_SECRET";
  
  late StreamSubscription _liveFeedSubscription;
  List<Map<String, dynamic>> _processedFeed = [];
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _saveAuthToken("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...");
    
    // FLAW 2: Subscribing to stream without canceling in dispose()
    _liveFeedSubscription = Stream.periodic(Duration(seconds: 1), (i) => i).listen((event) {
      setState(() {
        _counter = event;
      });
    });
  }

  // FLAW 3: Insecure plain-text storage of JWT bearer tokens
  Future<void> _saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_auth_token', token);
  }

  @override
  Widget build(BuildContext context) {
    // FLAW 4: Main thread CPU blocking inside build() method!
    final List<dynamic> parsedList = jsonDecode(widget.rawFeedJson);
    final sortedList = parsedList.map((e) => Map<String, dynamic>.from(e)).toList();
    sortedList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    _processedFeed = sortedList;

    return Scaffold(
      appBar: AppBar(
        // FLAW 5: Missing const constructors causing full tree rebuilds
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
