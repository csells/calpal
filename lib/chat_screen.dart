// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
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

  late final DartanticProvider _provider;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_setupAgent());
  }

  Future<void> _setupAgent() async {
    setState(() => _loading = true);

    _provider = DartanticProvider(await _zapierAgent());
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
            : buildSplitView(),
  );

  Widget buildSplitView() => SplitView(
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
  );

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
      const courierNewStyle = TextStyle(
        fontFamily: 'Courier New',
        fontWeight: FontWeight.bold,
        fontSize: 16,
      );
      final messages = _provider.messages.toList().reversed.toList();
      return ListView.builder(
        itemCount: messages.length,
        reverse: true,
        itemBuilder: (context, index) {
          final message = messages[index];
          final text = _messageText(message);
          return ListTile(
            title: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: courierNewStyle,
            ),
            onTap: () {
              unawaited(
                showDialog<void>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        content: SingleChildScrollView(
                          child: SelectableText(text, style: courierNewStyle),
                        ),
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
        return '[Tool.call: ${part.name}(${part.arguments})]';
      case ToolPartKind.result:
        const encoder = JsonEncoder.withIndent('  ');
        var result = part.result;
        // The result from Zapier comes back as a map with a 'result' key
        // that is a JSON string. We decode it to make it readable.
        if (result.containsKey('result')) {
          final resultMap = Map<String, dynamic>.from(result);
          final resultValue = resultMap['result'];
          if (resultValue is String) {
            try {
              resultMap['result'] = json.decode(resultValue);
              result = resultMap;
            } on Exception catch (e) {
              // Ignore if it's not valid JSON.
            }
          }
        }
        final prettyResult = encoder.convert(result);
        return '[Tool.result: ${part.name}(...) => $prettyResult]';
    }
  }
}

Future<Agent> _zapierAgent() async {
  final zapierServer = McpClient.remote(
    'google-calendar',
    url: Uri.parse(Platform.environment['ZAPIER_MCP_URL']!),
  );

  final zapierTools = await zapierServer.listTools();
  for (final tool in zapierTools) {
    print('Tool: ${tool.name}, ${tool.description}');
  }

  return Agent(
    'google',
    systemPrompt: '''
You are a helpful calendar assistant.

1. **Ground yourself**
   * Always call the get-current-date-time tool **first**.

2. **Tool permissions**
   * You already have permission to call any Google Calendar tool.
   * Never ask the user for additional access or confirmation.

3. **Default calendar**
   * My Google-calendar email is `csells@sellsbrothers.com`.
   * Use that as the default `calendarId` unless the user says otherwise.

4. **Searching a single calendar day**
   * When the user asks for events for a specific <DATE>, build the date window like this:

     * `start_time_before` -> "`<DATE>T23:59:59`" (end of day), i.e. the latest an event may begin
     * `end_time_after`  -> "`<DATE>T00:00:00`" (start of day), i.e. the earliest an event may end
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
}
