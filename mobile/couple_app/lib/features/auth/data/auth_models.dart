class AuthSession {
  AuthSession({
    required this.userId,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    this.coupleId,
  });

  final String userId;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final String? coupleId;

  bool get hasCouple => coupleId != null && coupleId!.isNotEmpty;

  AuthSession copyWith({String? coupleId, bool clearCouple = false}) =>
      AuthSession(
        userId: userId,
        accessToken: accessToken,
        accessTokenExpiresAt: accessTokenExpiresAt,
        refreshToken: refreshToken,
        refreshTokenExpiresAt: refreshTokenExpiresAt,
        coupleId: clearCouple ? null : (coupleId ?? this.coupleId),
      );

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        userId: json['userId'] as String,
        accessToken: json['accessToken'] as String,
        accessTokenExpiresAt:
            DateTime.parse(json['accessTokenExpiresAt'] as String),
        refreshToken: json['refreshToken'] as String,
        refreshTokenExpiresAt:
            DateTime.parse(json['refreshTokenExpiresAt'] as String),
        coupleId: json['coupleId'] as String?,
      );
}
