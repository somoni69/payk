import 'package:flutter/services.dart';

/// Локальные 9 цифр. Вставка `+992 90 123 45 67` приходит без кода страны:
/// префикс уже нарисован слева от поля.
String tajikLocalDigits(String raw) {
  final compact = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  var body = compact;
  if (body.startsWith('+992')) {
    body = body.substring(4);
  } else {
    final digits = body.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('992') && digits.length > 9) {
      body = digits.substring(3);
    }
  }
  final digits = body.replaceAll(RegExp(r'\D'), '');
  return digits.length > 9 ? digits.substring(0, 9) : digits;
}

class TajikPhoneFormatter extends TextInputFormatter {
  const TajikPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final limited = tajikLocalDigits(newValue.text);
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
