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
      if (kDebugMode && fcmToken != null && fcmToken.isNotEmpty) {
        debugPrint('FCM token obtenido.');
      }

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _sendTokenToBackend(authToken: authToken, fcmToken: fcmToken);
      }

      await _stopListeningForTokenRefresh();
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((newToken) async {
            if (kDebugMode) {
              debugPrint('FCM token refrescado.');
            }
            await _sendTokenToBackend(authToken: authToken, fcmToken: newToken);
          });
    } catch (error) {
      debugPrint('No se pudo registrar FCM: $error');
    }
  }

  static Future<void> unregisterDevice({required String authToken}) async {
    if (!_isSupportedPlatform) {
      await _stopListeningForTokenRefresh();
      return;
    }

    try {
      await initialize();

      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _removeTokenFromBackend(authToken: authToken, fcmToken: fcmToken);
      }
    } catch (error) {
      debugPrint('No se pudo desregistrar FCM: $error');
    } finally {
      await _stopListeningForTokenRefresh();
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

  static Future<void> _removeTokenFromBackend({
    required String authToken,
    required String fcmToken,
  }) async {
    final apiClient = ApiClient();
    final deviceTokensApi = DeviceTokensApi(apiClient: apiClient);

    try {
      await deviceTokensApi.unregisterDeviceToken(
        authToken: authToken,
        deviceToken: fcmToken,
      );
    } finally {
      apiClient.close();
    }
  }

  static Future<void> _stopListeningForTokenRefresh() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }
}
