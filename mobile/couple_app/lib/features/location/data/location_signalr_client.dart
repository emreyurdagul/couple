import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../../core/config/app_config.dart';
import '../../auth/state/auth_controller.dart';
import 'location_models.dart';

/// LocationHub ile bağlantıyı yöneten ince sarmalayıcı.
/// Chat'in `ChatSignalrClient` deseninin birebir aynası — tek event yeterli:
/// partner konum push'ları için `ReceiveLocation`.
class LocationSignalrClient {
  LocationSignalrClient(this._ref);

  final Ref _ref;
  HubConnection? _conn;

  final _locationController = StreamController<LocationDto>.broadcast();
  final _stateController =
      StreamController<HubConnectionState>.broadcast();

  Stream<LocationDto> get onPartnerLocation => _locationController.stream;
  Stream<HubConnectionState> get onState => _stateController.stream;

  HubConnectionState get state =>
      _conn?.state ?? HubConnectionState.Disconnected;

  Future<void> ensureConnected() async {
    if (_conn != null && _conn!.state == HubConnectionState.Connected) return;
    if (_conn != null) await _conn!.stop();

    final session = _readSession();
    if (session == null) return;

    final url =
        '${AppConfig.apiBaseUrl}/hubs/location?access_token=${Uri.encodeQueryComponent(session.accessToken)}';

    final conn = HubConnectionBuilder()
        .withUrl(url)
        .withAutomaticReconnect()
        .build();

    conn.on('ReceiveLocation', _onReceive);
    conn.onclose(({error}) {
      _stateController.add(HubConnectionState.Disconnected);
    });
    conn.onreconnecting(({error}) {
      _stateController.add(HubConnectionState.Reconnecting);
    });
    conn.onreconnected(({connectionId}) {
      _stateController.add(HubConnectionState.Connected);
    });

    try {
      await conn.start();
      _conn = conn;
      _stateController.add(HubConnectionState.Connected);
    } catch (_) {
      _stateController.add(HubConnectionState.Disconnected);
      rethrow;
    }
  }

  Future<void> stop() async {
    final c = _conn;
    _conn = null;
    if (c != null) {
      try {
        await c.stop();
      } catch (_) {}
    }
    _stateController.add(HubConnectionState.Disconnected);
  }

  /// Tracker tarafından çağrılır; SignalR connected değilse REST fallback'e bırakır.
  Future<LocationDto?> sendLocation(LocationInput input) async {
    if (_conn?.state != HubConnectionState.Connected) return null;
    try {
      final raw = await _conn!.invoke('SendLocation', args: [input.toJson()]);
      if (raw is Map) {
        return LocationDto.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _onReceive(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is Map) {
      try {
        final dto = LocationDto.fromJson(Map<String, dynamic>.from(raw));
        _locationController.add(dto);
      } catch (_) {/* malformed */}
    }
  }

  ({String accessToken})? _readSession() {
    final state = _ref.read(authControllerProvider);
    if (state is AuthSignedIn) {
      return (accessToken: state.session.accessToken);
    }
    return null;
  }

  Future<void> dispose() async {
    await stop();
    await _locationController.close();
    await _stateController.close();
  }
}

final locationSignalrClientProvider =
    Provider<LocationSignalrClient>((ref) {
  final client = LocationSignalrClient(ref);
  ref.onDispose(() async => await client.dispose());
  return client;
});
