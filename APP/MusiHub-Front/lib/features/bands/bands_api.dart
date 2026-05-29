import 'dart:convert';

import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';

class BandsApi {
  BandsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Band>> listMyBands(String token) async {
    final response = await _apiClient.get('/bands/me', token: token);

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar tus bandas.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map((item) => Band.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Band> getBand({required String token, required int bandId}) async {
    final response = await _apiClient.get('/bands/$bandId', token: token);

    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar la banda.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Band.fromJson(json);
  }

  Future<Band> createBand({
    required String token,
    required BandSaveRequest request,
  }) async {
    final response = await _apiClient.post(
      '/bands',
      token: token,
      body: request.toJson(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('No se pudo crear la banda.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Band.fromJson(json);
  }

  Future<Band> updateBand({
    required String token,
    required int bandId,
    required BandUpdateRequest request,
  }) async {
    final response = await _apiClient.put(
      '/bands/$bandId',
      token: token,
      body: request.toJson(),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo actualizar la banda.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Band.fromJson(json);
  }

  Future<void> deleteBand({required String token, required int bandId}) async {
    final response = await _apiClient.delete('/bands/$bandId', token: token);

    if (response.statusCode == 400) {
      throw const BandHasMembersException();
    }

    if (response.statusCode == 403) {
      throw const BandDeleteForbiddenException();
    }

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('No se pudo eliminar la banda.');
    }
  }

  Future<Band> addBandMember({
    required String token,
    required int bandId,
    required BandMemberSaveRequest request,
  }) async {
    final response = await _apiClient.post(
      '/bands/$bandId/members',
      token: token,
      body: request.toJson(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('No se pudo anadir el miembro.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Band.fromJson(json);
  }

  Future<void> removeBandMember({
    required String token,
    required int bandId,
    required int userId,
  }) async {
    final response = await _apiClient.delete(
      '/bands/$bandId/members/$userId',
      token: token,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('No se pudo eliminar el miembro.');
    }
  }

  Future<BandVisibility> updateMyBandVisibility({
    required String token,
    required int bandId,
    required bool isVisibleInProfile,
  }) async {
    final response = await _apiClient.patch(
      '/bands/$bandId/me/visibility',
      token: token,
      body: {'is_visible_in_profile': isVisibleInProfile},
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo actualizar la visibilidad de la banda.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return BandVisibility.fromJson(json);
  }
}

class BandHasMembersException implements Exception {
  const BandHasMembersException();
}

class BandDeleteForbiddenException implements Exception {
  const BandDeleteForbiddenException();
}

class Band {
  const Band({
    required this.id,
    required this.name,
    required this.bio,
    required this.city,
    required this.province,
    required this.photoUrl,
    required this.createdByUserId,
    required this.createdAt,
    required this.styles,
    required this.members,
  });

  factory Band.fromJson(Map<String, dynamic> json) {
    final styles = json['styles'] as List<dynamic>? ?? const <dynamic>[];
    final members = json['members'] as List<dynamic>? ?? const <dynamic>[];

    return Band(
      id: json['id'] as int,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdByUserId: json['created_by_user_id'] as int,
      createdAt: json['created_at'] as String,
      styles: styles
          .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      members: members
          .map((item) => BandMember.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final String name;
  final String? bio;
  final String? city;
  final String? province;
  final String? photoUrl;
  final int createdByUserId;
  final String createdAt;
  final List<CatalogItem> styles;
  final List<BandMember> members;
}

class BandMember {
  const BandMember({
    required this.userId,
    required this.fullName,
    required this.roleInBand,
    required this.membershipStatus,
    required this.isVisibleInProfile,
    required this.joinedAt,
  });

  factory BandMember.fromJson(Map<String, dynamic> json) {
    return BandMember(
      userId: json['user_id'] as int,
      fullName: json['full_name'] as String,
      roleInBand: json['role_in_band'] as String,
      membershipStatus: json['membership_status'] as String,
      isVisibleInProfile: json['is_visible_in_profile'] as bool,
      joinedAt: json['joined_at'] as String,
    );
  }

  final int userId;
  final String fullName;
  final String roleInBand;
  final String membershipStatus;
  final bool isVisibleInProfile;
  final String joinedAt;
}

class BandVisibility {
  const BandVisibility({
    required this.bandId,
    required this.userId,
    required this.isVisibleInProfile,
  });

  factory BandVisibility.fromJson(Map<String, dynamic> json) {
    return BandVisibility(
      bandId: json['band_id'] as int,
      userId: json['user_id'] as int,
      isVisibleInProfile: json['is_visible_in_profile'] as bool,
    );
  }

  final int bandId;
  final int userId;
  final bool isVisibleInProfile;
}

class BandSaveRequest {
  const BandSaveRequest({
    required this.name,
    required this.bio,
    required this.city,
    required this.province,
    required this.photoUrl,
    required this.roleInBand,
    required this.isVisibleInProfile,
    required this.styleIds,
  });

  final String name;
  final String? bio;
  final String city;
  final String province;
  final String? photoUrl;
  final String roleInBand;
  final bool isVisibleInProfile;
  final List<int> styleIds;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bio': bio,
      'city': city,
      'province': province,
      'photo_url': photoUrl,
      'role_in_band': roleInBand,
      'is_visible_in_profile': isVisibleInProfile,
      'style_ids': styleIds,
    };
  }
}

class BandUpdateRequest {
  const BandUpdateRequest({
    required this.name,
    required this.bio,
    required this.city,
    required this.province,
    required this.photoUrl,
    required this.styleIds,
  });

  final String name;
  final String? bio;
  final String city;
  final String province;
  final String? photoUrl;
  final List<int> styleIds;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bio': bio,
      'city': city,
      'province': province,
      'photo_url': photoUrl,
      'style_ids': styleIds,
    };
  }
}

class BandMemberSaveRequest {
  const BandMemberSaveRequest({
    required this.userId,
    required this.roleInBand,
    required this.isVisibleInProfile,
  });

  final int userId;
  final String roleInBand;
  final bool isVisibleInProfile;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role_in_band': roleInBand,
      'is_visible_in_profile': isVisibleInProfile,
    };
  }
}
