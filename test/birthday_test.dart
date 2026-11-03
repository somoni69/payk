import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/birthday.dart';

void main() {
  test('окно купона вокруг 15 ноября', () {
    final gift = birthdayGift(DateTime(1992, 11, 15), 3, DateTime(2026, 11, 15));
    expect(gift, isNotNull);
    expect(gift!.amount, 80);
    expect(gift.from, DateTime(2026, 11, 8));
    expect(gift.until, DateTime(2026, 11, 22));
    expect(gift.minClothes, 400);
    expect(gift.minSupermarket, 800);
  });

  test('вне окна купона нет', () {
    expect(birthdayGift(DateTime(1992, 11, 15), 1, DateTime(2026, 6, 1)), isNull);
  });

  test('29 февраля в невисокосный год — 28 февраля', () {
    final gift = birthdayGift(DateTime(1996, 2, 29), 5, DateTime(2027, 2, 28));
    expect(gift!.amount, 250);
    expect(gift.from, DateTime(2027, 2, 21));
  });
}
