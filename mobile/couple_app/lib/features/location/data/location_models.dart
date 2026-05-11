/// Sunucudan dönen konum noktası.
class LocationDto {
  LocationDto({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.batteryLevel,
    required this.isMoving,
    required this.recordedAt,
    required this.receivedAt,
  });

  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final int? batteryLevel;
  final bool isMoving;
  final DateTime recordedAt;
  final DateTime receivedAt;

  factory LocationDto.fromJson(Map<String, dynamic> j) => LocationDto(
        id: j['id'] as String,
        userId: j['userId'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        speed: (j['speed'] as num?)?.toDouble(),
        heading: (j['heading'] as num?)?.toDouble(),
        batteryLevel: (j['batteryLevel'] as num?)?.toInt(),
        isMoving: (j['isMoving'] as bool?) ?? false,
        recordedAt: DateTime.parse(j['recordedAt'] as String),
        receivedAt: DateTime.parse(j['receivedAt'] as String),
      );
}

/// İstemciden sunucuya gönderilen tek nokta. Hub `SendLocation` ve
/// REST `POST /locations` aynı şekli kullanır.
class LocationInput {
  LocationInput({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.batteryLevel,
    required this.isMoving,
    required this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final int? batteryLevel;
  final bool isMoving;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'batteryLevel': batteryLevel,
        'isMoving': isMoving,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };
}

/// Gün bazlı beraber-süre.
class TogetherDay {
  TogetherDay({required this.date, required this.togetherMinutes});

  final DateTime date;
  final int togetherMinutes;

  factory TogetherDay.fromJson(Map<String, dynamic> j) => TogetherDay(
        date: DateTime.parse(j['date'] as String),
        togetherMinutes: (j['togetherMinutes'] as num).toInt(),
      );
}

class TogetherSummary {
  TogetherSummary({
    required this.from,
    required this.to,
    required this.totalMinutes,
    required this.byDay,
  });

  final DateTime from;
  final DateTime to;
  final int totalMinutes;
  final List<TogetherDay> byDay;

  factory TogetherSummary.fromJson(Map<String, dynamic> j) => TogetherSummary(
        from: DateTime.parse(j['from'] as String),
        to: DateTime.parse(j['to'] as String),
        totalMinutes: (j['totalMinutes'] as num).toInt(),
        byDay: (j['byDay'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(TogetherDay.fromJson)
            .toList(growable: false),
      );
}
