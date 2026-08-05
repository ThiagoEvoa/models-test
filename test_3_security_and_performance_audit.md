# Test 3: Vulnerability, Security & Performance Review (Flutter)

## Objective
Evaluate the model's ability to audit Flutter/Dart code for security flaws (OWASP Mobile Top 10), severe memory leaks, and UI rendering performance bottlenecks, and produce a refactored, production-ready version.

---

## Scenario: Flutter Feed Screen Code Review

The following code is a candidate submission for a production Flutter app (`user_feed_screen.dart`). It compiles and renders, but contains **3 critical categories of bugs**:
1. **Security Vulnerabilities** (Insecure storage & hardcoded API secrets).
2. **Memory & Resource Leaks** (Un-disposed streams and controllers).
3. **Severe Performance Bottlenecks** (Main thread blocking in `build()`, missing const constructors).

---

## Input Code Snippet for the Model

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
  // FLAW 1: Hardcoded API Secret Key in Client Code
  static const String apiSecretKey = "sk_live_99a8b7c6d5e4f3a2b1c0_SECRET";
  
  late StreamSubscription _liveFeedSubscription;
  List<Map<String, dynamic>> _processedFeed = [];
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _saveAuthToken("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."); // Save JWT token
    
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
    // Heavy synchronous JSON parsing and sorting 10,000 items on every rebuild/setState
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
```

---

## Prompt to Give to the Model

```markdown
Perform a senior-level Flutter code review on `user_feed_screen.dart`.

### Task Instructions:
1. **Identify All Flaws**: Locate and explain all security vulnerabilities, memory leaks, and performance anti-patterns present in the code. Group them into:
   - Security Flaws
   - Lifecycle & Memory Leak Flaws
   - Flutter Performance & Rendering Bottlenecks
2. **Refactor Code**: Provide a fully refactored, production-ready Flutter widget that resolves every issue identified. Use proper Flutter conventions (`flutter_secure_storage`, `compute()` / isolates, `dispose()`, `const` constructors).
```

---

## Evaluation Rubric & Checklist

The model's review and refactored code must address all 5 specific flaws:

### 1. Security Analysis (30 Points)
- [ ] **Hardcoded Secret**: Identifies `apiSecretKey` and instructs moving it to compile-time environment variables (`--dart-define`) or backend proxy.
- [ ] **Insecure Token Storage**: Identifies `SharedPreferences` as unencrypted local storage on iOS/Android, recommending `flutter_secure_storage` (iOS Keychain / Android Keystore).

### 2. Memory Leak Analysis (30 Points)
- [ ] **Stream Subscription Disposal**: Identifies `_liveFeedSubscription` is never cancelled in `dispose()`.
- [ ] **State Lifecycle**: Implements `override void dispose()` and calls `_liveFeedSubscription.cancel()` and `super.dispose()`.

### 3. Performance & Rendering Analysis (40 Points)
- [ ] **Main Thread Blocking in `build()`**: Identifies `jsonDecode` and sorting inside `build()` method, which freezes UI frames on every `setState`.
- [ ] **Background Processing**: Moves heavy computation out of `build()` to `didUpdateWidget` / `initState` or uses Flutter's `compute()` / `Isolate.run()` for background thread processing.
- [ ] **Const Optimization**: Adds `const` modifiers to static widgets (`const Card(...)`, `const Icon(...)`) to prevent unnecessary widget re-renders.

---

## Benchmark Score Summary Sheet

When evaluating candidate models (e.g. Gemini, Claude, GPT-4), use this unified scorecard across the 3 test files:

```
===============================================================
FLUTTER / DART MODEL EVALUATION SCORECARD
===============================================================
Model Name: ________________________  Date: ____________________

Test 1: AsyncTaskQueue (Pure Algorithmic Synthesis)
[ ] Concurrency Guarding (20 pts): _____
[ ] Debounce & Timer Safety (15 pts): _____
[ ] Error Propagation (15 pts): _____
[ ] Passes All Unit Tests (50 pts): _____
Test 1 Total: _____ / 100

Test 2: Auth Refresh Race Condition (Repo Patch Repair)
[ ] Valid Git Diff Format (20 pts): _____
[ ] Asynchronous Lock/Completer Fix (40 pts): _____
[ ] Single Invalidation Call (20 pts): _____
[ ] Clean Error/Reset Handling (20 pts): _____
Test 2 Total: _____ / 100

Test 3: Feed Screen Audit (Security & Performance)
[ ] Security Vulnerabilities (30 pts): _____
[ ] Memory Leak / Stream Disposal (30 pts): _____
[ ] Performance & Isolate Refactoring (40 pts): _____
Test 3 Total: _____ / 100

FINAL BENCHMARK SCORE: _____ / 300
===============================================================
```
