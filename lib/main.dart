// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'chat_screen.dart';

void main() {
  Logger.root.level = Level.ALL; // INFO
  Logger.root.onRecord.listen((record) => debugPrint('\n${record.message}\n'));

  runApp(_MainApp());
}

class _MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'CalPal',
    home: ChatScreen(),
    debugShowCheckedModeBanner: false,
  );
}
