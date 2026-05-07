class ApiConfig {
  const ApiConfig._();

  static const defaultBaseUrl = 'http://10.0.2.2:8000/api/v1';

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );
}
