import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_3d_icon.dart';
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
          final formats = rules.activeFormats;
          return ListView(
          padding: PaykInsets.list(context, top: 8, bottom: 28),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
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
                    _TierRatesGrid(
                      locale: locale,
                      tier: tier,
                      formats: formats,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (rules.birthday case final birthday?) ...[
              const SizedBox(height: 6),
              SectionTitle(tr(locale, 'rules.birthdayTitle')),
              SoftPanel(
                key: const ValueKey('rules-birthday'),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(locale, 'rules.birthdayText', {
                        'before': '${birthday.windowBefore}',
                        'beforeUnit': daysWord(birthday.windowBefore),
                        'after': '${birthday.windowAfter}',
                        'afterUnit': daysWord(birthday.windowAfter),
                      }),
                      style: const TextStyle(
                        color: PaykColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < rules.statuses.length; i++)
                      if (i < birthday.coupon.length) ...[
                        if (i > 0) const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F6FB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEBE9F2)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                tierLabel(
                                  locale,
                                  rules.statuses[i].level,
                                  tiers: rules.statuses.length,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: PaykColors.ink,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatMoneyAuto(birthday.coupon[i]),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: PaykColors.ink,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    if (_birthdayMinList(rules, locale).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        tr(locale, 'rules.birthdayMin', {
                          'list': _birthdayMinList(rules, locale),
                        }),
                        key: const ValueKey('rules-birthday-min'),
                        style: const TextStyle(
                          color: PaykColors.muted,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      tr(locale, 'rules.birthdayDate'),
                      style: const TextStyle(
                        color: PaykColors.muted,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (rules.welcomeBonus != null && rules.welcomeBonus! > 0) ...[
              const SizedBox(height: 6),
              SoftPanel(
                key: const ValueKey('rules-welcome'),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: PaykColors.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Gift3dIcon(size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(locale, 'rules.welcome', {
                          'amount': formatMoneyAuto(rules.welcomeBonus!),
                        }),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          fontSize: 14.5,
                          color: PaykColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SectionTitle('Друзья и рефералы'),
            SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(locale, 'rules.referral', {
                      'l1': formatPercent(rules.level1),
                      'l2': formatPercent(rules.level2),
                      'months': '${rules.months}',
                    }),
                    style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45, fontSize: 14),
                  ),
                  if (rules.firstBonus > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      rules.firstBonusMin > 0
                          ? tr(locale, 'friends.firstBonusMin', {
                              'bonus': formatMoneyAuto(rules.firstBonus),
                              'min': formatMoneyAuto(rules.firstBonusMin),
                            })
                          : tr(locale, 'friends.firstBonus', {
                              'bonus': formatMoneyAuto(rules.firstBonus),
                            }),
                      key: const ValueKey('rules-first-bonus'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        fontSize: 14,
                        color: PaykColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionTitle('Оплата и чеки'),
            SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      locale,
                      rules.burnKeepsCashback
                          ? 'rules.modesNoteKeep'
                          : 'rules.check',
                    ),
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

  /// «Супермаркет ×10, Либос ×5, Ресторан ×5»: во сколько раз минимальный чек больше купона.
  String _birthdayMinList(RulesInfo rules, String locale) {
    final times = rules.birthday?.minBillX;
    if (times == null || times.isEmpty) return '';
    return [
      for (final fmt in rules.activeFormats)
        if (times[fmt] case final x?)
          '${tr(locale, 'format.$fmt')} ×${_formatMultiplier(x)}',
    ].join(', ');
  }

  String _formatMultiplier(double value) {
    final rounded = (value * 100).round() / 100;
    if ((rounded - rounded.roundToDouble()).abs() < 0.001) {
      return rounded.round().toString();
    }
    return rounded
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll('.', ',');
  }
}

class _TierRatesGrid extends StatelessWidget {
  const _TierRatesGrid({
    required this.locale,
    required this.tier,
    required this.formats,
  });

  final String locale;
  final TierRule tier;
  final List<String> formats;

  @override
  Widget build(BuildContext context) {
    if (formats.length <= 2) {
      return Row(
        children: [
          for (var i = 0; i < formats.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _RuleRateBox(
                key: ValueKey('rules-rate-${tier.level}-${formats[i]}'),
                locale: locale,
                format: formats[i],
                rate: tier.rates.byFormat(formats[i]),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _RuleRateBox(
                key: ValueKey('rules-rate-${tier.level}-${formats[0]}'),
                locale: locale,
                format: formats[0],
                rate: tier.rates.byFormat(formats[0]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RuleRateBox(
                key: ValueKey('rules-rate-${tier.level}-${formats[1]}'),
                locale: locale,
                format: formats[1],
                rate: tier.rates.byFormat(formats[1]),
              ),
            ),
          ],
        ),
        for (var i = 2; i < formats.length; i++) ...[
          const SizedBox(height: 8),
          _RuleRateBox(
            key: ValueKey('rules-rate-${tier.level}-${formats[i]}'),
            locale: locale,
            format: formats[i],
            rate: tier.rates.byFormat(formats[i]),
          ),
        ],
      ],
    );
  }
}

class _RuleRateBox extends StatelessWidget {
  const _RuleRateBox({
    super.key,
    required this.locale,
    required this.format,
    required this.rate,
  });

  final String locale;
  final String format;
  final Rate rate;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            tr(locale, 'format.$format'),
            style: const TextStyle(
              color: PaykColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatPercent(rate.earn),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: PaykColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tr(locale, 'home.burnCap', {'pct': formatPercent(rate.burnCap)}),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PaykColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
