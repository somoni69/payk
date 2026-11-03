import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/check_quote.dart';
import 'package:payk/core/format.dart';

void main() {
  CheckQuote goldSm(double amount, double balance, double voluntary) {
    return quoteCheck(
      amount: amount,
      earnRate: 0.05,
      burnCap: 1246 * 0.02,
      balance: balance,
      burnMin: 0.50,
      stackPct: 0.05,
      stackAbs: 9.99,
      voluntary: voluntary,
      coin: false,
      toTen: false,
    );
  }

  test('пять статусов и пороги', () {
    expect(tierName(1), 'Стандарт');
    expect(tierName(4), 'Платинум');
    expect(tierName(5), 'Алмаз');
  });

  test('голд, супермаркет, 1246', () {
    final plain = goldSm(1246, 200, 0);
    expect(plain.x0, 62.30);
    expect(plain.a, 24.92);
    expect(plain.y, 24.92);
    expect(plain.mode, 'earn');

    final small = goldSm(1246, 200, 6);
    expect(small.x, 62.00);
    expect(small.mode, 'earn_burn');

    final larger = goldSm(1246, 200, 16);
    expect(larger.x, 61.50);
    expect(larger.mode, 'earn_burn');
  });

  test('голд, либос, танга и то даҳӣ', () {
    final base = quoteCheck(
      amount: 1023.45,
      earnRate: 0.15,
      burnCap: 204.69,
      balance: 1240,
      burnMin: 0.50,
      stackPct: 0.05,
      stackAbs: 9.99,
      voluntary: 0,
      coin: true,
      toTen: false,
    );
    expect(base.x0, 153.51);
    expect(base.a, 51.17);
    expect(base.r, 0.45);
    expect(base.x, 153.45);
    expect(base.cash, 1023.00);

    final spent = quoteCheck(
      amount: 1023.45,
      earnRate: 0.15,
      burnCap: 204.69,
      balance: 1240,
      burnMin: 0.50,
      stackPct: 0.05,
      stackAbs: 9.99,
      voluntary: 40,
      coin: true,
      toTen: false,
    );
    expect(spent.r, 0.45);
    expect(spent.x, 147.45);
    expect(spent.cash, 983.00);
    expect(spent.mode, 'earn_burn');

    final tens = quoteCheck(
      amount: 1023.45,
      earnRate: 0.15,
      burnCap: 204.69,
      balance: 1240,
      burnMin: 0.50,
      stackPct: 0.05,
      stackAbs: 9.99,
      voluntary: 40,
      coin: true,
      toTen: true,
    );
    expect(tens.r, 3.45);
    expect(tens.x, 147.00);
    expect(tens.cash, 980.00);

    final full = quoteCheck(
      amount: 1000,
      earnRate: 0.15,
      burnCap: 200,
      balance: 500,
      burnMin: 0.50,
      stackPct: 0.05,
      stackAbs: 9.99,
      voluntary: 200,
      coin: false,
      toTen: false,
    );
    expect(full.a, 50);
    expect(full.x, 0);
    expect(full.mode, 'burn');
  });
}
