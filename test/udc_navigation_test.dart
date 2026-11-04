import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payk/app/router.dart';
import 'package:payk/core/theme/payk_colors.dart';
import 'package:payk/core/widgets/payk_shell.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/splash_screen.dart';

void main() {
  Widget buildTestApp(ProviderContainer container) {
    final router = container.read(routerProvider);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  ProviderContainer createLoggedInContainer() {
    return ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _LoggedInSessionController()),
        splashFinishedProvider.overrideWith(() => _FinishedSplashGate()),
        meProvider.overrideWith((ref) => _fakeAccount),
        friendsProvider.overrideWith((ref) => _fakeFriendsInfo),
        historyProvider.overrideWith((ref) => const []),
        rulesProvider.overrideWith((ref) => const RulesInfo(
          thresholds: [],
          statuses: [],
          referralLevels: [0.05, 0.02],
          months: 6,
        )),
      ],
    );
  }

  group('UDC 4-Tab Bottom App Bar & Shell Navigation', () {
    testWidgets('Renders exactly 4 navigation tabs with UDC icons and semantics', (tester) async {
      final container = createLoggedInContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestApp(container));
      await tester.pumpAndSettle();

      // Verify PaykShell is rendered
      expect(find.byType(PaykShell), findsOneWidget);

      // Verify the bar contains exactly 4 semantic items: 'Главная', 'Категории', 'Друзья', 'Профиль'
      expect(find.bySemanticsLabel('Главная'), findsOneWidget);
      expect(find.bySemanticsLabel('Категории'), findsOneWidget);
      expect(find.bySemanticsLabel('Друзья'), findsOneWidget);
      expect(find.bySemanticsLabel('Профиль'), findsOneWidget);

      // Verify the 4 specific UDC icons are present
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // Verify legacy 5-tab icons are NOT present
      expect(find.byIcon(Icons.receipt_long_outlined), findsNothing);
      expect(find.byIcon(Icons.group_outlined), findsNothing);
      expect(find.byIcon(Icons.qr_code_rounded), findsNothing);

      // Verify Liquid Glass: BackdropFilter is present inside floating navigation bar
      final shellFinder = find.byType(PaykShell);
      expect(
        find.descendant(of: shellFinder, matching: find.byType(BackdropFilter)),
        findsOneWidget,
        reason: 'Liquid Glass navigation bar uses BackdropFilter for real-time optical blur',
      );
    });

    testWidgets('Active tab displays lavender pill capsule and primary violet icon', (tester) async {
      final container = createLoggedInContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestApp(container));
      await tester.pumpAndSettle();

      // Default branch is 0: /home
      final router = container.read(routerProvider);
      expect(router.state.matchedLocation, equals('/home'));

      // Check Home icon color is primary purple (#6248EE)
      final homeIcon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(homeIcon.color, equals(PaykColors.primary));

      // Check Categories icon color is muted (#9FA1AE)
      final catIcon = tester.widget<Icon>(find.byIcon(Icons.grid_view_rounded));
      expect(catIcon.color, equals(PaykColors.textMuted));

      // Check Friends icon color is muted (#9FA1AE)
      final friendsIcon = tester.widget<Icon>(find.byIcon(Icons.people_alt_rounded));
      expect(friendsIcon.color, equals(PaykColors.textMuted));

      // Check Profile icon color is muted (#9FA1AE)
      final profIcon = tester.widget<Icon>(find.byIcon(Icons.person_rounded));
      expect(profIcon.color, equals(PaykColors.textMuted));

      // Check active container has PaykColors.activePill decoration
      final homePill = find.ancestor(
        of: find.byIcon(Icons.home_rounded),
        matching: find.byType(AnimatedContainer),
      );
      expect(homePill, findsOneWidget);
      final containerWidget = tester.widget<AnimatedContainer>(homePill);
      final boxDecoration = containerWidget.decoration as BoxDecoration?;
      expect(boxDecoration?.color, equals(PaykColors.activePill));
      expect(boxDecoration?.borderRadius, equals(BorderRadius.circular(18)));
    });

    testWidgets('Tapping "Категории" tab navigates to /categories branch with active pill', (tester) async {
      final container = createLoggedInContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      expect(router.state.matchedLocation, equals('/home'));

      // Tap on Categories tab
      await tester.tap(find.bySemanticsLabel('Категории'));
      await tester.pumpAndSettle();

      // Location must be /categories
      expect(router.state.matchedLocation, equals('/categories'));

      // Active icon should now be grid_view_rounded
      final catIcon = tester.widget<Icon>(find.byIcon(Icons.grid_view_rounded));
      expect(catIcon.color, equals(PaykColors.primary));

      // Home icon must become muted
      final homeIcon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(homeIcon.color, equals(PaykColors.textMuted));
    });

    testWidgets('Tapping "Друзья" tab navigates to /friends branch with active pill', (tester) async {
      final container = createLoggedInContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      expect(router.state.matchedLocation, equals('/home'));

      // Tap on Friends tab
      await tester.tap(find.bySemanticsLabel('Друзья'));
      await tester.pumpAndSettle();

      // Location must be /friends
      expect(router.state.matchedLocation, equals('/friends'));

      // Active icon should now be people_alt_rounded
      final friendsIcon = tester.widget<Icon>(find.byIcon(Icons.people_alt_rounded));
      expect(friendsIcon.color, equals(PaykColors.primary));

      // Home icon must become muted
      final homeIcon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(homeIcon.color, equals(PaykColors.textMuted));
    });

    testWidgets('Tapping "Профиль" tab navigates to /profile branch', (tester) async {
      final container = createLoggedInContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);

      // Tap on Profile tab
      await tester.tap(find.bySemanticsLabel('Профиль'));
      await tester.pumpAndSettle();

      // Location must be /profile
      expect(router.state.matchedLocation, equals('/profile'));

      // Active icon should now be person_rounded
      final profIcon = tester.widget<Icon>(find.byIcon(Icons.person_rounded));
      expect(profIcon.color, equals(PaykColors.primary));
    });

    testWidgets('Round-trip tab switching (/home -> /categories -> /friends -> /profile -> /home)', (tester) async {
      final container = createLoggedInContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildTestApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      expect(router.state.matchedLocation, equals('/home'));

      // 0 -> 1
      await tester.tap(find.bySemanticsLabel('Категории'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/categories'));

      // 1 -> 2
      await tester.tap(find.bySemanticsLabel('Друзья'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/friends'));

      // 2 -> 3
      await tester.tap(find.bySemanticsLabel('Профиль'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/profile'));

      // 3 -> 0
      await tester.tap(find.bySemanticsLabel('Главная'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));
    });
  });
}

class _LoggedInSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
        ready: true,
        onboardingSeen: true,
        accessToken: 'mock_access_jwt',
        refreshToken: 'mock_refresh_jwt',
      );
}

class _FinishedSplashGate extends SplashGate {
  @override
  bool build() => true;
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
    balance: 250,
    onHold: 0,
    debt: 0,
    spendMonth: 120,
    spendSupermarket: 70,
    spendClothes: 50,
    daysLeft: 20,
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

const _fakeFriendsInfo = FriendsInfo(
  code: 'FARZOD',
  levels: [0.05, 0.02],
  months: 6,
  countL1: 0,
  countL2: 0,
  total: 0,
  month: 0,
  invitees: [],
);
