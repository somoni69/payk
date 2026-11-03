import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/app/payk_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Payk opens the phone step after splash', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: PaykApp()));
    expect(find.text('Карты лояльности'), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Получить код'), findsOneWidget);
    expect(find.text('Ввести 000000'), findsNothing);
    expect(find.textContaining('Демо'), findsNothing);
  });
}
