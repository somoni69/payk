import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payk/app/router.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/splash_screen.dart';
import 'package:payk/features/categories/categories_screen.dart';

void main() {
  testWidgets(
    'Fresh install navigates to onboarding after splash without redirect loop',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => _FreshSessionController()),
          splashFinishedProvider.overrideWith(() => _FinishedSplashGate()),
        ],
      );

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Verify errorBuilder was NOT triggered
      expect(find.text("Страница не найдена"), findsNothing);
      // Verify we are at onboarding
      expect(router.state.matchedLocation, equals('/onboarding'));
    },
  );

  testWidgets('User with completed onboarding navigates to /auth/phone', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _OnboardingSeenSessionController()),
        splashFinishedProvider.overrideWith(() => _FinishedSplashGate()),
      ],
    );

    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("Страница не найдена"), findsNothing);
    expect(router.state.matchedLocation, equals('/auth/phone'));
  });

  testWidgets(
    'Logging in transitions router from /auth/code to /home without showing onboarding or splash',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => _LoginTestSessionController()),
          splashFinishedProvider.overrideWith(() => _FinishedSplashGate()),
          meProvider.overrideWith((ref) => _fakeAccount),
        ],
      );

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      router.go('/auth/code');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/auth/code'));

      final controller = container.read(
        sessionProvider.notifier,
      ) as _LoginTestSessionController;
      controller.login();
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/home'));
      expect(find.text("Страница не найдена"), findsNothing);
    },
  );

  testWidgets(
    '4-tab Payk / UDC Shell routes (/home, /categories, /friends, /profile) work as expected',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => _LoggedInSessionController()),
          splashFinishedProvider.overrideWith(() => _FinishedSplashGate()),
          meProvider.overrideWith((ref) => _fakeAccount),
          historyProvider.overrideWith((ref) => const []),
          friendsProvider.overrideWith(
            (ref) => const FriendsInfo(
              code: 'TEST',
              levels: [0.05, 0.02],
              months: 6,
              countL1: 0,
              countL2: 0,
              total: 0,
              month: 0,
              invitees: [],
            ),
          ),
        ],
      );

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Initially at /home
      expect(router.state.matchedLocation, equals('/home'));
      expect(find.bySemanticsLabel('Главная'), findsOneWidget);
      expect(find.bySemanticsLabel('Категории'), findsOneWidget);
      expect(find.bySemanticsLabel('PAYK для бизнеса'), findsOneWidget);
      expect(find.bySemanticsLabel('Друзья'), findsOneWidget);
      expect(find.bySemanticsLabel('Профиль'), findsOneWidget);

      // 2. Navigate to /categories
      router.go('/categories');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/categories'));
      expect(find.byType(CategoriesScreen), findsOneWidget);
      expect(
        find.textContaining('Категори', skipOffstage: false),
        findsWidgets,
      );
      expect(find.text("Страница не найдена"), findsNothing);

      // 3. Navigate to /friends
      router.go('/friends');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/friends'));
      expect(find.text("Страница не найдена"), findsNothing);

      // 4. Navigate to /profile
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/profile'));
      expect(find.text("Страница не найдена"), findsNothing);
    },
  );

  testWidgets(
    'Push routes (/code, /history, /notifications, /rules) remain accessible',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => _LoggedInSessionController()),
          splashFinishedProvider.overrideWith(() => _FinishedSplashGate()),
          meProvider.overrideWith((ref) => _fakeAccount),
          historyProvider.overrideWith((ref) => const []),
          messagesProvider.overrideWith((ref) => const []),
          friendsProvider.overrideWith(
            (ref) => const FriendsInfo(
              code: 'TEST',
              levels: [0.05, 0.02],
              months: 6,
              countL1: 0,
              countL2: 0,
              total: 0,
              month: 0,
              invitees: [],
            ),
          ),
          rulesProvider.overrideWith(
            (ref) => const RulesInfo(
              thresholds: [],
              statuses: [],
              referralLevels: [0.05, 0.02],
              months: 6,
            ),
          ),
        ],
      );

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      router.push('/history');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/history'));
      expect(find.text("Страница не найдена"), findsNothing);

      router.push('/notifications');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/notifications'));
      expect(find.text("Страница не найдена"), findsNothing);

      router.push('/rules');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/rules'));
      expect(find.text("Страница не найдена"), findsNothing);

      // Dispose widget tree to cleanly cancel any timers
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

class _FreshSessionController extends SessionController {
  @override
  SessionState build() =>
      const SessionState(ready: true, onboardingSeen: false);
}

class _OnboardingSeenSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(ready: true, onboardingSeen: true);
}

class _LoggedInSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
    ready: true,
    onboardingSeen: true,
    accessToken: 'token_123',
    refreshToken: 'refresh_123',
  );
}

class _LoginTestSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
    ready: true,
    onboardingSeen: true,
    pendingPhone: '+992900000000',
  );

  void login() {
    state = state.copyWith(
      ready: true,
      accessToken: 'token_123',
      refreshToken: 'refresh_123',
      onboardingSeen: true,
      clearPhone: true,
    );
  }
}

class _FinishedSplashGate extends SplashGate {
  @override
  bool build() => true;
}

const _fakeAccount = Account(
  member: Member(
    firstName: 'Тест',
    lastName: 'Тестов',
    phone: '+992900000000',
    referralCode: 'TEST12',
  ),
  wallet: Wallet(
    status: 1,
    balance: 100,
    onHold: 0,
    debt: 0,
    spendMonth: 50,
    spendSupermarket: 30,
    spendClothes: 20,
    daysLeft: 15,
    keep: null,
    up: null,
    nextMonthStatus: 1,
    rates: ProgramRates(
      supermarket: Rate(earn: 0.03, burnCap: 0.5),
      clothes: Rate(earn: 0.05, burnCap: 0.5),
    ),
    todaySupermarket: 0,
    todayClothes: 0,
  ),
  store: 'Тестовый магазин',
  programEnabled: true,
);
