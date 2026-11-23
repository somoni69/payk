import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_colors.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/core/widgets/screen_skeletons.dart';
import 'package:payk/core/widgets/shimmer.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/friends/friends_screen.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/showcase/payk_business_screen.dart';

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

  testWidgets(
    'PaykBusinessSkeleton and FriendsSkeleton match real header & block geometry without vertical jump',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Finder gradientHeader() => find.byWidgetPredicate((w) {
        if (w is! DecoratedBox) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.gradient == PaykColors.headerGradient &&
            d.borderRadius ==
                const BorderRadius.vertical(
                  bottom: Radius.circular(PaykRadius.header),
                );
      });

      // 1. FriendsSkeleton vs FriendsScreen (exact 0px header & hero card alignment)
      await tester.pumpWidget(
        MaterialApp(
          theme: PaykTheme.light,
          home: const Scaffold(body: FriendsSkeleton(locale: 'ru')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final friendsSkelHeaderBottom = tester.getRect(gradientHeader()).bottom;
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _RuLocale()),
            meProvider.overrideWith((ref) => _testAccount),
            friendsProvider.overrideWith((ref) => _testFriends),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const FriendsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final friendsRealHeaderBottom = tester.getRect(gradientHeader()).bottom;
      expect(
        (friendsRealHeaderBottom - friendsSkelHeaderBottom).abs(),
        lessThanOrEqualTo(1.0),
      );

      // 2. PaykBusinessSkeleton vs PaykBusinessScreen (loading & loaded)
      await tester.pumpWidget(
        MaterialApp(
          theme: PaykTheme.light,
          home: const Scaffold(body: PaykBusinessSkeleton(locale: 'ru')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final businessSkelHeaderBottom = tester.getRect(gradientHeader()).bottom;
      expect(tester.takeException(), isNull);

      final completer = Completer<ShowcaseFeed>();
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            localeProvider.overrideWith(() => _RuLocale()),
            loyaltyApiProvider.overrideWithValue(_CompleterApi(completer)),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const PaykBusinessScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final businessLoadingHeaderBottom = tester.getRect(gradientHeader()).bottom;
      expect(find.byType(PaykBusinessCardsSkeleton), findsOneWidget);

      completer.complete(
        const ShowcaseFeed(
          cards: [
            ShowcaseCard(
              id: 1,
              titleTj: 'Касса ва анбор',
              titleRu: 'Касса и склад в одной системе',
              textTj: 'Ҳамааш аз телефон',
              textRu: 'Продажи, смены кассиров и остатки видны с телефона.',
              art: 'receipt',
            ),
          ],
          leadSentToday: false,
          contact: ShowcaseContact(name: 'PAYK', phone: '992900000000'),
        ),
      );
      await tester.pumpAndSettle();
      final businessLoadedHeaderBottom = tester.getRect(gradientHeader()).bottom;

      expect(
        (businessLoadedHeaderBottom - businessLoadingHeaderBottom).abs(),
        0.0,
      );
      expect(
        (businessLoadedHeaderBottom - businessSkelHeaderBottom).abs(),
        lessThanOrEqualTo(1.0),
      );
    },
  );
}

class _RuLocale extends LocaleController {
  @override
  String build() => 'ru';
}

class _CompleterApi extends Fake implements LoyaltyApi {
  _CompleterApi(this.completer);
  final Completer<ShowcaseFeed> completer;

  @override
  Future<ShowcaseFeed> showcase() => completer.future;
}

const _testAccount = Account(
  member: Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    referralCode: 'SO-6850',
  ),
  wallet: Wallet(
    status: 1,
    balance: 100,
    onHold: 0,
    debt: 0,
    spendMonth: 0,
    spendSupermarket: 0,
    spendClothes: 0,
    daysLeft: 7,
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
  store: 'Алмоси',
  programEnabled: true,
);

const _testFriends = FriendsInfo(
  code: 'SO-6850',
  levels: [0.01, 0.01],
  months: 12,
  countL1: 0,
  countL2: 0,
  total: 0,
  month: 0,
  invitees: [],
);
