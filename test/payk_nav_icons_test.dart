import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/widgets/payk_nav_icons.dart';

void main() {
  testWidgets('PaykNavIcon renders all 4 icons without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              PaykNavIcon(type: PaykNavIconType.home, color: Colors.blue),
              PaykNavIcon(type: PaykNavIconType.history, color: Colors.blue),
              PaykNavIcon(type: PaykNavIconType.friends, color: Colors.blue),
              PaykNavIcon(type: PaykNavIconType.profile, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaykNavIcon), findsNWidgets(4));
  });
}
