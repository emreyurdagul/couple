import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/couple/presentation/invite_accept_screen.dart';
import '../../features/couple/presentation/invite_create_screen.dart';
import '../../features/couple/presentation/onboarding_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../shared/widgets/page_turn_transition.dart';
import '../theme/tokens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);

  Page<void> page(Widget child, GoRouterState state) =>
      PageTurnPage(child: child, key: state.pageKey, name: state.name);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (auth is AuthInitializing) {
        return loc == '/splash' ? null : '/splash';
      }
      if (auth is AuthSignedOut) {
        if (loc == '/login' || loc == '/register') return null;
        return '/login';
      }
      if (auth is AuthSignedIn) {
        final hasCouple = auth.session.hasCouple;
        if (loc == '/login' || loc == '/register' || loc == '/splash') {
          return hasCouple ? '/' : '/couple';
        }
        if (!hasCouple) {
          if (loc.startsWith('/couple')) return null;
          return '/couple';
        }
        if (hasCouple && loc.startsWith('/couple')) return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, s) => page(const _SplashScreen(), s),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) => page(const LoginScreen(), s),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, s) => page(const RegisterScreen(), s),
      ),
      GoRoute(
        path: '/couple',
        pageBuilder: (_, s) => page(const OnboardingScreen(), s),
      ),
      GoRoute(
        path: '/couple/invite',
        pageBuilder: (_, s) => page(const InviteCreateScreen(), s),
      ),
      GoRoute(
        path: '/couple/accept',
        pageBuilder: (_, s) => page(const InviteAcceptScreen(), s),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (_, s) => page(const HomeScreen(), s),
      ),
      GoRoute(
        path: '/chat',
        pageBuilder: (_, s) => page(const ChatScreen(), s),
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _ref.listen<AuthState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }
  final Ref _ref;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
