import 'package:flutter/material.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/auth/session_gate.dart';

void main() {
  runApp(const MusiHubApp());
}

class MusiHubApp extends StatelessWidget {
  const MusiHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusiHub',
      debugShowCheckedModeBanner: false,
      theme: MusiHubTheme.light(),
      home: const SessionGate(),
    );
  }
}
