import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/api_client.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/code/payment_card.dart';
import 'package:payk/features/history/history_screen.dart';
import 'package:payk/features/history/receipt_detail_screen.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/notifications/notifications_screen.dart';

class _LocaleStub extends LocaleController {
  _LocaleStub(this._locale);
  final String _locale;

  @override
  String build() => _locale;
}

class _ReceiptAndMessagesApi extends Fake implements LoyaltyApi {
  _ReceiptAndMessagesApi({this.receiptView});

  final ReceiptView? receiptView;
  final List<int> singleReadIds = <int>[];

  @override
  Future<int> markMessagesRead({int? upToId}) async => 0;

  @override
  Future<int> markMessageRead(int id) async {
    singleReadIds.add(id);
    return 0;
  }

  @override
  Future<ReceiptView> receipt(int id) async => receiptView!;
}

Account _splitWalletAccount({
  double smBalance = 120,
  double clBalance = 45.5,
  double smDebt = 0,
  double clDebt = 0,
  double smOnHold = 0,
  double clOnHold = 0,
}) {
  return Account(
    member: const Member(
      firstName: 'Фарзод',
      lastName: 'Сомони',
      phone: '+992900000000',
      referralCode: 'SO-4654',
    ),
    wallet: Wallet(
      status: 2,
      balance: smBalance + clBalance,
      reserved: 0,
      onHold: smOnHold + clOnHold,
      debt: smDebt + clDebt,
      wallets: StoreWallets(
        sm: StoreWallet(
          balance: smBalance,
          onHold: smOnHold,
          debt: smDebt,
        ),
        cl: StoreWallet(
          balance: clBalance,
          onHold: clOnHold,
          debt: clDebt,
        ),
      ),
      spendMonth: 1500,
      spendSupermarket: 900,
      spendClothes: 600,
      daysLeft: 10,
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
  );
}

ReceiptView _receiptWithReturn(int id) {
  return ReceiptView(
    id: id,
    number: 'CHK-$id',
    ts: DateTime(2026, 11, 20, 20, 6),
    store: 'Алмоси',
    format: 'SM',
    state: 'partially_returned',
    itemsStatus: 'ok',
    amount: 350,
    amountBeforeCoupon: 350,
    coupon: 0,
    burn: 0,
    round: 0,
    b: 0,
    cashPay: 350,
    cardPay: 0,
    earn: 12.25,
    mode: 'earn',
    lines: const [
      ReceiptLine(
        lineNo: 1,
        name: 'Чай зелёный',
        qty: 1,
        unit: 'шт',
        price: 350,
        amount: 350,
        returnedQty: 0,
        returnedAmount: 0,
        state: 'sold',
        estimated: false,
        returned: false,
      ),
    ],
    returns: [
      ReceiptReturn(
        ts: DateTime(2026, 11, 20, 20, 10),
        amount: 212,
        reversedEarn: 7.42,
        refundedBurn: 0,
        refundedRound: 0,
        linesState: 'ok',
        lines: const [],
      ),
    ],
  );
}

void main() {
  LoyaltyApi apiWith(http.Client client) => LoyaltyApi(
    ApiClient(
      readTokens: () =>
          const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
      writeTokens: (access, refresh) {},
      onExpired: () {},
      httpClient: client,
    ),
  );

  group('Separate wallets & notification receipt API/models', () {
    test('Account.fromJson parses SM/CL wallets and falls back on legacy payload', () {
      final base = {
        'member': {
          'first_name': 'Фарзод',
          'last_name': 'Сомони',
          'phone': '+992900000000',
          'referral_code': 'SO-4654',
        },
        'program': {'title': 'ПАЙК', 'store': 'Алмоси', 'enabled': true},
        'status': 2,
        'balance': '165.50',
        'reserved': '10.00',
        'on_hold': '5.00',
        'debt': '2.00',
        'spend_month': '1000',
        'spend_sm': '600',
        'spend_cl': '400',
        'days_left': 10,
        'next_month_status': 2,
        'rates': {
          'SM': {'earn': '0.03', 'burn_cap': '0.02'},
          'CL': {'earn': '0.07', 'burn_cap': '0.15'},
        },
        'today': {},
      };

      final withWallets = Account.fromJson({
        ...base,
        'wallets': {
          'SM': {'balance': '120.00', 'reserved': '10.00', 'on_hold': '0', 'debt': '0'},
          'CL': {'balance': '45.50', 'reserved': '0', 'on_hold': '5.00', 'debt': '2.00'},
        },
      });
      expect(withWallets.wallet.storeWallets.sm.balance, 120.0);
      expect(withWallets.wallet.storeWallets.sm.reserved, 10.0);
      expect(withWallets.wallet.storeWallets.cl.balance, 45.5);
      expect(withWallets.wallet.storeWallets.cl.onHold, 5.0);
      expect(withWallets.wallet.storeWallets.cl.debt, 2.0);

      // Legacy backend without `wallets` field puts total into SM.
      final legacy = Account.fromJson(base);
      expect(legacy.wallet.wallets, isNull);
      expect(legacy.wallet.storeWallets.sm.balance, 165.5);
      expect(legacy.wallet.storeWallets.sm.debt, 2.0);
      expect(legacy.wallet.storeWallets.cl.balance, 0.0);
    });

    test('PendingCheck parses wallet and LoyaltyMessageItem parses bill_id', () {
      final check = PendingCheck.fromJson({
        'id': 7,
        'format': 'CL',
        'mode': 'earn',
        'v': '0',
        'client_confirmed': false,
        'balance': '45.50',
        'debt': '0',
        'wallet': 'CL',
      });
      expect(check.wallet, 'CL');
      expect(check.balance, 45.5);

      final msg = LoyaltyMessageItem.fromJson({
        'id': 42,
        'kind': 'purchase_return',
        'text': 'Возврат товара',
        'created_at': '2026-11-20T15:06:00Z',
        'read': false,
        'bill_id': 912,
      });
      expect(msg.billId, 912);
      expect(msg.copyWith(read: true).read, isTrue);
      expect(msg.copyWith(read: true).billId, 912);

      final withoutBill = LoyaltyMessageItem.fromJson({
        'id': 43,
        'kind': 'broadcast',
        'text': 'Новости',
        'created_at': '2026-11-20T15:06:00Z',
        'read': true,
        'bill_id': null,
      });
      expect(withoutBill.billId, isNull);
    });

    test('LoyaltyApi.markMessageRead posts to /me/messages/{id}/read', () async {
      final api = apiWith(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, endsWith('/loyalty-app/me/messages/55/read'));
          return http.Response(jsonEncode({'unread': 3}), 200);
        }),
      );

      final unread = await api.markMessageRead(55);
      expect(unread, 3);
    });
  });

  group('UI integration for separate wallets & notification -> receipt', () {
    testWidgets('HomeScreen displays split wallets, per-wallet debt and onHold', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final account = _splitWalletAccount(
        smBalance: 120,
        clBalance: 45.5,
        clDebt: 15,
        smOnHold: 8.5,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _LocaleStub('ru')),
            meProvider.overrideWith((ref) => account),
            sizeOffersPreviewProvider.overrideWith(
              (ref) async => SizeOffersResponse(
                items: const [],
                serverNow: DateTime(2026, 11, 21),
              ),
            ),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final smTile = find.byKey(const ValueKey('loyalty-wallet-SM'));
      final clTile = find.byKey(const ValueKey('loyalty-wallet-CL'));
      expect(smTile, findsOneWidget);
      expect(clTile, findsOneWidget);
      expect(find.descendant(of: smTile, matching: find.text('Супермаркет')), findsOneWidget);
      expect(find.descendant(of: smTile, matching: find.textContaining('120,00')), findsOneWidget);
      expect(find.descendant(of: clTile, matching: find.text('Либос')), findsOneWidget);
      expect(find.descendant(of: clTile, matching: find.textContaining('45,50')), findsOneWidget);
      expect(
        find.text('Отрицательный баланс в «Либос»: −15,00 смн'),
        findsOneWidget,
      );
      expect(
        find.text('«Супермаркет»: +8,50 смн в ожидании'),
        findsOneWidget,
      );
    });

    testWidgets('PaymentCard displays store-specific wallet balance', (
      tester,
    ) async {
      const check = PendingCheck(
        id: 1,
        format: 'CL',
        mode: 'earn',
        v: 0,
        clientConfirmed: false,
        amount: 300,
        x0: 15,
        x: 15,
        y: 30,
        balance: 45.5,
        debt: 0,
        wallet: 'CL',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _LocaleStub('ru')),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: PaymentCard(
                  check: check,
                  fetchedAt: DateTime(2026, 11, 21),
                  onChanged: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Баланс «Либос»: 45,50 смн'), findsOneWidget);
    });

    testWidgets('HistoryScreen shows wallet-specific balanceAfter on entries', (
      tester,
    ) async {
      final entries = [
        HistoryEntry(
          id: 10,
          type: 'accrual',
          amount: 12.25,
          balanceAfter: 50.55,
          createdAt: DateTime(2026, 11, 20, 20, 6),
          format: 'SM',
        ),
        HistoryEntry(
          id: 9,
          type: 'accrual',
          amount: 20,
          balanceAfter: 20,
          createdAt: DateTime(2026, 11, 19, 14, 0),
          format: 'CL',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _LocaleStub('ru')),
            historyProvider.overrideWith((ref) => entries),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const HistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Баланс «Супермаркет»: 50,55 смн'), findsOneWidget);
      expect(find.text('Баланс «Либос»: 20,00 смн'), findsOneWidget);
    });

    testWidgets(
      'Tapping notification with bill_id marks it read and opens receipt focused on returns',
      (tester) async {
        final api = _ReceiptAndMessagesApi(receiptView: _receiptWithReturn(777));
        final items = [
          LoyaltyMessageItem(
            id: 501,
            kind: 'purchase_return',
            text: 'Возврат товара в «Супермаркет»: 212,00 сомони.',
            createdAt: DateTime(2026, 11, 20, 20, 10),
            read: false,
            billId: 777,
          ),
          LoyaltyMessageItem(
            id: 500,
            kind: 'broadcast',
            text: 'Просто новость без чека',
            createdAt: DateTime(2026, 11, 20, 15, 0),
            read: true,
            billId: null,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localeProvider.overrideWith(() => _LocaleStub('ru')),
              loyaltyApiProvider.overrideWithValue(api),
              messagesProvider.overrideWith((ref) => items),
              receiptDetailProvider(777).overrideWith(
                (ref) async => _receiptWithReturn(777),
              ),
            ],
            child: MaterialApp(
              theme: PaykTheme.light,
              home: NotificationsScreen(
                nowProvider: () => DateTime(2026, 11, 21, 10, 0),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only the notification with bill_id shows "Открыть чек"
        expect(find.text('Открыть чек'), findsOneWidget);

        await tester.tap(find.text('Открыть чек'));
        await tester.pumpAndSettle();

        expect(api.singleReadIds, [501]);
        expect(find.byType(ReceiptDetailScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('receipt-returns-section')),
          findsOneWidget,
        );

        // Advance past highlight timer so no pending timer remains.
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}
