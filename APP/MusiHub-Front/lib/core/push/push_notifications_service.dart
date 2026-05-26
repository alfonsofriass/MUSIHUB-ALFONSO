import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/push/device_tokens_api.dart';

class PushNotificationsService {
  const PushNotificationsService._();

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _firebaseInitialized = false;

  static bool get _isSupportedPlatform {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<void> initialize() async {
    if (!_isSupportedPlatform || _firebaseInitialized) {
      return;
    }

    await Firebase.initializeApp();
    _firebaseInitialized = true;
  }

  static Future<void> registerDevice({required String authToken}) async {
    if (!_isSupportedPlatform) {
      return;
    }

    try {
      await initialize();
      await FirebaseMessaging.instance.requestPermission();

      final fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM TOKEN: $fcmToken');

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _sendTokenToBackend(authToken: authToken, fcmToken: fcmToken);
      }

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((newToken) async {
            debugPrint('FCM TOKEN REFRESHED: $newToken');
            await _sendTokenToBackend(authToken: authToken, fcmToken: newToken);
          });
    } catch (error) {
      debugPrint('No se pudo registrar FCM: $error');
    }
  }

  static Future<void> _sendTokenToBackend({
    required String authToken,
    required String fcmToken,
  }) async {
    final apiClient = ApiClient();
    final deviceTokensApi = DeviceTokensApi(apiClient: apiClient);

    try {
      await deviceTokensApi.registerDeviceToken(
        authToken: authToken,
        deviceToken: fcmToken,
        platform: 'android',
      );
    } finally {
      apiClient.close();
    }
  }
}
