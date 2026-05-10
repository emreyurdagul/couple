import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'couple_models.dart';

class CoupleRepository {
  CoupleRepository(this._dio);
  final Dio _dio;

  Future<CoupleInvite> createInvite() async {
    final res = await _dio.post<Map<String, dynamic>>('/couples/invites');
    return CoupleInvite.fromJson(res.data!);
  }

  Future<CoupleAccept> acceptInvite(String code) async {
    final res = await _dio
        .post<Map<String, dynamic>>('/couples/invites/${code.trim().toUpperCase()}/accept');
    return CoupleAccept.fromJson(res.data!);
  }

  Future<CoupleInfo?> getMyCouple() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/couples/me');
      return CoupleInfo.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> endCouple() async {
    await _dio.delete<void>('/couples/me');
  }
}

final coupleRepositoryProvider = Provider<CoupleRepository>((ref) {
  return CoupleRepository(ref.read(apiClientProvider));
});
