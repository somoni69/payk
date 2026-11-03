class BirthdayGift {
  const BirthdayGift({
    required this.amount,
    required this.from,
    required this.until,
    required this.minClothes,
    required this.minSupermarket,
  });

  final int amount;
  final DateTime from;
  final DateTime until;
  final int minClothes;
  final int minSupermarket;
}

const birthdayCoupon = <int, int>{1: 20, 2: 40, 3: 80, 4: 150, 5: 250};

DateTime birthdayThisYear(DateTime birth, int year) {
  final day = birth.month == 2 && birth.day == 29 && !_leap(year) ? 28 : birth.day;
  return DateTime(year, birth.month, day);
}

bool _leap(int year) => DateTime(year, 2, 29).month == 2;

/// Купон ±7 дней вокруг дня рождения. Окно через Новый год берётся у ближайшей даты.
BirthdayGift? birthdayGift(DateTime? birth, int status, DateTime today) {
  if (birth == null) return null;
  final day = DateTime(today.year, today.month, today.day);
  final candidates = [birthdayThisYear(birth, day.year - 1), birthdayThisYear(birth, day.year), birthdayThisYear(birth, day.year + 1)];
  DateTime? chosen;
  for (final date in candidates) {
    final from = date.subtract(const Duration(days: 7));
    final until = date.add(const Duration(days: 7));
    if (!day.isBefore(from) && !day.isAfter(until)) {
      chosen = date;
      break;
    }
  }
  if (chosen == null) return null;
  final level = status < 1 ? 1 : (status > 5 ? 5 : status);
  final amount = birthdayCoupon[level] ?? 20;
  return BirthdayGift(
    amount: amount,
    from: chosen.subtract(const Duration(days: 7)),
    until: chosen.add(const Duration(days: 7)),
    minClothes: amount * 5,
    minSupermarket: amount * 10,
  );
}
