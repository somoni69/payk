import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/core/widgets/payk_3d_icon.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/history/history_screen.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/profile/profile_screen.dart';
import 'package:payk/features/sizes/size_offers_screen.dart';
import 'package:payk/features/store/almosi_store_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestLocale extends LocaleController {
  @override
  String build() => 'ru';
}

Finder _findAsset(String path) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == path,
  );
}

Account _account({String? birthDate}) {
  return Account(
    member: Member(
      firstName: 'Фарзод',
      lastName: 'Сомони',
      phone: '+992900000000',
      referralCode: 'SO-4654',
      birthDate: birthDate,
      messages: true,
      telegram: false,
    ),
    wallet: const Wallet(
      status: 2,
      balance: 500,
      onHold: 0,
      debt: 0,
      spendMonth: 100,
      spendSupermarket: 60,
      spendClothes: 40,
      daysLeft: 20,
      keep: null,
      up: null,
      nextMonthStatus: 2,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.03, burnCap: 0.02),
        clothes: Rate(earn: 0.07, burnCap: 0.15),
      ),
      todaySupermarket: 0,
      todayClothes: 0,
    ),
    store: 'MSX Алмоси',
    programEnabled: true,
  );
}

void main() {
  Widget wrap(Widget child, Account account) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith(_TestLocale.new),
        meProvider.overrideWith((ref) => account),
        friendsProvider.overrideWith(
          (ref) => const FriendsInfo(
            code: 'SO-4654',
            levels: [0.01, 0.005],
            months: 12,
            countL1: 0,
            countL2: 0,
            total: 0,
            month: 0,
            invitees: [],
          ),
        ),
        historyProvider.overrideWith((ref) => const []),
      ],
      child: MaterialApp(theme: PaykTheme.light, home: child),
    );
  }

  testWidgets('Certificates modal renders ticket.webp when empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrap(const Scaffold(body: HomeScreen()), _account()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мои сертификаты'));
    await tester.pumpAndSettle();

    expect(find.text('Нет активных купонов'), findsOneWidget);
    expect(find.byType(Ticket3dIcon), findsOneWidget);
    expect(_findAsset(Ticket3dIcon.assetPath), findsOneWidget);
  });

  testWidgets('Certificates modal renders ticket.webp when gift coupon is active', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    final todayBirth =
        '1995-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await tester.pumpWidget(
      wrap(
        const Scaffold(body: HomeScreen()),
        _account(birthDate: todayBirth),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мои сертификаты'));
    await tester.pumpAndSettle();

    expect(find.text('Подарочный купон на ДР'), findsOneWidget);
    expect(find.byType(Ticket3dIcon), findsOneWidget);
    expect(_findAsset(Ticket3dIcon.assetPath), findsOneWidget);
  });

  testWidgets('My Store modal in ProfileScreen renders gem.webp', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(const ProfileScreen(), _account()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мой магазин'));
    await tester.pumpAndSettle();

    expect(find.text('Понятно'), findsOneWidget);
    expect(find.byType(Gem3dIcon), findsOneWidget);
    expect(_findAsset(Gem3dIcon.assetPath), findsOneWidget);
  });

  testWidgets('SettingsScreen renders language.webp, bell.webp and bags.webp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(const SettingsScreen(), _account()));
    await tester.pumpAndSettle();

    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('Покупки'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);
    expect(find.byIcon(Icons.language_rounded), findsNothing);
    expect(find.byType(Language3dIcon), findsOneWidget);
    expect(_findAsset(Language3dIcon.assetPath), findsOneWidget);
    expect(find.byType(Bell3dIcon), findsOneWidget);
    expect(_findAsset(Bell3dIcon.assetPath), findsOneWidget);
    expect(find.byType(Bags3dIcon), findsOneWidget);
    expect(_findAsset(Bags3dIcon.assetPath), findsOneWidget);
  });

  testWidgets('HomeScreen renders bell.webp, qr-code.webp and ruler.webp', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrap(const Scaffold(body: HomeScreen()), _account()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Bell3dIcon), findsOneWidget);
    expect(_findAsset(Bell3dIcon.assetPath), findsOneWidget);
    expect(find.byType(QrCode3dIcon), findsNWidgets(2));
    expect(_findAsset(QrCode3dIcon.assetPath), findsNWidgets(2));
    expect(find.byType(Ruler3dIcon), findsOneWidget);
    expect(_findAsset(Ruler3dIcon.assetPath), findsOneWidget);
    expect(find.text('Указать размеры'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AlmosiDirectionScreen renders cashback-plus.webp and cashback-minus.webp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWith(_TestLocale.new),
          meProvider.overrideWith((ref) => _account()),
          rulesProvider.overrideWith(
            (ref) => const RulesInfo(
              thresholds: [1800],
              statuses: [],
              referralLevels: [0.01],
              months: 12,
            ),
          ),
        ],
        child: MaterialApp(
          theme: PaykTheme.light,
          home: const AlmosiDirectionScreen(
            direction: StoreDirection.supermarket,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CashbackPlus3dIcon), findsOneWidget);
    expect(_findAsset(CashbackPlus3dIcon.assetPath), findsOneWidget);
    expect(find.byType(CashbackMinus3dIcon), findsOneWidget);
    expect(_findAsset(CashbackMinus3dIcon.assetPath), findsOneWidget);
  });

  testWidgets('ProfileScreen menu renders all eight 3D icons', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(const ProfileScreen(), _account()));
    await tester.pumpAndSettle();

    expect(_findAsset(Store3dIcon.assetPath), findsOneWidget);
    expect(_findAsset(MySizes3dIcon.assetPath), findsOneWidget);
    expect(_findAsset(MyReceipts3dIcon.assetPath), findsOneWidget);
    expect(_findAsset(SizeOffers3dIcon.assetPath), findsOneWidget);
    expect(_findAsset(StatusRules3dIcon.assetPath), findsOneWidget);
    expect(_findAsset(StoreContact3dIcon.assetPath), findsOneWidget);
    expect(_findAsset(AboutApp3dIcon.assetPath), findsOneWidget);
    expect(_findAsset(Gear3dIcon.assetPath), findsOneWidget);
  });

  testWidgets('SizeOffersScreen empty state renders ruler.webp', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWith(_TestLocale.new),
          meProvider.overrideWith((ref) => _account()),
          sizeOffersFeedProvider.overrideWith(_EmptySizeOffersFeed.new),
        ],
        child: MaterialApp(
          theme: PaykTheme.light,
          home: const SizeOffersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Ruler3dIcon), findsOneWidget);
    expect(_findAsset(Ruler3dIcon.assetPath), findsOneWidget);
  });

  testWidgets('HistoryScreen renders cashback-plus.webp and cashback-minus.webp on rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final entries = [
      HistoryEntry(
        id: 1,
        type: 'welcome',
        amount: 100,
        balanceAfter: 100,
        createdAt: DateTime(2026, 11, 23, 13, 0),
      ),
      HistoryEntry(
        id: 2,
        type: 'burn',
        amount: -25,
        balanceAfter: 75,
        createdAt: DateTime(2026, 11, 23, 13, 10),
      ),
      HistoryEntry(
        id: 3,
        type: 'custom_unknown',
        amount: 10,
        balanceAfter: 85,
        createdAt: DateTime(2026, 11, 23, 13, 20),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWith(_TestLocale.new),
          historyProvider.overrideWith((ref) => entries),
        ],
        child: MaterialApp(
          theme: PaykTheme.light,
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Подарок за регистрацию'), findsOneWidget);
    expect(find.text('Начисление бонусов'), findsOneWidget);
    expect(find.text('Операция'), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.byType(CashbackPlus3dIcon), findsNWidgets(2));
    expect(_findAsset(CashbackPlus3dIcon.assetPath), findsNWidgets(2));
    expect(find.byType(CashbackMinus3dIcon), findsOneWidget);
    expect(_findAsset(CashbackMinus3dIcon.assetPath), findsOneWidget);
  });
}

class _EmptySizeOffersFeed extends SizeOffersFeedNotifier {
  @override
  Future<SizeOffersResponse> build() async =>
      SizeOffersResponse(items: const [], serverNow: DateTime(2026, 11, 23));
}
