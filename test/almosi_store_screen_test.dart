import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/home/loyalty_card.dart';
import 'package:payk/features/store/almosi_store_screen.dart';

class _TestLocaleController extends LocaleController {
  _TestLocaleController(this.initial);
  final String initial;

  @override
  String build() => initial;
}

const _sampleRules = RulesInfo(
  thresholds: [1800, 4000, 10000, 18000],
  statuses: [
    TierRule(
      level: 1,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.02, burnCap: 0.01),
        clothes: Rate(earn: 0.05, burnCap: 0.10),
      ),
    ),
    TierRule(
      level: 2,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.035, burnCap: 0.015),
        clothes: Rate(earn: 0.10, burnCap: 0.15),
      ),
    ),
    TierRule(
      level: 3,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.05, burnCap: 0.02),
        clothes: Rate(earn: 0.15, burnCap: 0.20),
      ),
    ),
    TierRule(
      level: 4,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.065, burnCap: 0.025),
        clothes: Rate(earn: 0.20, burnCap: 0.25),
      ),
    ),
    TierRule(
      level: 5,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.08, burnCap: 0.03),
        clothes: Rate(earn: 0.25, burnCap: 0.35),
      ),
    ),
  ],
  referralLevels: [0.01, 0.01],
  months: 12,
);

Account _account({
  int status = 2,
  int nextMonthStatus = 1,
  double balance = 120,
  double spendMonth = 950,
  double spendSm = 400,
  double spendCl = 550,
  KeepInfo? keep = const KeepInfo(gap: 850, perDay: 61, kept: false),
  UpInfo? up = const UpInfo(
    level: 3,
    threshold: 4000,
    gap: 3050,
    perDay: 218,
    rates: ProgramRates(
      supermarket: Rate(earn: 0.05, burnCap: 0.02),
      clothes: Rate(earn: 0.15, burnCap: 0.20),
    ),
  ),
}) {
  return Account(
    member: const Member(
      id: 1,
      firstName: 'Наджибулло',
      lastName: 'Сатторов',
      phone: '+992900000000',
      referralCode: 'NA-5470',
    ),
    wallet: Wallet(
      status: status,
      balance: balance,
      onHold: 0,
      debt: 0,
      spendMonth: spendMonth,
      spendSupermarket: spendSm,
      spendClothes: spendCl,
      daysLeft: 14,
      keep: keep,
      up: up,
      nextMonthStatus: nextMonthStatus,
      rates: const ProgramRates(
        supermarket: Rate(earn: 0.035, burnCap: 0.015),
        clothes: Rate(earn: 0.10, burnCap: 0.15),
      ),
      todaySupermarket: 0,
      todayClothes: 0,
    ),
    store: 'MSX Алмоси',
    programEnabled: true,
  );
}

void main() {
  Widget wrap(Widget child, {Account? account, String locale = 'ru'}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => _TestLocaleController(locale)),
        meProvider.overrideWith((ref) => account ?? _account()),
        rulesProvider.overrideWith((ref) => _sampleRules),
      ],
      child: MaterialApp(
        theme: PaykTheme.light,
        home: child,
      ),
    );
  }

  testWidgets(
    'LoyaltyCard shows Магазин and Алмоси without overflow at 320px and 1.25x scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final acc = _account(status: 1, nextMonthStatus: 1, keep: null);
      await tester.pumpWidget(
        MaterialApp(
          theme: PaykTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: LoyaltyCard(
                  member: acc.member,
                  wallet: acc.wallet,
                  locale: 'ru',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('МАГАЗИН'), findsOneWidget);
      expect(find.text('Алмоси'), findsOneWidget);
      expect(find.text('ПАЙК'), findsNothing);
      expect(find.text('Стандарт'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'HomeScreen shows Almosi store card and growth hint, navigates to store directions and details',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrap(const Scaffold(body: HomeScreen())));
      await tester.pumpAndSettle();

      // Главная: карточка с «МАГАЗИН», «Алмоси» и компактная подсказка роста статуса
      expect(find.text('МАГАЗИН'), findsOneWidget);
      expect(find.text('Алмоси'), findsOneWidget);
      expect(
        find.text('До статуса «Голд» осталось купить на 3 050 смн'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Чтобы сохранить Силвер, купите ещё на 850 смн'),
        findsOneWidget,
      );

      // Нажимаем на карточку «Алмоси» -> экран магазина с подсказкой и двумя направлениями
      await tester.tap(find.text('Алмоси'));
      await tester.pumpAndSettle();

      expect(find.text('Магазин «Алмоси»'), findsOneWidget);
      expect(
        find.text('До статуса «Голд» осталось купить на 3 050 смн'),
        findsOneWidget,
      );
      expect(
        find.textContaining('может повышаться или снижаться'),
        findsOneWidget,
      );
      expect(find.text('Супермаркет'), findsOneWidget);
      expect(find.text('Продуктовый магазин'), findsOneWidget);
      expect(find.text('Одежда'), findsOneWidget);
      expect(find.text('Магазин одежды и обуви'), findsOneWidget);

      // Заходим в «Супермаркет» -> статус, начисление, списание, все статусы для СМ
      await tester.tap(find.byKey(const ValueKey('direction-supermarket')));
      await tester.pumpAndSettle();

      expect(find.text('Ваш текущий статус'), findsOneWidget);
      expect(find.text('Силвер'), findsWidgets);
      expect(find.text('3,5%'), findsWidgets);
      expect(find.text('до 1,5%'), findsOneWidget);
      final earnRect = tester.getRect(
        find.ancestor(
          of: find.text('Начисление кэшбэка'),
          matching: find.byType(Container),
        ).first,
      );
      final burnRect = tester.getRect(
        find.ancestor(
          of: find.text('Списание бонусами'),
          matching: find.byType(Container),
        ).first,
      );
      expect(earnRect.top, burnRect.top);
      expect(earnRect.height, burnRect.height);
      expect(find.text('Принципы начисления кэшбэка'), findsOneWidget);
      expect(find.text('Принципы списания (снятия) кэшбэка'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Показать код для кассы'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Условия по всем статусам'), findsOneWidget);
      expect(find.text('Текущий'), findsOneWidget);
      expect(find.text('Показать код для кассы'), findsOneWidget);

      // Возвращаемся и заходим в «Одежда»
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('direction-clothes')));
      await tester.pumpAndSettle();

      expect(find.text('Магазин одежды и обуви'), findsOneWidget);
      expect(find.text('10%'), findsWidgets);
      expect(find.text('до 15%'), findsOneWidget);
      expect(find.text('Принципы начисления кэшбэка'), findsOneWidget);
      expect(find.text('Принципы списания (снятия) кэшбэка'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Almosi store flow renders correctly in Tajik locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(const AlmosiStoreScreen(), locale: 'tj'));
    await tester.pumpAndSettle();

    expect(find.text('Мағозаи «Алмоси»'), findsOneWidget);
    expect(
      find.text('То статуси «Голд» боз ба 3 050 смн харид мондааст'),
      findsOneWidget,
    );
    expect(find.text('Мағозаи хӯрокворӣ'), findsOneWidget);
    expect(find.text('Мағозаи либос ва пойафзол'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('direction-clothes')));
    await tester.pumpAndSettle();

    expect(find.text('Статуси ҷории шумо'), findsOneWidget);
    expect(find.text('Қоидаҳои ҷамъшавии кэшбэк'), findsOneWidget);
    expect(find.text('Қоидаҳои харҷи (гирифтани) кэшбэк'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ҷорӣ'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ҷорӣ'), findsOneWidget);
  });
}
