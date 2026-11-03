/// Расчёт чека по ТЗ v1.2 (п. 3.4 и 3.4.1). Деньги — в центах, округление вниз.
class CheckQuote {
  const CheckQuote({
    required this.cap,
    required this.a,
    required this.y,
    required this.x0,
    required this.v,
    required this.r,
    required this.b,
    required this.x,
    required this.cash,
    required this.mode,
  });

  final double cap;
  final double a;
  final double y;
  final double x0;
  final double v;
  final double r;
  final double b;
  final double x;
  final double cash;
  final String mode;

  bool get keepsCashback => mode != 'burn';
}

int floorCents(double value) {
  if (value <= 0) return 0;
  final scaled = value * 100;
  final nearest = scaled.round();
  if ((scaled - nearest).abs() < 1e-6) return nearest;
  return scaled.floor();
}

double floorMoney(double value) => floorCents(value) / 100;

double _tail(double cash, double unit) {
  if (unit <= 0 || cash <= 0) return 0;
  final steps = (cash / unit).floor();
  return floorMoney(cash - steps * unit);
}

CheckQuote quoteCheck({
  required double amount,
  required double earnRate,
  required double burnCap,
  required double balance,
  required double burnMin,
  required double stackPct,
  required double stackAbs,
  required double voluntary,
  required bool coin,
  required bool toTen,
}) {
  final s = floorMoney(amount);
  final cap = floorMoney(burnCap);
  final small = floorMoney(stackPct * s);
  final threshold = cap < (stackAbs > small ? stackAbs : small) ? cap : (stackAbs > small ? stackAbs : small);
  final y = balance <= 0 ? 0.0 : floorMoney(balance < cap ? balance : cap);
  final x0 = floorMoney(earnRate * s);
  final v = floorMoney(voluntary);
  final cashBefore = floorMoney(s - v);
  final tail = cashBefore > 0 ? _tail(cashBefore, toTen ? 10 : 1) : 0.0;
  var r = 0.0;
  if (coin && cashBefore > 0 && tail > 0) {
    final trial = v + tail;
    final keepsMode = v <= threshold && trial > threshold;
    if (trial <= cap && balance + 1e-9 >= trial && !keepsMode) r = tail;
  }
  final b = floorMoney(v + r);
  final mode = b <= 0 ? 'earn' : (b <= threshold ? 'earn_burn' : 'burn');
  final x = mode == 'burn' ? 0.0 : floorMoney(earnRate * (s - b));
  return CheckQuote(
    cap: cap,
    a: threshold,
    y: y,
    x0: x0,
    v: v,
    r: r,
    b: b,
    x: x,
    cash: floorMoney(s - b),
    mode: mode,
  );
}

/// Добровольное списание: 0 или от минимума до Y.
double clampVoluntary(double value, double maxBurn, double burnMin) {
  if (value <= 0 || maxBurn < burnMin) return 0;
  final next = value < burnMin ? burnMin : value;
  return floorMoney(next > maxBurn ? maxBurn : next);
}
