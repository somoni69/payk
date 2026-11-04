import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payk/app/router.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/onboarding_screen.dart';
import 'package:payk/features/auth/splash_screen.dart';

void main() {
  group('SplashGate Unit & Contract Tests', () {
    test('SplashGate initial state is false and complete() turns it to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(splashFinishedProvider), isFalse);

      final gate = container.read(splashFinishedProvider.notifier);
      gate.complete();
      expect(container.read(splashFinishedProvider), isTrue);
      expect(gate.introDone, isTrue);
    });

    test('SplashGate.reset() reverts state back to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final gate = container.read(splashFinishedProvider.notifier);
      gate.complete();
      expect(container.read(splashFinishedProvider), isTrue);

      // Trigger reset
      gate.reset();
      expect(container.read(splashFinishedProvider), isFalse);
      expect(gate.introDone, isFalse);
    });

    test('SplashGate state updates notify reactive listeners', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final history = <bool>[];
      container.listen<bool>(
        splashFinishedProvider,
        (prev, next) => history.add(next),
        fireImmediately: true,
      );

      final gate = container.read(splashFinishedProvider.notifier);
      gate.complete();
      gate.reset();
      gate.complete();

      expect(history, equals([false, true, false, true]));
    });
  });

  group('Logout & Splash Screen Flow (Feature 8 / R4)', () {
    Widget buildApp(ProviderContainer container) {
      final router = container.read(routerProvider);
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('Logging out resets SplashGate, navigates to /splash, and then to /auth/phone', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sessionController = _TestSessionController();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => sessionController),
          meProvider.overrideWith((ref) => _fakeAccount),
        ],
      );
      addTearDown(container.dispose);

      // Initially complete splash and login
      container.read(splashFinishedProvider.notifier).complete();
      final router = container.read(routerProvider);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      // User starts at /home as authenticated
      expect(router.state.matchedLocation, equals('/home'));

      // Navigate to /profile
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/profile'));

      // Trigger logout flow:
      // 1. Reset splash gate (SplashGate.reset())
      // 2. Clear tokens and session
      container.read(splashFinishedProvider.notifier).reset();
      sessionController.performLogout();
      // Pump initial frame to trigger router redirect to /splash before animation finishes
      await tester.pump();

      // Router must redirect to /splash while introDone is false
      expect(router.state.matchedLocation, equals('/splash'));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Pump through splash animation to completion
      await tester.pumpAndSettle();

      // SplashScreen animation completion calls complete(), redirecting to /onboarding (Option 2)
      expect(router.state.matchedLocation, equals('/onboarding'));
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Страница не найдена'), findsNothing);
    });

    testWidgets('Unauthenticated user cannot access protected routes after logout', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sessionController = _TestSessionController();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => sessionController),
          meProvider.overrideWith((ref) => _fakeAccount),
        ],
      );
      addTearDown(container.dispose);

      container.read(splashFinishedProvider.notifier).complete();
      final router = container.read(routerProvider);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      // Perform logout and settle splash
      container.read(splashFinishedProvider.notifier).reset();
      sessionController.performLogout();
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/onboarding'));

      // Attempt unauthorized navigation to /home, /categories, /profile
      router.go('/home');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/onboarding'));

      router.go('/categories');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/onboarding'));

      router.go('/profile');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/onboarding'));
    });
  });
}

class _TestSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
        ready: true,
        onboardingSeen: true,
        accessToken: 'valid_jwt_token',
        refreshToken: 'valid_refresh_token',
      );

  void performLogout() {
    state = const SessionState(
      ready: true,
      onboardingSeen: false,
      accessToken: null,
      refreshToken: null,
    );
  }
}

const _fakeAccount = Account(
  member: Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    referralCode: 'FARZOD',
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
  store: 'Payk Store',
  programEnabled: true,
);
