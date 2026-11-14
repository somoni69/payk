import '../data/models/models.dart';

enum OfferAction { claim, code, issued, none }

const shoeSizeRows = [
  ['36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'],
  ['36.5', '37.5', '38.5', '39.5', '40.5', '41.5', '42.5', '43.5', '44.5', '45.5'],
];

const pantsSizeRows = [
  ['28', '30', '32', '34', '36', '38', '40', '42', '44', '46', '48', '50', '52', '54', '56', '58', '60'],
  ['S', 'M', 'L', 'XL', '2XL', '3XL'],
];

const topSizeRows = [
  ['S', 'M', 'L', 'XL', '2XL', '3XL', '4XL'],
  ['46', '48', '50', '52', '54', '56', '58', '60'],
];

/// Как сервер: без пробелов, латиница в верхнем регистре, «40,5» → «40.5».
String normalizeSize(String? value) {
  if (value == null) return '';
  return value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(',', '.')
      .replaceAll('\u0425', 'X')
      .replaceAll('\u041C', 'M')
      .replaceAll('\u0410', 'A');
}

/// Если магазин вписал размер, которого нет среди чипов (например «XXL»),
/// добавляем его в конец последнего ряда, чтобы клиент видел выбор.
List<List<String>> rowsWithCurrentSize(
  List<List<String>> baseRows,
  String? current,
) {
  final rows = [for (final row in baseRows) [...row]];
  final norm = normalizeSize(current);
  if (norm.isNotEmpty && !rows.any((row) => row.contains(norm))) {
    rows.last.add(norm);
  }
  return rows;
}

/// Повторное нажатие на выбранный размер снимает выбор.
String? toggleSizeSelection(String? current, String value) {
  final normCurrent = normalizeSize(current);
  final normValue = normalizeSize(value);
  if (normCurrent == normValue) return null;
  return value;
}

/// Только изменённые поля; снятый размер уходит как null.
Map<String, String?> buildSizesPatch({
  required String? initialShoe,
  required String? initialPants,
  required String? initialTop,
  required String? draftShoe,
  required String? draftPants,
  required String? draftTop,
}) {
  final patch = <String, String?>{};
  void compare(String field, String? before, String? after) {
    final b = normalizeSize(before);
    final a = normalizeSize(after);
    if (b != a) patch[field] = a.isEmpty ? null : a;
  }

  compare('shoe_size', initialShoe, draftShoe);
  compare('pants_size', initialPants, draftPants);
  compare('top_size', initialTop, draftTop);
  return patch;
}

bool isSizesEmpty(Member member) {
  return normalizeSize(member.shoeSize).isEmpty &&
      normalizeSize(member.pantsSize).isEmpty &&
      normalizeSize(member.topSize).isEmpty;
}

/// Скидка в процентах, округлённая вниз: 1200 → 700 даёт 41. Нет скидки — null.
int? discountPercent(double? original, double? discount) {
  if (original == null || discount == null || original <= 0 || discount >= original) {
    return null;
  }
  final pct = (((original - discount) / original) * 100 + 1e-9).floor();
  return pct > 0 ? pct : null;
}

/// Статус «сейчас» по часам сервера.
String liveOfferStatus(SizeOffer offer, DateTime now) {
  if (offer.status == 'SOLD_OUT') return 'SOLD_OUT';
  if (offer.status != 'ACTIVE') return 'EXPIRED';
  if (offer.expiresAt == null) return 'ACTIVE';
  return offer.remainingAt(now) <= Duration.zero ? 'EXPIRED' : 'ACTIVE';
}

final _conflictSoldOut = RegExp(r'распродан', caseSensitive: false);
final _conflictExpired = RegExp(r'срок', caseSensitive: false);

/// «Забрать» вернул 409: причина по тексту сервера, иначе по оставшемуся времени.
String statusAfterOfferConflict(
  SizeOffer offer,
  DateTime now, {
  String? detail,
}) {
  final text = detail ?? '';
  if (_conflictSoldOut.hasMatch(text)) return 'SOLD_OUT';
  if (_conflictExpired.hasMatch(text)) return 'EXPIRED';
  if (offer.expiresAt != null && offer.remainingAt(now) <= const Duration(seconds: 60)) {
    return 'EXPIRED';
  }
  return 'SOLD_OUT';
}

/// Свежий список поверх того, что на экране, без отката кода, «Получено» и финальных статусов.
List<SizeOffer> mergeSizeOffers(
  List<SizeOffer>? prev,
  List<SizeOffer> next,
) {
  if (prev == null || prev.isEmpty) return List<SizeOffer>.from(next);
  final known = {for (final offer in prev) offer.id: offer};
  return [
    for (final offer in next)
      _mergeOffer(known[offer.id], offer),
  ];
}

SizeOffer _mergeOffer(SizeOffer? old, SizeOffer fresh) {
  if (old == null) return fresh;
  var claimed = fresh.claimed;
  var promoCode = fresh.promoCode;
  if (old.claimed && (old.promoCode ?? '').isNotEmpty && !(fresh.claimed && (fresh.promoCode ?? '').isNotEmpty)) {
    claimed = true;
    promoCode = old.promoCode;
  }
  final issued = old.issued || fresh.issued;
  final status = (old.status != 'ACTIVE' && fresh.status == 'ACTIVE') ? old.status : fresh.status;
  return fresh.copyWith(
    claimed: claimed,
    promoCode: promoCode,
    issued: issued,
    status: status,
  );
}

OfferAction resolveOfferAction(SizeOffer offer, String liveStatus) {
  if (offer.issued) return OfferAction.issued;
  if (liveStatus != 'ACTIVE') return OfferAction.none;
  if (offer.claimed && (offer.promoCode ?? '').isNotEmpty) {
    return OfferAction.code;
  }
  return OfferAction.claim;
}

bool showOfferOnHome(SizeOffer offer, String liveStatus) {
  return liveStatus == 'ACTIVE' && !offer.issued;
}

/// «AB3K9Q» → «AB3 K9Q».
String formatPromoCode(String? code) {
  final text = (code ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (text.length <= 4) return text;
  final half = (text.length / 2).ceil();
  return '${text.substring(0, half)} ${text.substring(half)}';
}

/// «05:12:33», больше суток — «2 д 05:12:33».
String formatOfferCountdownWithDays(Duration value, String dayShort) {
  final total = value.isNegative ? 0 : value.inSeconds;
  final days = total ~/ 86400;
  final hours = (total % 86400) ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  final clock = '${two(hours)}:${two(minutes)}:${two(seconds)}';
  return days > 0 ? '$days\u00A0$dayShort $clock' : clock;
}
