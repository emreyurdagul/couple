import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../../core/config/app_config.dart';
import '../../auth/state/auth_controller.dart';
import 'message_models.dart';

/// ChatHub ile bağlantıyı yöneten ince sarmalayıcı.
/// Auth state değişince connection yeniden kurulur.
class ChatSignalrClient {
  ChatSignalrClient(this._ref);

  final Ref _ref;
  HubConnection? _conn;

  // Stream broadcast — birden fazla dinleyici (ChatController + bildirim badge'i vb.)
  final _messageController = StreamController<Message>.broadcast();
  final _readController = StreamController<({String id, DateTime at})>.broadcast();
  final _typingController = StreamController<bool>.broadcast();
  final _stateController =
      StreamController<HubConnectionState>.broadcast();

  Stream<Message> get onMessage => _messageController.stream;
  Stream<({String id, DateTime at})> get onRead => _readController.stream;
  Stream<bool> get onTyping => _typingController.stream;
  Stream<HubConnectionState> get onState => _stateController.stream;

  HubConnectionState get state =>
      _conn?.state ?? HubConnectionState.Disconnected;

  Future<void> ensureConnected() async {
    if (_conn != null && _conn!.state == HubConnectionState.Connected) return;
    if (_conn != null) await _conn!.stop();

    final session = _readSession();
    if (session == null) return;

    final url =
        '${AppConfig.apiBaseUrl}/hubs/chat?access_token=${Uri.encodeQueryComponent(session.accessToken)}';

    final conn = HubConnectionBuilder()
        .withUrl(url)
        .withAutomaticReconnect()
        .build();

    conn.on('ReceiveMessage', _onReceive);
    conn.on('MessageRead', _onRead);
    conn.on('Typing', _onTyping);
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

  Future<void> sendTyping(bool isTyping) async {
    if (_conn?.state != HubConnectionState.Connected) return;
    try {
      await _conn!.invoke('Typing', args: [isTyping]);
    } catch (_) {/* sessizce yut */}
  }

  Future<void> markRead(String messageId) async {
    if (_conn?.state != HubConnectionState.Connected) return;
    try {
      await _conn!.invoke('MarkRead', args: [messageId]);
    } catch (_) {/* REST tarafı zaten yapıyor olabilir */}
  }

  void _onReceive(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final raw = args.first;
    if (raw is Map) {
      try {
        final m = Message.fromJson(Map<String, dynamic>.from(raw));
        _messageController.add(m);
      } catch (_) {/* malformed */}
    }
  }

  void _onRead(List<Object?>? args) {
    if (args == null || args.length < 2) return;
    final id = args[0]?.toString();
    final at = args[1]?.toString();
    if (id == null || at == null) return;
    try {
      _readController.add((id: id, at: DateTime.parse(at)));
    } catch (_) {}
  }

  void _onTyping(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final v = args.first;
    if (v is bool) _typingController.add(v);
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
    await _messageController.close();
    await _readController.close();
    await _typingController.close();
    await _stateController.close();
  }
}

final chatSignalrClientProvider =
    Provider<ChatSignalrClient>((ref) {
  final client = ChatSignalrClient(ref);
  ref.onDispose(() async => await client.dispose());
  return client;
});
