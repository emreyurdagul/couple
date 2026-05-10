class CoupleInvite {
  CoupleInvite({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;

  factory CoupleInvite.fromJson(Map<String, dynamic> j) => CoupleInvite(
        code: j['code'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );
}

class CoupleAccept {
  CoupleAccept({
    required this.coupleId,
    required this.partnerUserId,
    required this.partnerDisplayName,
  });
  final String coupleId;
  final String partnerUserId;
  final String partnerDisplayName;

  factory CoupleAccept.fromJson(Map<String, dynamic> j) => CoupleAccept(
        coupleId: j['coupleId'] as String,
        partnerUserId: j['partnerUserId'] as String,
        partnerDisplayName: j['partnerDisplayName'] as String,
      );
}

class CoupleInfo {
  CoupleInfo({
    required this.coupleId,
    required this.status,
    required this.createdAt,
    required this.partnerUserId,
    required this.partnerDisplayName,
  });
  final String coupleId;
  final String status;
  final DateTime createdAt;
  final String partnerUserId;
  final String partnerDisplayName;

  factory CoupleInfo.fromJson(Map<String, dynamic> j) => CoupleInfo(
        coupleId: j['coupleId'] as String,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        partnerUserId: j['partnerUserId'] as String,
        partnerDisplayName: j['partnerDisplayName'] as String,
      );
}
