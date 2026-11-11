import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/payment_choice.dart';
import 'package:payk/data/models/models.dart';

PendingCheck sample({
  double y = 20,
  double balance = 20,
  double debt = 0,
  bool wholesale = false,
  String source = 'pos',
  bool coinSuggested = false,
  bool coin10Available = false,
  bool confirmed = false,
  double v = 0,
  bool coin10 = false,
  bool declined = false,
}) {
  return PendingCheck(
    id: 7,
    format: 'SM',
    mode: 'earn',
    v: v,
    clientConfirmed: confirmed,
    amount: 100,
    x0: 5,
    x: 5,
    y: y,
    aStar: 4,
    balance: balance,
    debt: debt,
    isWholesale: wholesale,
    source: source,
    coinSuggested: coinSuggested,
    coin10Available: coin10Available,
    coin10: coin10,
    coinDeclined: declined,
    burnMin: 0.5,
  );
}

void main() {
  test('кешбэк без выбора начисляется сам', () {
    expect(needsChoice(sample(y: 0, balance: 0)), isFalse);
    expect(needsChoice(sample(wholesale: true)), isFalse);
    expect(needsChoice(sample(source: 'sms')), isFalse);
    expect(needsChoice(sample(debt: 3)), isFalse);
  });

  test('окно нужно, если можно списать, кассир предложил округление или выбор уже есть', () {
    expect(needsChoice(sample()), isTrue);
    expect(
      needsChoice(
        sample(y: 0, balance: 0, coinSuggested: true, coin10Available: true),
      ),
      isTrue,
    );
    expect(needsChoice(sample(y: 0, balance: 0, confirmed: true)), isTrue);
  });

  test('списание зажимается в минимум и максимум', () {
    final check = sample();
    expect(clampBurn(0, check), 0);
    expect(clampBurn(0.2, check), 0.5);
    expect(clampBurn(3.456, check), 3.46);
    expect(clampBurn(40, check), 20);
  });

  test('ключ выбора совпадает с тем, что уже лежит в чеке', () {
    final check = sample(v: 2, coin10: true, declined: false);
    expect(choiceKeyOf(check), choiceKey(2, true, false));
    expect(choiceKeyOf(sample(declined: true)), choiceKey(0, false, true));
  });

  test('отмену тихого чека не объявляем, проведённый — объявляем', () {
    final quiet = sample(y: 0, balance: 0);
    const cancelled = ClosedBill(id: 7, state: 'cancelled');
    const committed = ClosedBill(
      id: 7,
      state: 'committed',
      earn: 1.5,
      round: 0.4,
    );
    expect(shouldAnnounceClose(closed: cancelled, previous: quiet), isFalse);
    expect(shouldAnnounceClose(closed: committed, previous: quiet), isTrue);
    expect(shouldAnnounceClose(closed: cancelled, previous: sample()), isTrue);
  });

  test('журнал режет операции так же, как сервер', () {
    expect(historyTypeInCategory('round', 'purchases'), isTrue);
    expect(historyTypeInCategory('round', 'burn'), isTrue);
    expect(historyTypeInCategory('refund', 'burn'), isFalse);
    expect(historyTypeInCategory('referral_reversal', 'returns'), isTrue);
    expect(historyTypeInCategory('accrual', 'all'), isTrue);
  });

  test('ответ чека v1.4 разбирается в модель', () {
    final check = PendingCheck.fromJson({
      'id': 4,
      'state': 'pending',
      'format': 'CL',
      'bill_ext_id': 'A-15',
      'amount': 80,
      'x0': 4,
      'x': 3.5,
      'y': 10,
      'a_star': 6,
      'mode': 'earn_burn',
      'v': 2,
      'r': 0.4,
      'coin10': false,
      'coin10_available': true,
      'coin_declined': true,
      'coin_suggested': true,
      'card_amount': 20,
      'to_pay': 57.6,
      'cash_to_pay': 37.6,
      'client_confirmed': false,
      'burn_min': 0.5,
      'balance': 30,
      'debt': 0,
    });
    expect(check.billExtId, 'A-15');
    expect(check.v, 2);
    expect(check.aStar, 6);
    expect(check.coinDeclined, isTrue);
    expect(check.cashToPay, 37.6);
    expect(needsChoice(check), isTrue);
  });
}
