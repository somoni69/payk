import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/api_exception.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/categories/categories_screen.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/profile/profile_screen.dart';

void main() {
  Widget wrapWithThemeAndScope(
    Widget child, {
    Account? account,
    Object? error,
    List<HistoryEntry>? history,
  }) {
    return ProviderScope(
      overrides: [
        if (error != null)
          meProvider.overrideWith((ref) => throw error)
        else
          meProvider.overrideWith((ref) => account ?? _mockAccount),
        historyProvider.overrideWith((ref) => history ?? const []),
      ],
      child: MaterialApp(
        theme: PaykTheme.light,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Categories & Search Screen Structure (UDC Feature 6 / R1)', () {
    testWidgets('Renders search input bar, categories header, and 6 3D category tiles', (tester) async {
      await tester.pumpWidget(wrapWithThemeAndScope(const CategoriesScreen()));
      await tester.pumpAndSettle();

      // Verify search input field exists with search icon
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Verify Section Title "Категории" / "Категорияҳо"
      expect(find.textContaining('Категори'), findsWidgets);

      // Verify 6 3D category tiles exist
      expect(find.textContaining('Все операции'), findsOneWidget);
      expect(find.textContaining('Покупки'), findsWidgets);
      expect(find.textContaining('Кэшбэк'), findsWidgets);
      expect(find.textContaining('Бонусами'), findsOneWidget);
      expect(find.textContaining('Возвраты'), findsOneWidget);
      expect(find.textContaining('От друзей'), findsWidgets);
    });

    testWidgets('Search input accepts user typing without errors', (tester) async {
      await tester.pumpWidget(wrapWithThemeAndScope(const CategoriesScreen()));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, '1045');
      await tester.pump();

      expect(find.text('1045'), findsOneWidget);
    });

    testWidgets('Renders empty state card with 3D receipt when operations list is empty', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithThemeAndScope(const CategoriesScreen()));
      await tester.pumpAndSettle();

      // Verify empty state text and 3D receipt illustration
      expect(find.text('Операций пока нет'), findsOneWidget);
      expect(find.textContaining('Покажите код кассиру'), findsOneWidget);
    });
  });

  group('Home Screen Structure & Data Binding (UDC Feature 5 / R1)', () {
    testWidgets('Renders user greeting and notifications button', (tester) async {
      await tester.pumpWidget(wrapWithThemeAndScope(const HomeScreen()));
      await tester.pumpAndSettle();

      // Verify personalized greeting containing user's name
      expect(find.textContaining('Фарзод'), findsOneWidget);

      // Verify notifications / messages action button is present
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });

    testWidgets('Displays error state with retry action when account loading fails', (tester) async {
      await tester.pumpWidget(
        wrapWithThemeAndScope(
          const HomeScreen(),
          error: ApiException(500, 'Сбой сети бэкенда'),
        ),
      );
      await tester.pumpAndSettle();

      // Error message must be rendered gracefully with retry button
      expect(find.text('Сбой сети бэкенда'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });
  });

  group('Profile Screen Structure & Actions (UDC Feature 7 / R1)', () {
    testWidgets('Renders user name, formatted phone and edit button', (tester) async {
      await tester.pumpWidget(wrapWithThemeAndScope(const ProfileDetailsScreen()));
      await tester.pumpAndSettle();

      // Verify user full name and phone number
      expect(find.text('Фарзод Сомони'), findsOneWidget);
      expect(find.text('+992 90 000 00 00'), findsAtLeastNWidgets(1));

      // Verify edit button is present
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('Renders logout button in AppBar and shows confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithThemeAndScope(const ProfileDetailsScreen()));
      await tester.pumpAndSettle();

      // Verify Logout button in AppBar exists with logout icon and tooltip 'Выйти'
      final logoutIcon = find.byIcon(Icons.logout_rounded);
      final logoutTooltip = find.byTooltip('Выйти');
      expect(logoutIcon, findsOneWidget);
      expect(logoutTooltip, findsOneWidget);

      // Tap logout action in AppBar
      await tester.tap(logoutTooltip);
      await tester.pumpAndSettle();

      // Verify confirmation dialog appears with title and confirm action
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Выйти'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
    });
  });
}

const _mockAccount = Account(
  member: Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    referralCode: 'FARZOD99',
    messages: true,
    coinRounding: false,
    telegram: false,
  ),
  wallet: Wallet(
    status: 1,
    balance: 500,
    onHold: 0,
    debt: 0,
    spendMonth: 150,
    spendSupermarket: 90,
    spendClothes: 60,
    daysLeft: 25,
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
  store: 'Payk Flagship',
  programEnabled: true,
  messagesUnread: 2,
);
