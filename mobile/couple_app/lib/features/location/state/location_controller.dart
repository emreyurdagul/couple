import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../auth/state/auth_controller.dart';
import '../data/location_models.dart';
import '../data/location_repository.dart';
import '../data/location_signalr_client.dart';
import '../data/location_tracker.dart';

enum HistoryWindow { hour1, day1, week1 }

extension HistoryWindowX on HistoryWindow {
  Duration get duration {
    switch (this) {
      case HistoryWindow.hour1:
        return const Duration(hours: 1);
      case HistoryWindow.day1:
        return const Duration(hours: 24);
      case HistoryWindow.week1:
        return const Duration(days: 7);
    }
  }

  String get label {
    switch (this) {
      case HistoryWindow.hour1:
        return '1 saat';
      case HistoryWindow.day1:
        return '24 saat';
      case HistoryWindow.week1:
        return '7 gün';
    }
  }
}

enum LocationConnectionState { disconnected, connecting, connected }

class LocationState {
  LocationState({
    required this.myLast,
    required this.partnerLast,
    required this.myHistory,
    required this.partnerHistory,
    required this.historyWindow,
    required this.togetherTodayMinutes,
    required this.connection,
    this.loading = false,
    this.error,
  });

  LocationState.initial()
      : myLast = null,
        partnerLast = null,
        myHistory = const [],
        partnerHistory = const [],
        historyWindow = HistoryWindow.day1,
        togetherTodayMinutes = 0,
        connection = LocationConnectionState.disconnected,
        loading = true,
        error = null;

  final LocationDto? myLast;
  final LocationDto? partnerLast;
  final List<LocationDto> myHistory;
  final List<LocationDto> partnerHistory;
  final HistoryWindow historyWindow;
  final int togetherTodayMinutes;
  final LocationConnectionState connection;
  final bool loading;
  final String? error;

  LocationState copyWith({
    LocationDto? myLast,
    LocationDto? partnerLast,
    List<LocationDto>? myHistory,
    List<LocationDto>? partnerHistory,
    HistoryWindow? historyWindow,
    int? togetherTodayMinutes,
    LocationConnectionState? connection,
    bool? loading,
    Object? error = _sentinel,
  }) =>
      LocationState(
        myLast: myLast ?? this.myLast,
        partnerLast: partnerLast ?? this.partnerLast,
        myHistory: myHistory ?? this.myHistory,
        partnerHistory: partnerHistory ?? this.partnerHistory,
        historyWindow: historyWindow ?? this.historyWindow,
        togetherTodayMinutes:
            togetherTodayMinutes ?? this.togetherTodayMinutes,
        connection: connection ?? this.connection,
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();
}

class LocationController extends Notifier<LocationState> {
  late final LocationRepository _repo;
  late final LocationSignalrClient _signalr;
  StreamSubscription<LocationDto>? _partnerSub;
  StreamSubscription<HubConnectionState>? _stateSub;
  StreamSubscription<Position>? _mySub;

  String? get _myUserId {
    final s = ref.read(authControllerProvider);
    return s is AuthSignedIn ? s.session.userId : null;
  }

  @override
  LocationState build() {
    _repo = ref.read(locationRepositoryProvider);
    _signalr = ref.read(locationSignalrClientProvider);

    ref.onDispose(() async {
      await _partnerSub?.cancel();
      await _stateSub?.cancel();
      await _mySub?.cancel();
    });

    _bootstrap();
    return LocationState.initial();
  }

  Future<void> _bootstrap() async {
    await _loadAll(HistoryWindow.day1);

    _partnerSub = _signalr.onPartnerLocation.listen(_onPartner);
    _stateSub = _signalr.onState.listen((s) {
      state = state.copyWith(
        connection: switch (s) {
          HubConnectionState.Connected => LocationConnectionState.connected,
          HubConnectionState.Reconnecting =>
            LocationConnectionState.connecting,
          _ => LocationConnectionState.disconnected,
        },
      );
    });

    // Ana isolate'ta üretilen kendi konum noktalarını state'e yansıt
    _mySub = ref.read(locationTrackerProvider).myPositions.listen((p) {
      final dto = LocationDto(
        id: '__local__${p.timestamp.microsecondsSinceEpoch}',
        userId: _myUserId ?? '__me__',
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        speed: p.speed,
        heading: p.heading,
        batteryLevel: null,
        isMoving: p.speed > 0.5,
        recordedAt: p.timestamp,
        receivedAt: DateTime.now().toUtc(),
      );
      state = state.copyWith(
        myLast: dto,
        myHistory: [...state.myHistory, dto],
      );
    });

    state = state.copyWith(connection: LocationConnectionState.connecting);
    try {
      await _signalr.ensureConnected();
      state = state.copyWith(connection: LocationConnectionState.connected);
    } catch (_) {
      state = state.copyWith(connection: LocationConnectionState.disconnected);
    }
  }

  Future<void> setHistoryWindow(HistoryWindow w) async {
    state = state.copyWith(historyWindow: w);
    await _loadAll(w);
  }

  Future<void> refresh() => _loadAll(state.historyWindow);

  Future<void> _loadAll(HistoryWindow w) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final now = DateTime.now().toUtc();
      final from = now.subtract(w.duration);
      final history = await _repo.history(from: from, to: now);
      final partnerCurrent = await _repo.getPartnerCurrent();

      final me = _myUserId;
      final mine = <LocationDto>[];
      final theirs = <LocationDto>[];
      for (final dto in history) {
        if (me != null && dto.userId == me) {
          mine.add(dto);
        } else {
          theirs.add(dto);
        }
      }

      // bugünün beraber-dakikası
      final dayStart = DateTime(now.year, now.month, now.day).toUtc();
      int todayMin = 0;
      try {
        final today = await _repo.getTogether(from: dayStart, to: now);
        todayMin = today.totalMinutes;
      } on DioException {/* başarısızsa 0 kalır */}

      state = state.copyWith(
        myLast: mine.isNotEmpty ? mine.last : state.myLast,
        partnerLast: partnerCurrent ?? (theirs.isNotEmpty ? theirs.last : null),
        myHistory: mine,
        partnerHistory: theirs,
        togetherTodayMinutes: todayMin,
        loading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _readableError(e));
    }
  }

  void _onPartner(LocationDto dto) {
    state = state.copyWith(
      partnerLast: dto,
      partnerHistory: [...state.partnerHistory, dto],
    );
  }

  String _readableError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Yeniden giriş yapmalısın.';
    if (code == 403) return 'Konum paylaşımı kapalı.';
    if (e.type == DioExceptionType.connectionError) {
      return 'Sunucuya bağlanılamadı.';
    }
    return 'Konum bilgisi alınamadı.';
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);
