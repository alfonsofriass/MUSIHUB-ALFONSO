import 'dart:convert';

import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';

class AlertsApi {
  AlertsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AlertPreferencesResponse> getPreferences(String token) async {
    final response = await _apiClient.get('/alerts/preferences', token: token);

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las preferencias de alertas.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AlertPreferencesResponse.fromJson(json);
  }

  Future<AlertPreferences> savePreferences({
    required String token,
    required AlertPreferencesSaveRequest request,
  }) async {
    final response = await _apiClient.put(
      '/alerts/preferences',
      token: token,
      body: request.toJson(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('No se pudieron guardar las preferencias de alertas.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json.containsKey('preferences')) {
      final preferencesJson = json['preferences'];
      if (preferencesJson == null) {
        throw Exception('No se pudieron leer las preferencias guardadas.');
      }

      return AlertPreferences.fromJson(preferencesJson as Map<String, dynamic>);
    }

    return AlertPreferences.fromJson(json);
  }

  Future<List<GeneratedAlert>> listMyAlerts(String token) async {
    final response = await _apiClient.get('/alerts/me', token: token);

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar tus alertas.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>;

    return items
        .map((item) => GeneratedAlert.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class AlertPreferencesResponse {
  const AlertPreferencesResponse({
    required this.exists,
    required this.preferences,
  });

  factory AlertPreferencesResponse.fromJson(Map<String, dynamic> json) {
    final preferencesJson = json['preferences'];

    return AlertPreferencesResponse(
      exists: json['exists'] as bool,
      preferences: preferencesJson == null
          ? null
          : AlertPreferences.fromJson(preferencesJson as Map<String, dynamic>),
    );
  }

  final bool exists;
  final AlertPreferences? preferences;
}

class AlertPreferences {
  const AlertPreferences({
    required this.id,
    required this.frequency,
    required this.preferredCity,
    required this.preferredProvince,
    required this.notificationsEnabled,
    required this.opportunityTypes,
  });

  factory AlertPreferences.fromJson(Map<String, dynamic> json) {
    final opportunityTypes = json['opportunity_types'] as List<dynamic>;

    return AlertPreferences(
      id: json['id'] as int,
      frequency: json['frequency'] as String,
      preferredCity: json['preferred_city'] as String?,
      preferredProvince: json['preferred_province'] as String?,
      notificationsEnabled: json['notifications_enabled'] as bool,
      opportunityTypes: opportunityTypes
          .map((item) => OpportunityType.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final String frequency;
  final String? preferredCity;
  final String? preferredProvince;
  final bool notificationsEnabled;
  final List<OpportunityType> opportunityTypes;
}

class AlertPreferencesSaveRequest {
  const AlertPreferencesSaveRequest({
    required this.frequency,
    required this.preferredCity,
    required this.preferredProvince,
    required this.notificationsEnabled,
    required this.opportunityTypeIds,
  });

  final String frequency;
  final String? preferredCity;
  final String? preferredProvince;
  final bool notificationsEnabled;
  final List<int> opportunityTypeIds;

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'preferred_city': preferredCity,
      'preferred_province': preferredProvince,
      'notifications_enabled': notificationsEnabled,
      'opportunity_type_ids': opportunityTypeIds,
    };
  }
}

class GeneratedAlert {
  const GeneratedAlert({
    required this.id,
    required this.score,
    required this.reason,
    required this.createdAt,
    required this.opportunity,
  });

  factory GeneratedAlert.fromJson(Map<String, dynamic> json) {
    return GeneratedAlert(
      id: json['id'] as int,
      score: json['score'] as int,
      reason: json['reason'] as String,
      createdAt: json['created_at'] as String,
      opportunity: Opportunity.fromJson(
        json['opportunity'] as Map<String, dynamic>,
      ),
    );
  }

  final int id;
  final int score;
  final String reason;
  final String createdAt;
  final Opportunity opportunity;
}
