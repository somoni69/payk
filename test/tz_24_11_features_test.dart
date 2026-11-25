import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/payment_choice.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/api_client.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/code/client_code_screen.dart';
import 'package:payk/features/code/payment_card.dart';
import 'package:payk/features/friends/friends_screen.dart';
import 'package:payk/features/history/receipt_detail_screen.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/notifications/notifications_screen.dart';
import 'package:payk/features/raffles/raffles_screen.dart';
import 'package:payk/features/rules/rules_screen.dart';

class _TestLocaleController extends LocaleController {
  _TestLocaleController(this.initial);
  final String initial;

  @override
  String build() => initial;
}

class _FakePaymentApi extends Fake implements LoyaltyApi {
  double? quotedBurn;
  double? chosenBurn;

  @override
  Future<QuoteResult> quote(
    int id, {
    required double burn,
    required bool coin10,
    required bool noCoin,
    bool coupon = false,
  }) async {
    quotedBurn = burn;
    return QuoteResult(
      preview: PendingCheck(
        id: id,
        format: 'SM',
        mode: 'earn_burn',
        v: burn,
        clientConfirmed: false,
        amount: 200,
        x0: 10,
        x: 2.5,
        y: 156,
        aStar: 156,
        cashToPay: 200 - burn,
        toPay: 200 - burn,
        roundBurn: 150,
        roundCash: 50,
        roundSuggested: true,
      ),
    );
  }

  @override
  Future<PendingCheck> choose(
    int id, {
    required double burn,
    required bool coin10,
    required bool noCoin,
    bool coupon = false,
  }) async {
    chosenBurn = burn;
    return PendingCheck(
      id: id,
      format: 'SM',
      mode: 'earn_burn',
      v: burn,
      clientConfirmed: true,
      amount: 200,
      x0: 10,
      x: 2.5,
      y: 156,
      aStar: 156,
      cashToPay: 200 - burn,
      toPay: 200 - burn,
      roundBurn: 150,
      roundCash: 50,
      roundSuggested: true,
    );
  }
}

class _FakeCodeApi extends Fake implements LoyaltyApi {
  @override
  Future<CashierCode> code({CodeChoice? choice}) async => CashierCode(
    qr: 'PAYK-L:keep',
    code: '123456',
    ttl: 40,
    spendPref: choice?.spend ?? SpendPref.keep,
    useCoupon: choice?.coupon ?? false,
  );

  @override
  Future<PendingSnapshot> pending() async => const PendingSnapshot();

  @override
  Future<int> markMessagesRead({int? upToId}) async => 0;
}

Account _account({bool burnKeepsCashback = false}) {
  return Account(
    member: const Member(
      firstName: 'Фарзод',
      lastName: 'Сомони',
      phone: '+992900000000',
      referralCode: 'SO-4654',
    ),
    wallet: const Wallet(
      status: 2,
      balance: 156,
      onHold: 0,
      debt: 0,
      spendMonth: 500,
      spendSupermarket: 300,
      spendClothes: 200,
      daysLeft: 14,
      keep: null,
      up: null,
      nextMonthStatus: 2,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.03, burnCap: 1.0),
        clothes: Rate(earn: 0.07, burnCap: 1.0),
      ),
      todaySupermarket: 0,
      todayClothes: 0,
    ),
    store: 'Алмоси',
    programEnabled: true,
    burnKeepsCashback: burnKeepsCashback,
  );
}

