class ApiConfig {
  const ApiConfig._();

  static const defaultBaseUrl = 'https://musihub-back.onrender.com/api/v1';

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  static String publicFileUrl(String? value) {
    final path = value?.trim();

    if (path == null || path.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) {
      return path;
    }

    final apiUri = Uri.parse(baseUrl);
    final publicBase = apiUri.replace(path: '', queryParameters: null);
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return publicBase.resolve(normalizedPath).toString();
  }
}
