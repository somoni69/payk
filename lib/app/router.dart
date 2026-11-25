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
import '../features/history/receipt_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/connect_screen.dart';
import '../features/profile/phone_change_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/raffles/raffles_screen.dart';
import '../features/rules/rules_screen.dart';
import '../features/showcase/payk_business_screen.dart';
import '../features/sizes/size_offers_screen.dart';
import '../features/sizes/sizes_screen.dart';
import '../features/store/almosi_store_screen.dart';

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

      // Захват реферального кода из Universal/App Link (`/r/AZ-4821`) до любых редиректов.
      final referralCode = parseReferralCodeFromUri(state.uri);
      if (referralCode != null) {
        ref.read(referralServiceProvider).captureCode(referralCode).ignore();
      }

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
        if (location == '/auth/code' &&
            (session.pendingPhone == null || session.pendingPhone!.isEmpty)) {
          return '/auth/phone';
        }
        if (location == '/auth/profile' &&
            (session.registrationToken == null ||
                session.registrationToken!.isEmpty)) {
          return '/auth/phone';
        }
        if (!auth) return '/auth/phone';
        return null;
      }

      // 4. После регистрации с подарком показываем экран «Подарок» один раз перед главной
      final hasGift = (session.pendingWelcomeBonus ?? 0) > 0;
      final onGift = location == '/welcome-gift';
      if (hasGift) {
        return onGift ? null : '/welcome-gift';
      }
      if (onGift) {
        return '/home';
      }

      // 5. Авторизованный пользователь не должен попадать на экраны входа, сплэша или пустой корень
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
      GoRoute(
        path: '/r/:code',
        redirect: (context, state) {
          final code = state.pathParameters['code'];
          if (code != null && code.isNotEmpty) {
            ref.read(referralServiceProvider).captureCode(code).ignore();
          }
          final session = ref.read(sessionProvider);
          if (session.loggedIn) return '/home';
          return session.onboardingSeen ? '/auth/phone' : '/onboarding';
        },
      ),
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          name: state.name ?? state.path,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => PaykMotion.buildFadeScalePage(
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/phone',
        pageBuilder: (context, state) => PaykMotion.buildFadeScalePage(
          state: state,
          child: const PhoneScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/code',
        pageBuilder: (context, state) =>
            PaykMotion.buildPage(state: state, child: const OtpScreen()),
      ),
      GoRoute(path: '/auth/otp', redirect: (context, state) => '/auth/code'),
      GoRoute(
        path: '/auth/profile',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const ProfileSetupScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/register',
        redirect: (context, state) => '/auth/profile',
      ),
      GoRoute(
        path: '/welcome-gift',
        pageBuilder: (context, state) => PaykMotion.buildFadeScalePage(
          state: state,
          child: const WelcomeGiftScreen(),
        ),
      ),

      // Push-маршруты приложения (единая плавная система переходов PaykMotion)
      GoRoute(
        path: '/code',
        pageBuilder: (context, state) =>
            PaykMotion.buildPage(state: state, child: const ClientCodeScreen()),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'] == 'bills'
              ? HistoryTab.bills
              : HistoryTab.ops;
          final cat = state.uri.queryParameters['cat'];
          return PaykMotion.buildPage(
            state: state,
            child: HistoryScreen(initialCategory: cat, initialTab: tab),
          );
        },
      ),
      GoRoute(
        path: '/receipts',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const HistoryScreen(initialTab: HistoryTab.bills),
        ),
      ),
      GoRoute(
        path: '/history/receipt/:id',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final focusReturns = state.uri.queryParameters['focus'] == 'returns';
          return PaykMotion.buildPage(
            state: state,
            child: ReceiptDetailScreen(
              receiptId: id,
              focusReturns: focusReturns,
            ),
          );
        },
      ),
      GoRoute(
        path: '/rules',
        pageBuilder: (context, state) =>
            PaykMotion.buildPage(state: state, child: const RulesScreen()),
      ),
      GoRoute(
        path: '/raffles',
        pageBuilder: (context, state) =>
            PaykMotion.buildPage(state: state, child: const RafflesScreen()),
      ),
      GoRoute(
        path: '/almosi',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const AlmosiStoreScreen(),
        ),
      ),
      GoRoute(
        path: '/almosi/supermarket',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const AlmosiDirectionScreen(
            direction: StoreDirection.supermarket,
          ),
        ),
      ),
      GoRoute(
        path: '/almosi/clothes',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const AlmosiDirectionScreen(
            direction: StoreDirection.clothes,
          ),
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
        path: '/profile/phone',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const PhoneChangeScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/connect',
        pageBuilder: (context, state) =>
            PaykMotion.buildPage(state: state, child: const ConnectScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            PaykMotion.buildPage(state: state, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/profile/settings',
        redirect: (context, state) => '/settings',
      ),
      GoRoute(
        path: '/sizes',
        pageBuilder: (context, state) =>
            PaykMotion.buildPage(state: state, child: const SizesScreen()),
      ),
      GoRoute(
        path: '/size-offers',
        pageBuilder: (context, state) {
          final focus = int.tryParse(state.uri.queryParameters['focus'] ?? '');
          return PaykMotion.buildPage(
            state: state,
            child: SizeOffersScreen(focusOfferId: focus),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => PaykMotion.buildPage(
          state: state,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/messages',
        redirect: (context, state) => '/notifications',
      ),

      // Главная, категории, PAYK для бизнеса, друзья, профиль.
      // Код кассы открывается с главной и не занимает центр меню.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => PaykShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (context, state) => const CategoriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payk',
                builder: (context, state) => const PaykBusinessScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/friends',
                builder: (context, state) => const FriendsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
