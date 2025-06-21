// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:logging/logging.dart';
import 'package:split_view/split_view.dart';

import 'dartantic_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _zapierServer = McpClient.remote(
    'google-calendar',
    url: Uri.parse(Platform.environment['ZAPIER_MCP_URL']!),
  );

  late final Agent _agent;
  late final DartanticProvider _provider;
  var _loading = true;
  var _showMessagesView = true;

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
When calling google_calendar_find_event, use a specific date instead of works
like "today" or "tomorrow".
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

    _provider = DartanticProvider(_agent);
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    unawaited(_zapierServer.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('CalPal - Your Calendar Chat Assistant'),
      actions: [
        IconButton(
          onPressed:
              () => setState(() => _showMessagesView = !_showMessagesView),
          icon: Icon(
            _showMessagesView ? Icons.visibility_off : Icons.visibility,
          ),
        ),
      ],
    ),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : buildSplitView(),
  );

  Widget buildSplitView() =>
      _showMessagesView
          ? SplitView(
            viewMode: SplitViewMode.Horizontal,
            gripColor: Colors.transparent,
            indicator: const SplitIndicator(
              viewMode: SplitViewMode.Horizontal,
              color: Colors.grey,
            ),
            gripColorActive: Colors.transparent,
            activeIndicator: const SplitIndicator(
              viewMode: SplitViewMode.Horizontal,
              isActive: true,
              color: Colors.black,
            ),
            children: [buildChatView(), buildMessagesView()],
          )
          : buildChatView();

  LlmChatView buildChatView() => LlmChatView(
    provider: _provider,
    welcomeMessage:
        'Hi! I can help you manage your calendar. '
        'What can I do for you?',
    suggestions: const [
      "What's on my schedule today?",
      'Schedule a two-hour block for focused work tomorrow.',
      'Can I skip work and go to the movies tomorrow?',
    ],
  );

  Widget buildMessagesView() => ListenableBuilder(
    listenable: _provider,
    builder: (context, child) {
      final messages = _provider.messages.toList().reversed.toList();
      return ListView.builder(
        reverse: true,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final text = _messageText(message);
          return ListTile(
            title: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () {
              unawaited(
                showDialog<void>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        content: SingleChildScrollView(child: Text(text)),
                      ),
                ),
              );
            },
          );
        },
      );
    },
  );

  String _messageText(Message message) {
    final buffer = StringBuffer('[${message.role.name}]: ');
    for (final part in message.parts) {
      buffer.write(switch (part) {
        TextPart() => part.text.trim(),
        LinkPart() => '[Link: ${part.url}]',
        DataPart() => '[Data: ${part.mimeType}]',
        ToolPart() => _toolText(part),
      });
    }
    return buffer.toString();
  }

  String _toolText(ToolPart part) {
    switch (part.kind) {
      case ToolPartKind.call:
        return '[Tool: ${part.name}(${part.arguments})]';
      case ToolPartKind.result:
        return '[Tool Result: ${part.name}(...) => ${part.result}]';
    }
  }
}
