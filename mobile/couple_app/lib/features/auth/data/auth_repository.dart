import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository(this._raw, this._authed);
  final Dio _raw;
  final Dio _authed;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _raw.post<Map<String, dynamic>>('/auth/register', data: {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
    return AuthSession.fromJson(res.data!);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final res = await _raw.post<Map<String, dynamic>>('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(res.data!);
  }

  Future<AuthSession?> refresh(String refreshToken) async {
    try {
      final res = await _raw.post<Map<String, dynamic>>('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      return AuthSession.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authed.post<void>('/auth/logout');
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(rawApiClientProvider),
    ref.read(apiClientProvider),
  );
});
