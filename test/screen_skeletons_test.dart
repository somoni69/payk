import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/core/widgets/screen_skeletons.dart';
import 'package:payk/core/widgets/shimmer.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/home/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSkeleton(WidgetTester tester, Widget skeleton) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: PaykTheme.light,
        home: Scaffold(body: skeleton),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SkeletonBox), findsWidgets);
  }

  testWidgets('skeletons follow the real screen blocks', (tester) async {
    await pumpSkeleton(tester, const HomeSkeleton());
    await pumpSkeleton(tester, const ProfileSkeleton());
    await pumpSkeleton(tester, const ProfileDetailsSkeleton());
    await pumpSkeleton(tester, const HistorySkeleton());
    await pumpSkeleton(tester, const FriendsSkeleton());
    await pumpSkeleton(tester, const PaykBusinessSkeleton());
    await pumpSkeleton(tester, const NotificationsSkeleton());
    await pumpSkeleton(tester, const RulesSkeleton());
    await pumpSkeleton(tester, const SettingsSkeleton());
    await pumpSkeleton(tester, const ConnectSkeleton());
    await pumpSkeleton(tester, const CodeSkeleton());
    await tester.pumpWidget(const MaterialApp(home: RegisterSkeleton()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('home stays on its skeleton while the account loads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meProvider.overrideWith((ref) => Completer<Account>().future),
        ],
        child: MaterialApp(theme: PaykTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(HomeSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
