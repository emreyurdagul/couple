import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../network/api_client.dart';

/// Backend `/api/version/latest` yanıtı.
class VersionInfo {
  const VersionInfo({
    required this.updateAvailable,
    required this.mandatory,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.sha256,
    required this.releaseNotes,
  });

  final bool updateAvailable;
  final bool mandatory;
  final int latestVersionCode;
  final String latestVersionName;
  final String downloadUrl;
  final int sizeBytes;
  final String sha256;
  final String? releaseNotes;

  factory VersionInfo.fromJson(Map<String, dynamic> json) => VersionInfo(
        updateAvailable: json['updateAvailable'] as bool? ?? false,
        mandatory: json['mandatory'] as bool? ?? false,
        latestVersionCode: (json['latestVersionCode'] as num).toInt(),
        latestVersionName: json['latestVersionName'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String? ?? '',
        releaseNotes: json['releaseNotes'] as String?,
      );
}

final versionServiceProvider = Provider<VersionService>((ref) {
  return VersionService(ref.read(rawApiClientProvider));
});

class VersionService {
  VersionService(this._dio);
  final Dio _dio;

  /// Mevcut paket için /api/version/latest'i çağırır. Update yoksa null döner.
  /// Hata durumunda da null — startup'ta sessizce başarısız ol, kullanıcıyı engelleme.
  Future<VersionInfo?> checkForUpdate() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(pkg.buildNumber) ?? 0;
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/version/latest',
        queryParameters: {
          'platform': 'android',
          'currentVersionCode': currentCode,
        },
        options: Options(
          // 404 durumunda da gracefully null dön; hata fırlatma.
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (res.statusCode != 200 || res.data == null) return null;
      final info = VersionInfo.fromJson(res.data!);
      return info.updateAvailable ? info : null;
    } catch (_) {
      return null;
    }
  }

  /// APK'yı cache dizinine indirir; mevcut dosya geri kullanılır
  /// (cihazda art arda denemeler için).
  Future<File> downloadApk(
    VersionInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final cacheDir = await getApplicationCacheDirectory();
    final apksDir = Directory(p.join(cacheDir.path, 'apks'));
    if (!apksDir.existsSync()) apksDir.createSync(recursive: true);

    final filename =
        'couple-${info.latestVersionCode}-${info.sha256.substring(0, 8)}.apk';
    final out = File(p.join(apksDir.path, filename));

    // Aynı sha ile aynı boyutta dosya zaten varsa atla.
    if (out.existsSync() && out.lengthSync() == info.sizeBytes) {
      onProgress?.call(1.0);
      return out;
    }

    await _dio.download(
      info.downloadUrl,
      out.path,
      onReceiveProgress: (rec, total) {
        if (total > 0) onProgress?.call(rec / total);
      },
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return out;
  }

  /// Sistem package installer'ını tetikler. Kullanıcının "Bilinmeyen
  /// kaynaklardan yükle" iznini onaylaması gerekir (Android 8+).
  Future<bool> installApk(File apk) async {
    final res = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    return res.type == ResultType.done;
  }
}
