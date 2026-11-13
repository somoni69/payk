import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/features/auth/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadManrope() async {
  final loader = FontLoader('Manrope');
  for (final file in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Manrope-$file.ttf'));
  }
  await loader.load();
}

void main() {
  testWidgets('status slide adds platinum between gold and diamond', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    await _loadManrope();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: PaykTheme.light, home: const OnboardingScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Дальше'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Силвер'), findsOneWidget);
    expect(find.text('Платинум'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Голд'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Платинум'), findsOneWidget);
    expect(find.text('+6,5%'), findsOneWidget);
    expect(find.text('от 10 000 смн'), findsOneWidget);
    expect(find.text('Либос 20%'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Алмаз'), findsOneWidget);
    expect(find.text('+8%'), findsOneWidget);
    expect(find.text('от 18 000 смн'), findsOneWidget);
    expect(find.text('Либос 25%'), findsOneWidget);
    expect(find.text('Платинум'), findsNothing);
  });
}
