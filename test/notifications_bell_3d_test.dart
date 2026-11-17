import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/core/widgets/payk_3d_icon.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/notifications/notifications_screen.dart';

class _TestLocale extends LocaleController {
  @override
  String build() => 'ru';
}

class _FakeApi extends Fake implements LoyaltyApi {
  @override
  Future<int> markMessagesRead({int? upToId}) async => 0;
}

Finder _findBellAsset() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == Bell3dIcon.assetPath,
  );
}

void main() {
  Widget wrap(List<LoyaltyMessageItem> items) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith(_TestLocale.new),
        loyaltyApiProvider.overrideWithValue(_FakeApi()),
        messagesProvider.overrideWith((ref) => items),
      ],
      child: MaterialApp(
        theme: PaykTheme.light,
        home: const NotificationsScreen(),
      ),
    );
  }

  testWidgets('Empty NotificationsScreen uses 3D bell icon', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('Уведомлений пока нет'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.byType(Bell3dIcon), findsOneWidget);
    expect(_findBellAsset(), findsOneWidget);
  });

  testWidgets('Notification cards use 3D bell icon for read and unread messages', (
    tester,
  ) async {
    final items = [
      LoyaltyMessageItem(
        id: 1,
        kind: 'purchase_earn',
        text: 'Начислено 15 бонусов',
        createdAt: DateTime(2026, 11, 17, 12, 0),
        read: false,
      ),
      LoyaltyMessageItem(
        id: 2,
        kind: 'broadcast',
        text: 'Новые поступления в Алмоси',
        createdAt: DateTime(2026, 11, 16, 18, 0),
        read: true,
      ),
      LoyaltyMessageItem(
        id: 3,
        kind: 'size_flash',
        text: 'Скидка 20% на кроссовки',
        createdAt: DateTime(2026, 11, 16, 15, 0),
        read: false,
      ),
    ];

    await tester.pumpWidget(wrap(items));
    await tester.pumpAndSettle();

    expect(find.byType(Bell3dIcon), findsNWidgets(2));
    expect(_findBellAsset(), findsNWidgets(2));
    expect(find.byIcon(Icons.local_offer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
  });
}
