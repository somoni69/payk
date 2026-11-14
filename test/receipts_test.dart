import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/format.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/history/history_screen.dart';
import 'package:payk/features/history/receipt_detail_screen.dart';

class _FakeReceiptsApi extends Fake implements LoyaltyApi {
  String? lastFmt;

  @override
  Future<ReceiptsPage> receipts({
    int? beforeId,
    String? dFrom,
    String? dTo,
    String? fmt,
    String? q,
  }) async {
    lastFmt = fmt;
    return const ReceiptsPage(
      header: ReceiptsHeader(
        month: '2026-11',
        spendMonth: 0,
        bills: 0,
        earned: 0,
        spent: 0,
        toNext: 1800,
      ),
      months: [],
      items: [],
    );
  }
}

void main() {
  test('receipt models and formatters parse full receipt payload', () {
    final page = ReceiptsPage.fromJson({
      'header': {
        'month': '2026-11',
        'spend_month': '1250.00',
        'bills': 4,
        'earned': '62.50',
        'spent': '100.00',
        'to_next': '750.00',
      },
      'months': [
        {
          'month': '2026-11',
          'bills': 4,
          'amount': '1250.00',
          'earned': '62.50',
          'spent': '100.00',
        },
      ],
      'items': [
        {
          'id': 42,
          'ts': '2026-11-12T10:15:30Z',
          'store': 'MSX Алмоси',
          'format': 'SM',
          'number': 'CHK-0042',
          'amount': '350.00',
          'earn': '17.50',
          'burn': '0.00',
          'round': '0.00',
          'coupon': '0.00',
          'mode': 'earn',
          'state': 'ok',
          'items_status': 'ok',
        },
      ],
      'next_before_id': 41,
    });

    expect(page.header?.bills, 4);
    expect(page.header?.toNext, 750.0);
    expect(page.months.single.month, '2026-11');
    expect(page.items.single.id, 42);
    expect(page.nextBeforeId, 41);

    expect(receiptsCountLabel('ru', 1), '1 чек');
    expect(receiptsCountLabel('ru', 4), '4 чека');
    expect(receiptsCountLabel('ru', 5), '5 чеков');
    expect(formatRatePct(0.05), '5\u00A0%');
    expect(formatQty(2, 'шт'), '2');
    expect(formatQty(0.5, 'кг'), '0,5\u00A0кг');
  });

  testWidgets('ReceiptDetailScreen renders items, totals, and claim sheet trigger', (tester) async {
    final view = ReceiptView.fromJson({
      'id': 99,
      'ts': '2026-11-12T14:20:05Z',
      'store': 'Либос Центр',
      'format': 'CL',
      'terminal': 'POS-3',
      'number': '9001',
      'lines': [
        {
          'line_no': 1,
          'name': 'Куртка зимняя',
          'qty': '1',
          'unit': 'шт',
          'price': '450.00',
          'amount': '450.00',
          'returned_qty': '0',
          'returned_amount': '0',
          'state': 'ok',
          'estimated': false,
          'returned': false,
        },
      ],
      'items_status': 'ok',
      'amount_before_coupon': '450.00',
      'coupon': '0.00',
      'amount': '450.00',
      'burn': '50.00',
      'round': '0.00',
      'b': '0.00',
      'mode': 'earn_burn',
      'pay': {'cash': '0.00', 'card': '400.00'},
      'earn': '20.00',
      'rate': {'pct': '0.05', 'status': 2},
      'balance_after': '120.00',
      'spend_contribution': '400.00',
      'spend_after': '1400.00',
      'returns': const [],
      'state': 'ok',
      'claim': null,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptDetailProvider(99).overrideWith((ref) => view),
        ],
        child: MaterialApp(
          theme: PaykTheme.light,
          home: const ReceiptDetailScreen(receiptId: 99),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Чек № 9001'), findsOneWidget);
    expect(find.text('Куртка зимняя'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ошибка в чеке?'), 200);
    expect(find.text('Оплата (картой)'), findsOneWidget);
    expect(find.text('Ошибка в чеке?'), findsOneWidget);
  });

  testWidgets('HistoryScreen bills tab uses 3D icons, custom format tiles, and animated tab switch', (tester) async {
    final fakeApi = _FakeReceiptsApi();
    const account = Account(
      store: 'MSX',
      member: Member(
        id: 1,
        firstName: 'Тест',
        lastName: 'Юзер',
        phone: '+992900000001',
        referralCode: 'REF',
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
          supermarket: Rate(earn: 0.03, burnCap: 0.5),
          clothes: Rate(earn: 0.05, burnCap: 0.5),
        ),
        todaySupermarket: 0,
        todayClothes: 0,
      ),
      programEnabled: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loyaltyApiProvider.overrideWithValue(fakeApi),
          meProvider.overrideWith((ref) => account),
          historyProvider.overrideWith((ref) => const []),
        ],
        child: MaterialApp(
          theme: PaykTheme.light,
          home: const HistoryScreen(initialTab: HistoryTab.bills),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Чеков пока нет'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/3d/receipt.webp',
      ),
      findsWidgets,
    );

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Супермаркет'), findsOneWidget);
    expect(find.text('Либос'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('Супермаркет'));
    await tester.pumpAndSettle();
    expect(fakeApi.lastFmt, 'SM');

    await tester.tap(find.text('Операции'));
    await tester.pumpAndSettle();
    expect(find.text('Категории'), findsOneWidget);

    final searchRect = tester.getRect(find.byType(TextField));
    final tabBarRect = tester.getRect(find.text('Операции'));
    final billsTabRect = tester.getRect(find.text('Чеки'));
    expect(searchRect.left, 16.0);
    expect(searchRect.right, 784.0);
    expect(tabBarRect.left, greaterThanOrEqualTo(searchRect.left));
    expect(billsTabRect.right, lessThanOrEqualTo(searchRect.right));
  });
}
