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
  }) async {
    final body = <String, dynamic>{
      'id': id,
      'type': messageTypeToServer(type),
    };
    if (content != null) body['content'] = content;
    final res = await _dio.post<Map<String, dynamic>>('/messages', data: body);
    return Message.fromJson(res.data!);
  }

  Future<void> markRead(String messageId) async {
    await _dio.post<void>('/messages/$messageId/read');
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.read(apiClientProvider));
});
