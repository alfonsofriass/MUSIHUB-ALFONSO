import 'dart:convert';

import 'package:musihub_front/core/api/api_client.dart';

class LocationsApi {
  LocationsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<LocationProvince>> listLocations() async {
    final response = await _apiClient.get('/catalogs/locations');

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las ubicaciones.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .map((item) => LocationProvince.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class LocationProvince {
  const LocationProvince({
    required this.id,
    required this.name,
    required this.cities,
  });

  factory LocationProvince.fromJson(Map<String, dynamic> json) {
    final cities = json['cities'] as List<dynamic>? ?? const <dynamic>[];

    return LocationProvince(
      id: json['id'] as int,
      name: json['name'] as String,
      cities: cities
          .map((item) => LocationCity.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final String name;
  final List<LocationCity> cities;
}

class LocationCity {
  const LocationCity({required this.id, required this.name});

  factory LocationCity.fromJson(Map<String, dynamic> json) {
    return LocationCity(id: json['id'] as int, name: json['name'] as String);
  }

  final int id;
  final String name;
}
