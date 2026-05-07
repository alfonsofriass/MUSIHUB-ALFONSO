import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiClient = ApiClient();
  final _tokenStore = TokenStore();

  late final AuthApi _authApi;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(apiClient: _apiClient);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authApi.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _tokenStore.saveAccessToken(token);
      final user = await _authApi.me(token);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(user: user, tokenStore: _tokenStore),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo iniciar sesion.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MusiHub')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contrasena'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _login,
                child: Text(_isLoading ? 'Entrando...' : 'Entrar'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
