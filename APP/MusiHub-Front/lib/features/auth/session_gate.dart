import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/push/push_notifications_service.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/auth/login_screen.dart';
import 'package:musihub_front/features/opportunities/opportunities_list_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final _apiClient = ApiClient();
  final _tokenStore = TokenStore();

  late final AuthApi _authApi;
  late final Future<Widget> _initialScreen;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(apiClient: _apiClient);
    _initialScreen = _loadInitialScreen();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<Widget> _loadInitialScreen() async {
    final token = await _tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      return const LoginScreen();
    }

    try {
      await _authApi.me(token);
      await PushNotificationsService.registerDevice(authToken: token);

      return OpportunitiesListScreen(tokenStore: _tokenStore);
    } catch (_) {
      await _tokenStore.clearAccessToken();

      return const LoginScreen(
        initialMessage: 'La sesión anterior ya no es válida.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreen,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
