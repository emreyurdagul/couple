import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  TokenStore(this._storage);
  final FlutterSecureStorage _storage;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserId = 'user_id';
  static const _kCoupleId = 'couple_id';

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userId,
    String? coupleId,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccess, value: accessToken),
      _storage.write(key: _kRefresh, value: refreshToken),
      _storage.write(key: _kUserId, value: userId),
      if (coupleId != null)
        _storage.write(key: _kCoupleId, value: coupleId)
      else
        _storage.delete(key: _kCoupleId),
    ]);
  }

  Future<({String? access, String? refresh, String? userId, String? coupleId})>
      read() async {
    final values = await Future.wait([
      _storage.read(key: _kAccess),
      _storage.read(key: _kRefresh),
      _storage.read(key: _kUserId),
      _storage.read(key: _kCoupleId),
    ]);
    return (
      access: values[0],
      refresh: values[1],
      userId: values[2],
      coupleId: values[3],
    );
  }

  Future<void> updateCoupleId(String? coupleId) async {
    if (coupleId == null) {
      await _storage.delete(key: _kCoupleId);
    } else {
      await _storage.write(key: _kCoupleId, value: coupleId);
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kCoupleId),
    ]);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ));
});
