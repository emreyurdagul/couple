class AppConfig {
  /// API base URL. Override via --dart-define=API_BASE_URL=https://...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator → host loopback
  );

  static const Duration httpConnectTimeout = Duration(seconds: 10);
  static const Duration httpReceiveTimeout = Duration(seconds: 30);
}
