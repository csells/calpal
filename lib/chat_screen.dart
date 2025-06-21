// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_providers/flutter_ai_providers.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:split_view/split_view.dart';

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

  DartanticProvider? _provider;
  List<Tool>? _tools;
  final _models = ['google', 'openai'];
  late String _selectedModel;

  @override
  void initState() {
    super.initState();
    _selectedModel = _models.first;
    unawaited(_resetProviderAndTools(_selectedModel));
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
        DropdownButton<String>(
          value: _selectedModel.split(RegExp('[:/]')).first,
          items:
              _models
                  .map(
                    (model) => DropdownMenuItem<String>(
                      value: model,
                      child: Text(model),
                    ),
                  )
                  .toList(),
          onChanged: (newModel) {
            if (newModel != null && newModel != _selectedModel) {
              setState(() => _selectedModel = newModel);
              unawaited(_resetProviderAndTools(_selectedModel));
            }
          },
          underline: const SizedBox.shrink(),
        ),
      ],
    ),
    body:
        _provider == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
              children: [
                Expanded(
                  child: SplitView(
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
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Model: $_selectedModel'),
                  ),
                ),
              ],
            ),
  );

  LlmChatView buildChatView() => LlmChatView(
    provider: _provider!,
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
    listenable: _provider!,
    builder: (context, child) {
      const courierNewStyle = TextStyle(
        fontFamily: 'Courier New',
        fontWeight: FontWeight.bold,
        fontSize: 16,
      );

      final messages = _provider!.messages.toList().reversed.toList();
      final messageCount = messages.length;
      final toolCount = _tools!.length;

      return ListView.builder(
        itemCount: messageCount + toolCount, // total items
        reverse: true,
        itemBuilder: (context, index) {
          if (index < messageCount) {
            // show a message
            final message = messages[index];
            final messageText = _messageText(message);
            return ListTile(
              title: Text(
                messageText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: courierNewStyle,
              ),
              onTap: () => _messageBox(context, messageText, courierNewStyle),
            );
          }

          // show a tool
          final tool = _tools![index - messageCount];
          final toolText = _toolText(tool);

          return ListTile(
            title: Text(
              toolText,
              style: courierNewStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _messageBox(context, toolText, courierNewStyle),
          );
        },
      );
    },
  );

  void _messageBox(
    BuildContext context,
    String toolText,
    TextStyle courierNewStyle,
  ) {
    unawaited(
      showDialog<void>(
        context: context,
        builder:
            (context) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: SelectableText(toolText, style: courierNewStyle),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  String _toolText(Tool tool) {
    const encoder = JsonEncoder.withIndent('  ');
    final schemaSource = tool.inputSchema?.toJson() ?? '{}';
    final schemaToEncode = json.decode(schemaSource);
    final prettyInputSchema = encoder.convert(schemaToEncode);
    final toolText =
        '[tool]: ${tool.name} (${tool.description})\n'
        'schema: $prettyInputSchema';
    return toolText;
  }

  String _messageText(Message message) {
    final buffer = StringBuffer('[${message.role.name}]: ');
    for (final part in message.parts) {
      buffer.write(switch (part) {
        TextPart() => part.text.trim(),
        LinkPart() => '[Link: ${part.url}]',
        DataPart() => '[Data: ${part.mimeType}]',
        ToolPart() => _toolPartText(part),
      });
    }
    return buffer.toString();
  }

  String _toolPartText(ToolPart part) {
    switch (part.kind) {
      case ToolPartKind.call:
        const encoder = JsonEncoder.withIndent('  ');
        final prettyArguments = encoder.convert(part.arguments);
        return '[Tool.call: ${part.name}($prettyArguments)]';
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
            } on Exception catch (_) {
              // Ignore if it's not valid JSON.
            }
          }
        }
        final prettyResult = encoder.convert(result);
        return '[Tool.result: ${part.name}(...) => $prettyResult]';
    }
  }

  Future<void> _resetProviderAndTools(String model) async {
    setState(() => _provider = null);

    if (_tools == null) {
      final zapierTools = await _zapierServer.listTools();
      for (final tool in zapierTools) {
        print('Tool: ${tool.name}, ${tool.description}');
      }

      _tools = [
        Tool(
          name: 'get-current-date-time',
          description: 'Get the current local date and time in ISO-8601 format',
          onCall: (_) async => {'datetime': DateTime.now().toIso8601String()},
        ),
        ...zapierTools,
      ];
    }

    final tools = _tools!;
    final toolUsages = StringBuffer();
    for (final tool in tools) {
      toolUsages.write('- Tool: ${tool.name}\n');
      toolUsages.write('  - Description: ${tool.description}\n');
      toolUsages.write('  - Input schema: ${tool.inputSchema}\n');
      toolUsages.write('\n');
    }

    final agent = Agent(
      model,
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

4. **Tool usage**
Before composing a tool call, carefully consider each tool's name, description
input schema. In particular, pay close attention to required parameters and
their descriptions. The tools will fail otherwise.

$toolUsages
''',
      tools: tools,
    );

    setState(() {
      _provider = DartanticProvider(agent);
      _selectedModel = agent.model;
    });
  }
}
