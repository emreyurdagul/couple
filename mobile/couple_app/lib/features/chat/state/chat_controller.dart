import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../data/chat_signalr_client.dart';
import '../data/message_models.dart';

class ChatState {
  ChatState({
    required this.messages,
    required this.connection,
    this.partnerTyping = false,
    this.loading = false,
    this.error,
  });

  ChatState.initial()
      : messages = const [],
        connection = ChatConnectionState.disconnected,
        partnerTyping = false,
        loading = true,
        error = null;

  final List<Message> messages;
  final ChatConnectionState connection;
  final bool partnerTyping;
  final bool loading;
  final String? error;

  ChatState copyWith({
    List<Message>? messages,
    ChatConnectionState? connection,
    bool? partnerTyping,
    bool? loading,
    Object? error = _sentinel,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        connection: connection ?? this.connection,
        partnerTyping: partnerTyping ?? this.partnerTyping,
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();
}

enum ChatConnectionState { disconnected, connecting, connected }

class ChatController extends Notifier<ChatState> {
  late final ChatRepository _repo;
  late final ChatSignalrClient _signalr;
  StreamSubscription<Message>? _messageSub;
  StreamSubscription<bool>? _typingSub;
  StreamSubscription<({String id, DateTime at})>? _readSub;

  @override
  ChatState build() {
    _repo = ref.read(chatRepositoryProvider);
    _signalr = ref.read(chatSignalrClientProvider);

    ref.onDispose(() async {
      await _messageSub?.cancel();
      await _typingSub?.cancel();
      await _readSub?.cancel();
    });

    _bootstrap();
    return ChatState.initial();
  }

  Future<void> _bootstrap() async {
    try {
      final history = await _repo.history(take: 50);
      // history desc → ekranda eskiden yeniye olsun diye reverse
      final ordered = history.reversed.toList(growable: true);
      state = state.copyWith(messages: ordered, loading: false);
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _readableError(e));
      return;
    }

    _messageSub = _signalr.onMessage.listen(_onIncoming);
    _typingSub = _signalr.onTyping.listen((isTyping) {
      state = state.copyWith(partnerTyping: isTyping);
    });
    _readSub = _signalr.onRead.listen((evt) {
      _applyRead(evt.id, evt.at);
    });

    state = state.copyWith(connection: ChatConnectionState.connecting);
    try {
      await _signalr.ensureConnected();
      state = state.copyWith(connection: ChatConnectionState.connected);
    } catch (_) {
      state = state.copyWith(connection: ChatConnectionState.disconnected);
    }
  }

  Future<void> send(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final id = _repo.newId();
    final now = DateTime.now().toUtc();
    // Mevcut session'dan sender id alabilir miyiz? Basitlik için empty bırakıyoruz,
    // server cevabı ile gerçek değerle replace edeceğiz.
    final optimistic = Message(
      id: id,
      coupleId: state.messages.isNotEmpty ? state.messages.last.coupleId : '',
      senderId: '__me__',
      type: MessageType.text,
      content: trimmed,
      createdAt: now,
      serverReceivedAt: now,
      deliveryStatus: MessageDeliveryStatus.sending,
    );

    state = state.copyWith(messages: [...state.messages, optimistic]);

    try {
      final saved = await _repo.send(
        id: id,
        type: MessageType.text,
        content: trimmed,
      );
      _replace(id, saved.copyWith(deliveryStatus: MessageDeliveryStatus.delivered));
    } on DioException catch (_) {
      _replace(
        id,
        optimistic.copyWith(deliveryStatus: MessageDeliveryStatus.failed),
      );
    }
  }

  Future<void> markPartnerMessageRead(String messageId) async {
    try {
      await _repo.markRead(messageId);
    } catch (_) {}
  }

  Future<void> retryConnect() async {
    state = state.copyWith(connection: ChatConnectionState.connecting);
    try {
      await _signalr.ensureConnected();
      state = state.copyWith(connection: ChatConnectionState.connected);
    } catch (_) {
      state = state.copyWith(connection: ChatConnectionState.disconnected);
    }
  }

  void _onIncoming(Message m) {
    // Aynı id ile zaten varsa (sender echo veya retry) güncelle
    final idx = state.messages.indexWhere((e) => e.id == m.id);
    if (idx >= 0) {
      final next = [...state.messages]..[idx] = m;
      state = state.copyWith(messages: next);
    } else {
      state = state.copyWith(messages: [...state.messages, m]);
    }
  }

  void _applyRead(String id, DateTime at) {
    final idx = state.messages.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final next = [...state.messages]..[idx] =
        state.messages[idx].copyWith(readAt: at);
    state = state.copyWith(messages: next);
  }

  void _replace(String id, Message updated) {
    final idx = state.messages.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final next = [...state.messages]..[idx] = updated;
    state = state.copyWith(messages: next);
  }

  String _readableError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Yeniden giriş yapmalısın.';
    if (e.type == DioExceptionType.connectionError) {
      return 'Sunucuya bağlanılamadı.';
    }
    return 'Mesajlar alınamadı.';
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
