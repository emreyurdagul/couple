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

  /// Sadece istemci tarafında kullanılır. Server'dan gelen mesajlar
  /// always = delivered olarak başlar.
  final MessageDeliveryStatus deliveryStatus;

  Message copyWith({
    DateTime? readAt,
    MessageDeliveryStatus? deliveryStatus,
    DateTime? serverReceivedAt,
  }) =>
      Message(
        id: id,
        coupleId: coupleId,
        senderId: senderId,
        type: type,
        content: content,
        payload: payload,
        mediaObjectKey: mediaObjectKey,
        mediaMimeType: mediaMimeType,
        mediaDurationMs: mediaDurationMs,
        mediaSizeBytes: mediaSizeBytes,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        serverReceivedAt: serverReceivedAt ?? this.serverReceivedAt,
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
      );
}

enum MessageDeliveryStatus { sending, delivered, failed }
