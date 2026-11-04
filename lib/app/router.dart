import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion/payk_motion.dart';
import '../core/widgets/payk_shell.dart';
import '../core/widgets/states.dart';
import '../data/providers.dart';
import '../features/auth/auth_screens.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/code/client_code_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/connect_screen.dart';
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
      final onboarding = location == '/onboarding';
      final introDone = ref.read(splashFinishedProvider);

      // 1. Пока не завершился сплэш и чтение сессии — остаёмся на /splash
      if (!session.ready || !introDone) return splash ? null : '/splash';

      // 2. Онбординг: для неавторизованных пользователей, если ещё не просмотрен
      if (!logged && !session.onboardingSeen) {
        return onboarding ? null : '/onboarding';
      }
      if (onboarding) {
        return logged ? '/home' : '/auth/phone';
      }

      // 3. Неавторизованный пользователь: разрешаем только экраны авторизации
      if (!logged) {
        if (location == '/auth/code' && (session.pendingPhone == null || session.pendingPhone!.isEmpty)) {
          return '/auth/phone';
        }
        if (location == '/auth/profile' && (session.registrationToken == null || session.registrationToken!.isEmpty)) {
          return '/auth/phone';
        }
        if (!auth) return '/auth/phone';
        return null;
      }

      // 4. Авторизованный пользователь не должен попадать на экраны входа, сплэша или пустой корень
      if (auth || splash || location == '/') {
        return '/home';
      }
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
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/auth/phone', builder: (context, state) => const PhoneScreen()),
      GoRoute(
        path: '/auth/code',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const OtpScreen(),
        ),
      ),
      GoRoute(path: '/auth/otp', redirect: (context, state) => '/auth/code'),
      GoRoute(
        path: '/auth/profile',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const ProfileSetupScreen(),
        ),
      ),
      GoRoute(path: '/auth/register', redirect: (context, state) => '/auth/profile'),

      // Push-маршруты приложения (единая плавная система переходов PaykMotion)
      GoRoute(
        path: '/code',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const ClientCodeScreen(),
        ),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const HistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/rules',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const RulesScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/details',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const ProfileDetailsScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/connect',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const ConnectScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(path: '/profile/settings', redirect: (context, state) => '/settings'),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(path: '/messages', redirect: (context, state) => '/notifications'),

      // 4-вкладочный Shell Payk / UDC (Главная, Категории, Друзья, Профиль)
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => PaykShell(shell: shell),
        branches: [
          // Ветка 0: Главный экран
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          ]),
          // Ветка 1: Категории и поиск
          StatefulShellBranch(routes: [
            GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
          ]),
          // Ветка 2: Друзья
          StatefulShellBranch(routes: [
            GoRoute(path: '/friends', builder: (context, state) => const FriendsScreen()),
          ]),
          // Ветка 3: Профиль
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});
