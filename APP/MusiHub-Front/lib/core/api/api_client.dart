import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:musihub_front/core/config/api_config.dart';

class ApiClient {
  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<http.Response> get(String path, {String? token}) {
    return _httpClient.get(_uri(path), headers: _headers(token));
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return _httpClient.post(
      _uri(path),
      headers: _headers(token),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
  }

  Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('${ApiConfig.baseUrl}$normalizedPath');
  }

  Map<String, String> _headers(String? token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  void close() {
    _httpClient.close();
  }
}
