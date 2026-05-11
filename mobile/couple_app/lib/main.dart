import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/config/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/update/update_dialog.dart';
import 'core/update/version_service.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/location/data/location_tracker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  runApp(const ProviderScope(child: CoupleApp()));
}

class CoupleApp extends ConsumerStatefulWidget {
  const CoupleApp({super.key});

  @override
  ConsumerState<CoupleApp> createState() => _CoupleAppState();
}

class _CoupleAppState extends ConsumerState<CoupleApp> {
  ProviderSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Auth state değişimlerini dinle — login+couple olunca tracker başlat,
    // logout/break olunca durdur.
    _authSub = ref.listenManual<AuthState>(
      authControllerProvider,
      (prev, next) async {
        await _syncTracker(next);
      },
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  bool _updatePromptShown = false;
  Future<void> _checkForUpdate() async {
    if (_updatePromptShown) return;
    final info = await ref.read(versionServiceProvider).checkForUpdate();
    if (info == null) return;
    final router = ref.read(appRouterProvider);
    final ctx = router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    _updatePromptShown = true;
    await UpdateDialog.show(
      ctx,
      info: info,
      onDownloadAndInstall: (onProgress) async {
        final service = ref.read(versionServiceProvider);
        final apk = await service.downloadApk(info, onProgress: onProgress);
        return service.installApk(apk);
      },
    );
  }

  @override
  void dispose() {
    _authSub?.close();
    super.dispose();
  }

  Future<void> _syncTracker(AuthState state) async {
    final tracker = ref.read(locationTrackerProvider);
    if (state is AuthSignedIn && state.session.coupleId != null) {
      final granted = await _ensureLocationPermissions();
      if (granted && !tracker.isRunning) {
        await tracker.start();
      }
    } else {
      if (tracker.isRunning) {
        await tracker.stop();
      }
    }
  }

  /// İzin akışı: önce whileInUse, sonra background promote.
  /// Reddedilirse tracker başlatılmaz; UI ileride bunu surface eder.
  Future<bool> _ensureLocationPermissions() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    // Always (background) izni — Android 10+ ayrı kullanıcı kararı
    if (perm == LocationPermission.whileInUse) {
      await Permission.locationAlways.request();
    }
    // Bildirim izni (Android 13+) — foreground service notification
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Couple',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
