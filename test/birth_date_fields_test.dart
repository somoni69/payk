import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/widgets/birth_date_fields.dart';

void main() {
  final first = DateTime(1920);
  final last = DateTime(2012, 11, 11);

  test('separate day month and year become one date', () {
    final parsed = parseBirthDate(day: '11', month: '11', year: '2012', first: first, last: last);
    expect(parsed.date, DateTime(2012, 11, 11));
  });

  test('February 31 is not a date', () {
    final parsed = parseBirthDate(day: '31', month: '2', year: '2012', first: first, last: last);
    expect(parsed.issue, BirthDateIssue.invalid);
  });

  test('a date after the age limit is rejected', () {
    final parsed = parseBirthDate(day: '12', month: '11', year: '2012', first: first, last: last);
    expect(parsed.issue, BirthDateIssue.tooLate);
  });

  test('month names are the twelve full names', () {
    expect(birthMonthName('ru', 11), 'Ноябрь');
    expect(birthMonthName('tj', 9), 'Сентябр');
    expect(birthMonthsRu, hasLength(12));
    expect(birthMonthsTj, hasLength(12));
  });

  testWidgets('day stays above the month and the year stays below it', (tester) async {
    final day = TextEditingController();
    final year = TextEditingController();
    addTearDown(day.dispose);
    addTearDown(year.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BirthDateFields(
              day: day,
              month: null,
              year: year,
              locale: 'ru',
              onMonth: (_) {},
              dayLabel: 'День',
              monthLabel: 'Месяц',
              yearLabel: 'Год',
            ),
          ),
        ),
      ),
    );

    final dayTop = tester.getTopLeft(find.text('День')).dy;
    final monthTop = tester.getTopLeft(find.text('Месяц')).dy;
    final yearTop = tester.getTopLeft(find.text('Год')).dy;
    expect(dayTop, lessThan(monthTop));
    expect(monthTop, lessThan(yearTop));

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.text('Январь'), findsOneWidget);
    expect(find.text('Май'), findsOneWidget);
    expect(find.text('Декабрь'), findsNothing);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.itemExtent, 44);
    expect(tester.getSize(find.byType(ListView)).height, 220);
  });

  test('empty parts mean the date is cleared', () {
    final parsed = parseBirthDate(day: '', month: '', year: '', first: first, last: last);
    expect(parsed.isEmpty, isTrue);
  });
}
