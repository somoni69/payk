String formatGrouped(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  if (negative) buffer.write('−');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String formatPoints(int value) => formatGrouped(value);

String formatSum(int value) => '${formatGrouped(value)} сум';

String formatNumber(double value, {bool signed = false, bool decimals = true}) {
  final negative = value < 0;
  final abs = value.abs();
  final raw = decimals ? abs.toStringAsFixed(2) : abs.toStringAsFixed(0);
  final parts = raw.split('.');
  final whole = formatGrouped(int.parse(parts[0]));
  final body = decimals ? '$whole,${parts[1]}' : whole;
  final sign = signed && value > 0 ? '+' : (negative ? '−' : '');
  return '$sign$body';
}

String formatMoney(double value, {bool signed = false, bool decimals = true}) {
  return '${formatNumber(value, signed: signed, decimals: decimals)} смн';
}

/// Доля с сервера: 0.02 → «2%», 0.015 → «1,5%».
String formatPercent(double rate) {
  final pct = (rate * 10000).round() / 100;
  final negative = pct < 0;
  final abs = negative ? -pct : pct;
  final text = abs == abs.roundToDouble()
      ? abs.toStringAsFixed(0)
      : abs.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
  return '${negative ? '−' : ''}$text%';
}

String tierName(int level) {
  switch (level) {
    case 2:
      return 'Силвер';
    case 3:
      return 'Голд';
    case 4:
      return 'Платинум';
    case 5:
      return 'Алмаз';
    default:
      return 'Стандарт';
  }
}

String plural(int value, String one, String few, String many) {
  final n10 = value.abs() % 10;
  final n100 = value.abs() % 100;
  if (n10 == 1 && n100 != 11) return one;
  if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) return few;
  return many;
}

String pointsWord(int value) => plural(value, 'балл', 'балла', 'баллов');

String certificatesWord(int value) =>
    plural(value, 'сертификат', 'сертификата', 'сертификатов');

String daysWord(int value) => plural(value, 'день', 'дня', 'дней');

String monthsWord(int value) => plural(value, 'месяц', 'месяца', 'месяцев');

String formatRating(double rating) =>
    rating.toStringAsFixed(1).replaceAll('.', ',');

const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String countdownLabel(DateTime endsAt) {
  final days = endsAt.difference(DateTime.now()).inDays;
  if (days <= 0) return 'Последний день';
  if (days == 1) return 'Остался 1 день';
  return 'Осталось $days ${daysWord(days)}';
}

String formatPhone(String digits) {
  final raw = digits.replaceAll(RegExp(r'\D'), '');
  if (raw.length == 12 && (raw.startsWith('992') || raw.startsWith('998'))) {
    return '+${raw.substring(0, 3)} ${raw.substring(3, 5)} ${raw.substring(5, 8)} ${raw.substring(8, 10)} ${raw.substring(10)}';
  }
  if (raw.length == 9) {
    return '+998 ${raw.substring(0, 2)} ${raw.substring(2, 5)} ${raw.substring(5, 7)} ${raw.substring(7)}';
  }
  return raw.isEmpty ? '' : '+$raw';
}

String companyInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'P';
  return trimmed[0].toUpperCase();
}

String spacedCode(String code) => code.split('').join(' ');
