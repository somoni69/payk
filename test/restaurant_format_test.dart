import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:payk/core/birthday.dart';
import 'package:payk/core/formats.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/i18n/strings.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/code/client_code_screen.dart';
import 'package:payk/features/code/payment_card.dart';
import 'package:payk/features/history/history_screen.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/home/loyalty_card.dart';
import 'package:payk/features/rules/rules_screen.dart';
import 'package:payk/features/store/almosi_store_screen.dart';

class _TestLocale extends LocaleController {
  _TestLocale(this.value);
  final String value;

  @override
  String build() => value;
}

class _FakeApi extends Fake implements LoyaltyApi {
  String? lastFmt;
  List<ReceiptRow> rows = const [];

  @override
  Future<CashierCode> code({CodeChoice? choice}) async {
    return CashierCode(
      code: '123456',
      qr: 'PAYK:123456',
      ttl: 1800,
      spendPref: choice?.spend ?? SpendPref.earn,
      useCoupon: choice?.coupon ?? true,
    );
  }

  @override
  Future<PendingSnapshot> pending() async => const PendingSnapshot();

  @override
  Future<ReceiptsPage> receipts({
    int? beforeId,
    String? dFrom,
    String? dTo,
    String? fmt,
    String? q,
  }) async {
    lastFmt = fmt;
    return ReceiptsPage(
      header: null,
      months: const [],
      items: rows,
    );
  }
}

const _rulesWithRs = RulesInfo(
  thresholds: [1800, 4000, 10000, 18000],
  formats: ['SM', 'CL', 'RS'],
  statuses: [
    TierRule(
      level: 1,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.02, burnCap: 0.01),
        clothes: Rate(earn: 0.05, burnCap: 0.10),
        restaurant: Rate(earn: 0.07, burnCap: 0.10),
      ),
    ),
    TierRule(
      level: 2,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.035, burnCap: 0.015),
        clothes: Rate(earn: 0.10, burnCap: 0.15),
        restaurant: Rate(earn: 0.10, burnCap: 0.15),
      ),
    ),
    TierRule(
      level: 3,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.05, burnCap: 0.02),
        clothes: Rate(earn: 0.15, burnCap: 0.20),
        restaurant: Rate(earn: 0.15, burnCap: 0.20),
      ),
    ),
    TierRule(
      level: 4,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.065, burnCap: 0.025),
        clothes: Rate(earn: 0.20, burnCap: 0.25),
        restaurant: Rate(earn: 0.20, burnCap: 0.25),
      ),
    ),
    TierRule(
      level: 5,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.08, burnCap: 0.03),
        clothes: Rate(earn: 0.25, burnCap: 0.35),
        restaurant: Rate(earn: 0.25, burnCap: 0.30),
      ),
    ),
  ],
  referralLevels: [0.01, 0.01],
  months: 12,
  birthday: BirthdayRules(
    coupon: [20, 40, 80, 150, 250],
    minBillX: {'SM': 10, 'CL': 5, 'RS': 5},
    windowBefore: 7,
    windowAfter: 7,
  ),
);

Account _accountWithFormats({
  List<String>? formats = const ['SM', 'CL', 'RS'],
  BirthdayCoupon? coupon,
  double spendRs = 320,
}) {
  return Account(
    member: const Member(
      id: 7,
      firstName: 'Азиз',
      lastName: 'Рахимов',
      phone: '+992900000007',
      referralCode: 'AZ-7777',
      messages: true,
    ),
    wallet: Wallet(
      status: 1,
      balance: 240,
      onHold: 0,
      debt: 0,
      spendMonth: 820,
      spendSupermarket: 300,
      spendClothes: 200,
      spendRestaurant: spendRs,
      daysLeft: 12,
      keep: null,
      up: const UpInfo(
        level: 2,
        threshold: 1800,
        gap: 980,
        perDay: 82,
        rates: ProgramRates(
          supermarket: Rate(earn: 0.035, burnCap: 0.015),
          clothes: Rate(earn: 0.10, burnCap: 0.15),
          restaurant: Rate(earn: 0.10, burnCap: 0.15),
        ),
      ),
      nextMonthStatus: 1,
      rates: const ProgramRates(
        supermarket: Rate(earn: 0.02, burnCap: 0.01),
        clothes: Rate(earn: 0.05, burnCap: 0.10),
        restaurant: Rate(earn: 0.07, burnCap: 0.10),
      ),
      todaySupermarket: 0,
      todayClothes: 0,
      todayRestaurant: 70,
    ),
    store: 'MSX Алмоси',
    programEnabled: true,
    formats: formats,
    coupon: coupon,
  );
}

