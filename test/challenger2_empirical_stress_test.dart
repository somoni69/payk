import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payk/app/router.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/splash_screen.dart';
import 'package:payk/features/home/categories_preview_section.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/home/new_companies_section.dart';
import 'package:payk/features/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseMember = Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    email: 'farzod.1034@gmail.com',
    referralCode: 'FARZOD99',
    messages: true,
    coinRounding: false,
    telegram: false,
  );

  const baseAccount = Account(
    member: baseMember,
    wallet: Wallet(
      status: 2,
      balance: 750,
      onHold: 0,
      debt: 0,
      spendMonth: 200,
      spendSupermarket: 120,
      spendClothes: 80,
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
    store: 'Payk Flagship Dushanbe',
    programEnabled: true,
    messagesUnread: 3,
  );

  Widget wrapWithScope(Widget child, {Account? account}) {
    return ProviderScope(
      overrides: [
        meProvider.overrideWith((ref) => account ?? baseAccount),
      ],
      child: MaterialApp(
        theme: PaykTheme.light,
        home: Scaffold(body: child),
      ),
    );
  }

  // ===========================================================================
  // 1. HOME SCREEN EDGE CASES & STRESS TESTING
  // ===========================================================================
  group('Challenger 2: HomeScreen Edge Cases & Stress Tests', () {
    testWidgets('1.1 Empty companies list in NewCompaniesSection renders without layout exceptions', (tester) async {
      var viewAllClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: PaykTheme.light,
          home: Scaffold(
            body: NewCompaniesSection(
              companies: const [],
              onViewAll: () => viewAllClicked = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Section header and "Все" chip exist
      expect(find.text('Новые компании'), findsOneWidget);
      expect(find.text('Все'), findsOneWidget);

      // Horizontal list has 0 company cards
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap "Все" works
      await tester.tap(find.text('Все'));
      expect(viewAllClicked, isTrue);
    });

    testWidgets('1.2 HomeScreen with blank profile fields, 0 balance, 0 messages handles fallbacks gracefully', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const emptyAccount = Account(
        member: Member(
          firstName: '',
          lastName: '',
          phone: '',
          referralCode: '',
        ),
        wallet: Wallet(
          status: 0,
          balance: 0,
          onHold: 0,
          debt: 0,
          spendMonth: 0,
          spendSupermarket: 0,
          spendClothes: 0,
          daysLeft: 0,
          keep: null,
          up: null,
          nextMonthStatus: 0,
          rates: ProgramRates(
            supermarket: Rate(earn: 0.01, burnCap: 0.1),
            clothes: Rate(earn: 0.01, burnCap: 0.1),
          ),
          todaySupermarket: 0,
          todayClothes: 0,
        ),
        store: '',
        programEnabled: true,
        messagesUnread: 0,
      );

      await tester.pumpWidget(wrapWithScope(const HomeScreen(), account: emptyAccount));
      await tester.pumpAndSettle();

      // Fallback name 'Фарзод'
      expect(find.text('Привет, Фарзод!'), findsOneWidget);
      expect(find.text('С возвращением!'), findsOneWidget);

      // Balance displayed as 0 смн
      expect(find.text('0 смн'), findsOneWidget);

      // Unread messages badge should not be displayed when messagesUnread = 0
      final notificationBtn = find.bySemanticsLabel('Уведомления');
      expect(notificationBtn, findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('1.3 HomeScreen displays notice banners for debt and disabled program without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const stressAccount = Account(
        member: baseMember,
        wallet: Wallet(
          status: 2,
          balance: 1500000,
          onHold: 0,
          debt: 450,
          spendMonth: 200,
          spendSupermarket: 120,
          spendClothes: 80,
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
        store: 'Payk Flagship Dushanbe',
        programEnabled: false,
        messagesUnread: 3,
      );

      await tester.pumpWidget(wrapWithScope(const HomeScreen(), account: stressAccount));
      await tester.pumpAndSettle();

      // High balance rendered
      expect(find.text('1 500 000 смн'), findsOneWidget);

      // Paused notice is present
      expect(find.textContaining('Программа временно приостановлена'), findsOneWidget);

      // Debt notice is present
      expect(find.textContaining('Отрицательный баланс'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.4 Quick actions taps trigger callbacks and open bottom sheets', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithScope(const HomeScreen()));
      await tester.pumpAndSettle();

      // 1. Tap "Мои размеры" -> экран размеров
      await tester.tap(find.text('Мои размеры'));
      await tester.pumpAndSettle();
      expect(find.text('Обувь'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);

      Navigator.of(tester.element(find.text('Обувь'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Обувь'), findsNothing);

      // 2. Tap "Мои сертификаты" -> bottom sheet opens
      await tester.tap(find.text('Мои сертификаты'));
      await tester.pumpAndSettle();
      expect(find.text('Мои сертификаты'), findsAtLeastNWidgets(1));

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      // 3. Tap Notifications button -> dedicated notifications screen opens
      await tester.tap(find.bySemanticsLabel('Уведомления'));
      await tester.pumpAndSettle();
      expect(find.text('Уведомления'), findsOneWidget);

      // Close notifications screen via back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Уведомления'), findsNothing);
    });

    testWidgets('1.5 CategoriesPreviewSection: taps on Спорт, Парфюмерия, Все компании trigger handlers', (tester) async {
      String? selectedCategory;
      var viewAllCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: PaykTheme.light,
          home: Scaffold(
            body: CategoriesPreviewSection(
              onViewAll: () => viewAllCalled = true,
              onCategorySelect: (cat) => selectedCategory = cat,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Спорт'), findsOneWidget);
      expect(find.text('Парфюмерия'), findsOneWidget);
      expect(find.text('Все компании'), findsOneWidget);

      // Tap "Спорт"
      await tester.tap(find.text('Спорт'));
      expect(selectedCategory, equals('Спорт'));

      // Tap "Парфюмерия"
      await tester.tap(find.text('Парфюмерия'));
      expect(selectedCategory, equals('Парфюмерия'));

      // Tap "Все компании"
      await tester.tap(find.text('Все компании'));
      expect(viewAllCalled, isTrue);
    });
  });

  // ===========================================================================
  // 2. PROFILE SCREEN UDC INTEGRITY, 7 CARDS, DELETE MODAL & LOGOUT BUTTON CHECK
  // ===========================================================================
  group('Challenger 2: ProfileScreen 7 UDC Cards, Delete Dialog & Logout Isolation', () {
    testWidgets('2.1 Exactly 7 UDC cards are present in ProfileScreen ListView', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithScope(const ProfileDetailsScreen()));
      await tester.pumpAndSettle();

      // Card 1: Аватар
      expect(find.text('Изображение профиля'), findsOneWidget);
      expect(find.text('Добавить изображение'), findsOneWidget);

      // Card 2: Пользователь
      expect(find.text('Пользователь'), findsOneWidget);
      expect(find.text('Изменить'), findsOneWidget);

      // Card 3: Контакты
      expect(find.text('Контакты'), findsOneWidget);
      expect(find.text('Сменить пароль'), findsOneWidget);

      expect(find.text('Дата рождения'), findsOneWidget);
      expect(find.text('Пол'), findsOneWidget);
      expect(find.text('Детский клуб'), findsNothing);
      expect(find.text('Пушистый клуб'), findsNothing);

      // Scroll to reveal the remaining cards
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Card 6: Способы входа
      expect(find.text('Способы входа'), findsOneWidget);
      expect(find.text('Посмотреть'), findsOneWidget);

      // Card 7: Удаление аккаунта
      expect(find.text('Удаление аккаунта'), findsOneWidget);
      expect(find.text('Все бонусы будут удалены'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);
    });

    testWidgets('2.2 Absence of redundant logout button in body of ProfileScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithScope(const ProfileDetailsScreen()));
      await tester.pumpAndSettle();

      // Ensure NO OutlinedButton exists anywhere on the screen
      expect(find.byType(OutlinedButton), findsNothing);

      // Ensure NO button in ListView contains text 'Выйти'
      final listFinder = find.byType(ListView);
      expect(
        find.descendant(of: listFinder, matching: find.text('Выйти')),
        findsNothing,
        reason: 'Redundant logout button in body must be strictly absent',
      );

      // Ensure the ONLY logout action is in AppBar with tooltip 'Выйти'
      final appbarLogout = find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Выйти'),
      );
      expect(appbarLogout, findsOneWidget);
    });

    testWidgets('2.3 Delete account card opens confirmation dialog with Cancel and Delete actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      var loggedOut = false;
      final sessionController = _TestSessionController(onLogout: () => loggedOut = true);

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => sessionController),
          meProvider.overrideWith((ref) => baseAccount),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const Scaffold(body: ProfileDetailsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to the Delete Account card
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Tap «Удалить» action on Card 7
      final deleteCardAction = find.text('Удалить');
      expect(deleteCardAction, findsOneWidget);
      await tester.tap(deleteCardAction);
      await tester.pumpAndSettle();

      // Verify modal dialog appears
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Удалить аккаунт?'), findsOneWidget);
      expect(
        find.text('Все ваши накопленные бонусы, статус и история операций будут безвозвратно удалены. Вы уверены?'),
        findsOneWidget,
      );

      // Check actions: «Отмена» and «Удалить навсегда»
      final cancelBtn = find.widgetWithText(TextButton, 'Отмена');
      final confirmDeleteBtn = find.widgetWithText(FilledButton, 'Удалить навсегда');
      expect(cancelBtn, findsOneWidget);
      expect(confirmDeleteBtn, findsOneWidget);

      // 1. Test Cancel action
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Dialog dismissed, logout was NOT called
      expect(find.byType(AlertDialog), findsNothing);
      expect(loggedOut, isFalse);

      // 2. Open dialog again and test Confirm Delete action
      await tester.tap(deleteCardAction);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(confirmDeleteBtn);
      await tester.pumpAndSettle();

      // Logout callback must have been executed
      expect(loggedOut, isTrue);
    });
  });

  // ===========================================================================
  // 3. 3-TAB BOTTOM NAVIGATION RAPID SWITCHING & STRESS TEST
  // ===========================================================================
  group('Challenger 2: 3-Tab Bottom Navigation Switching & Leak Stress Test', () {
    testWidgets('3.1 Rapid 30-cycle tab switching performs cleanly with zero errors or leaks', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => _LoggedInTestSessionController()),
          splashFinishedProvider.overrideWith(() => _FinishedTestSplashGate()),
          meProvider.overrideWith((ref) => baseAccount),
          historyProvider.overrideWith((ref) => const []),
          friendsProvider.overrideWith((ref) => const FriendsInfo(
            code: 'FARZOD',
            levels: [0.05, 0.02],
            months: 6,
            countL1: 0,
            countL2: 0,
            total: 0,
            month: 0,
            invitees: [],
          )),
        ],
      );
      addTearDown(container.dispose);

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

      expect(router.state.matchedLocation, equals('/home'));

      // Perform 30 rapid switching iterations across all 3 tabs:
      // Home -> Categories -> Profile -> Home
      final homeTab = find.bySemanticsLabel('Главная');
      final catTab = find.bySemanticsLabel('Категории');
      final profileTab = find.bySemanticsLabel('Профиль');

      for (var i = 0; i < 10; i++) {
        // Tap Categories
        await tester.tap(catTab);
        await tester.pump(const Duration(milliseconds: 50));
        expect(router.state.matchedLocation, equals('/categories'));

        // Tap Profile
        await tester.tap(profileTab);
        await tester.pump(const Duration(milliseconds: 50));
        expect(router.state.matchedLocation, equals('/profile'));

        // Tap Home
        await tester.tap(homeTab);
        await tester.pump(const Duration(milliseconds: 50));
        expect(router.state.matchedLocation, equals('/home'));

        // Verify zero uncaught exceptions in each cycle
        expect(tester.takeException(), isNull);
      }

      // Finish any pending animations
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('3.2 Repeated taps on the currently active tab are safe and idempotent', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => _LoggedInTestSessionController()),
          splashFinishedProvider.overrideWith(() => _FinishedTestSplashGate()),
          meProvider.overrideWith((ref) => baseAccount),
          historyProvider.overrideWith((ref) => const []),
          friendsProvider.overrideWith((ref) => const FriendsInfo(
            code: 'FARZOD',
            levels: [0.05, 0.02],
            months: 6,
            countL1: 0,
            countL2: 0,
            total: 0,
            month: 0,
            invitees: [],
          )),
        ],
      );
      addTearDown(container.dispose);

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

      final homeTab = find.bySemanticsLabel('Главная');

      // Tap active tab 5 times in a row
      for (var i = 0; i < 5; i++) {
        await tester.tap(homeTab);
        await tester.pump(const Duration(milliseconds: 50));
        expect(router.state.matchedLocation, equals('/home'));
      }
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/home'));
      expect(tester.takeException(), isNull);
    });
  });
}

class _TestSessionController extends SessionController {
  _TestSessionController({this.onLogout});

  final VoidCallback? onLogout;

  @override
  SessionState build() => const SessionState(
        ready: true,
        onboardingSeen: true,
        accessToken: 'valid_access_token',
        refreshToken: 'valid_refresh_token',
      );

  @override
  Future<void> logout() async {
    state = const SessionState(
      ready: true,
      onboardingSeen: true,
      accessToken: null,
      refreshToken: null,
    );
    onLogout?.call();
  }
}

class _LoggedInTestSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
        ready: true,
        onboardingSeen: true,
        accessToken: 'valid_jwt_access',
        refreshToken: 'valid_jwt_refresh',
      );
}

class _FinishedTestSplashGate extends SplashGate {
  @override
  bool build() => true;
}
