import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/config/api_config.dart';
import 'package:musihub_front/core/uploads/image_upload_rules.dart';

class ProfileApi {
  ProfileApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<CatalogItem>> listInstruments() async {
    final response = await _apiClient.get('/catalogs/instruments');

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los instrumentos.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CatalogItem>> listMusicStyles() async {
    final response = await _apiClient.get('/catalogs/music-styles');

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los estilos.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProfileMe> getMyProfile(String token) async {
    final response = await _apiClient.get('/profile/me', token: token);

    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar el perfil.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ProfileMe.fromJson(json);
  }

  Future<PublicProfile> getPublicProfile({
    required String token,
    required int userId,
  }) async {
    final response = await _apiClient.get('/profile/$userId', token: token);

    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar el perfil público.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return PublicProfile.fromJson(json);
  }

  Future<ProfileMe> saveMyProfile({
    required String token,
    required ProfileSaveRequest request,
  }) async {
    final response = await _apiClient.put(
      '/profile/me',
      token: token,
      body: request.toJson(),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo guardar el perfil.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ProfileMe.fromJson(json);
  }

  Future<ProfilePhotoUploadResponse> uploadMyProfilePhoto({
    required String token,
    required File file,
  }) async {
    final contentType = ImageUploadRules.contentTypeForPath(file.path);

    if (contentType == null) {
      throw const UnsupportedProfilePhotoTypeException();
    }

    if (await ImageUploadRules.isTooLarge(file)) {
      throw const ProfilePhotoTooLargeException();
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/profile/me/photo'),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: contentType,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('No se pudo subir la foto.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ProfilePhotoUploadResponse.fromJson(json);
  }
}

class UnsupportedProfilePhotoTypeException implements Exception {
  const UnsupportedProfilePhotoTypeException();
}

class ProfilePhotoTooLargeException implements Exception {
  const ProfilePhotoTooLargeException();
}

class ProfilePhotoUploadResponse {
  const ProfilePhotoUploadResponse({required this.photoUrl});

  factory ProfilePhotoUploadResponse.fromJson(Map<String, dynamic> json) {
    return ProfilePhotoUploadResponse(photoUrl: json['photo_url'] as String);
  }

  final String photoUrl;
}

class PublicProfile {
  const PublicProfile({
    required this.user,
    required this.profile,
    required this.bands,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final bands = json['bands'] as List<dynamic>? ?? const <dynamic>[];

    return PublicProfile(
      user: PublicProfileUser.fromJson(json['user'] as Map<String, dynamic>),
      profile: profileJson == null
          ? null
          : UserProfile.fromJson(profileJson as Map<String, dynamic>),
      bands: bands
          .map(
            (band) => PublicProfileBand.fromJson(band as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final PublicProfileUser user;
  final UserProfile? profile;
  final List<PublicProfileBand> bands;
}

class PublicProfileUser {
  const PublicProfileUser({
    required this.id,
    required this.fullName,
    required this.role,
  });

  factory PublicProfileUser.fromJson(Map<String, dynamic> json) {
    return PublicProfileUser(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      role: json['role'] as String? ?? 'musico',
    );
  }

  final int id;
  final String fullName;
  final String role;
}

class PublicProfileBand {
  const PublicProfileBand({
    required this.id,
    required this.name,
    required this.roleInBand,
    required this.city,
    required this.province,
    required this.photoUrl,
    required this.styles,
  });

  factory PublicProfileBand.fromJson(Map<String, dynamic> json) {
    final styles = json['styles'] as List<dynamic>? ?? const <dynamic>[];

    return PublicProfileBand(
      id: json['id'] as int,
      name: json['name'] as String,
      roleInBand: json['role_in_band'] as String,
      city: json['city'] as String?,
      province: json['province'] as String?,
      photoUrl: json['photo_url'] as String?,
      styles: styles
          .map((style) => ProfileStyle.fromJson(style as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final String name;
  final String roleInBand;
  final String? city;
  final String? province;
  final String? photoUrl;
  final List<ProfileStyle> styles;
}

class ProfileMe {
  const ProfileMe({required this.exists, required this.profile});

  factory ProfileMe.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];

    return ProfileMe(
      exists: json['exists'] as bool,
      profile: profileJson == null
          ? null
          : UserProfile.fromJson(profileJson as Map<String, dynamic>),
    );
  }

  final bool exists;
  final UserProfile? profile;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.city,
    required this.province,
    required this.bio,
    required this.photoUrl,
    required this.websiteUrl,
    required this.contactEmail,
    required this.contactPhone,
    required this.instruments,
    required this.styles,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final instruments =
        json['instruments'] as List<dynamic>? ?? const <dynamic>[];
    final styles = json['styles'] as List<dynamic>? ?? const <dynamic>[];

    return UserProfile(
      id: json['id'] as int,
      city: json['city'] as String?,
      province: json['province'] as String?,
      bio: json['bio'] as String?,
      photoUrl: json['photo_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      instruments: instruments
          .map(
            (item) => ProfileInstrument.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      styles: styles
          .map((item) => ProfileStyle.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final String? city;
  final String? province;
  final String? bio;
  final String? photoUrl;
  final String? websiteUrl;
  final String? contactEmail;
  final String? contactPhone;
  final List<ProfileInstrument> instruments;
  final List<ProfileStyle> styles;
}

class ProfileInstrument {
  const ProfileInstrument({
    required this.id,
    required this.name,
    required this.isPrimary,
  });

  factory ProfileInstrument.fromJson(Map<String, dynamic> json) {
    return ProfileInstrument(
      id: json['id'] as int,
      name: json['name'] as String,
      isPrimary: json['is_primary'] as bool,
    );
  }

  final int id;
  final String name;
  final bool isPrimary;
}

class ProfileStyle {
  const ProfileStyle({required this.id, required this.name});

  factory ProfileStyle.fromJson(Map<String, dynamic> json) {
    return ProfileStyle(id: json['id'] as int, name: json['name'] as String);
  }

  final int id;
  final String name;
}

class ProfileSaveRequest {
  const ProfileSaveRequest({
    required this.city,
    required this.province,
    required this.bio,
    required this.photoUrl,
    required this.websiteUrl,
    required this.contactEmail,
    required this.contactPhone,
    required this.instrumentIds,
    required this.primaryInstrumentId,
    required this.styleIds,
  });

  final String? city;
  final String? province;
  final String? bio;
  final String? photoUrl;
  final String? websiteUrl;
  final String? contactEmail;
  final String? contactPhone;
  final List<int> instrumentIds;
  final int? primaryInstrumentId;
  final List<int> styleIds;

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'province': province,
      'bio': bio,
      'photo_url': photoUrl,
      'website_url': websiteUrl,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'instrument_ids': instrumentIds,
      'primary_instrument_id': primaryInstrumentId,
      'style_ids': styleIds,
    };
  }
}
