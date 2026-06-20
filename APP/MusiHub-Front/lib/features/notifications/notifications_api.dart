import 'dart:convert';

import 'package:musihub_front/core/api/api_client.dart';

class NotificationsApi {
  NotificationsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<NotificationsResponse> listNotifications(String token) async {
    final response = await _apiClient.get('/notifications', token: token);

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las notificaciones.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return NotificationsResponse.fromJson(json);
  }

  Future<NotificationReadResponse> markAsRead({
    required String token,
    required int notificationId,
  }) async {
    final response = await _apiClient.patch(
      '/notifications/$notificationId/read',
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo marcar la notificación como leída.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return NotificationReadResponse.fromJson(json);
  }

  Future<int> markAllAsRead(String token) async {
    final response = await _apiClient.patch(
      '/notifications/read-all',
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudieron marcar las notificaciones como leídas.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['updated'] as int? ?? 0;
  }
}

class NotificationsResponse {
  const NotificationsResponse({required this.unreadCount, required this.items});

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const <dynamic>[];

    return NotificationsResponse(
      unreadCount: json['unread_count'] as int? ?? 0,
      items: items
          .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int unreadCount;
  final List<AppNotification> items;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
    required this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'];

    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: json['created_at'] as String,
      readAt: json['read_at'] as String?,
      data: dataJson is Map<String, dynamic> ? dataJson : null,
    );
  }

  final int id;
  final String type;
  final String title;
  final String body;
  final String createdAt;
  final String? readAt;
  final Map<String, dynamic>? data;

  bool get isUnread => readAt == null;
}

class NotificationReadResponse {
  const NotificationReadResponse({required this.id, required this.readAt});

  factory NotificationReadResponse.fromJson(Map<String, dynamic> json) {
    return NotificationReadResponse(
      id: json['id'] as int,
      readAt: json['read_at'] as String?,
    );
  }

  final int id;
  final String? readAt;
}
