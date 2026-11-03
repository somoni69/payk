import 'api_exception.dart';

Map<String, dynamic> asMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw ApiException(0, 'Неожиданный ответ сервера');
}

double asMoney(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value.replaceAll(',', '.'));
  return 0;
}

double? asMoneyOrNull(Object? value) {
  if (value == null) return null;
  return asMoney(value);
}

int asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  return asInt(value);
}

String asString(Object? value) => value is String ? value : '';

String? asStringOrNull(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

DateTime asDate(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.parse(value).toLocal();
  throw ApiException(0, 'Неожиданный ответ сервера');
}

List<double> asDoubleList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) asMoney(item)];
}
