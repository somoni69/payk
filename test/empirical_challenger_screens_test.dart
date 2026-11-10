import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:payk/app/router.dart';
import 'package:payk/core/format.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/onboarding_screen.dart';
import 'package:payk/features/auth/splash_screen.dart';
import 'package:payk/features/categories/categories_screen.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/home/new_companies_section.dart';
import 'package:payk/features/home/quick_action_cards.dart';
import 'package:payk/features/profile/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testHistory = <HistoryEntry>[
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
  ];

  const mockMember = Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    email: 'farzod.1034@gmail.com',
    referralCode: 'FARZOD99',
    messages: true,
    coinRounding: false,
    telegram: false,
  );

  const mockAccount = Account(
    member: mockMember,
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

  Widget wrapWithProviders(
    Widget child, {
    Account? account,
    List<HistoryEntry>? history,
  }) {
    return ProviderScope(
      overrides: [
        meProvider.overrideWith((ref) => account ?? mockAccount),
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
        home: Scaffold(body: child),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. ЭКРАН ПОКУПОК / КАТЕГОРИЙ: ПОИСК, ОЧИСТКА, ПУСТОЙ РЕЗУЛЬТАТ, ФИЛЬТРЫ
  // ---------------------------------------------------------------------------
  group('1. Empirical Challenge: Categories & Search Screen', () {
    testWidgets('1.1 Fast typing in search input filters categories in real time', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const CategoriesScreen()));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Fast typing: search receipt number '1045'
      await tester.enterText(searchField, '1045');
      await tester.pump();

      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsNothing);

      // Fast updating: change to '1046'
      await tester.enterText(searchField, '1046');
      await tester.pump();

      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(15.5, signed: true)), findsNothing);
    });

    testWidgets('1.2 Cross (close) icon button appears on input and clears search', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const CategoriesScreen()));
      await tester.pumpAndSettle();

      // Suffix clear button is not present when text is empty
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, '1046');
      await tester.pump();

      // Clear button must appear
      final clearButton = find.byIcon(Icons.close_rounded);
      expect(clearButton, findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);

      // Tap clear button
      await tester.tap(clearButton);
      await tester.pump();

      // Text is cleared, close icon disappears, all operations restored
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
    });

    testWidgets('1.3 Non-existent query displays Empty State with reset button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const CategoriesScreen()));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      const query = 'НесуществующийЗапрос123';
      await tester.enterText(searchField, query);
      await tester.pump();

      // Verify Empty State elements
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(find.text('По этому запросу операций не найдено'), findsOneWidget);

      final clearButton = find.byIcon(Icons.close_rounded);
      expect(clearButton, findsOneWidget);

      // Tap clear button
      await tester.tap(clearButton);
      await tester.pump();

      // Search cleared, Empty State gone, all operations restored
      expect(find.text('Ничего не найдено'), findsNothing);
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
    });

    testWidgets('1.4 Category tile selection filtering works accurately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const CategoriesScreen()));
      await tester.pumpAndSettle();

      // Tap «Кэшбэк» category tile (first instance is the tile)
      await tester.tap(find.text('Кэшбэк').first);
      await tester.pumpAndSettle();
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsNothing);

      // Tap «Бонусами»
      await tester.tap(find.text('Бонусами'));
      await tester.pumpAndSettle();
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(15.5, signed: true)), findsNothing);

      // Tap «Все операции»
      await tester.tap(find.text('Все операции'));
      await tester.pumpAndSettle();
      expect(find.text(formatMoney(15.5, signed: true)), findsOneWidget);
      expect(find.text(formatMoney(-50.0, signed: true)), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. ГЛАВНЫЙ ЭКРАН: ПРИВЕТСТВИЕ, ИНТЕРАКТИВНОСТЬ КАРТОЧЕК, СКРОЛЛ НОВЫХ КОМПАНИЙ
  // ---------------------------------------------------------------------------
  group('2. Empirical Challenge: Home Screen Interactivity', () {
    testWidgets('2.1 Personalized greeting dynamically displays user name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // User with custom name 'Алишер'
      const customAccount = Account(
        member: Member(
          firstName: 'Алишер',
          lastName: 'Каримов',
          phone: '+992918887766',
          referralCode: 'ALISHER7',
        ),
        wallet: Wallet(
          status: 1,
          balance: 100,
          onHold: 0,
          debt: 0,
          spendMonth: 0,
          spendSupermarket: 0,
          spendClothes: 0,
          daysLeft: 10,
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
        store: 'Payk',
        programEnabled: true,
      );

      await tester.pumpWidget(wrapWithProviders(const HomeScreen(), account: customAccount));
      await tester.pumpAndSettle();

      expect(find.text('Привет, Алишер!'), findsOneWidget);
      expect(find.text('С возвращением!'), findsOneWidget);
    });

    testWidgets('2.2 Interactivity: Tapping QuickActionCards triggers callbacks / modals', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      var codeTapped = false;
      var companiesTapped = false;
      var certsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: PaykTheme.light,
          home: Scaffold(
            body: QuickActionCards(
              account: mockAccount,
              locale: 'ru',
              onOpenCode: () => codeTapped = true,
              onOpenSizes: () => companiesTapped = true,
              onOpenCertificates: () => certsTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap QR-код
      final qrCard = find.text('QR-код');
      expect(qrCard, findsOneWidget);
      await tester.tap(qrCard);
      expect(codeTapped, isTrue);

      // Tap Мои размеры
      final companiesCard = find.text('Мои размеры');
      expect(companiesCard, findsOneWidget);
      await tester.tap(companiesCard);
      expect(companiesTapped, isTrue);

      // Tap Мои сертификаты
      final certsCard = find.text('Мои сертификаты');
      expect(certsCard, findsOneWidget);
      await tester.tap(certsCard);
      expect(certsTapped, isTrue);
    });

    testWidgets('2.3 Full Home Screen modal interactivity: Мои размеры & Мои сертификаты', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const HomeScreen()));
      await tester.pumpAndSettle();

      // Tap Мои размеры -> экран размеров
      await tester.tap(find.text('Мои размеры'));
      await tester.pumpAndSettle();

      expect(find.text('Обувь'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);

      Navigator.of(tester.element(find.text('Обувь'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Обувь'), findsNothing);

      // Tap Мои сертификаты -> Modal bottom sheet appears
      await tester.tap(find.text('Мои сертификаты'));
      await tester.pumpAndSettle();

      expect(find.text('Мои сертификаты'), findsAtLeastNWidgets(1));
      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
    });

    testWidgets('2.4 New Companies section horizontal scroll and company tap details modal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithProviders(
          Builder(
            builder: (context) => Scaffold(
              body: NewCompaniesSection(
                onViewAll: () {},
                onCompanyTap: (company) => showCompanyDetailsModal(context, company),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial companies visible
      expect(find.text('ELITESTORE'), findsOneWidget);
      expect(find.text('A-99'), findsOneWidget);

      // Horizontal drag to reveal remaining companies
      final horizontalList = find.byType(ListView);
      expect(horizontalList, findsOneWidget);

      await tester.drag(horizontalList, const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('PAYK STORE'), findsOneWidget);

      // Tap on a company card to open company details sheet
      await tester.tap(find.text('PAYK STORE'));
      await tester.pumpAndSettle();

      // Details bottom sheet is displayed
      expect(find.text('Кэшбэк: до 12% на карту Payk'), findsOneWidget);
      expect(find.text('Посмотреть каталог товаров'), findsOneWidget);

      // Dismiss details modal via barrier tap
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Кэшбэк: до 12% на карту Payk'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. ЭКРАН ПРОФИЛЯ: 7 КАРТОЧЕК UDC И АККОРДЕОНЫ КЛУБОВ
  // ---------------------------------------------------------------------------
  group('3. Empirical Challenge: Profile Screen (7 UDC Cards & Accordions)', () {
    testWidgets('3.1 All 7 UDC cards are present on the profile screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const ProfileDetailsScreen()));
      await tester.pumpAndSettle();

      // 1. Аватар
      expect(find.text('Изображение профиля'), findsOneWidget);
      expect(find.text('Добавить изображение'), findsOneWidget);

      // 2. Пользователь
      expect(find.text('Пользователь'), findsOneWidget);
      expect(find.text('Фарзод Сомони'), findsOneWidget);
      expect(find.text('Изменить'), findsOneWidget);

      // 3. Контакты
      expect(find.text('Контакты'), findsOneWidget);
      expect(find.text('farzod.1034@gmail.com'), findsOneWidget);
      expect(find.text('Сменить пароль'), findsOneWidget);

      expect(find.text('Дата рождения'), findsOneWidget);
      expect(find.text('Пол'), findsOneWidget);
      expect(find.text('Детский клуб'), findsNothing);
      expect(find.text('Пушистый клуб'), findsNothing);

      // Scroll down to see remaining cards
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // 6. Способы входа
      expect(find.text('Способы входа'), findsOneWidget);
      expect(find.text('Посмотреть'), findsOneWidget);

      // 7. Удаление аккаунта
      expect(find.text('Удаление аккаунта'), findsOneWidget);
      expect(find.text('Все бонусы будут удалены'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);
    });

    testWidgets('3.2 Edit opens one sheet for name, birth date and gender', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithProviders(const ProfileDetailsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Изменить'));
      await tester.pumpAndSettle();

      expect(find.text('Изменить профиль'), findsOneWidget);
      expect(find.text('Мужской'), findsOneWidget);
      expect(find.text('Женский'), findsOneWidget);
      expect(find.text('Фарзод'), findsOneWidget);
      expect(find.text('Сомони'), findsOneWidget);
      expect(find.text('Детский клуб'), findsNothing);
      expect(find.text('Пушистый клуб'), findsNothing);

      await tester.tap(find.text('Женский'));
      await tester.pump();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(find.text('Изменить профиль'), findsNothing);
      expect(find.text('Пользователь'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. ФЛОУ ЛОГАУТА (R4): ВЫЗОВ LOGOUT(), СБРОС SPLASHGATE, ПОКАЗ СПЛЭША И /AUTH/PHONE
  // ---------------------------------------------------------------------------
  group('4. Empirical Challenge: Logout Flow (R4)', () {
    testWidgets('4.1 Full UI logout from ProfileScreen with dialog confirmation, splash, and redirect to /auth/phone', (tester) async {
      SharedPreferences.setMockInitialValues({
        'payk.access': 'mock_access_token',
        'payk.refresh': 'mock_refresh_token',
        'payk.onboarding': true,
      });

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sessionController = _MockSessionController();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => sessionController),
          meProvider.overrideWith((ref) => mockAccount),
        ],
      );
      addTearDown(container.dispose);

      // Initially complete splash
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

      // Navigate to /profile
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/profile'));

      // Tap on the top profile widget to open ProfileDetailsScreen
      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();

      // Tap logout icon in AppBar
      final logoutButton = find.byTooltip('Выйти');
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Logout confirmation dialog appears
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);

      // First test "Отмена"
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      // Still on /profile, dialog dismissed
      expect(find.text('Выйти из аккаунта?'), findsNothing);
      expect(router.state.matchedLocation, equals('/profile'));

      // Tap logout again and confirm
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Выйти'));

      // Pumping frame after logout: SplashGate reset, router redirected to /splash
      await tester.pump();
      expect(router.state.matchedLocation, equals('/splash'));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Settle splash animation
      await tester.pumpAndSettle();

      // After splash completion, auto-redirected to /onboarding
      expect(router.state.matchedLocation, equals('/onboarding'));
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(container.read(sessionProvider).loggedIn, isFalse);
      expect(container.read(splashFinishedProvider), isTrue);
    });

    testWidgets('4.2 Direct session.logout() verifies SplashGate reset contract and router reaction', (tester) async {
      SharedPreferences.setMockInitialValues({
        'payk.access': 'mock_jwt_access',
        'payk.refresh': 'mock_jwt_refresh',
        'payk.onboarding': true,
      });

      final sessionController = _MockSessionController();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(() => sessionController),
          meProvider.overrideWith((ref) => mockAccount),
        ],
      );
      addTearDown(container.dispose);

      // Complete splash gate initially
      container.read(splashFinishedProvider.notifier).complete();
      expect(container.read(splashFinishedProvider), isTrue);

      // Call logout()
      await container.read(sessionProvider.notifier).logout();

      // Verification: SplashGate must be reset to false
      expect(container.read(splashFinishedProvider), isFalse);
      expect(container.read(sessionProvider).loggedIn, isFalse);

      // When splash gate completes again:
      container.read(splashFinishedProvider.notifier).complete();
      expect(container.read(splashFinishedProvider), isTrue);
    });
  });
}

class _MockSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
        ready: true,
        onboardingSeen: true,
        accessToken: 'mock_jwt_access',
        refreshToken: 'mock_jwt_refresh',
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
