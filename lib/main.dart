// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

import 'chat_screen.dart';

void main() => runApp(_MainApp());

class _MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'CalPal',
    home: ChatScreen(),
    debugShowCheckedModeBanner: false,
  );
}
