import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:payk/core/motion/payk_motion.dart';
import 'package:payk/core/theme/payk_colors.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/friends/friends_screen.dart';
import 'package:payk/features/home/home_header.dart';
import 'package:payk/features/home/home_screen.dart';

void main() {
  group('PaykMotion Design Tokens & Emil Kowalski Laws', () {
    test('UI durations stay strictly below 300ms ceiling', () {
      expect(PaykMotion.pressDown.inMilliseconds, lessThan(300));
      expect(PaykMotion.pressUp.inMilliseconds, lessThan(300));
      expect(PaykMotion.micro.inMilliseconds, lessThan(300));
      expect(PaykMotion.fast.inMilliseconds, lessThan(300));
      expect(PaykMotion.normal.inMilliseconds, lessThan(300));
      expect(PaykMotion.page.inMilliseconds, lessThan(300));
      expect(PaykMotion.pageReverse.inMilliseconds, lessThan(300));
      expect(PaykMotion.pageReverse.inMilliseconds, lessThan(PaykMotion.page.inMilliseconds));
    });

    test('Scale tokens never animate from 0', () {
      expect(PaykMotion.entranceScale, greaterThanOrEqualTo(0.95));
      expect(PaykMotion.scaleSubtle, greaterThan(0.95));
      expect(PaykMotion.scaleButton, greaterThan(0.95));
      expect(PaykMotion.scaleIcon, greaterThan(0.90));
    });
  });

  group('PaykMotion Accessibility (Reduced Motion Gate)', () {
    testWidgets('returns zero duration when disableAnimations is active', (tester) async {
      late Duration resolved;
      late bool reduced;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = PaykMotion.shouldReduceMotion(context);
              resolved = PaykMotion.duration(context, PaykMotion.page);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduced, isTrue);
      expect(resolved, Duration.zero);
    });

    testWidgets('returns standard duration when animations are enabled', (tester) async {
      late Duration resolved;
      late bool reduced;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              reduced = PaykMotion.shouldReduceMotion(context);
              resolved = PaykMotion.duration(context, PaykMotion.page);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduced, isFalse);
      expect(resolved, PaykMotion.page);
    });
  });

  group('PaykPressable Tactile Feedback & Interruptibility', () {
    testWidgets('scales down on pointer down and restores on pointer up without blocking child tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PaykPressable(
                scaleDown: 0.95,
                child: ElevatedButton(
                  onPressed: () => tapped = true,
                  child: const Text('Tap Me'),
                ),
              ),
            ),
          ),
        ),
      );

      Transform transformWidget() => tester.widget<Transform>(
            find.descendant(
              of: find.byType(PaykPressable),
              matching: find.byType(Transform),
            ),
          );

      expect(transformWidget().transform.storage[0], closeTo(1.0, 0.0001));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Tap Me')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      expect(transformWidget().transform.storage[0], closeTo(0.95, 0.005));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(transformWidget().transform.storage[0], closeTo(1.0, 0.0001));
      expect(tapped, isTrue);
    });

    testWidgets('cancels press scale when finger drags past scroll threshold', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PaykPressable(
                scaleDown: 0.95,
                child: SizedBox(width: 120, height: 60, child: Text('Card')),
              ),
            ),
          ),
        ),
      );

      Transform transformWidget() => tester.widget<Transform>(
            find.descendant(
              of: find.byType(PaykPressable),
              matching: find.byType(Transform),
            ),
          );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Card')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(transformWidget().transform.storage[0], closeTo(0.95, 0.005));

      // Drag 30px vertically (> 18px scroll slop)
      await gesture.moveBy(const Offset(0, 30));
      await tester.pumpAndSettle();

      expect(transformWidget().transform.storage[0], closeTo(1.0, 0.0001));
      await gesture.up();
    });
  });

  group('PaykMotion Navigation Helpers', () {
    testWidgets('PaykMotion.push navigates via GoRouter when available', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => PaykMotion.buildFadeScalePage(
              state: state,
              child: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => PaykMotion.push(context, '/details'),
                    child: const Text('Open Details'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/details',
            pageBuilder: (context, state) => PaykMotion.buildPage(
              state: state,
              child: const Scaffold(body: Center(child: Text('Details Screen'))),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      expect(find.text('Details Screen'), findsOneWidget);
    });

    testWidgets('PaykMotion.push falls back to PaykMotion.route in standalone MaterialApp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => PaykMotion.push(
                    context,
                    '/standalone',
                    fallback: () => const Scaffold(body: Center(child: Text('Fallback Screen'))),
                  ),
                  child: const Text('Open Fallback'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Fallback'));
      await tester.pumpAndSettle();

      expect(find.text('Fallback Screen'), findsOneWidget);
    });
  });

  group('iOS BouncingScrollPhysics Overscroll Bleed Guard (App Store)', () {
    const mockAccount = Account(
      member: Member(
        firstName: 'SOMONI',
        lastName: 'SOMONI',
        phone: '+992900000000',
        referralCode: 'SO-4654',
      ),
      wallet: Wallet(
        status: 1,
        balance: 0,
        onHold: 0,
        debt: 0,
        spendMonth: 0,
        spendSupermarket: 0,
        spendClothes: 0,
        daysLeft: 20,
        keep: null,
        up: null,
        nextMonthStatus: 1,
        rates: ProgramRates(
          supermarket: Rate(earn: 0.02, burnCap: 0.01),
          clothes: Rate(earn: 0.05, burnCap: 0.10),
        ),
        todaySupermarket: 0,
        todayClothes: 0,
      ),
      store: 'Payk',
      programEnabled: true,
    );

    testWidgets('HomeHeader gradient bleed covers top of screen during 200px pull-down overscroll', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meProvider.overrideWith((ref) => mockAccount),
          ],
          child: const MaterialApp(
            home: Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();

      final bleedFinder = find.descendant(
        of: find.byType(HomeHeader),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).gradient == PaykColors.headerGradient &&
              (w.decoration as BoxDecoration).shape == BoxShape.rectangle,
        ),
      );
      expect(bleedFinder, findsOneWidget);
      final rect = tester.getRect(bleedFinder);
      expect(rect.top, lessThanOrEqualTo(0.0));
      expect(rect.bottom, greaterThan(150.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('FriendsScreen hero gradient bleed covers top of screen during 200px pull-down overscroll', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meProvider.overrideWith((ref) => mockAccount),
            friendsProvider.overrideWith(
              (ref) => const FriendsInfo(
                code: 'SO-4654',
                link: 'https://payk.tj/r/SO-4654',
                levels: [0.01, 0.01],
                months: 12,
                countL1: 0,
                countL2: 0,
                total: 0,
                month: 0,
                invitees: [],
              ),
            ),
          ],
          child: const MaterialApp(
            home: FriendsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();

      final bleedFinder = find.descendant(
        of: find.byType(FriendsScreen),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).gradient == PaykColors.headerGradient,
        ),
      );
      expect(bleedFinder, findsOneWidget);
      final rect = tester.getRect(bleedFinder);
      expect(rect.top, lessThanOrEqualTo(0.0));
      expect(rect.bottom, greaterThan(150.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
