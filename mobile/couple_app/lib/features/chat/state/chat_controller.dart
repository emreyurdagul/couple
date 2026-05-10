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
    this.replyTo,
    this.editing,
  });

  ChatState.initial()
      : messages = const [],
        connection = ChatConnectionState.disconnected,
        partnerTyping = false,
        loading = true,
        error = null,
        replyTo = null,
        editing = null;

  final List<Message> messages;
  final ChatConnectionState connection;
  final bool partnerTyping;
  final bool loading;
  final String? error;

  /// Yanıtlanmak üzere seçilen mesaj (null = aktif değil)
  final Message? replyTo;

  /// Düzenlenmek üzere seçilen kendi mesajı (null = aktif değil)
  final Message? editing;

  ChatState copyWith({
    List<Message>? messages,
    ChatConnectionState? connection,
    bool? partnerTyping,
    bool? loading,
    Object? error = _sentinel,
    Object? replyTo = _sentinel,
    Object? editing = _sentinel,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        connection: connection ?? this.connection,
        partnerTyping: partnerTyping ?? this.partnerTyping,
        loading: loading ?? this.loading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        replyTo: identical(replyTo, _sentinel)
            ? this.replyTo
            : replyTo as Message?,
        editing: identical(editing, _sentinel)
            ? this.editing
            : editing as Message?,
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
  StreamSubscription<({String messageId, Reaction reaction})>? _reactedSub;
  StreamSubscription<({String messageId, String userId, String emoji})>?
      _reactionRemovedSub;
  StreamSubscription<Message>? _editedSub;
  StreamSubscription<({String messageId, String scope})>? _deletedSub;

  @override
  ChatState build() {
    _repo = ref.read(chatRepositoryProvider);
    _signalr = ref.read(chatSignalrClientProvider);

    ref.onDispose(() async {
      await _messageSub?.cancel();
      await _typingSub?.cancel();
      await _readSub?.cancel();
      await _reactedSub?.cancel();
      await _reactionRemovedSub?.cancel();
      await _editedSub?.cancel();
      await _deletedSub?.cancel();
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
    _reactedSub = _signalr.onReacted.listen((evt) {
      _applyReactionAdded(evt.messageId, evt.reaction);
    });
    _reactionRemovedSub = _signalr.onReactionRemoved.listen((evt) {
      _applyReactionRemoved(evt.messageId, evt.userId, evt.emoji);
    });
    _editedSub = _signalr.onEdited.listen(_applyEdited);
    _deletedSub = _signalr.onDeleted.listen((evt) {
      if (evt.scope == 'both') _applyDeletedForBoth(evt.messageId);
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

    // Editing modu varsa edit'e döner
    final editing = state.editing;
    if (editing != null) {
      await _submitEdit(editing, trimmed);
      return;
    }

    final replyTarget = state.replyTo;
    final id = _repo.newId();
    final now = DateTime.now().toUtc();
    final optimistic = Message(
      id: id,
      coupleId: state.messages.isNotEmpty ? state.messages.last.coupleId : '',
      senderId: '__me__',
      type: MessageType.text,
      content: trimmed,
      createdAt: now,
      serverReceivedAt: now,
      replyToMessageId: replyTarget?.id,
      deliveryStatus: MessageDeliveryStatus.sending,
    );

    state = state.copyWith(
      messages: [...state.messages, optimistic],
      replyTo: null,
    );

    try {
      final saved = await _repo.send(
        id: id,
        type: MessageType.text,
        content: trimmed,
        replyToMessageId: replyTarget?.id,
      );
      _replace(
        id,
        saved.copyWith(deliveryStatus: MessageDeliveryStatus.delivered),
      );
    } on DioException catch (_) {
      _replace(
        id,
        optimistic.copyWith(deliveryStatus: MessageDeliveryStatus.failed),
      );
    }
  }

  void startReply(Message m) {
    if (m.isDeleted) return;
    state = state.copyWith(replyTo: m, editing: null);
  }

  void cancelReply() {
    state = state.copyWith(replyTo: null);
  }

  void startEdit(Message m) {
    state = state.copyWith(editing: m, replyTo: null);
  }

  void cancelEdit() {
    state = state.copyWith(editing: null);
  }

  Future<void> _submitEdit(Message original, String newContent) async {
    state = state.copyWith(editing: null);
    final optimistic = original.copyWith(
      content: newContent,
      editedAt: DateTime.now().toUtc(),
    );
    _replace(original.id, optimistic);
    try {
      final updated = await _repo.edit(original.id, newContent);
      _replace(original.id, updated);
    } on DioException catch (_) {
      // Edit başarısız → eski içerik geri
      _replace(original.id, original);
    }
  }

  Future<void> deleteMessage(Message m, {required bool forBoth}) async {
    try {
      await _repo.delete(m.id, forBoth: forBoth);
      if (forBoth) {
        _applyDeletedForBoth(m.id);
      } else {
        // for me → mesajı listeden çıkar
        state = state.copyWith(
          messages: state.messages.where((x) => x.id != m.id).toList(),
        );
      }
    } on DioException catch (_) {
      // sessizce geri al
    }
  }

  Future<void> toggleReaction(Message m, String emoji, String myUserId) async {
    final existing = m.reactions
        .where((r) => r.userId == myUserId && r.emoji == emoji)
        .toList();
    if (existing.isNotEmpty) {
      // Optimistic remove
      _applyReactionRemoved(m.id, myUserId, emoji);
      try {
        await _repo.removeReaction(m.id, emoji);
      } catch (_) {
        // hata: optimistic geri alma karmaşası — ileride iyileştirilecek
      }
    } else {
      // Optimistic add (geçici id)
      final tempReaction = Reaction(
        id: '__temp__',
        userId: myUserId,
        emoji: emoji,
        createdAt: DateTime.now().toUtc(),
      );
      _applyReactionAdded(m.id, tempReaction);
      try {
        final saved = await _repo.addReaction(m.id, emoji);
        // Temp'i gerçekle değiştir
        _replaceReaction(m.id, '__temp__', saved);
      } catch (_) {
        _applyReactionRemoved(m.id, myUserId, emoji);
      }
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
    final idx = state.messages.indexWhere((e) => e.id == m.id);
    if (idx >= 0) {
      // Mevcut reactions'ları koru (server payload'da reactions zaten geliyor ama
      // eski local optimistic state'in reactions'ları daha güncel olabilir).
      final preservedReactions = state.messages[idx].reactions.isNotEmpty &&
              m.reactions.isEmpty
          ? state.messages[idx].reactions
          : m.reactions;
      final next = [...state.messages]
        ..[idx] = m.copyWith(reactions: preservedReactions);
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

  void _applyEdited(Message updated) {
    _replace(updated.id, updated);
  }

  void _applyDeletedForBoth(String id) {
    final idx = state.messages.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final m = state.messages[idx].copyWith(
      deletedAt: DateTime.now().toUtc(),
      clearContent: true,
    );
    final next = [...state.messages]..[idx] = m;
    state = state.copyWith(messages: next);
  }

  void _applyReactionAdded(String messageId, Reaction r) {
    final idx = state.messages.indexWhere((e) => e.id == messageId);
    if (idx < 0) return;
    final m = state.messages[idx];
    // Aynı user+emoji varsa idempotent
    if (m.reactions.any((x) => x.userId == r.userId && x.emoji == r.emoji)) {
      return;
    }
    final newList = [...m.reactions, r];
    final next = [...state.messages]..[idx] = m.copyWith(reactions: newList);
    state = state.copyWith(messages: next);
  }

  void _applyReactionRemoved(String messageId, String userId, String emoji) {
    final idx = state.messages.indexWhere((e) => e.id == messageId);
    if (idx < 0) return;
    final m = state.messages[idx];
    final newList = m.reactions
        .where((x) => !(x.userId == userId && x.emoji == emoji))
        .toList();
    final next = [...state.messages]..[idx] = m.copyWith(reactions: newList);
    state = state.copyWith(messages: next);
  }

  void _replaceReaction(String messageId, String oldId, Reaction newR) {
    final idx = state.messages.indexWhere((e) => e.id == messageId);
    if (idx < 0) return;
    final m = state.messages[idx];
    final newList = m.reactions
        .map((r) => r.id == oldId ? newR : r)
        .toList(growable: false);
    final next = [...state.messages]..[idx] = m.copyWith(reactions: newList);
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
