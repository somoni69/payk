import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payk/core/format.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/api_client.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/code/client_code_screen.dart';

class _TestLocaleController extends LocaleController {
  _TestLocaleController(this.initial);
  final String initial;

  @override
  String build() => initial;
}

class _QueuedCodeApi extends Fake implements LoyaltyApi {
  _QueuedCodeApi({
    this.initialSpend = SpendPref.earn,
    this.initialCoupon = true,
    this.ttl = 40,
  });

  final SpendPref initialSpend;
  final bool initialCoupon;
  final int ttl;
  final List<CodeChoice?> calls = [];
  final List<Completer<CashierCode>> pendingCompleters = [];
  bool manualCompleterMode = false;
  int _seq = 0;

  @override
  Future<CashierCode> code({CodeChoice? choice}) {
    calls.add(choice);
    if (manualCompleterMode) {
      final completer = Completer<CashierCode>();
      pendingCompleters.add(completer);
      return completer.future;
    }
    _seq++;
    final spend = choice?.spend ?? initialSpend;
    final coupon = choice?.coupon ?? initialCoupon;
    final digits = (42447990 + _seq).toString();
    return Future.value(
      CashierCode(
        qr: 'PAYK-L:tok_$_seq',
        code: digits,
        ttl: ttl,
        spendPref: spend,
        useCoupon: coupon,
      ),
    );
  }

  @override
  Future<PendingSnapshot> pending() async => const PendingSnapshot();
}

