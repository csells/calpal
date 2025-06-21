// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_ai_providers/flutter_ai_providers.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:logging/logging.dart';

import 'dartantic_provider.dart';

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
  final _zapierServer = McpClient.remote(
    'google-calendar',
    url: Uri.parse(Platform.environment['ZAPIER_MCP_URL']!),
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

    Logger.root.level = Level.ALL; // INFO
    Logger.root.onRecord.listen(
      (record) => debugPrint('\n${record.message}\n'),
    );

    final zapierServer = McpClient.remote(
      'google-calendar',
      url: Uri.parse(Platform.environment['ZAPIER_MCP_URL']!),
    );
    final zapierTools = await zapierServer.listTools();

    _agent = Agent(
      'google',
      systemPrompt: '''
You are a helpful calendar assistant.
Make sure you use the get-current-date-time tool FIRST to ground yourself.
You have access to tools to interact with Google Calendar.
You already have permission to call any Google Calendar tool.
Never ask the user for additional access or confirmation.
My Google calendar email is csells@sellsbrothers.com.
''',
      tools: [
        Tool(
          name: 'get-current-date-time',
          description: 'Get the current local date and time in ISO-8601 format',
          onCall: (_) async => {'datetime': DateTime.now().toIso8601String()},
        ),
        ...zapierTools,
      ],
      toolCallingMode: ToolCallingMode.multiStep,
    );

    for (final tool in zapierTools) {
      print('Tool: ${tool.name}, ${tool.description}');
    }

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    unawaited(_zapierServer.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CalPal - Your Calendar Chat Assistant')),
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
