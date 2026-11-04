import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_page.dart';
import '../../core/widgets/screen_skeletons.dart';
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
        loading: const RulesSkeleton(),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: tierLook(tier.level).colors,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tierLabel(locale, tier.level, tiers: rules.statuses.length),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _threshold(locale, rules, tier),
                          style: const TextStyle(
                            color: PaykColors.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F6FB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEBE9F2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(locale, 'format.SM'),
                                  style: const TextStyle(
                                    color: PaykColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatPercent(tier.rates.supermarket.earn),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: PaykColors.ink,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(locale, 'home.burnCap', {'pct': formatPercent(tier.rates.supermarket.burnCap)}),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: PaykColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F6FB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEBE9F2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(locale, 'format.CL'),
                                  style: const TextStyle(
                                    color: PaykColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatPercent(tier.rates.clothes.earn),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: PaykColors.ink,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(locale, 'home.burnCap', {'pct': formatPercent(tier.rates.clothes.burnCap)}),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: PaykColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            SectionTitle('Друзья и рефералы'),
            SoftPanel(
              child: Text(
                tr(locale, 'rules.referral', {
                  'l1': formatPercent(rules.level1),
                  'l2': formatPercent(rules.level2),
                  'months': '${rules.months}',
                }),
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            SectionTitle('Оплата и чеки'),
            SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(locale, 'rules.check'),
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(locale, 'rules.burnNote'),
                    style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w500, height: 1.45, fontSize: 13),
                  ),
                ],
              ),
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
