import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/format.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/notifications/notifications_screen.dart';

class _LocaleStub extends LocaleController {
  _LocaleStub(this._locale);
  final String _locale;

  @override
  String build() => _locale;
}

class _FakeLoyaltyApi extends Fake implements LoyaltyApi {
  _FakeLoyaltyApi({this.nextPage = const []});

  final List<LoyaltyMessageItem> nextPage;

  @override
  Future<int> markMessagesRead({int? upToId}) async => 0;

  @override
  Future<List<LoyaltyMessageItem>> messages({int? beforeId}) async => nextPage;
}

void main() {
  group('Date/time & day section formatters', () {
    final now = DateTime(2026, 11, 21, 10, 30);

    test('formatDateTime includes day, month, year and HH:mm', () {
      expect(
        formatDateTime(DateTime(2026, 11, 20, 20, 6)),
        '20 ноября 2026 · 20:06',
      );
      expect(
        formatDateTime(DateTime(2026, 11, 20, 8, 5)),
        '20 ноября 2026 · 08:05',
      );
      expect(
        formatDateTime(DateTime(2026, 11, 20, 20, 6), locale: 'tj'),
        '20 ноябри 2026 · 20:06',
      );
    });

    test('formatDayHeader formats today, yesterday, same year and past year', () {
      expect(
        formatDayHeader(DateTime(2026, 11, 21, 0, 1), 'ru', now: now),
        'Сегодня, 21 ноября',
      );
      expect(
        formatDayHeader(DateTime(2026, 11, 20, 23, 59), 'ru', now: now),
        'Вчера, 20 ноября',
      );
      expect(
        formatDayHeader(DateTime(2026, 11, 18, 14, 0), 'ru', now: now),
        '18 ноября',
      );
      expect(
        formatDayHeader(DateTime(2025, 12, 28, 14, 0), 'ru', now: now),
        '28 декабря 2025',
      );

      expect(
        formatDayHeader(DateTime(2026, 11, 21, 9, 0), 'tj', now: now),
        'Имрӯз, 21 ноябр',
      );
      expect(
        formatDayHeader(DateTime(2026, 11, 20, 19, 0), 'tj', now: now),
        'Дирӯз, 20 ноябр',
      );
      expect(
        formatDayHeader(DateTime(2026, 11, 18, 14, 0), 'tj', now: now),
        '18 ноябр',
      );
      expect(
        formatDayHeader(DateTime(2025, 12, 28, 14, 0), 'tj', now: now),
        '28 декабри 2025',
      );
    });
  });

  group('NotificationsScreen day sections and time rendering', () {
    final fixedNow = DateTime(2026, 11, 21, 12, 0);

    Widget buildApp(
      List<LoyaltyMessageItem> items, {
      String locale = 'ru',
      LoyaltyApi? api,
    }) {
      return ProviderScope(
        overrides: [
          localeProvider.overrideWith(() => _LocaleStub(locale)),
          loyaltyApiProvider.overrideWithValue(api ?? _FakeLoyaltyApi()),
          messagesProvider.overrideWith((ref) => items),
        ],
        child: MaterialApp(
          theme: PaykTheme.light,
          home: NotificationsScreen(nowProvider: () => fixedNow),
        ),
      );
    }

    testWidgets('groups notifications by calendar day and displays HH:mm', (
      tester,
    ) async {
      final items = [
        LoyaltyMessageItem(
          id: 4,
          kind: 'purchase_earn',
          text: 'Покупка сегодня утром',
          createdAt: DateTime(2026, 11, 21, 9, 15),
          read: false,
        ),
        LoyaltyMessageItem(
          id: 3,
          kind: 'purchase_earn',
          text: 'Покупка вчера вечером',
          createdAt: DateTime(2026, 11, 20, 20, 6),
          read: false,
        ),
        LoyaltyMessageItem(
          id: 2,
          kind: 'purchase_return',
          text: 'Возврат вчера днём',
          createdAt: DateTime(2026, 11, 20, 18, 56),
          read: true,
        ),
        LoyaltyMessageItem(
          id: 1,
          kind: 'broadcast',
          text: 'Старое сообщение прошлого года',
          createdAt: DateTime(2025, 12, 28, 8, 5),
          read: true,
        ),
      ];

      await tester.pumpWidget(buildApp(items));
      await tester.pumpAndSettle();

      // Day headers
      expect(find.text('Сегодня, 21 ноября'), findsOneWidget);
      expect(find.text('Вчера, 20 ноября'), findsOneWidget);

      // Card date + time with hours and minutes
      expect(find.text('21 ноября 2026 · 09:15'), findsOneWidget);
      expect(find.text('20 ноября 2026 · 20:06'), findsOneWidget);
      expect(find.text('20 ноября 2026 · 18:56'), findsOneWidget);

      // Group count pills: 1 today, 2 yesterday, 1 on 28 Dec 2025
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsAtLeastNWidgets(1));

      // Scroll down to verify older year header & formatted time
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('28 декабря 2025'), findsOneWidget);
      expect(find.text('28 декабря 2025 · 08:05'), findsOneWidget);
    });

    testWidgets('pagination merges same-day items into one day header', (
      tester,
    ) async {
      final firstPage = [
        for (var i = 0; i < 30; i++)
          LoyaltyMessageItem(
            id: 100 - i,
            kind: 'purchase_earn',
            text: 'Покупка #$i',
            createdAt: DateTime(2026, 11, 20, 20, 30 - i),
            read: true,
          ),
      ];
      final secondPage = [
        LoyaltyMessageItem(
          id: 50,
          kind: 'purchase_return',
          text: 'Догруженный возврат за тот же день',
          createdAt: DateTime(2026, 11, 20, 12, 15),
          read: true,
        ),
      ];

      await tester.pumpWidget(
        buildApp(firstPage, api: _FakeLoyaltyApi(nextPage: secondPage)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Вчера, 20 ноября'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(OutlinedButton),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      // Scroll back to top: still only one header for 20 Nov, now with count 31
      await tester.scrollUntilVisible(
        find.text('Вчера, 20 ноября'),
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Вчера, 20 ноября'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
    });

    testWidgets('renders Tajik day headers and date-time cleanly', (
      tester,
    ) async {
      final items = [
        LoyaltyMessageItem(
          id: 2,
          kind: 'purchase_earn',
          text: 'Харид имрӯз',
          createdAt: DateTime(2026, 11, 21, 10, 4),
          read: false,
        ),
        LoyaltyMessageItem(
          id: 1,
          kind: 'purchase_return',
          text: 'Бозгашт дирӯз',
          createdAt: DateTime(2026, 11, 20, 20, 6),
          read: true,
        ),
      ];

      await tester.pumpWidget(buildApp(items, locale: 'tj'));
      await tester.pumpAndSettle();

      expect(find.text('Имрӯз, 21 ноябр'), findsOneWidget);
      expect(find.text('Дирӯз, 20 ноябр'), findsOneWidget);
      expect(find.text('21 ноябри 2026 · 10:04'), findsOneWidget);
      expect(find.text('20 ноябри 2026 · 20:06'), findsOneWidget);
    });

    testWidgets('no overflow on narrow screen with clamped 1.25 text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final items = [
        LoyaltyMessageItem(
          id: 1,
          kind: 'purchase_earn',
          text: 'Тест узкого экрана',
          createdAt: DateTime(2026, 11, 21, 20, 6),
          read: false,
        ),
      ];

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
          child: buildApp(items),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Сегодня, 21 ноября'), findsOneWidget);
      expect(find.text('21 ноября 2026 · 20:06'), findsOneWidget);
    });
  });
}
