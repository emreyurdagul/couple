import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_store.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitializing extends AuthState {
  const AuthInitializing();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.errorMessage});
  final String? errorMessage;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.session);
  final AuthSession session;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthInitializing();
  }

  Future<void> _restore() async {
    final store = ref.read(tokenStoreProvider);
    final stored = await store.read();
    if (stored.access == null || stored.refresh == null || stored.userId == null) {
      state = const AuthSignedOut();
      return;
    }
    // Önce stored token ile session kur → router yönlendirebilir.
    state = AuthSignedIn(AuthSession(
      userId: stored.userId!,
      accessToken: stored.access!,
      accessTokenExpiresAt: DateTime.now().add(const Duration(minutes: 1)),
      refreshToken: stored.refresh!,
      refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
      coupleId: stored.coupleId,
    ));
    // Backend'den güncel coupleId/claim'leri al; refresh fail olursa signed out'a düşer.
    await refresh();
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .register(email: email, password: password, displayName: displayName);
    await _persist(session);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await _persist(session);
  }

  Future<bool> refresh() async {
    final current = state;
    if (current is! AuthSignedIn) return false;
    final next = await ref
        .read(authRepositoryProvider)
        .refresh(current.session.refreshToken);
    if (next == null) {
      await _signOut();
      return false;
    }
    await _persist(next);
    return true;
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // sunucu zaten erişilemez olabilir; lokali yine de temizle
    }
    await _signOut();
  }

  /// Couple davet kabul edildikten sonra token'ı yenileyip couple_id claim'ini almak için.
  Future<void> rotateAfterCoupleChange() async {
    await refresh();
  }

  /// Soft archive sonrası: refresh tokenları sunucuda revoke edildi → lokali temizle.
  Future<void> handleCoupleEnded() async {
    await _signOut();
  }

  Future<void> _persist(AuthSession session) async {
    await ref.read(tokenStoreProvider).save(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          userId: session.userId,
          coupleId: session.coupleId,
        );
    state = AuthSignedIn(session);
  }

  Future<void> _signOut() async {
    await ref.read(tokenStoreProvider).clear();
    state = const AuthSignedOut();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
