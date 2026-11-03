import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/app/payk_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Payk opens onboarding after splash on clean install', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: PaykApp()));

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(find.text('Кэшбэк с каждой покупки'), findsOneWidget);
    expect(find.text('Страница не найдена'), findsNothing);
  });

  testWidgets('Payk opens the phone step after splash if onboarding seen', (tester) async {
    SharedPreferences.setMockInitialValues({'payk.onboarding': true});
    await tester.pumpWidget(const ProviderScope(child: PaykApp()));

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(find.text('Получить код'), findsOneWidget);
    expect(find.text('Ввести 000000'), findsNothing);
    expect(find.textContaining('Демо'), findsNothing);
    expect(find.text('Страница не найдена'), findsNothing);
  });
}
