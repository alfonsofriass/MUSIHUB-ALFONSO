import 'package:flutter/material.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/auth/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user, required this.tokenStore});

  final AuthUser user;
  final TokenStore tokenStore;

  Future<void> _logout(BuildContext context) async {
    await tokenStore.clearAccessToken();

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sesion')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sesion iniciada'),
              const SizedBox(height: 16),
              Text('ID: ${user.id}'),
              Text('Email: ${user.email}'),
              Text('Nombre: ${user.fullName}'),
              Text('Rol: ${user.role}'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _logout(context),
                child: const Text('Cerrar sesion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
