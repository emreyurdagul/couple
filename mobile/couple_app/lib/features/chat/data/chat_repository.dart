import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import 'message_models.dart';

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;
  static const _uuid = Uuid();

  /// İstemci tarafında bir UUIDv7 türevi üretir (Uuid paketinin v7'si).
  String newId() => _uuid.v7();

  Future<List<Message>> history({DateTime? since, int take = 50}) async {
    final res = await _dio.get<List<dynamic>>(
      '/messages',
      queryParameters: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
        'take': take,
      },
    );
    final data = res.data ?? const [];
    return data
        .cast<Map<String, dynamic>>()
        .map(Message.fromJson)
        .toList(growable: false);
  }

  Future<Message> send({
    required String id,
    required MessageType type,
    String? content,
    String? replyToMessageId,
  }) async {
    final body = <String, dynamic>{
      'id': id,
      'type': messageTypeToServer(type),
    };
    if (content != null) body['content'] = content;
    if (replyToMessageId != null) body['replyToMessageId'] = replyToMessageId;
    final res = await _dio.post<Map<String, dynamic>>('/messages', data: body);
    return Message.fromJson(res.data!);
  }

  Future<void> markRead(String messageId) async {
    await _dio.post<void>('/messages/$messageId/read');
  }

  Future<Message> edit(String messageId, String content) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/messages/$messageId',
      data: {'content': content},
    );
    return Message.fromJson(res.data!);
  }

  Future<void> delete(String messageId, {required bool forBoth}) async {
    await _dio.delete<void>(
      '/messages/$messageId',
      queryParameters: {'scope': forBoth ? 'both' : 'me'},
    );
  }

  Future<Reaction> addReaction(String messageId, String emoji) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/messages/$messageId/reactions',
      data: {'emoji': emoji},
    );
    return Reaction.fromJson(res.data!);
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    final encoded = Uri.encodeComponent(emoji);
    await _dio.delete<void>('/messages/$messageId/reactions/$encoded');
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.read(apiClientProvider));
});
