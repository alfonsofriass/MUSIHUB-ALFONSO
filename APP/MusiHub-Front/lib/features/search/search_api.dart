import 'dart:convert';

import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';

class SearchApi {
  SearchApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<ProfileSearchResult>> searchProfiles({
    required String token,
    required String query,
  }) async {
    final response = await _apiClient.get(
      '/search/profiles',
      token: token,
      queryParameters: _queryParameters(query),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudieron buscar perfiles.');
    }

    return _decodeItems(
      response.body,
      (json) => ProfileSearchResult.fromJson(json),
    );
  }

  Future<List<BandSearchResult>> searchBands({
    required String token,
    required String query,
  }) async {
    final response = await _apiClient.get(
      '/search/bands',
      token: token,
      queryParameters: _queryParameters(query),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudieron buscar bandas.');
    }

    return _decodeItems(
      response.body,
      (json) => BandSearchResult.fromJson(json),
    );
  }

  Map<String, String> _queryParameters(String query) {
    final trimmed = query.trim();
    return trimmed.isEmpty ? const {} : {'q': trimmed};
  }

  List<T> _decodeItems<T>(
    String body,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const <dynamic>[];

    return items.map((item) => fromJson(item as Map<String, dynamic>)).toList();
  }
}

class ProfileSearchResult {
  const ProfileSearchResult({
    required this.user,
    required this.profileId,
    required this.city,
    required this.province,
    required this.bio,
    required this.photoUrl,
    required this.instruments,
    required this.styles,
  });

  factory ProfileSearchResult.fromJson(Map<String, dynamic> json) {
    final instruments =
        json['instruments'] as List<dynamic>? ?? const <dynamic>[];
    final styles = json['styles'] as List<dynamic>? ?? const <dynamic>[];

    return ProfileSearchResult(
      user: SearchUser.fromJson(json['user'] as Map<String, dynamic>),
      profileId: json['profile_id'] as int,
      city: json['city'] as String?,
      province: json['province'] as String?,
      bio: json['bio'] as String?,
      photoUrl: json['photo_url'] as String?,
      instruments: instruments
          .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      styles: styles
          .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final SearchUser user;
  final int profileId;
  final String? city;
  final String? province;
  final String? bio;
  final String? photoUrl;
  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
}

class BandSearchResult {
  const BandSearchResult({
    required this.id,
    required this.name,
    required this.bio,
    required this.city,
    required this.province,
    required this.photoUrl,
    required this.styles,
  });

  factory BandSearchResult.fromJson(Map<String, dynamic> json) {
    final styles = json['styles'] as List<dynamic>? ?? const <dynamic>[];

    return BandSearchResult(
      id: json['id'] as int,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      photoUrl: json['photo_url'] as String?,
      styles: styles
          .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final String name;
  final String? bio;
  final String? city;
  final String? province;
  final String? photoUrl;
  final List<CatalogItem> styles;
}

class SearchUser {
  const SearchUser({required this.id, required this.fullName});

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    return SearchUser(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
    );
  }

  final int id;
  final String fullName;
}
