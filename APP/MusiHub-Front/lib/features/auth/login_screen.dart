import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/push/push_notifications_service.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/auth/register_screen.dart';
import 'package:musihub_front/features/opportunities/opportunities_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialMessage});

  final String? initialMessage;

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
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(apiClient: _apiClient);
    _successMessage = widget.initialMessage;
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
      _successMessage = null;
    });

    try {
      final token = await _authApi.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _tokenStore.saveAccessToken(token);
      await _authApi.me(token);
      await PushNotificationsService.registerDevice(authToken: token);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OpportunitiesListScreen(tokenStore: _tokenStore),
        ),
      );
    } catch (_) {
      await _tokenStore.clearAccessToken();

      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo iniciar sesion. Revisa los datos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openRegister() async {
    final wasRegistered = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const RegisterScreen()),
    );

    if (wasRegistered != true || !mounted) return;

    setState(() {
      _successMessage = 'Cuenta creada. Inicia sesion.';
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MusiHub')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              maxLength: InputLimits.email,
              decoration: const InputDecoration(
                labelText: 'Email',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              maxLength: InputLimits.password,
              decoration: const InputDecoration(
                labelText: 'Contrasena',
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _login,
              child: Text(_isLoading ? 'Entrando...' : 'Entrar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading ? null : _openRegister,
              child: const Text('Crear cuenta'),
            ),
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _successMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
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
    );
  }
}
