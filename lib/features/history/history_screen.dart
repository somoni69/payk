import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_page.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return ColoredBox(
      color: PaykColors.canvas,
      child: AsyncView(
        value: ref.watch(historyProvider),
        onRetry: () => ref.invalidate(historyProvider),
        data: (items) {
          final title = Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(tr(locale, 'history.title'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          );
          if (items.isEmpty) {
            return ListView(
              padding: PaykInsets.list(context, horizontal: 0, top: 16),
              children: [
                title,
                const SizedBox(height: 48),
                EmptyState(
                  title: tr(locale, 'history.empty'),
                  body: tr(locale, 'history.emptyText'),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: PaykInsets.list(context, horizontal: 0, top: 16),
            itemCount: items.length + 1,
            separatorBuilder: (context, index) => index == 0 ? const SizedBox(height: 4) : const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) return title;
              return _Row(entry: items[index - 1], locale: locale);
            },
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.locale});

  final HistoryEntry entry;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final positive = entry.amount >= 0;
    return ListTile(
      title: Text(tr(locale, 'history.type.${_known(entry.type)}'), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        [
          formatDate(entry.createdAt),
          if (entry.billAmount != null) tr(locale, 'history.billAmount', {'amount': formatMoney(entry.billAmount!)}),
          if (entry.format == 'SM') tr(locale, 'format.SM'),
          if (entry.format == 'CL') tr(locale, 'format.CL'),
          tr(locale, 'history.balanceAfter', {'amount': formatMoney(entry.balanceAfter)}),
        ].join(' · '),
      ),
      trailing: Text(
        formatMoney(entry.amount, signed: true),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: positive ? PaykColors.good : PaykColors.orange,
        ),
      ),
    );
  }
}

String _known(String type) {
  const known = {
    'accrual',
    'burn',
    'round',
    'referral',
    'referral_reversal',
    'reversal',
    'refund',
    'adjustment',
    'expiry',
    'debt',
  };
  return known.contains(type) ? type : 'other';
}

