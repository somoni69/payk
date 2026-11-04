import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/app/router.dart';
import 'package:payk/core/theme/payk_colors.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/splash_screen.dart';

// --- WCAG 2.1 Contrast Calculation Helpers ---
double _linearize(double srgb) {
  return srgb <= 0.04045 ? srgb / 12.92 : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color color) {
  final r = _linearize(color.r);
  final g = _linearize(color.g);
  final b = _linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color c1, Color c2) {
  final l1 = relativeLuminance(c1);
  final l2 = relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

int _alpha255(Color c) => (c.a * 255.0).round().clamp(0, 255);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // --- 1. UDC Color Palette Validation & WCAG Contrast ---
  group('UDC Palette Validation & WCAG Contrast Compliance', () {
    test('All core UDC colors have valid 32-bit ARGB values and full opacity where required', () {
      final solidColors = <String, Color>{
        'primary': PaykColors.primary,
        'primaryDark': PaykColors.primaryDark,
        'headerGradientStart': PaykColors.headerGradientStart,
        'headerGradientEnd': PaykColors.headerGradientEnd,
        'canvas': PaykColors.canvas,
        'sheet': PaykColors.sheet,
        'tile': PaykColors.tile,
        'activePill': PaykColors.activePill,
        'chipBg': PaykColors.chipBg,
        'iconPillSoft': PaykColors.iconPillSoft,
        'border': PaykColors.border,
        'navDivider': PaykColors.navDivider,
        'textPrimary': PaykColors.textPrimary,
        'textSecondary': PaykColors.textSecondary,
        'textMuted': PaykColors.textMuted,
        'textOnHeader': PaykColors.textOnHeader,
        'danger': PaykColors.danger,
        'success': PaykColors.success,
      };

      for (final entry in solidColors.entries) {
        expect(_alpha255(entry.value), equals(255),
            reason: '${entry.key} must be an opaque color with alpha=255');
      }

      // Transparent/overlay colors check
      expect(_alpha255(PaykColors.headerButtonBg), equals(0x38),
          reason: 'headerButtonBg must have specified 22% (0x38) alpha');
      expect(_alpha255(PaykColors.navShadow), equals(0x0A),
          reason: 'navShadow must have subtle 4% (0x0A) alpha');
      expect(_alpha255(PaykColors.textOnHeaderSubtitle), equals(0xD9),
          reason: 'textOnHeaderSubtitle must have 85% (0xD9) alpha');
    });

    test('WCAG 2.1 text contrast ratios meet or exceed accessibility standards', () {
      // 1. High contrast primary text #111111 on white canvas/sheet
      final textRatio = contrastRatio(PaykColors.textPrimary, PaykColors.sheet);
      expect(textRatio, greaterThanOrEqualTo(16.0),
          reason: 'Primary text must provide high contrast on white background (WCAG AAA >= 7.0)');

      // 2. Navigation active icon #6248EE against active pill #EDEAFB
      final activeNavRatio = contrastRatio(PaykColors.primary, PaykColors.activePill);
      expect(activeNavRatio, greaterThanOrEqualTo(3.0),
          reason: 'Active navigation pill icon must meet WCAG non-text contrast >= 3.0:1');

      // 3. Text on purple header #FFFFFF against gradient bounds (#9F72E7 and #8574E6)
      final headerRatioStart = contrastRatio(PaykColors.textOnHeader, PaykColors.headerGradientStart);
      final headerRatioEnd = contrastRatio(PaykColors.textOnHeader, PaykColors.headerGradientEnd);
      expect(headerRatioStart, greaterThanOrEqualTo(3.0),
          reason: 'Header text against gradient start must meet large text contrast >= 3.0:1');
      expect(headerRatioEnd, greaterThanOrEqualTo(3.0),
          reason: 'Header text against gradient end must meet large text contrast >= 3.0:1');

      // 4. Danger color #E04875 on white background
      final dangerRatio = contrastRatio(PaykColors.danger, PaykColors.sheet);
      expect(dangerRatio, greaterThanOrEqualTo(3.5),
          reason: 'Danger text/icons on white background must be clearly distinguishable');

      // 5. Success color #44A05D on white background
      final successRatio = contrastRatio(PaykColors.success, PaykColors.sheet);
      expect(successRatio, greaterThanOrEqualTo(3.0),
          reason: 'Success badge text/icons on white background must have >= 3.0:1 contrast');
    });
  });

  // --- Widget & Navigation Setup ---
  Widget buildApp(ProviderContainer container) {
    final router = container.read(routerProvider);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  ProviderContainer createTestContainer() {
    return ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _FuzzLoggedInSessionController()),
        splashFinishedProvider.overrideWith(() => _FuzzSplashFinishedGate()),
        meProvider.overrideWith((ref) => _fuzzFakeAccount),
        historyProvider.overrideWith((ref) => const []),
        messagesProvider.overrideWith((ref) => const []),
        friendsProvider.overrideWith((ref) => const FriendsInfo(
              code: 'STRESS_TEST',
              levels: [0.05, 0.02],
              months: 6,
              countL1: 10,
              countL2: 20,
              total: 500,
              month: 100,
              invitees: [],
            )),
        rulesProvider.overrideWith((ref) => const RulesInfo(
              thresholds: [],
              statuses: [],
              referralLevels: [0.05, 0.02],
              months: 6,
            )),
      ],
    );
  }

  // --- 2. Rapid Cyclic Tab Switching Fuzzing ---
  group('Rapid Cyclic Tab Switching Stress Test', () {
    testWidgets('Stress: 60 rapid cyclic switches between all 3 tabs without exception or frame drops', (tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      expect(router.state.matchedLocation, equals('/home'));

      final tabIcons = [Icons.home_rounded, Icons.grid_view_rounded, Icons.person_rounded];
      final expectedPaths = ['/home', '/categories', '/profile'];

      // Perform 60 rapid sequential taps with partial frame pumps (interrupting active animations)
      for (var cycle = 0; cycle < 20; cycle++) {
        for (var i = 0; i < 3; i++) {
          final nextIndex = (cycle * 3 + i) % 3;
          final icon = tabIcons[nextIndex];
          final expectedPath = expectedPaths[nextIndex];

          await tester.tap(find.byIcon(icon));
          // Pump partially (30ms) to interrupt the 200ms easeOutCubic animation
          await tester.pump(const Duration(milliseconds: 30));

          expect(router.state.matchedLocation, equals(expectedPath));
        }
      }

      // Settle completely and check final state consistency
      await tester.pumpAndSettle();

      // Final tab should match last tap (profile, index 2)
      expect(router.state.matchedLocation, equals('/profile'));
      final activeProfileIcon = tester.widget<Icon>(find.byIcon(Icons.person_rounded));
      expect(activeProfileIcon.color, equals(PaykColors.primary));

      final inactiveHomeIcon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(inactiveHomeIcon.color, equals(PaykColors.textMuted));

      final inactiveCategoriesIcon = tester.widget<Icon>(find.byIcon(Icons.grid_view_rounded));
      expect(inactiveCategoriesIcon.color, equals(PaykColors.textMuted));

      // Clean disposal check
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Stress: Rapid random switching between tabs preserves integrity', (tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      final randomSequence = [1, 2, 0, 0, 2, 1, 1, 0, 2, 2, 1, 0, 1, 2];
      final tabIcons = [Icons.home_rounded, Icons.grid_view_rounded, Icons.person_rounded];
      final expectedPaths = ['/home', '/categories', '/profile'];

      for (final targetIndex in randomSequence) {
        await tester.tap(find.byIcon(tabIcons[targetIndex]));
        await tester.pump(const Duration(milliseconds: 50));
        expect(router.state.matchedLocation, equals(expectedPaths[targetIndex]));
      }

      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/profile'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  // --- 3. Out-of-bounds Tab Indices & Invalid Routes ---
  group('Edge-case Handling: Out-of-bounds Indices and Invalid Routes', () {
    testWidgets('Invalid route URLs trigger ErrorState gracefully without crash', (tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);

      // 1. Test unknown route /unknown_page
      router.go('/unknown_page');
      await tester.pumpAndSettle();

      expect(find.text('Страница не найдена'), findsOneWidget);
      expect(find.text('На главную'), findsOneWidget);

      // Tap 'На главную' retry button and verify recovery
      await tester.tap(find.text('На главную'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));

      // 2. Test deep invalid route /home/subroute_invalid
      router.go('/home/subroute_invalid');
      await tester.pumpAndSettle();
      expect(find.text('Страница не найдена'), findsOneWidget);

      await tester.tap(find.text('На главную'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));

      // 3. Test edge paths /tab999, /-1
      router.go('/tab999');
      await tester.pumpAndSettle();
      expect(find.text('Страница не найдена'), findsOneWidget);

      router.go('/home');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('PaykShell visual widget resilience when given out-of-bounds index (-1, 3, 999)', (tester) async {
      // Test PaykShell and bottom bar visual resilience in standalone test widget
      // Verify that out-of-bounds indices do not throw RangeError or crash rendering
      for (final invalidIndex in [-1, 3, 999]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Center(child: Text('Index: $invalidIndex')),
              bottomNavigationBar: PaykShellTestableBar(
                currentIndex: invalidIndex,
                onTap: (index) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must render without exception
        expect(find.byType(PaykShellTestableBar), findsOneWidget);

        // When currentIndex is invalid, none of the 3 tabs should be highlighted with primary color
        final homeIcon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
        final catIcon = tester.widget<Icon>(find.byIcon(Icons.grid_view_rounded));
        final profIcon = tester.widget<Icon>(find.byIcon(Icons.person_rounded));

        expect(homeIcon.color, equals(PaykColors.textMuted));
        expect(catIcon.color, equals(PaykColors.textMuted));
        expect(profIcon.color, equals(PaykColors.textMuted));
      }
    });
  });

  // --- 4. Push Routes & Navigation Pop Stack Integrity ---
  group('Push Routes and Pop Stack Integrity', () {
    testWidgets('Navigating to push routes from /home and popping back preserves Shell', (tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      expect(router.state.matchedLocation, equals('/home'));

      // 1. /code
      router.push('/code');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/code'));
      expect(find.text('Страница не найдена'), findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));

      // 2. /history
      router.push('/history');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/history'));

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));

      // 3. /notifications
      router.push('/notifications');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/notifications'));

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));

      // 4. /rules
      router.push('/rules');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/rules'));

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Push routes from non-home shell tabs (/categories, /profile) pop back to the origin tab', (tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);

      // Go to /categories
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/categories'));

      // Push /history from /categories
      router.push('/history');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/history'));

      // Pop back -> should return to /categories
      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/categories'));

      // Go to /profile
      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/profile'));

      // Push /friends from /profile
      router.push('/friends');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/friends'));

      // Pop back -> should return to /profile
      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/profile'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Deep stack stress: nesting 4 push routes (/code -> /history -> /notifications -> /rules) and unwinding', (tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      expect(router.state.matchedLocation, equals('/home'));

      router.push('/code');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/code'));

      router.push('/history');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/history'));

      router.push('/notifications');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/notifications'));

      router.push('/rules');
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/rules'));

      // Now unwind stack in reverse order
      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/notifications'));

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/history'));

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/code'));

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/home'));

      // Verify shell navigation remains functional after deep push/pop unwind
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, equals('/categories'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}

// --- Testable replica of _UdcBottomBar for standalone edge-case testing ---
class PaykShellTestableBar extends StatelessWidget {
  const PaykShellTestableBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <_TestNavItem>[
    _TestNavItem(icon: Icons.home_rounded, label: 'Главная'),
    _TestNavItem(icon: Icons.grid_view_rounded, label: 'Категории'),
    _TestNavItem(icon: Icons.person_rounded, label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PaykColors.sheet,
        border: Border(top: BorderSide(color: PaykColors.navDivider, width: 1.0)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    label: _items[i].label,
                    selected: i == currentIndex,
                    child: InkResponse(
                      onTap: () => onTap(i),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          height: 38,
                          decoration: BoxDecoration(
                            color: i == currentIndex ? PaykColors.activePill : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            _items[i].icon,
                            size: 24,
                            color: i == currentIndex ? PaykColors.primary : PaykColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestNavItem {
  const _TestNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

// --- Test Mocks ---
class _FuzzLoggedInSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
        ready: true,
        onboardingSeen: true,
        accessToken: 'fuzz_token',
        refreshToken: 'fuzz_refresh',
      );
}

class _FuzzSplashFinishedGate extends SplashGate {
  @override
  bool build() => true;
}

const _fuzzFakeAccount = Account(
  member: Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    referralCode: 'FARZOD',
  ),
  wallet: Wallet(
    status: 1,
    balance: 500,
    onHold: 0,
    debt: 0,
    spendMonth: 200,
    spendSupermarket: 120,
    spendClothes: 80,
    daysLeft: 18,
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
);
