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

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PaykPage(
      title: tr(ref.watch(localeProvider), 'rules.title'),
      body: AsyncView(
        value: ref.watch(rulesProvider),
        onRetry: () => ref.invalidate(rulesProvider),
        data: (rules) {
          final locale = ref.watch(localeProvider);
          return ListView(
          padding: PaykInsets.list(context, top: 8, bottom: 28),
          children: [
            Text(
              tr(locale, 'rules.tiersText'),
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              tr(locale, 'rules.rise'),
              style: TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 18),
            for (final tier in rules.statuses) ...[
              SoftPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tierLabel(locale, tier.level, tiers: rules.statuses.length), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      _threshold(locale, rules, tier),
                      style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(locale, 'rules.sm', {
                        'earn': formatPercent(tier.rates.supermarket.earn),
                        'burn': formatPercent(tier.rates.supermarket.burnCap),
                      }),
                    ),
                    Text(
                      tr(locale, 'rules.cl', {
                        'earn': formatPercent(tier.rates.clothes.earn),
                        'burn': formatPercent(tier.rates.clothes.burnCap),
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Text(
              tr(locale, 'rules.referral', {
                'l1': formatPercent(rules.level1),
                'l2': formatPercent(rules.level2),
                'months': '${rules.months}',
              }),
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              tr(locale, 'rules.check'),
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              tr(locale, 'rules.burnNote'),
              style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ],
        );
        },
      ),
    );
  }

  String _threshold(String locale, RulesInfo rules, TierRule tier) {
    if (tier.level <= 1) return tr(locale, 'rules.start');
    final index = tier.level - 2;
    if (index < 0 || index >= rules.thresholds.length) return tr(locale, 'rules.start');
    return tr(locale, 'rules.from', {'amount': formatMoney(rules.thresholds[index], decimals: false)});
  }
}
