import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../features/couple/presentation/invite_accept_screen.dart';
import '../../features/couple/presentation/invite_create_screen.dart';
import '../../features/couple/presentation/onboarding_screen.dart';
import '../../features/home/presentation/home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);

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
        if (loc == '/login' ||
            loc == '/register' ||
            loc == '/splash') {
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
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/couple', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
          path: '/couple/invite',
          builder: (_, _) => const InviteCreateScreen()),
      GoRoute(
          path: '/couple/accept',
          builder: (_, _) => const InviteAcceptScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
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
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