Account _sampleAccount({
  double balance = 150,
  double reserved = 0,
  double debt = 0,
  BirthdayCoupon? coupon,
}) {
  return Account(
    member: const Member(
      firstName: 'Фарзод',
      lastName: 'Сомони',
      phone: '+992900000000',
      referralCode: 'SO-4654',
      spendPref: SpendPref.keep,
      couponPref: false,
    ),
    wallet: Wallet(
      status: 2,
      balance: balance,
      reserved: reserved,
      onHold: 0,
      debt: debt,
      spendMonth: 500,
      spendSupermarket: 300,
      spendClothes: 200,
      daysLeft: 14,
      keep: null,
      up: null,
      nextMonthStatus: 2,
      rates: const ProgramRates(
        supermarket: Rate(earn: 0.03, burnCap: 0.02),
        clothes: Rate(earn: 0.07, burnCap: 0.15),
      ),
      todaySupermarket: 0,
      todayClothes: 0,
    ),
    store: 'Алмоси',
    programEnabled: true,
    coupon: coupon,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      return null;
    });
  });

  LoyaltyApi apiWith(http.Client client) => LoyaltyApi(
        ApiClient(
          readTokens: () =>
              const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
          writeTokens: (access, refresh) {},
          onExpired: () {},
          httpClient: client,
        ),
      );

  group('1C pre-choice models and API', () {
    test('formatMoneyAuto drops trailing zeros for whole amounts', () {
      expect(formatMoneyAuto(20), '20 смн');
      expect(formatMoneyAuto(20.00), '20 смн');
      expect(formatMoneyAuto(20.5), '20,50 смн');
      expect(formatMoneyAuto(1250.75), '1 250,75 смн');
    });

    test('Account.fromJson parses reserved, spend_pref, coupon_pref and coupon status', () {
      final account = Account.fromJson({
        'member': {
          'first_name': 'Фарзод',
          'last_name': 'Сомони',
          'phone': '+992900000000',
          'referral_code': 'SO-4654',
          'spend_pref': 'max',
          'coupon_pref': false,
        },
        'program': {'title': 'ПАЙК', 'store': 'Алмоси', 'enabled': true},
        'status': 3,
        'balance': '120.50',
        'reserved': '35.00',
        'on_hold': '0',
        'debt': '0',
        'spend_month': '1000',
        'spend_sm': '600',
        'spend_cl': '400',
        'days_left': 10,
        'next_month_status': 3,
        'rates': {
          'SM': {'earn': '0.03', 'burn_cap': '0.02'},
          'CL': {'earn': '0.07', 'burn_cap': '0.15'},
        },
        'today': {},
        'coupon': {
          'id': 9,
          'amount': 40,
          'min_bill_sm': 400,
          'min_bill_cl': 200,
          'valid_from': '2026-11-10',
          'valid_to': '2026-11-24',
          'status': 'issued',
        },
      });

      expect(account.member.spendPref, SpendPref.max);
      expect(account.member.couponPref, isFalse);
      expect(account.wallet.balance, 120.50);
      expect(account.wallet.reserved, 35.00);
      expect(account.coupon?.status, 'issued');
      expect(account.coupon?.amount, 40);
    });

    test('LoyaltyApi.code omits body when choice is null and sends choice when set', () async {
      final requests = <String?>[];
      final api = apiWith(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, endsWith('/loyalty-app/me/code'));
          requests.add(request.body.isEmpty ? null : request.body);
          return http.Response(
            jsonEncode({
              'qr': 'PAYK-L:abc',
              'code': '12345678',
              'issued_at': '2026-11-16T10:00:00Z',
              'expires_at': '2026-11-16T10:00:40Z',
              'ttl': 40,
              'spend_pref': 'keep',
              'use_coupon': false,
            }),
            200,
          );
        }),
      );

      final first = await api.code();
      expect(first.spendPref, SpendPref.keep);
      expect(first.useCoupon, isFalse);
      expect(first.issuedAt, isNotNull);

      await api.code(
        choice: const CodeChoice(spend: SpendPref.max, coupon: true),
      );

      expect(requests[0], isNull);
      expect(
        jsonDecode(requests[1]!),
        {'spend': 'max', 'coupon': true},
      );
    });
  });

  group('ClientCodeScreen 1C spend & coupon choice', () {
    Widget buildScreen({
      Key? screenKey,
      required _QueuedCodeApi api,
      required Account account,
      String locale = 'ru',
      DateTime Function()? nowProvider,
    }) {
      return ProviderScope(
        key: screenKey,
        overrides: [
          localeProvider.overrideWith(() => _TestLocaleController(locale)),
          loyaltyApiProvider.overrideWithValue(api),
          meProvider.overrideWith((ref) => account),
        ],
        child: MaterialApp(
          theme: PaykTheme.light,
          home: ClientCodeScreen(nowProvider: nowProvider),
        ),
      );
    }

    testWidgets('shows spend choice, balance, reserved, debt and coupon controls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _QueuedCodeApi(
        initialSpend: SpendPref.keep,
        initialCoupon: true,
      );
      final account = _sampleAccount(
        balance: 150,
        reserved: 25,
        debt: 10,
        coupon: const BirthdayCoupon(
          amount: 40,
          minBillSm: 400,
          minBillCl: 200,
          validTo: '2026-11-24',
          status: 'issued',
        ),
      );

      await tester.pumpWidget(buildScreen(api: api, account: account));
      await tester.pumpAndSettle();

      // Первый запрос идёт без тела, чтобы подтянуть сохранённый выбор с сервера
      expect(api.calls, [null]);

      expect(find.byKey(const ValueKey('spend-choice-card')), findsOneWidget);
      expect(find.text('Как оплатить этот чек'), findsOneWidget);
      expect(find.text('На счёте 150,00 смн'), findsOneWidget);
      expect(
        find.text(
          'Часть чека оплатите кэшбэком — с остатка кэшбэк всё равно начислится',
        ),
        findsOneWidget,
      );
      // При долге и выбранном keep показываем предупреждение
      expect(
        find.text('Пока есть долг, кэшбэк не тратится — только копится'),
        findsOneWidget,
      );
      // Резерв 1С отображается
      expect(
        find.text('Ещё 25,00 смн отложено для покупки, которую сейчас проводит касса'),
        findsOneWidget,
      );
      // Купон ко дню рождения
      expect(find.text('Купон ко дню рождения −40 смн'), findsOneWidget);
      expect(
        find.text('Применится, если чек подходит: Либос — 200 смн, Супермаркет — 400 смн'),
        findsOneWidget,
      );

      // Переключаем на «Копить» — предупреждение о долге скрывается, а запрос уходит с earn
      await tester.tap(find.byKey(const ValueKey('spend-earn')));
      await tester.pumpAndSettle();
      expect(
        api.calls.last,
        const CodeChoice(spend: SpendPref.earn, coupon: true),
      );
      expect(
        find.text('Пока есть долг, кэшбэк не тратится — только копится'),
        findsNothing,
      );

      // Выключаем купон — уходит новый запрос с coupon: false
      await tester.tap(find.byKey(const ValueKey('spend-coupon-toggle')));
      await tester.pumpAndSettle();
      expect(
        api.calls.last,
        const CodeChoice(spend: SpendPref.earn, coupon: false),
      );
    });

    testWidgets('hides coupon if status is not issued and renders Tajik copy', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _QueuedCodeApi(initialSpend: SpendPref.earn);
      final account = _sampleAccount(
        coupon: const BirthdayCoupon(
          amount: 40,
          minBillSm: 400,
          minBillCl: 200,
          validTo: '2026-11-24',
          status: 'used',
        ),
      );

      await tester.pumpWidget(
        buildScreen(api: api, account: account, locale: 'tj'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ин чекро чӣ тавр мепардозед'), findsOneWidget);
      expect(find.text('Дар ҳисоб 150,00 смн'), findsOneWidget);
      expect(find.byKey(const ValueKey('spend-coupon-toggle')), findsNothing);
    });

    testWidgets(
      'marks code outdated while switching and queues follow-up when tapped rapidly',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final api = _QueuedCodeApi()..manualCompleterMode = true;
        final account = _sampleAccount();

        await tester.pumpWidget(buildScreen(api: api, account: account));
        await tester.pump();

        // 1. Завершаем первый запрос с earn
        api.pendingCompleters[0].complete(
          const CashierCode(
            qr: 'PAYK-L:1',
            code: '11112222',
            ttl: 40,
            spendPref: SpendPref.earn,
            useCoupon: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1111 2222'), findsOneWidget);

        // 2. Переключаем на keep — пока идёт запрос, код помечен как outdated
        await tester.tap(find.byKey(const ValueKey('spend-keep')));
        await tester.pump();
        expect(find.text('Готовим код с вашим выбором…'), findsOneWidget);
        expect(find.text('…'), findsOneWidget);
        expect(api.calls.length, 2);
        expect(
          api.calls[1],
          const CodeChoice(spend: SpendPref.keep, coupon: true),
        );

        // 3. Пока keep ещё не ответил, пользователь сразу переключает на max
        await tester.tap(find.byKey(const ValueKey('spend-max')));
        await tester.pump();
        // Одновременный запрос не шлётся — ждём завершения первого
        expect(api.calls.length, 2);

        // 4. Ответ на keep приходит, но клиент уже выбрал max -> остаётся outdated и сразу уходит max
        api.pendingCompleters[1].complete(
          const CashierCode(
            qr: 'PAYK-L:2',
            code: '22223333',
            ttl: 40,
            spendPref: SpendPref.keep,
            useCoupon: true,
          ),
        );
        await tester.pump();
        expect(api.calls.length, 3);
        expect(
          api.calls[2],
          const CodeChoice(spend: SpendPref.max, coupon: true),
        );
        expect(find.text('Готовим код с вашим выбором…'), findsOneWidget);

        // 5. Завершается запрос с max -> показывается свежий код 3333 4444 и обычный таймер
        api.pendingCompleters[2].complete(
          const CashierCode(
            qr: 'PAYK-L:3',
            code: '33334444',
            ttl: 40,
            spendPref: SpendPref.max,
            useCoupon: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('3333 4444'), findsOneWidget);
        expect(find.text('Готовим код с вашим выбором…'), findsNothing);
        expect(find.textContaining('Код обновится через'), findsOneWidget);
      },
    );

    testWidgets(
      'formats long TTL (>=120s, e.g. 1800s / 30 min) as mm:ss and minutes in ru & tj',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        var fakeNow = DateTime(2026, 11, 16, 17, 30, 0);
        final apiRu = _QueuedCodeApi(ttl: 1800);
        final account = _sampleAccount();

        await tester.pumpWidget(
          buildScreen(
            screenKey: const ValueKey('ru-1800'),
            api: apiRu,
            account: account,
            nowProvider: () => fakeNow,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('30:00'), findsOneWidget);
        expect(find.text('Код обновится через 30:00'), findsOneWidget);
        expect(
          find.text('Каждый код одноразовый и действует 30 минут'),
          findsOneWidget,
        );

        fakeNow = fakeNow.add(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('29:58'), findsOneWidget);
        expect(find.text('Код обновится через 29:58'), findsOneWidget);

        final apiMin2 = _QueuedCodeApi(ttl: 125);
        await tester.pumpWidget(
          buildScreen(
            screenKey: const ValueKey('ru-125'),
            api: apiMin2,
            account: account,
            nowProvider: () => fakeNow,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2:05'), findsOneWidget);
        expect(
          find.text('Каждый код одноразовый и действует 2 минуты'),
          findsOneWidget,
        );

        final apiTj = _QueuedCodeApi(ttl: 1800);
        await tester.pumpWidget(
          buildScreen(
            screenKey: const ValueKey('tj-1800'),
            api: apiTj,
            account: account,
            locale: 'tj',
            nowProvider: () => fakeNow,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Рамз баъд аз 30:00 нав мешавад'), findsOneWidget);
        expect(
          find.text('Ҳар рамз як бор ва 30 дақиқа амал мекунад'),
          findsOneWidget,
        );
      },
    );
  });
}