void main() {
  group('ТЗ 24.11 models & API', () {
    test('parses burn_keeps_cashback, first_bonus, round fields and raffles', () async {
      final account = Account.fromJson({
        'member': {
          'first_name': 'Фарзод',
          'last_name': 'Сомони',
          'phone': '+992900000000',
          'referral_code': 'SO-4654',
        },
        'program': {'title': 'ПАЙК', 'store': 'Алмоси', 'enabled': true},
        'status': 2,
        'balance': '156.00',
        'on_hold': '0',
        'debt': '0',
        'spend_month': '500',
        'spend_sm': '300',
        'spend_cl': '200',
        'days_left': 14,
        'next_month_status': 2,
        'rates': {},
        'today': {},
        'burn_keeps_cashback': true,
      });
      expect(account.burnKeepsCashback, isTrue);

      final rules = RulesInfo.fromJson({
        'thresholds': [1800],
        'statuses': [],
        'referral': {
          'levels': [0.01, 0.01],
          'months': 12,
          'first_bonus': 15,
          'first_bonus_min': 100,
        },
        'burn_keeps_cashback': true,
      });
      expect(rules.burnKeepsCashback, isTrue);
      expect(rules.firstBonus, 15);
      expect(rules.firstBonusMin, 100);

      final friends = FriendsInfo.fromJson({
        'code': 'SO-4654',
        'levels': [0.01, 0.01],
        'months': 12,
        'first_bonus': 20,
        'first_bonus_min': 150,
        'count_l1': 0,
        'count_l2': 0,
        'total': 0,
        'month': 0,
        'invitees': [],
      });
      expect(friends.firstBonus, 20);
      expect(friends.firstBonusMin, 150);

      final pending = PendingCheck.fromJson({
        'id': 11,
        'format': 'SM',
        'mode': 'earn',
        'v': 0,
        'client_confirmed': false,
        'y': 0,
        'round_burn': 150,
        'round_cash': 50,
        'round_suggested': true,
      });
      expect(pending.roundBurn, 150);
      expect(pending.roundCash, 50);
      expect(pending.roundSuggested, isTrue);
      expect(needsChoice(pending), isTrue);

      final api = LoyaltyApi(
        ApiClient(
          readTokens: () =>
              const TokenPair(accessToken: 'a', refreshToken: 'r'),
          writeTokens: (_, _) {},
          onExpired: () {},
          httpClient: MockClient((request) async {
            expect(request.url.path, endsWith('/loyalty-app/me/raffles'));
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'current': {
                    'id': 5,
                    'title': 'Осенний розыгрыш',
                    'prizes': 'iPhone 17',
                    'starts_on': '2026-11-01',
                    'ends_on': '2026-11-30',
                    'step_amount': 200,
                    'winners_count': 3,
                    'state': 'active',
                    'drawn_at': null,
                  },
                  'raffles': [
                    {
                      'id': 5,
                      'title': 'Осенний розыгрыш',
                      'prizes': 'iPhone 17',
                      'starts_on': '2026-11-01',
                      'ends_on': '2026-11-30',
                      'step_amount': 200,
                      'winners_count': 3,
                      'state': 'active',
                      'drawn_at': null,
                      'codes': [
                        {
                          'code': 'AB34CD9',
                          'state': 'active',
                          'place': null,
                          'cancel_reason': null,
                          'created_at': '2026-11-24T12:00:00Z',
                          'bill': {'id': 1, 'ext_id': 'C-1', 'amount': 250},
                        },
                      ],
                      'winners': [],
                    },
                  ],
                  'active_codes': 1,
                }),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );

      final raffles = await api.raffles();
      expect(raffles.current?.id, 5);
      expect(raffles.activeCodes, 1);
      expect(raffles.raffles.single.codes.single.code, 'AB34CD9');
    });
  });

  group('ТЗ 24.11 UI features', () {
    testWidgets('ClientCodeScreen shows 2 options when burnKeepsCashback is true', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocaleController('ru')),
            loyaltyApiProvider.overrideWithValue(_FakeCodeApi()),
            meProvider.overrideWith((ref) => _account(burnKeepsCashback: true)),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const ClientCodeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('spend-earn')), findsOneWidget);
      expect(find.byKey(const ValueKey('spend-max')), findsOneWidget);
      expect(find.byKey(const ValueKey('spend-keep')), findsNothing);
      expect(
        find.textContaining('Кассир может списать меньше — например, чтобы доплатить без сдачи'),
        findsOneWidget,
      );
    });

    testWidgets('PaymentCard renders round-without-change option and confirms it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _FakePaymentApi();
      const check = PendingCheck(
        id: 77,
        format: 'SM',
        mode: 'earn',
        v: 0,
        clientConfirmed: false,
        amount: 200,
        x0: 10,
        x: 10,
        y: 156,
        aStar: 156,
        cashToPay: 200,
        toPay: 200,
        roundBurn: 150,
        roundCash: 50,
        roundSuggested: true,
        balance: 156,
        burnMin: 0.5,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocaleController('ru')),
            loyaltyApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PaymentCard(
                  check: check,
                  fetchedAt: DateTime.now(),
                  onChanged: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('spend-round')), findsOneWidget);
      expect(find.byKey(const ValueKey('spend-round-suggested')), findsOneWidget);
      expect(
        find.text('Без сдачи: 150,00 смн кэшбэком, доплата 50,00 смн'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Кассир предлагает оплатить без сдачи'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('spend-round')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(api.quotedBurn, 150);
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(api.chosenBurn, 150);
    });

    testWidgets('RafflesScreen renders raffles, codes and winners', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const response = RafflesResponse(
        current: RaffleInfo(
          id: 1,
          title: 'Зимний розыгрыш',
          prizes: 'Телевизор',
          startsOn: '2026-11-01',
          endsOn: '2026-11-30',
          stepAmount: 200,
          winnersCount: 1,
          state: 'active',
        ),
        activeCodes: 1,
        raffles: [
          RaffleInfo(
            id: 1,
            title: 'Зимний розыгрыш',
            prizes: 'Телевизор',
            startsOn: '2026-11-01',
            endsOn: '2026-11-30',
            stepAmount: 200,
            winnersCount: 1,
            state: 'active',
            codes: [
              RaffleCode(code: 'ZX78QW2', state: 'active'),
              RaffleCode(code: 'MN45KL9', state: 'cancelled'),
            ],
          ),
          RaffleInfo(
            id: 2,
            title: 'Осенний розыгрыш',
            prizes: 'Смартфон',
            startsOn: '2026-10-01',
            endsOn: '2026-10-31',
            stepAmount: 200,
            winnersCount: 1,
            state: 'drawn',
            codes: [
              RaffleCode(code: 'WIN9999', state: 'won', place: 1),
            ],
            winners: [RaffleWinner(code: 'WIN9999', place: 1)],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocaleController('ru')),
            meProvider.overrideWith((ref) => _account()),
            rafflesProvider.overrideWith((ref) => response),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const RafflesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Зимний розыгрыш'), findsOneWidget);
      expect(find.text('Телевизор'), findsOneWidget);
      expect(find.text('ZX78QW2'), findsOneWidget);
      expect(find.text('Участвует'), findsOneWidget);
      expect(find.text('MN45KL9'), findsOneWidget);
      expect(find.text('Погашен — возврат'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Осенний розыгрыш'), 200);
      expect(find.text('Выигрыш · 1-е место'), findsOneWidget);
      expect(find.text('Выигрышные промокоды'), findsOneWidget);
    });

    testWidgets('HomeScreen renders active raffle card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const response = RafflesResponse(
        current: RaffleInfo(
          id: 1,
          title: 'Зимний розыгрыш',
          prizes: 'Телевизор',
          startsOn: '2026-11-01',
          endsOn: '2026-11-30',
          stepAmount: 200,
          winnersCount: 1,
          state: 'active',
        ),
        activeCodes: 1,
        raffles: [
          RaffleInfo(
            id: 1,
            title: 'Зимний розыгрыш',
            prizes: 'Телевизор',
            startsOn: '2026-11-01',
            endsOn: '2026-11-30',
            stepAmount: 200,
            winnersCount: 1,
            state: 'active',
            codes: [RaffleCode(code: 'ZX78QW2', state: 'active')],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocaleController('ru')),
            meProvider.overrideWith((ref) => _account()),
            rafflesPreviewProvider.overrideWith((ref) => response),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-raffle')), findsOneWidget);
      expect(find.text('Розыгрыш «Зимний розыгрыш»'), findsOneWidget);
      expect(find.textContaining('у вас 1 промокод'), findsOneWidget);
    });

    testWidgets('ReceiptDetailScreen shows line discount when qty*price > amount', (
      tester,
    ) async {
      final view = ReceiptView.fromJson({
        'id': 50,
        'ts': '2026-11-24T12:00:00Z',
        'store': 'Алмоси',
        'format': 'SM',
        'number': '1001',
        'lines': [
          {
            'line_no': 1,
            'name': 'Сыр',
            'qty': '2',
            'unit': 'шт',
            'price': '100.00',
            'amount': '175.00',
            'returned_qty': '0',
            'returned_amount': '0',
            'state': 'ok',
            'estimated': false,
            'returned': false,
          },
          {
            'line_no': 2,
            'name': 'Молоко',
            'qty': '1',
            'unit': 'шт',
            'price': '20.00',
            'amount': '15.00',
            'returned_qty': '1',
            'returned_amount': '15.00',
            'state': 'full',
            'estimated': false,
            'returned': true,
          },
        ],
        'items_status': 'ok',
        'amount_before_coupon': '190.00',
        'coupon': '0.00',
        'amount': '190.00',
        'burn': '0.00',
        'round': '0.00',
        'b': '0.00',
        'mode': 'earn',
        'pay': {'cash': '190.00', 'card': '0.00'},
        'earn': '5.70',
        'returns': const [],
        'state': 'ok',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocaleController('ru')),
            receiptDetailProvider(50).overrideWith((ref) => view),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const ReceiptDetailScreen(receiptId: 50),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('receipt-line-discount-1')), findsOneWidget);
      expect(find.text('скидка −25,00 смн'), findsOneWidget);
      // Для полностью возвращённой строки скидку не показываем.
      expect(find.byKey(const ValueKey('receipt-line-discount-2')), findsNothing);
    });

    testWidgets('FriendsScreen shows first_bonus badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const friends = FriendsInfo(
        code: 'SO-4654',
        levels: [0.01, 0.01],
        months: 12,
        firstBonus: 15,
        firstBonusMin: 100,
        countL1: 0,
        countL2: 0,
        total: 0,
        month: 0,
        invitees: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocaleController('ru')),
            meProvider.overrideWith((ref) => _account(burnKeepsCashback: true)),
            friendsProvider.overrideWith((ref) => friends),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const FriendsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('friends-first-bonus')), findsOneWidget);
      expect(
        find.text('+15 смн вам, когда друг сделает первую покупку от 100 смн'),
        findsOneWidget,
      );
    });

    testWidgets('RulesScreen shows first_bonus and modesNoteKeep', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const rules = RulesInfo(
        thresholds: [],
        statuses: [],
        referralLevels: [0.01, 0.01],
        months: 12,
        firstBonus: 15,
        firstBonusMin: 100,
        burnKeepsCashback: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocaleController('ru')),
            rulesProvider.overrideWith((ref) => rules),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const RulesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rules-first-bonus')), findsOneWidget);
      expect(
        find.textContaining('с части чека, оплаченной деньгами, кэшбэк начисляется всегда'),
        findsOneWidget,
      );
    });

    testWidgets('NotificationsScreen shows raffle and referral_bonus actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final items = [
        LoyaltyMessageItem(
          id: 1,
          kind: 'raffle_code',
          text: 'Вы получили промокод AB34CD9',
          createdAt: DateTime(2026, 11, 24, 15, 0),
          read: false,
        ),
        LoyaltyMessageItem(
          id: 2,
          kind: 'referral_bonus',
          text: 'Первая покупка друга — +15 смн',
          createdAt: DateTime(2026, 11, 24, 14, 0),
          read: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocaleController('ru')),
            loyaltyApiProvider.overrideWithValue(_FakeCodeApi()),
            messagesProvider.overrideWith((ref) => items),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: NotificationsScreen(nowProvider: () => DateTime(2026, 11, 24, 16, 0)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Розыгрыш'), findsOneWidget);
      expect(find.byKey(const ValueKey('message-raffles-1')), findsOneWidget);
      expect(find.text('Мои промокоды'), findsOneWidget);
      expect(find.text('Бонус за друга'), findsOneWidget);
      expect(find.byKey(const ValueKey('message-friends-2')), findsOneWidget);
      expect(find.text('Мои друзья'), findsOneWidget);
    });
  });
}
