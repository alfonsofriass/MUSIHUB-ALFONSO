import 'dart:convert';

import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';

class ContactRequestsApi {
  ContactRequestsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ContactRequestStatus> createContactRequest({
    required String token,
    required int opportunityId,
  }) async {
    final response = await _apiClient.post(
      '/opportunities/$opportunityId/contact-requests',
      token: token,
    );

    if (response.statusCode == 409) {
      throw const DuplicateContactRequestException();
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('No se pudo solicitar el contacto.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ContactRequestStatus.fromJson(json);
  }

  Future<List<ContactRequestItem>> listReceived(String token) async {
    final response = await _apiClient.get(
      '/contact-requests/received',
      token: token,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('No se pudieron cargar las solicitudes recibidas.');
    }

    return _decodeList(response.body);
  }

  Future<List<ContactRequestItem>> listSent(String token) async {
    final response = await _apiClient.get(
      '/contact-requests/sent',
      token: token,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('No se pudieron cargar las solicitudes enviadas.');
    }

    return _decodeList(response.body);
  }

  Future<void> accept({
    required String token,
    required int contactRequestId,
  }) async {
    final response = await _apiClient.patch(
      '/contact-requests/$contactRequestId/accept',
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo aceptar la solicitud.');
    }
  }

  Future<void> reject({
    required String token,
    required int contactRequestId,
  }) async {
    final response = await _apiClient.patch(
      '/contact-requests/$contactRequestId/reject',
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo rechazar la solicitud.');
    }
  }

  List<ContactRequestItem> _decodeList(String body) {
    if (body.trim().isEmpty) {
      return const <ContactRequestItem>[];
    }

    final json = jsonDecode(body);

    if (json is List<dynamic>) {
      return json
          .map(
            (item) => ContactRequestItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    final map = json as Map<String, dynamic>;
    final items = map['items'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map(
          (item) => ContactRequestItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}

class DuplicateContactRequestException implements Exception {
  const DuplicateContactRequestException();
}

class ContactRequestStatus {
  const ContactRequestStatus({
    required this.id,
    required this.opportunityId,
    required this.requesterUserId,
    required this.ownerUserId,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
  });

  factory ContactRequestStatus.fromJson(Map<String, dynamic> json) {
    return ContactRequestStatus(
      id: json['id'] as int,
      opportunityId: json['opportunity_id'] as int,
      requesterUserId: json['requester_user_id'] as int,
      ownerUserId: json['owner_user_id'] as int,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      respondedAt: json['responded_at'] as String?,
    );
  }

  final int id;
  final int opportunityId;
  final int requesterUserId;
  final int ownerUserId;
  final String status;
  final String createdAt;
  final String? respondedAt;
}

class ContactRequestItem {
  const ContactRequestItem({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
    required this.requester,
    required this.opportunity,
  });

  factory ContactRequestItem.fromJson(Map<String, dynamic> json) {
    final requesterJson = json['requester'];

    return ContactRequestItem(
      id: json['id'] as int,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      respondedAt: json['responded_at'] as String?,
      requester: requesterJson == null
          ? null
          : ContactRequestUser.fromJson(requesterJson as Map<String, dynamic>),
      opportunity: Opportunity.fromJson(
        json['opportunity'] as Map<String, dynamic>,
      ),
    );
  }

  final int id;
  final String status;
  final String createdAt;
  final String? respondedAt;
  final ContactRequestUser? requester;
  final Opportunity opportunity;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}

class ContactRequestUser {
  const ContactRequestUser({required this.id, required this.fullName});

  factory ContactRequestUser.fromJson(Map<String, dynamic> json) {
    return ContactRequestUser(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
    );
  }

  final int id;
  final String fullName;
}
