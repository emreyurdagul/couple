class AppConfig {
  /// API base URL. Override via --dart-define=API_BASE_URL=https://...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator → host loopback
  );

  static const Duration httpConnectTimeout = Duration(seconds: 10);
  static const Duration httpReceiveTimeout = Duration(seconds: 30);

  /// Geliştirme için OSM tile servisi (key gerektirmez, User-Agent zorunlu).
  /// Production öncesi gerçek bir sağlayıcıya geçilecek
  /// (Stadia / MapTiler / Mapbox / self-host) — burası tek nokta.
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String tileAttribution = '© OpenStreetMap contributors';

  /// flutter_map TileLayer için zorunlu (OSM Tile Usage Policy).
  /// Bundle identifier ile aynı tutulur.
  static const String userAgentPackageName = 'com.coupleapp.couple_app';

  /// Birleşme eşiği (haversine). Server `CoupleSettings.TogetherDistanceMeters`
  /// ile uyumlu olmalı — client render kararı.
  static const double togetherMergeMeters = 50.0;
}
