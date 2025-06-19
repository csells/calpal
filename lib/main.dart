import 'dart:async';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_providers/flutter_ai_providers.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

void main() => runApp(_MainApp());

class _MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'CalPal', home: _ChatScreen());
}

class _ChatScreen extends StatefulWidget {
  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final McpServer _zapierServer = McpServer.remote(
    'google-calendar',
    url: Uri.parse(const String.fromEnvironment('ZAPIER_MCP_URL')),
  );

  late final Agent _agent;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_setupAgent());
  }

  Future<void> _setupAgent() async {
    setState(() => _loading = true);

    _agent = Agent(
      'gemini:gemini-2.5-flash',
      systemPrompt: '''
You are a helpful calendar assistant.

You have access to tools to get the current date/time and to interact with
Google Calendar.

Always use the get-current-date-time tool to anchor temporal references like
"today" and "tomorrow".

The user's primary calendar is csells@sellsbrothers.com.
''',
      tools: [
        Tool(
          name: 'get-current-date-time',
          description: 'Get the current local date and time in ISO-8601 format',
          onCall: (_) async => {'datetime': DateTime.now().toIso8601String()},
        ),
        ...(await _zapierServer.getTools()),
      ],
    );

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    unawaited(_zapierServer.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CalPal')),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : LlmChatView(
              provider: DartanticProvider(_agent),
              welcomeMessage:
                  'Hi! I can help you manage your calendar. '
                  'What can I do for you?',
              suggestions: const [
                "What's on my schedule today?",
                'Schedule a two-hour block for focused work tomorrow.',
                'Can I skip work and go to the movies tomorrow?',
              ],
            ),
  );
}
