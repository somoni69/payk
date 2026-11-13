import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/strings.dart';
import '../motion/payk_motion.dart';
import '../theme/payk_colors.dart';

enum BirthDateIssue { empty, incomplete, invalid, tooEarly, tooLate }

class BirthDateParse {
  const BirthDateParse.ok(this.date) : issue = null;

  const BirthDateParse.issue(this.issue) : date = null;

  final DateTime? date;
  final BirthDateIssue? issue;

  bool get isOk => date != null;
  bool get isEmpty => issue == BirthDateIssue.empty;
}

/// День, месяц и год отдельно. Пустые три поля — дата не указана.
BirthDateParse parseBirthDate({
  required String day,
  required String month,
  required String year,
  required DateTime first,
  required DateTime last,
}) {
  final dayText = day.trim();
  final monthText = month.trim();
  final yearText = year.trim();
  if (dayText.isEmpty && monthText.isEmpty && yearText.isEmpty) {
    return const BirthDateParse.issue(BirthDateIssue.empty);
  }
  if (dayText.isEmpty ||
      monthText.isEmpty ||
      yearText.isEmpty ||
      yearText.length != 4) {
    return const BirthDateParse.issue(BirthDateIssue.incomplete);
  }
  final dayNumber = int.tryParse(dayText);
  final monthNumber = int.tryParse(monthText);
  final yearNumber = int.tryParse(yearText);
  if (dayNumber == null || monthNumber == null || yearNumber == null) {
    return const BirthDateParse.issue(BirthDateIssue.incomplete);
  }
  if (monthNumber < 1 || monthNumber > 12 || dayNumber < 1 || dayNumber > 31) {
    return const BirthDateParse.issue(BirthDateIssue.invalid);
  }
  final date = DateTime(yearNumber, monthNumber, dayNumber);
  if (date.year != yearNumber ||
      date.month != monthNumber ||
      date.day != dayNumber) {
    return const BirthDateParse.issue(BirthDateIssue.invalid);
  }
  final dayOnly = DateTime(date.year, date.month, date.day);
  final firstDay = DateTime(first.year, first.month, first.day);
  final lastDay = DateTime(last.year, last.month, last.day);
  if (dayOnly.isBefore(firstDay)) {
    return const BirthDateParse.issue(BirthDateIssue.tooEarly);
  }
  if (dayOnly.isAfter(lastDay)) {
    return const BirthDateParse.issue(BirthDateIssue.tooLate);
  }
  return BirthDateParse.ok(dayOnly);
}

String birthDateError(
  String locale,
  BirthDateParse result,
  DateTime first,
  DateTime last,
) {
  final from = _dotted(first);
  final to = _dotted(last);
  return switch (result.issue) {
    BirthDateIssue.invalid => tr(locale, 'profile.birthInvalid'),
    BirthDateIssue.tooEarly || BirthDateIssue.tooLate => tr(
      locale,
      'profile.birthRange',
      {'from': from, 'to': to},
    ),
    _ => tr(locale, 'profile.birthNeed'),
  };
}

String _dotted(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

/// Последний допустимый день рождения: сегодня минус 14 лет.
DateTime latestBirthDate(DateTime now) {
  final year = now.year - 14;
  final lastDay = DateTime(year, now.month + 1, 0).day;
  final day = now.day > lastDay ? lastDay : now.day;
  return DateTime(year, now.month, day);
}

const birthMonthsRu = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

const birthMonthsTj = [
  'Январ',
  'Феврал',
  'Март',
  'Апрел',
  'Май',
  'Июн',
  'Июл',
  'Август',
  'Сентябр',
  'Октябр',
  'Ноябр',
  'Декабр',
];

String birthMonthName(String locale, int month) {
  final names = locale == 'tj' ? birthMonthsTj : birthMonthsRu;
  return names[month - 1];
}

class BirthDateFields extends StatelessWidget {
  const BirthDateFields({
    super.key,
    required this.day,
    required this.month,
    required this.year,
    required this.locale,
    required this.onMonth,
    required this.dayLabel,
    required this.monthLabel,
    required this.yearLabel,
    this.enabled = true,
    this.decoration,
  });

  final TextEditingController day;
  final int? month;
  final TextEditingController year;
  final String locale;
  final ValueChanged<int?> onMonth;
  final String dayLabel;
  final String monthLabel;
  final String yearLabel;
  final bool enabled;
  final InputDecoration Function(String label)? decoration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _part(day, dayLabel, 2, TextInputAction.next),
        const SizedBox(height: 12),
        _BirthMonthField(
          month: month,
          locale: locale,
          label: monthLabel,
          enabled: enabled,
          decoration: decoration,
          onMonth: onMonth,
        ),
        const SizedBox(height: 12),
        _part(year, yearLabel, 4, TextInputAction.done),
      ],
    );
  }

  Widget _part(
    TextEditingController controller,
    String label,
    int maxLength,
    TextInputAction action,
  ) {
    final base = decoration?.call(label) ?? InputDecoration(labelText: label);
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: action,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: base,
    );
  }
}

class _BirthMonthField extends StatefulWidget {
  const _BirthMonthField({
    required this.month,
    required this.locale,
    required this.label,
    required this.enabled,
    required this.onMonth,
    this.decoration,
  });

  final int? month;
  final String locale;
  final String label;
  final bool enabled;
  final ValueChanged<int?> onMonth;
  final InputDecoration Function(String label)? decoration;

  @override
  State<_BirthMonthField> createState() => _BirthMonthFieldState();
}

class _BirthMonthFieldState extends State<_BirthMonthField> {
  static const _rowHeight = 44.0;
  static const _visibleRows = 5;

  var _open = false;

  void _toggle() {
    if (!widget.enabled) return;
    setState(() => _open = !_open);
  }

  void _choose(int month) {
    setState(() => _open = false);
    widget.onMonth(month);
  }

  @override
  Widget build(BuildContext context) {
    final field =
        widget.decoration?.call(widget.label) ??
        InputDecoration(labelText: widget.label);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: widget.enabled ? _toggle : null,
          borderRadius: BorderRadius.circular(16),
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: InputDecorator(
            decoration: field,
            isEmpty: widget.month == null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.month == null
                        ? ''
                        : birthMonthName(widget.locale, widget.month!),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: reduce ? Duration.zero : PaykMotion.micro,
                  curve: PaykMotion.easeOut,
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: PaykColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PaykColors.tile,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PaykColors.border),
              ),
              child: SizedBox(
                height: _rowHeight * _visibleRows,
                child: ListView.builder(
                  primary: false,
                  itemExtent: _rowHeight,
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final selected = widget.month == month;
                    final style = Theme.of(context).textTheme.bodyLarge;
                    return InkWell(
                      onTap: widget.enabled ? () => _choose(month) : null,
                      splashFactory: NoSplash.splashFactory,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                birthMonthName(widget.locale, month),
                                style: selected
                                    ? style?.copyWith(color: PaykColors.primary)
                                    : style,
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: PaykColors.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