void main() {
  group('Formats helper & JSON parsing (b9c6f62)', () {
    test('usedFormats preserves SM, CL, RS order and falls back to all formats', () {
      expect(usedFormats(null), ['SM', 'CL', 'RS']);
      expect(usedFormats(const []), ['SM', 'CL', 'RS']);
      expect(usedFormats(const ['UNKNOWN']), ['SM', 'CL', 'RS']);
      expect(usedFormats(const ['RS', 'SM', 'BAD']), ['SM', 'RS']);
      expect(usedFormats(const ['RS']), ['RS']);
    });

    test('resolveActiveFormats avoids phantom RS on old server without RS rates', () {
      expect(resolveActiveFormats(null, hasRestaurant: false), ['SM', 'CL']);
      expect(resolveActiveFormats(null, hasRestaurant: true), ['SM', 'CL', 'RS']);
      expect(resolveActiveFormats(const ['RS'], hasRestaurant: false), ['RS']);
      expect(resolveActiveFormats(const [], hasRestaurant: false), ['SM', 'CL', 'RS']);
    });

    test('parseFormat, formatName and formatShortName recognize RS in RU and TJ', () {
      expect(parseFormat('RS'), 'RS');
      expect(parseFormat('XX'), isNull);
      expect(formatName('ru', 'RS'), 'Ресторан');
      expect(formatName('tj', 'RS'), 'Ресторан');
      expect(formatShortName('ru', 'RS'), 'Р');
      expect(formatShortName('tj', 'RS'), 'Р');
      expect(tr('ru', 'wallet.RS'), 'Ресторан');
      expect(tr('tj', 'wallet.RS'), 'Ресторан');
    });

    test('Account.fromJson parses formats, spend_rs, today.RS, rates.RS, coupon.min_bill_rs', () {
      final account = Account.fromJson({
        'member': {
          'id': 1,
          'first_name': 'Фарзод',
          'last_name': 'Сомони',
          'phone': '+992900000001',
          'referral_code': 'FS-1111',
        },
        'program': {'store': 'Ресторан', 'enabled': true},
        'status': 1,
        'balance': '150.00',
        'on_hold': '0',
        'debt': '0',
        'spend_month': '1000',
        'spend_sm': '0',
        'spend_cl': '0',
        'spend_rs': '1000',
        'days_left': 10,
        'next_month_status': 1,
        'formats': ['RS'],
        'rates': {
          'SM': {'earn': '0.02', 'burn_cap': '0.01'},
          'CL': {'earn': '0.05', 'burn_cap': '0.10'},
          'RS': {'earn': '0.07', 'burn_cap': '0.10'},
        },
        'today': {'RS': '70.00'},
        'coupon': {
          'amount': '40',
          'min_bill_sm': '400',
          'min_bill_cl': '200',
          'min_bill_rs': '200',
          'valid_to': '2026-12-01',
          'status': 'issued',
        },
        'wallets': {
          'SM': {'balance': '0', 'on_hold': '0', 'debt': '0'},
          'CL': {'balance': '0', 'on_hold': '0', 'debt': '0'},
          'RS': {'balance': '150', 'on_hold': '5', 'debt': '0'},
        },
      });

      expect(account.formats, ['RS']);
      expect(account.activeFormats, ['RS']);
      expect(account.wallet.spendRestaurant, 1000);
      expect(account.wallet.spendByFormat('RS'), 1000);
      expect(account.wallet.todayRestaurant, 70);
      expect(account.wallet.rates.restaurant?.earn, 0.07);
      expect(account.wallet.rates.restaurant?.burnCap, 0.10);
      expect(account.wallet.storeWallets.byFormat('RS').balance, 150);
      expect(account.coupon?.minBillRs, 200);
      expect(couponMinBill(account.coupon!, 'RS'), 200);
    });

    test('RulesInfo.fromJson parses formats, RS rates, birthday rules, and maxEarn', () {
      final rules = RulesInfo.fromJson({
        'thresholds': [1800, 4000, 10000, 18000],
        'formats': ['RS'],
        'statuses': [
          {
            'status': 1,
            'rates': {
              'SM': {'earn': '0.02', 'burn_cap': '0.01'},
              'CL': {'earn': '0.05', 'burn_cap': '0.10'},
              'RS': {'earn': '0.07', 'burn_cap': '0.10'},
            },
          },
          {
            'status': 5,
            'rates': {
              'SM': {'earn': '0.08', 'burn_cap': '0.03'},
              'CL': {'earn': '0.25', 'burn_cap': '0.35'},
              'RS': {'earn': '0.25', 'burn_cap': '0.30'},
            },
          },
        ],
        'referral': {'levels': [0.01, 0.01], 'months': 12},
        'birthday': {
          'coupon': [20, 40, 80, 150, 250],
          'min_bill_x': {'SM': 10, 'CL': 5, 'RS': 5},
          'window_before': 7,
          'window_after': 7,
        },
      });

      expect(rules.formats, ['RS']);
      expect(rules.activeFormats, ['RS']);
      expect(rules.maxEarn(), 0.25);
      expect(rules.maxEarn(format: 'SM'), 0.08);
      expect(rules.birthday?.minBillX['RS'], 5);
      expect(rules.birthday?.windowBefore, 7);
    });

    test('BirthdayGift computes restaurant minimum bill as amount * 5', () {
      final gift = birthdayGift(DateTime(1992, 11, 15), 3, DateTime(2026, 11, 15));
      expect(gift, isNotNull);
      expect(gift!.minRestaurant, 400);
      expect(gift.minFor('RS'), 400);
    });
  });

  group('Restaurant UI & dynamic formats integration', () {
    testWidgets('LoyaltyCard renders 3 formats without overflow at 320px and 1.25x scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final acc = _accountWithFormats();
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
                  formats: acc.formats,
                  locale: 'ru',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('loyalty-rate-SM')), findsOneWidget);
      expect(find.byKey(const ValueKey('loyalty-rate-CL')), findsOneWidget);
      expect(find.byKey(const ValueKey('loyalty-rate-RS')), findsOneWidget);
      expect(find.text('Ресторан'), findsOneWidget);
      expect(find.text('7% / 10%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AlmosiStoreScreen shows only active formats and navigates to Restaurant details', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final acc = _accountWithFormats(formats: const ['RS'], spendRs: 1000);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            meProvider.overrideWith((ref) => acc),
            rulesProvider.overrideWith((ref) => _rulesWithRs),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const AlmosiStoreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('direction-restaurant')), findsOneWidget);
      expect(find.byKey(const ValueKey('direction-supermarket')), findsNothing);
      expect(find.byKey(const ValueKey('direction-clothes')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('direction-restaurant')));
      await tester.pumpAndSettle();

      expect(find.text('Ресторан'), findsWidgets);
      expect(find.text('7%'), findsWidgets);
      expect(find.text('до 10%'), findsOneWidget);
      expect(find.textContaining('1 000 смн'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeScreen shows coupon mins and companies filtered by active formats', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final acc = _accountWithFormats(
        formats: const ['SM', 'RS'],
        coupon: const BirthdayCoupon(
          amount: 40,
          minBillSm: 400,
          minBillCl: 200,
          minBillRs: 200,
          validTo: '2026-12-01',
          status: 'issued',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            meProvider.overrideWith((ref) => acc),
            sizeOffersPreviewProvider.overrideWith(
              (ref) async => SizeOffersResponse(
                items: const [],
                serverNow: DateTime(2026, 11, 28),
              ),
            ),
            rafflesPreviewProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final couponCard = find.byKey(const ValueKey('birthday-coupon-card'));
      expect(couponCard, findsOneWidget);
      expect(
        find.descendant(of: couponCard, matching: find.text('Супермаркет: от 400,00 смн')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: couponCard, matching: find.text('Ресторан: от 200,00 смн')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: couponCard, matching: find.textContaining('Либос')),
        findsNothing,
      );

      await tester.tap(find.text('Мои компании'));
      await tester.pumpAndSettle();
      expect(find.text('СУПЕРМАРКЕТ'), findsOneWidget);
      expect(find.text('РЕСТОРАН'), findsOneWidget);
      expect(find.text('ЛИБОС'), findsNothing);
    });

    testWidgets('ClientCodeScreen coupon hint lists only active formats including RS', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _FakeApi();
      final acc = _accountWithFormats(
        formats: const ['SM', 'CL', 'RS'],
        coupon: const BirthdayCoupon(
          amount: 40,
          minBillSm: 400,
          minBillCl: 200,
          minBillRs: 200,
          validTo: '2026-12-01',
          status: 'issued',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            loyaltyApiProvider.overrideWithValue(api),
            meProvider.overrideWith((ref) => acc),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const ClientCodeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Применится, если чек подходит: Супермаркет — 400 смн, Либос — 200 смн, Ресторан — 200 смн',
        ),
        findsOneWidget,
      );
    });

    testWidgets('PaymentCard displays Ресторан for RS pending check', (tester) async {
      const check = PendingCheck(
        id: 42,
        format: 'RS',
        mode: 'earn',
        v: 0,
        clientConfirmed: false,
        amount: 500,
        x0: 35,
        x: 35,
        y: 50,
        balance: 200,
        debt: 0,
        store: 'MSX Ресторан',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localeProvider.overrideWith(() => _TestLocale('ru'))],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PaymentCard(
                  check: check,
                  fetchedAt: DateTime(2026, 11, 28),
                  onChanged: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MSX Ресторан · Ресторан'), findsOneWidget);
    });

    testWidgets('RulesScreen shows RS rates and dynamic birthday minimums', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            rulesProvider.overrideWith((ref) => _rulesWithRs),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const RulesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rules-rate-1-SM')), findsOneWidget);
      expect(find.byKey(const ValueKey('rules-rate-1-CL')), findsOneWidget);
      expect(find.byKey(const ValueKey('rules-rate-1-RS')), findsOneWidget);
      expect(find.text('7%'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rules-birthday-min')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Купон работает при оплате через приложение. Минимальный чек больше купона: Супермаркет ×10, Либос ×5, Ресторан ×5.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ReceiptsTab filters by RS, displays short RS badge Р, and keeps stale saved format button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _FakeApi()
        ..rows = [
          ReceiptRow(
            id: 99,
            ts: DateTime(2026, 11, 27, 19, 30),
            store: 'Алмоси Ресторан',
            format: 'RS',
            number: 'R-100',
            amount: 1000,
            earn: 70,
            burn: 0,
            round: 0,
            coupon: 0,
            state: 'posted',
            itemsStatus: 'ready',
          ),
        ];

      final acc = _accountWithFormats(formats: const ['SM', 'CL', 'RS']);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            loyaltyApiProvider.overrideWithValue(api),
            meProvider.overrideWith((ref) => acc),
            historyProvider.overrideWith(
              (ref) => [
                HistoryEntry(
                  id: 10,
                  type: 'earn',
                  amount: 70,
                  balanceAfter: 310,
                  createdAt: DateTime(2026, 11, 27, 19, 30),
                  billAmount: 1000,
                  format: 'RS',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const HistoryScreen(initialTab: HistoryTab.bills),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Строка чека с format: 'RS' показывает короткий значок «Р»
      expect(find.text('Р'), findsOneWidget);

      // Открываем фильтры и выбираем «Ресторан»
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('receipts-fmt-RS')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('receipts-fmt-RS')));
      await tester.pumpAndSettle();
      expect(api.lastFmt, 'RS');

      // Переключаемся на «Операции» — операция формата RS показывает «Ресторан»
      await tester.tap(find.text('Операции'));
      await tester.pumpAndSettle();
      expect(find.text('Ресторан'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ReceiptsTab keeps stale saved format filter button so user can clear it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _FakeApi();
      final acc = _accountWithFormats(formats: const ['RS']);

      final container = ProviderContainer(
        overrides: [
          localeProvider.overrideWith(() => _TestLocale('ru')),
          loyaltyApiProvider.overrideWithValue(api),
          meProvider.overrideWith((ref) => acc),
          historyProvider.overrideWith((ref) => const []),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(receiptsFilterProvider.notifier)
          .writeFor(acc.member.id, const ReceiptsQuery(fmt: 'CL'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const HistoryScreen(initialTab: HistoryTab.bills),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Фильтры открываются автоматически при сохранённом fmt: 'CL'
      expect(find.byKey(const ValueKey('receipts-fmt-RS')), findsOneWidget);
      expect(find.byKey(const ValueKey('receipts-fmt-CL')), findsOneWidget);
      expect(find.byKey(const ValueKey('receipts-fmt-SM')), findsNothing);

      // Можно снять фильтр, нажав «Все»
      await tester.tap(find.byKey(const ValueKey('receipts-fmt-all')));
      await tester.pumpAndSettle();
      expect(api.lastFmt, isNull);
      expect(find.byKey(const ValueKey('receipts-fmt-CL')), findsNothing);
    });
  });
}
