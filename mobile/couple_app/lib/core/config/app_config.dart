import 'package:flutter/foundation.dart';

class AppConfig {
  /// Release build'lerde default; Coolify production deploy.
  /// Custom domain'e geçince burayı güncelle (ADR-0010).
  static const String _prodApiBaseUrl =
      'http://vgvexxga7f7ah4puhujzkh60.72.61.95.76.sslip.io';

  /// Debug/emulator: host makinedeki dev compose'una bağlanır.
  static const String _devApiBaseUrl = 'http://10.0.2.2:8080';

  /// API base URL. CI ve cihaz build'lerinde
  /// `--dart-define=API_BASE_URL=...` ile override edilebilir.
  /// Override yoksa: release → prod, debug → dev.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? _prodApiBaseUrl : _devApiBaseUrl,
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
