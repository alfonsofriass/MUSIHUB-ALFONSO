import 'dart:convert';

import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';

class OpportunitiesApi {
  OpportunitiesApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<OpportunityType>> listOpportunityTypes() async {
    final response = await _apiClient.get('/catalogs/opportunity-types');

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los tipos de anuncio.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>;

    return items
        .map((item) => OpportunityType.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Opportunity>> listOpportunities({
    OpportunityFilters filters = const OpportunityFilters(),
  }) async {
    final response = await _apiClient.get(
      '/opportunities',
      queryParameters: filters.toQueryParameters(),
    );

    if (response.statusCode == 400) {
      throw const InvalidOpportunityFiltersException();
    }

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar los anuncios.');
    }

    return _decodeOpportunityList(response.body);
  }

  Future<Opportunity> getOpportunity(int id) async {
    final response = await _apiClient.get('/opportunities/$id');

    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar el anuncio.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Opportunity.fromJson(json);
  }

  Future<List<Opportunity>> listMyOpportunities(String token) async {
    final response = await _apiClient.get('/opportunities/me', token: token);

    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar tus anuncios.');
    }

    return _decodeOpportunityList(response.body);
  }

  Future<Opportunity> createOpportunity({
    required String token,
    required OpportunitySaveRequest request,
  }) async {
    final response = await _apiClient.post(
      '/opportunities',
      token: token,
      body: request.toJson(),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('No se pudo crear el anuncio.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Opportunity.fromJson(json);
  }

  Future<Opportunity> updateOpportunity({
    required String token,
    required int id,
    required OpportunityUpdateRequest request,
  }) async {
    final response = await _apiClient.patch(
      '/opportunities/$id',
      token: token,
      body: request.toJson(),
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo actualizar el anuncio.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Opportunity.fromJson(json);
  }

  Future<Opportunity> closeOpportunity({
    required String token,
    required int id,
  }) async {
    final response = await _apiClient.patch(
      '/opportunities/$id/close',
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo cerrar el anuncio.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Opportunity.fromJson(json);
  }

  List<Opportunity> _decodeOpportunityList(String body) {
    final json = jsonDecode(body);

    if (json is List<dynamic>) {
      return json
          .map((item) => Opportunity.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final map = json as Map<String, dynamic>;
    final items = map['items'] as List<dynamic>;

    return items
        .map((item) => Opportunity.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class InvalidOpportunityFiltersException implements Exception {
  const InvalidOpportunityFiltersException();
}

class OpportunityFilters {
  const OpportunityFilters({
    this.typeId,
    this.city,
    this.province,
    this.instrumentId,
    this.styleId,
    this.dateFrom,
    this.dateTo,
    this.minPrice,
    this.maxPrice,
  });

  final int? typeId;
  final String? city;
  final String? province;
  final int? instrumentId;
  final int? styleId;
  final String? dateFrom;
  final String? dateTo;
  final num? minPrice;
  final num? maxPrice;

  bool get hasFilters => toQueryParameters().isNotEmpty;

  Map<String, String> toQueryParameters() {
    return {
      if (typeId != null) 'type_id': typeId.toString(),
      if (_hasText(city)) 'city': city!.trim(),
      if (_hasText(province)) 'province': province!.trim(),
      if (instrumentId != null) 'instrument_id': instrumentId.toString(),
      if (styleId != null) 'style_id': styleId.toString(),
      if (_hasText(dateFrom)) 'date_from': dateFrom!.trim(),
      if (_hasText(dateTo)) 'date_to': dateTo!.trim(),
      if (minPrice != null) 'min_price': minPrice.toString(),
      if (maxPrice != null) 'max_price': maxPrice.toString(),
    };
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class OpportunityType {
  const OpportunityType({
    required this.id,
    required this.code,
    required this.name,
  });

  factory OpportunityType.fromJson(Map<String, dynamic> json) {
    return OpportunityType(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }

  final int id;
  final String code;
  final String name;
}

class Opportunity {
  const Opportunity({
    required this.id,
    required this.type,
    required this.authorUserId,
    required this.title,
    required this.description,
    required this.city,
    required this.province,
    required this.eventDate,
    required this.priceAmount,
    required this.contactMethod,
    required this.contactValue,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.instruments,
    required this.styles,
  });

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    final instruments = json['instruments'] as List<dynamic>;
    final styles = json['styles'] as List<dynamic>;

    return Opportunity(
      id: json['id'] as int,
      type: OpportunityType.fromJson(json['type'] as Map<String, dynamic>),
      authorUserId: json['author_user_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      city: json['city'] as String,
      province: json['province'] as String?,
      eventDate: json['event_date'] as String?,
      priceAmount: json['price_amount'] as String?,
      contactMethod: json['contact_method'] as String,
      contactValue: json['contact_value'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      expiresAt: json['expires_at'] as String?,
      instruments: instruments
          .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      styles: styles
          .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final OpportunityType type;
  final int authorUserId;
  final String title;
  final String description;
  final String city;
  final String? province;
  final String? eventDate;
  final String? priceAmount;
  final String contactMethod;
  final String contactValue;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? expiresAt;
  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;

  bool get isActive => status == 'active';
}

class OpportunitySaveRequest {
  const OpportunitySaveRequest({
    required this.typeId,
    required this.title,
    required this.description,
    required this.city,
    required this.province,
    required this.eventDate,
    required this.priceAmount,
    required this.contactMethod,
    required this.contactValue,
    required this.instrumentIds,
    required this.styleIds,
  });

  final int typeId;
  final String title;
  final String description;
  final String city;
  final String? province;
  final String? eventDate;
  final num? priceAmount;
  final String contactMethod;
  final String contactValue;
  final List<int> instrumentIds;
  final List<int> styleIds;

  Map<String, dynamic> toJson() {
    return {
      'type_id': typeId,
      'title': title,
      'description': description,
      'city': city,
      'province': province,
      'event_date': eventDate,
      'price_amount': priceAmount,
      'contact_method': contactMethod,
      'contact_value': contactValue,
      'instrument_ids': instrumentIds,
      'style_ids': styleIds,
    };
  }
}

class OpportunityUpdateRequest {
  const OpportunityUpdateRequest({
    this.title,
    this.description,
    this.city,
    this.province,
    this.eventDate,
    this.priceAmount,
    this.contactMethod,
    this.contactValue,
    this.instrumentIds,
    this.styleIds,
    this.includeNullValues = false,
  });

  final String? title;
  final String? description;
  final String? city;
  final String? province;
  final String? eventDate;
  final num? priceAmount;
  final String? contactMethod;
  final String? contactValue;
  final List<int>? instrumentIds;
  final List<int>? styleIds;
  final bool includeNullValues;

  Map<String, dynamic> toJson() {
    return {
      if (title != null || includeNullValues) 'title': title,
      if (description != null || includeNullValues) 'description': description,
      if (city != null || includeNullValues) 'city': city,
      if (province != null || includeNullValues) 'province': province,
      if (eventDate != null || includeNullValues) 'event_date': eventDate,
      if (priceAmount != null || includeNullValues) 'price_amount': priceAmount,
      if (contactMethod != null || includeNullValues)
        'contact_method': contactMethod,
      if (contactValue != null || includeNullValues)
        'contact_value': contactValue,
      if (instrumentIds != null) 'instrument_ids': instrumentIds,
      if (styleIds != null) 'style_ids': styleIds,
    };
  }
}
