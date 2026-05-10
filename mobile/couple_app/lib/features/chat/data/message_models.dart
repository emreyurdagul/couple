enum MessageType { text, image, voice, system, custom }

MessageType _typeFromString(String? raw) {
  switch (raw) {
    case 'Text':
      return MessageType.text;
    case 'Image':
      return MessageType.image;
    case 'Voice':
      return MessageType.voice;
    case 'System':
      return MessageType.system;
    default:
      return MessageType.custom;
  }
}

int messageTypeToServer(MessageType t) {
  switch (t) {
    case MessageType.text:
      return 0;
    case MessageType.image:
      return 1;
    case MessageType.voice:
      return 2;
    case MessageType.system:
      return 3;
    case MessageType.custom:
      return 99;
  }
}

class Reaction {
  Reaction({
    required this.id,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  factory Reaction.fromJson(Map<String, dynamic> j) => Reaction(
        id: j['id'] as String,
        userId: j['userId'] as String,
        emoji: j['emoji'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class Message {
  Message({
    required this.id,
    required this.coupleId,
    required this.senderId,
    required this.type,
    this.content,
    this.payload,
    this.mediaObjectKey,
    this.mediaMimeType,
    this.mediaDurationMs,
    this.mediaSizeBytes,
    required this.createdAt,
    this.readAt,
    required this.serverReceivedAt,
    this.replyToMessageId,
    this.editedAt,
    this.deletedAt,
    this.deletedByUserId,
    this.isPinned = false,
    this.pinnedAt,
    this.expiresAt,
    this.isEphemeral = false,
    this.viewedAt,
    this.reactions = const [],
    this.deliveryStatus = MessageDeliveryStatus.delivered,
  });

  final String id;
  final String coupleId;
  final String senderId;
  final MessageType type;
  final String? content;
  final String? payload;
  final String? mediaObjectKey;
  final String? mediaMimeType;
  final int? mediaDurationMs;
  final int? mediaSizeBytes;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime serverReceivedAt;

  // 3.2
  final String? replyToMessageId;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? deletedByUserId;

  // 3.3
  final bool isPinned;
  final DateTime? pinnedAt;

  // 3.4
  final DateTime? expiresAt;

  // 4.5
  final bool isEphemeral;
  final DateTime? viewedAt;

  final List<Reaction> reactions;

  /// Sadece istemci tarafında kullanılır.
  final MessageDeliveryStatus deliveryStatus;

  bool get isDeleted => deletedAt != null;

  Message copyWith({
    DateTime? readAt,
    MessageDeliveryStatus? deliveryStatus,
    DateTime? serverReceivedAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? content,
    bool clearContent = false,
    List<Reaction>? reactions,
  }) =>
      Message(
        id: id,
        coupleId: coupleId,
        senderId: senderId,
        type: type,
        content: clearContent ? null : (content ?? this.content),
        payload: payload,
        mediaObjectKey: mediaObjectKey,
        mediaMimeType: mediaMimeType,
        mediaDurationMs: mediaDurationMs,
        mediaSizeBytes: mediaSizeBytes,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        serverReceivedAt: serverReceivedAt ?? this.serverReceivedAt,
        replyToMessageId: replyToMessageId,
        editedAt: editedAt ?? this.editedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedByUserId: deletedByUserId,
        isPinned: isPinned,
        pinnedAt: pinnedAt,
        expiresAt: expiresAt,
        isEphemeral: isEphemeral,
        viewedAt: viewedAt,
        reactions: reactions ?? this.reactions,
        deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      );

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        coupleId: j['coupleId'] as String,
        senderId: j['senderId'] as String,
        type: _typeFromString(j['type'] as String?),
        content: j['content'] as String?,
        payload: j['payload'] as String?,
        mediaObjectKey: j['mediaObjectKey'] as String?,
        mediaMimeType: j['mediaMimeType'] as String?,
        mediaDurationMs: (j['mediaDurationMs'] as num?)?.toInt(),
        mediaSizeBytes: (j['mediaSizeBytes'] as num?)?.toInt(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        readAt: j['readAt'] is String
            ? DateTime.parse(j['readAt'] as String)
            : null,
        serverReceivedAt:
            DateTime.parse(j['serverReceivedAt'] as String),
        replyToMessageId: j['replyToMessageId'] as String?,
        editedAt: j['editedAt'] is String
            ? DateTime.parse(j['editedAt'] as String)
            : null,
        deletedAt: j['deletedAt'] is String
            ? DateTime.parse(j['deletedAt'] as String)
            : null,
        deletedByUserId: j['deletedByUserId'] as String?,
        isPinned: (j['isPinned'] as bool?) ?? false,
        pinnedAt: j['pinnedAt'] is String
            ? DateTime.parse(j['pinnedAt'] as String)
            : null,
        expiresAt: j['expiresAt'] is String
            ? DateTime.parse(j['expiresAt'] as String)
            : null,
        isEphemeral: (j['isEphemeral'] as bool?) ?? false,
        viewedAt: j['viewedAt'] is String
            ? DateTime.parse(j['viewedAt'] as String)
            : null,
        reactions: (j['reactions'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(Reaction.fromJson)
            .toList(),
      );
}

enum MessageDeliveryStatus { sending, delivered, failed }
