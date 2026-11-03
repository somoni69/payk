import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/payk_shell.dart';
import '../core/widgets/states.dart';
import '../data/providers.dart';
import '../features/auth/auth_screens.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/code/client_code_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/rules/rules_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (previous, next) {
    refresh.value++;
  });
  ref.listen(splashFinishedProvider, (previous, next) {
    refresh.value++;
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final logged = session.loggedIn;
      final auth = location.startsWith('/auth');
      final splash = location == '/splash';
      final introDone = ref.read(splashFinishedProvider);
      if (!session.ready || !introDone) return splash ? null : '/splash';
      if (!session.onboardingSeen && location != '/onboarding') return '/onboarding';
      if (session.onboardingSeen && location == '/onboarding') return logged ? '/home' : '/auth/phone';
      if (!logged && location == '/auth/code' && (session.pendingPhone == null || session.pendingPhone!.isEmpty)) {
        return '/auth/phone';
      }
      if (!logged && location == '/auth/profile' && (session.registrationToken == null || session.registrationToken!.isEmpty)) {
        return '/auth/phone';
      }
      if (!logged && splash) return '/auth/phone';
      if (!logged && !auth) return '/auth/phone';
      if (logged && (auth || splash)) return '/home';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: ErrorState(
        message: 'Страница не найдена',
        actionLabel: 'На главную',
        onRetry: () => context.go('/home'),
      ),
    ),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth/phone', builder: (context, state) => const PhoneScreen()),
      GoRoute(path: '/auth/code', builder: (context, state) => const OtpScreen()),
      GoRoute(path: '/auth/profile', builder: (context, state) => const ProfileSetupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => PaykShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/code', builder: (context, state) => const ClientCodeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/friends', builder: (context, state) => const FriendsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/rules', builder: (context, state) => const RulesScreen()),
    ],
  );
});
