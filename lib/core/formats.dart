import 'i18n/strings.dart';

/// Все форматы магазина в порядке показа: Супермаркет, Либос, Ресторан.
const List<String> allStoreFormats = ['SM', 'CL', 'RS'];

/// Форматы, которыми пользуется магазин; нет поля (старый сервер) или оно пустое — все.
List<String> usedFormats(Iterable<String>? formats) {
  if (formats == null) return allStoreFormats;
  final set = formats.toSet();
  final known = [
    for (final fmt in allStoreFormats)
      if (set.contains(fmt)) fmt,
  ];
  return known.isNotEmpty ? known : allStoreFormats;
}

/// Активные форматы для отображения.
/// Если сервер явно прислал `formats`, возвращаем [usedFormats].
/// Если поля `formats` нет (`null` от старого сервера) и нет ставок ресторана,
/// оставляем `['SM', 'CL']`, чтобы не показывать пустые нулевые ставки «Ресторан».
List<String> resolveActiveFormats(
  Iterable<String>? formats, {
  bool hasRestaurant = true,
}) {
  if (formats != null) return usedFormats(formats);
  return hasRestaurant ? allStoreFormats : const ['SM', 'CL'];
}

/// Формат из сохранённого/пришедшего значения или `null`, если такого формата нет.
String? parseFormat(Object? value) {
  if (value is! String) return null;
  for (final fmt in allStoreFormats) {
    if (fmt == value) return fmt;
  }
  return null;
}

/// Парсинг поля `formats` из ответа API (`null`, если сервер не прислал поле).
List<String>? parseFormatsField(Object? value) {
  if (value is! List) return null;
  return [for (final item in value) ?parseFormat(item)];
}

/// Локализованное полное название формата («Супермаркет» / «Либос» / «Ресторан») или `null`.
String? formatName(String locale, Object? format) {
  final parsed = parseFormat(format);
  if (parsed == null) return null;
  return tr(locale, 'format.$parsed');
}

/// Локализованное короткое название формата («СМ» / «Л» / «Р») или `null`.
String? formatShortName(String locale, Object? format) {
  final parsed = parseFormat(format);
  if (parsed == null) return null;
  return tr(locale, 'format.short.$parsed');
}
