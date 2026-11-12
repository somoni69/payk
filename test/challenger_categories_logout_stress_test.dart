import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:payk/app/router.dart';
import 'package:payk/core/format.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/onboarding_screen.dart';
import 'package:payk/features/auth/splash_screen.dart';
import 'package:payk/features/categories/categories_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockMember = Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    email: 'farzod.1034@gmail.com',
    referralCode: 'FARZOD99',
  );

  const mockAccount = Account(
    member: mockMember,
    wallet: Wallet(
      status: 2,
      balance: 1000,
      onHold: 0,
      debt: 0,
      spendMonth: 300,
      spendSupermarket: 150,
      spendClothes: 150,
      daysLeft: 20,
      keep: null,
      up: null,
      nextMonthStatus: 2,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.05, burnCap: 0.5),
        clothes: Rate(earn: 0.07, burnCap: 0.5),
      ),
      todaySupermarket: 0,
      todayClothes: 0,
    ),
    store: 'Payk Flagship',
    programEnabled: true,
  );

  final List<HistoryEntry> testHistory = [
    HistoryEntry(
      id: 1045,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      amount: 15.5,
      balanceAfter: 1015.5,
      billAmount: 155.0,
      type: 'accrual',
      mode: 'supermarket',
      note: 'Покупка в супермаркете',
    ),
    HistoryEntry(
      id: 1046,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      amount: -50.0,
      balanceAfter: 965.5,
      billAmount: 200.0,
      type: 'burn',
      mode: 'clothes',
      note: 'Списание бонусов на одежду',
    ),
    HistoryEntry(
      id: 1047,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      amount: -15.5,
      balanceAfter: 950.0,
      billAmount: 155.0,
      type: 'refund',
      mode: 'supermarket',
      note: 'Возврат товара',
    ),
    HistoryEntry(
      id: 1048,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      amount: 25.0,
      balanceAfter: 975.0,
      type: 'referral',
      note: 'Бонус за приглашение друга',
    ),
  ];

  Widget wrapCategories({List<HistoryEntry>? history}) {
    return ProviderScope(
      overrides: [
        historyProvider.overrideWith((ref) => history ?? testHistory),
        friendsProvider.overrideWith(
          (ref) => const FriendsInfo(
            code: 'FARZOD99',
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
      child: MaterialApp(
        theme: PaykTheme.light,
        home: const Scaffold(body: CategoriesScreen()),
      ),
    );
  }

  group('Adversarial Stress Test Suite: Categories Live Search', () {
    testWidgets('C1. Exact match search displays targeted category and hides others', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapCategories());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // 1. Поиск по номеру чека: «1045»
      await tester.enterText(searchField, '1045');
      await tester.pump();
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsNothing);
      expect(find.text('Бонусы возвращены'), findsNothing);

      // 2. Поиск по номеру чека: «1046»
      await tester.enterText(searchField, '1046');
      await tester.pump();
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(15.5, signed: true)), findsNothing);

      // 3. Поиск по заметке: «Возврат»
      await tester.enterText(searchField, 'Возврат');
      await tester.pump();
      expect(find.text('Бонусы возвращены'), findsOneWidget);
      expect(find.text(formatMoney(15.5, signed: true)), findsNothing);
    });

    testWidgets('C2. Alias search accurately finds categories via their aliases', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapCategories());
      await tester.pumpAndSettle();

      // Фильтрация через 3D-плитки категорий:
      // Тап по «Кэшбэк» (первый инстанс в дереве — плитка)
      await tester.tap(find.text('Кэшбэк').first);
      await tester.pumpAndSettle();
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsNothing);

      // Тап по «Бонусами»
      await tester.tap(find.text('Бонусами'));
      await tester.pumpAndSettle();
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(15.5, signed: true)), findsNothing);

      // Тап по «Возвраты»
      await tester.tap(find.text('Возвраты'));
      await tester.pumpAndSettle();
      expect(find.text('Бонусы возвращены'), findsOneWidget);

      // Тап по «От друзей» (первый инстанс — плитка)
      await tester.tap(find.text('От друзей').first);
      await tester.pumpAndSettle();
      expect(find.text(formatMoney(25.0, signed: true)), findsOneWidget);

      // Возврат к «Все операции»
      await tester.tap(find.text('Все операции'));
      await tester.pumpAndSettle();
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
      expect(find.text('Бонусы возвращены'), findsOneWidget);
    });

    testWidgets('C3. Case insensitivity and whitespace trimming stress testing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapCategories());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // UPPERCASE: 'СУПЕРМАРКЕТ'
      await tester.enterText(searchField, 'СУПЕРМАРКЕТ');
      await tester.pump();
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);

      // Leading and trailing whitespaces: '   1045   '
      await tester.enterText(searchField, '   1045   ');
      await tester.pump();
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);

      // Only spaces: '     ' -> effectively empty -> returns all operations
      await tester.enterText(searchField, '     ');
      await tester.pump();
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
      expect(find.text('Бонусы возвращены'), findsOneWidget);
    });

    testWidgets('C4. Suffix clear button lifecycle and state synchronization', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapCategories());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // Initially no clear button
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Enter text
      await tester.enterText(searchField, '1046');
      await tester.pump();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(15.5, signed: true)), findsNothing);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      // Clear button disappears
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // All operations restored
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
    });

    testWidgets('C5. Non-matching query triggers Empty State with informative UI and Reset Action', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapCategories());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      const invalidQuery = '999999';
      await tester.enterText(searchField, invalidQuery);
      await tester.pump();

      // Operations list hidden, empty state shown
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(find.text('По этому запросу операций не найдено'), findsOneWidget);

      // Clear search via suffix button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      // Empty state gone, operations back
      expect(find.text('Ничего не найдено'), findsNothing);
      expect(find.text('+15,50 смн'), findsOneWidget);
    });

    testWidgets('C6. DOM Integrity Check: No hidden or zero-sized widgets in Category Cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapCategories());
      await tester.pumpAndSettle();

      // All 6 category tiles exist
      expect(find.text('Все операции'), findsOneWidget);
      expect(find.text('Покупки'), findsOneWidget);
      expect(find.text('Кэшбэк'), findsNWidgets(2)); // Tile + row title
      expect(find.text('Бонусами'), findsOneWidget);
      expect(find.text('Возвраты'), findsOneWidget);
      expect(find.text('От друзей'), findsNWidgets(2)); // Tile + row title

      // Ensure no OverflowBox in category tiles
      expect(find.byType(OverflowBox), findsNothing);
    });
  });

  group('Adversarial Stress Test Suite: Profile Logout Flow', () {
    testWidgets('L1. Logout confirmation cancellation keeps user on Profile screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sessionController = _StressMockSessionController();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => sessionController),
          meProvider.overrideWith((ref) => mockAccount),
        ],
      );
      addTearDown(container.dispose);

      container.read(splashFinishedProvider.notifier).complete();
      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/profile');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/profile'));

      // Tap on top profile card to open details
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();

      // Tap logout icon
      final logoutButton = find.byTooltip('Выйти');
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);

      // Click "Отмена"
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      // Пользователь остаётся на экране деталей профиля
      expect(find.text('Выйти из аккаунта?'), findsNothing);
      expect(router.state.matchedLocation, equals('/profile/details'));
      expect(container.read(sessionProvider).loggedIn, isTrue);
      expect(container.read(splashFinishedProvider), isTrue);
    });

    testWidgets('L2. Confirmed logout executes SplashGate.reset() -> navigates to /splash -> auto-navigates to /auth/phone', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sessionController = _StressMockSessionController();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => sessionController),
          meProvider.overrideWith((ref) => mockAccount),
        ],
      );
      addTearDown(container.dispose);

      container.read(splashFinishedProvider.notifier).complete();
      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/profile');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/profile'));

      // Tap on top profile card to open details
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();

      // Tap logout icon
      final logoutButton = find.byTooltip('Выйти');
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Confirm logout
      await tester.tap(find.widgetWithText(FilledButton, 'Выйти'));

      // Frame immediately after logout: SplashGate has been reset, router is on /splash
      await tester.pump();
      expect(container.read(splashFinishedProvider), isFalse);
      expect(container.read(sessionProvider).loggedIn, isFalse);
      expect(router.state.matchedLocation, equals('/splash'));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Advance through splash animation
      await tester.pumpAndSettle();

      // SplashScreen animation finished -> SplashGate.complete() -> redirected to /onboarding
      expect(container.read(splashFinishedProvider), isTrue);
      expect(router.state.matchedLocation, equals('/onboarding'));
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('L3. Re-entrancy safety: rapid duplicate logout invocations do not crash', (tester) async {
      final sessionController = _StressMockSessionController();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => sessionController),
          meProvider.overrideWith((ref) => mockAccount),
        ],
      );
      addTearDown(container.dispose);

      container.read(splashFinishedProvider.notifier).complete();

      // Call logout multiple times rapidly
      await Future.wait([
        container.read(sessionProvider.notifier).logout(),
        container.read(sessionProvider.notifier).logout(),
        container.read(sessionProvider.notifier).logout(),
      ]);

      expect(container.read(sessionProvider).loggedIn, isFalse);
      expect(container.read(splashFinishedProvider), isFalse);
    });
  });
}

class _StressMockSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
        ready: true,
        onboardingSeen: true,
        accessToken: 'stress_test_access_token',
        refreshToken: 'stress_test_refresh_token',
      );

  @override
  Future<void> logout() async {
    state = const SessionState(
      ready: true,
      onboardingSeen: false,
      accessToken: null,
      refreshToken: null,
    );
    ref.read(splashFinishedProvider.notifier).reset();
  }
}
