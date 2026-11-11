import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/core/widgets/tajik_phone_field.dart';
import 'package:payk/features/auth/auth_screens.dart';
import 'package:payk/features/profile/phone_change_screen.dart';

void main() {
  test('pasted Tajik number drops the country code', () {
    expect(tajikLocalDigits('+992 90 123 45 67'), '901234567');
    expect(tajikLocalDigits('+992 901 23 45 67'), '901234567');
    expect(tajikLocalDigits('+992901234567'), '901234567');
    expect(tajikLocalDigits('992 90 123 45 67'), '901234567');
    expect(tajikLocalDigits('90 123 45 67'), '901234567');
  });

  testWidgets('login field keeps nine local digits after pasting +992', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PhoneScreen())),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '+992 90 123 45 67');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '90 123 45 67');
  });

  testWidgets('phone change field drops 992 the same way', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: PaykTheme.light, home: const PhoneChangeScreen()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '+992 90 099 91 39');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '90 099 91 39');
  });
}
