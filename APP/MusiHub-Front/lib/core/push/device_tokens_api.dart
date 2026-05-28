import 'dart:convert';

import 'package:musihub_front/core/api/api_client.dart';

class DeviceTokensApi {
  DeviceTokensApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DeviceTokenRegistration> registerDeviceToken({
    required String authToken,
    required String deviceToken,
    required String platform,
  }) async {
    final response = await _apiClient.post(
      '/device-tokens',
      token: authToken,
      body: {'token': deviceToken, 'platform': platform},
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('No se pudo registrar el token del dispositivo.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return DeviceTokenRegistration.fromJson(json);
  }

  Future<void> unregisterDeviceToken({
    required String authToken,
    required String deviceToken,
  }) async {
    final response = await _apiClient.post(
      '/device-tokens/unregister',
      token: authToken,
      body: {'token': deviceToken},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('No se pudo desregistrar el token del dispositivo.');
    }
  }
}

class DeviceTokenRegistration {
  const DeviceTokenRegistration({
    required this.id,
    required this.platform,
    required this.message,
  });

  factory DeviceTokenRegistration.fromJson(Map<String, dynamic> json) {
    return DeviceTokenRegistration(
      id: json['id'] as int,
      platform: json['platform'] as String,
      message: json['message'] as String,
    );
  }

  final int id;
  final String platform;
  final String message;
}
