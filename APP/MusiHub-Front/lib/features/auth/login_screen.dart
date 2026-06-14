import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/push/push_notifications_service.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/auth/register_screen.dart';
import 'package:musihub_front/features/auth/widgets/auth_logo.dart';
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          children: [
            const Center(child: MusiHubLogoMark(size: 236)),
            const SizedBox(height: 12),
            Text(
              'MusiHub',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'La plataforma que centraliza oportunidades musicales',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
            Text(
              'Iniciar sesion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              maxLength: InputLimits.email,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Introduce tu email',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              maxLength: InputLimits.password,
              onSubmitted: (_) {
                if (!_isLoading) {
                  _login();
                }
              },
              decoration: const InputDecoration(
                labelText: 'Contrasena',
                hintText: 'Introduce tu contrasena',
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _login,
              child: Text(_isLoading ? 'Entrando...' : 'Iniciar sesion'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : _openRegister,
              child: const Text('Crear cuenta'),
            ),
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              _AuthMessage(
                message: _successMessage!,
                color: MusiHubColors.primary,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _AuthMessage(
                message: _errorMessage!,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
