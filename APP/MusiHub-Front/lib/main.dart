import 'package:flutter/material.dart';
import 'package:musihub_front/core/push/push_notifications_service.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/auth/session_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationsService.initialize();
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
