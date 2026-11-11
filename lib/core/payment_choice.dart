import '../data/models/models.dart';
import 'format.dart';
import 'i18n/strings.dart';

/// Допуск при сравнении сумм в сомони. Как в loyalty-app.
const paymentAmountEps = 0.004;

double burnMinOf(PendingCheck check) => check.burnMin > 0 ? check.burnMin : 0.5;

bool isNoAppCheck(PendingCheck check) =>
    check.source == 'sms' || check.source == 'late';

/// Можно оплатить этот чек бонусами: есть минимум, нет долга, чек не оптовый и не без приложения.
bool canBurnOn(PendingCheck check) {
  return (check.y ?? 0) >= burnMinOf(check) &&
      (check.debt ?? 0) <= 0 &&
      !isNoAppCheck(check) &&
      !check.isWholesale;
}

/// Окно нужно, только если есть что выбрать. Иначе кешбэк начисляется сам.
bool needsChoice(PendingCheck check) {
  return canBurnOn(check) ||
      (check.coinSuggested && check.coin10Available) ||
      check.clientConfirmed;
}

double clampBurn(double value, PendingCheck check) {
  final max = check.y ?? 0;
  final min = burnMinOf(check);
  if (value <= 0 || max < min) return 0;
  final next = value < min ? min : value;
  final capped = next > max ? max : next;
  return (capped * 100).round() / 100.0;
}

String choiceKey(double burn, bool coin10, bool noCoin) {
  return '${burn.toStringAsFixed(2)}|${coin10 ? 1 : 0}|${noCoin ? 1 : 0}';
}

String choiceKeyOf(PendingCheck check) {
  final noCoin = check.coinDeclined && !check.coin10;
  return choiceKey(check.v, check.coin10, noCoin);
}

bool sameCheckNumbers(PendingCheck a, PendingCheck b) {
  return a.amount == b.amount &&
      a.x0 == b.x0 &&
      a.y == b.y &&
      a.cardAmount == b.cardAmount &&
      a.coin10Available == b.coin10Available &&
      a.toPay == b.toPay;
}

/// Текст после закрытия чека: кешбэк, списание и танга.
String closedCheckText(String locale, ClosedBill closed) {
  if (closed.state != 'committed') return tr(locale, 'pay.cancelledByCashier');
  final parts = <String>[];
  final earn = closed.earn ?? 0;
  final burn = closed.burn ?? 0;
  final round = closed.round ?? 0;
  if (earn > 0) {
    parts.add(tr(locale, 'pay.part.earn', {'amount': formatMoney(earn)}));
  }
  if (burn > 0) {
    parts.add(tr(locale, 'pay.part.burn', {'amount': formatMoney(burn)}));
  }
  if (round > 0) {
    parts.add(tr(locale, 'pay.part.round', {'amount': formatMoney(round)}));
  }
  if (parts.isEmpty) return tr(locale, 'pay.recorded');
  return tr(locale, 'pay.recordedParts', {'parts': parts.join(' · ')});
}

/// Отменённый чек, который клиент не выбирал, не показываем.
bool shouldAnnounceClose({
  required ClosedBill closed,
  required PendingCheck? previous,
}) {
  if (closed.state == 'committed') return true;
  if (previous == null || previous.id != closed.id) return false;
  return needsChoice(previous) || previous.clientConfirmed;
}

/// Категории журнала — те же типы, что сервер отдаёт по `cat`.
bool historyTypeInCategory(String type, String category) {
  const groups = {
    'purchases': {'accrual', 'burn', 'round'},
    'accrual': {'accrual'},
    'burn': {'burn', 'round'},
    'returns': {'reversal', 'refund', 'referral_reversal'},
    'friends': {'referral', 'referral_reversal'},
  };
  final types = groups[category];
  if (types == null) return true;
  return types.contains(type);
}
