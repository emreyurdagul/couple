import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/config/app_config.dart';
import 'location_models.dart';
import 'location_repository.dart';
import 'location_signalr_client.dart';

/// Konum takibi soyutlaması. Premium pakete (flutter_background_geolocation)
/// geçişte yalnız concrete sınıf değişir.
abstract class LocationTracker {
  /// Konum izleyicisini başlatır. İzinler önceden alınmış olmalı.
  Future<void> start();

  /// İzleyiciyi durdurur (logout / couple end / kullanıcı kapatması).
  Future<void> stop();

  /// İzleyici şu an çalışıyor mu?
  bool get isRunning;

  /// Üretilen kendi konum noktaları (UI ve metrik için).
  Stream<Position> get myPositions;
}

/// OSS combo: geolocator + flutter_foreground_task + workmanager.
///
/// - Ana isolate: `Geolocator.getPositionStream` ile foreground / app-running
///   tazeliği. SignalR varsa hub `SendLocation`, yoksa REST `POST /locations`.
/// - flutter_foreground_task: kalıcı bildirim — Android'in process'i öldürme
///   eğilimini azaltır, foreground service tag'i sayesinde konuma erişim sürer.
/// - workmanager: process tamamen kill edilirse 15dk'da bir uyanıp tek nokta
///   REST POST'lar (Android-only). iOS arka plan zayıf — kabul edildi.
class OssLocationTracker implements LocationTracker {
  OssLocationTracker(this._ref);

  final Ref _ref;
  final _positionsController = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _sub;
  final _battery = Battery();
  bool _running = false;

  @override
  bool get isRunning => _running;

  @override
  Stream<Position> get myPositions => _positionsController.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;

    // 1) Foreground service (kalıcı bildirim) — Android. iOS no-op.
    if (Platform.isAndroid) {
      await _initForegroundTask();
      await FlutterForegroundTask.startService(
        notificationTitle: 'Konum paylaşımı açık',
        notificationText: 'Partnerinle anlık konumun paylaşılıyor.',
        callback: foregroundTaskStartCallback,
      );
    }

    // 2) Geolocator stream — high accuracy + 10m distanceFilter (adaptif).
    final settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            forceLocationManager: false,
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          );

    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (_) {/* sessiz */});

    // 3) Workmanager periyodik 15dk — process-kill backup. Android only.
    if (Platform.isAndroid) {
      try {
        await Workmanager().initialize(workmanagerCallbackDispatcher);
        await Workmanager().registerPeriodicTask(
          'couple-loc-tick',
          'couple-loc-tick',
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
      } catch (_) {/* daha önce init edilmiş olabilir */}
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _sub?.cancel();
    _sub = null;
    if (Platform.isAndroid) {
      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
      try {
        await Workmanager().cancelByUniqueName('couple-loc-tick');
      } catch (_) {}
    }
  }

  Future<void> _onPosition(Position p) async {
    _positionsController.add(p);

    int? batteryLevel;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (_) {/* bazı emülatörlerde yok */}

    final input = LocationInput(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      speed: p.speed,
      heading: p.heading,
      batteryLevel: batteryLevel,
      isMoving: p.speed > 0.5,
      recordedAt: p.timestamp,
    );

    // Önce SignalR push dene, başarısızsa REST POST.
    final hub = _ref.read(locationSignalrClientProvider);
    final viaHub = await hub.sendLocation(input);
    if (viaHub != null) return;

    try {
      await _ref.read(locationRepositoryProvider).record(input);
    } catch (_) {/* offline kabul, sonraki tick'te tekrar */}
  }

  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'couple_location',
        channelName: 'Konum paylaşımı',
        channelDescription:
            'Partnerinle anlık konum paylaşımı için kalıcı bildirim.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }
}

@pragma('vm:entry-point')
void foregroundTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(_LocationForegroundTaskHandler());
}

class _LocationForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Konum stream'i ana isolate'ta dinleniyor; foreground service yalnızca
    // kalıcı bildirim için. Burayı boş bırakmak kasıtlı — pil dostu.
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final accessToken = await storage.read(key: 'access_token');
      if (accessToken == null) return true;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
        headers: {'Authorization': 'Bearer $accessToken'},
      ));

      await dio.post<void>('/locations', data: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'isMoving': position.speed > 0.5,
        'recordedAt': position.timestamp.toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return true; // retry'a düşmesin — sıradaki periyot dener
    }
  });
}

final locationTrackerProvider = Provider<LocationTracker>((ref) {
  return OssLocationTracker(ref);
});
