import 'dart:convert';

import 'package:musihub_front/core/api/api_client.dart';

class AuthApi {
  AuthApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo iniciar sesion.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['access_token'] as String;
  }

  Future<AuthUser> me(String token) async {
    final response = await _apiClient.get('/auth/me', token: token);

    if (response.statusCode != 200) {
      throw Exception('No se pudo obtener el usuario actual.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    return AuthUser(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
    );
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;
}
