import 'package:flutter/material.dart';
import 'package:musihub_front/features/auth/login_screen.dart';

void main() {
  runApp(const MusiHubApp());
}

class MusiHubApp extends StatelessWidget {
  const MusiHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusiHub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const LoginScreen(),
    );
  }
}
