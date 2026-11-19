import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../code/client_code_screen.dart';
import '../home/status_growth_card.dart';

/// Направление магазина «Алмоси».
enum StoreDirection { supermarket, clothes }

/// Экран бренда «Алмоси»: подсказка по росту статуса и выбор между продуктовым
/// магазином (супермаркет) и магазином одежды.
class AlmosiStoreScreen extends ConsumerWidget {
  const AlmosiStoreScreen({super.key});

  void _openDirection(BuildContext context, StoreDirection direction) {
    HapticFeedback.lightImpact();
    final path = direction == StoreDirection.supermarket
        ? '/almosi/supermarket'
        : '/almosi/clothes';
    PaykMotion.push<void>(
      context,
      path,
      fallback: () => AlmosiDirectionScreen(direction: direction),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: PaykPressable(
          scaleDown: PaykMotion.scaleIcon,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: PaykColors.textPrimary,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
            tooltip: tr(locale, 'common.back'),
          ),
        ),
        title: Text(
          tr(locale, 'store.almosiTitle'),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: PaykColors.textPrimary,
          ),
        ),
      ),
      body: AsyncView(
        value: ref.watch(meProvider),
        onRetry: () => ref.invalidate(meProvider),
        data: (account) {
          final wallet = account.wallet;
          final smRate = wallet.rates.supermarket;
          final clRate = wallet.rates.clothes;
          final bottomPad = 24.0 + MediaQuery.paddingOf(context).bottom;

          return RefreshIndicator(
            color: PaykColors.violet,
            backgroundColor: Colors.white,
            onRefresh: () async {
              ref.invalidate(meProvider);
              try {
                await ref.read(meProvider.future);
              } catch (_) {}
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                StatusGrowthCard(
                  wallet: wallet,
                  locale: locale,
                  tierCount: account.tierCount,
                  compact: false,
                ),
                const SizedBox(height: 20),
                Text(
                  tr(locale, 'store.directionsTitle'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: PaykColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(locale, 'store.directionsSub'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: PaykColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _DirectionCard(
                  key: const ValueKey('direction-supermarket'),
                  title: tr(locale, 'store.supermarketTitle'),
                  subtitle: tr(locale, 'store.supermarketSub'),
                  assetImage: 'assets/3d/cart.webp',
                  fallbackIcon: Icons.shopping_cart_outlined,
                  iconBg: const Color(0xFFF1F3F9),
                  earnPct: formatPercent(smRate.earn),
                  burnPct: formatPercent(smRate.burnCap),
                  locale: locale,
                  onTap: () => _openDirection(context, StoreDirection.supermarket),
                ),
                const SizedBox(height: 12),
                _DirectionCard(
                  key: const ValueKey('direction-clothes'),
                  title: tr(locale, 'store.clothesTitle'),
                  subtitle: tr(locale, 'store.clothesSub'),
                  assetImage: 'assets/3d/shirt.webp',
                  fallbackIcon: Icons.checkroom_outlined,
                  iconBg: const Color(0xFFEBF7EE),
                  earnPct: formatPercent(clRate.earn),
                  burnPct: formatPercent(clRate.burnCap),
                  locale: locale,
                  onTap: () => _openDirection(context, StoreDirection.clothes),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.assetImage,
    required this.fallbackIcon,
    required this.iconBg,
    required this.earnPct,
    required this.burnPct,
    required this.locale,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String assetImage;
  final IconData fallbackIcon;
  final Color iconBg;
  final String earnPct;
  final String burnPct;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PaykPressable(
        scaleDown: PaykMotion.scaleSubtle,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PaykColors.sheet,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PaykColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  assetImage,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    fallbackIcon,
                    size: 28,
                    color: PaykColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: PaykColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: PaykColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _RateChip(
                          label: tr(locale, 'store.rateEarnChip', {'pct': earnPct}),
                          highlight: true,
                        ),
                        _RateChip(
                          label: tr(locale, 'store.rateBurnChip', {'pct': burnPct}),
                          highlight: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: PaykColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({required this.label, required this.highlight});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? PaykColors.brandSoft : PaykColors.surfaceNested,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? PaykColors.primary.withValues(alpha: 0.18)
              : PaykColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: highlight ? PaykColors.primary : PaykColors.textSecondary,
        ),
      ),
    );
  }
}

/// Детальный экран направления («Супермаркет» или «Одежда»):
/// текущий статус пользователя, ставки, принципы начисления и списания кэшбэка.
class AlmosiDirectionScreen extends ConsumerWidget {
  const AlmosiDirectionScreen({super.key, required this.direction});

  final StoreDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isSm = direction == StoreDirection.supermarket;
    final title = tr(
      locale,
      isSm ? 'store.supermarketTitle' : 'store.clothesTitle',
    );
    final subtitle = tr(
      locale,
      isSm ? 'store.supermarketSub' : 'store.clothesSub',
    );
    final asset = isSm ? 'assets/3d/cart.webp' : 'assets/3d/shirt.webp';
    final iconBg = isSm ? const Color(0xFFF1F3F9) : const Color(0xFFEBF7EE);
    final fallbackIcon =
        isSm ? Icons.shopping_cart_outlined : Icons.checkroom_outlined;

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: PaykPressable(
          scaleDown: PaykMotion.scaleIcon,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: PaykColors.textPrimary,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
            tooltip: tr(locale, 'common.back'),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: PaykColors.textPrimary,
          ),
        ),
      ),
      body: AsyncView(
        value: ref.watch(meProvider),
        onRetry: () => ref.invalidate(meProvider),
        data: (account) {
          final wallet = account.wallet;
          final rate = isSm ? wallet.rates.supermarket : wallet.rates.clothes;
          final monthSpend = isSm
              ? wallet.spendSupermarket
              : wallet.spendClothes;
          final tierName = tierLabel(
            locale,
            wallet.status,
            tiers: account.tierCount,
          );
          final earnPct = formatPercent(rate.earn);
          final burnPct = formatPercent(rate.burnCap);
          final rulesAsync = ref.watch(rulesProvider);
          final bottomPad = 24.0 + MediaQuery.paddingOf(context).bottom;

          return ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: [
              // Карточка магазина и текущего статуса пользователя
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaykColors.sheet,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: PaykColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Image.asset(
                            asset,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              fallbackIcon,
                              size: 26,
                              color: PaykColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${tr(locale, 'store.label')} «${tr(locale, 'store.brand')}»',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: PaykColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: PaykColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PaykColors.surfaceNested,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: PaykColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr(locale, 'store.yourStatus'),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: PaykColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _TierBadge(
                                label: tierName,
                                level: wallet.status,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: PaykColors.border),
                          const SizedBox(height: 10),
                          Text(
                            '${tr(locale, 'store.monthInStore')}: ${formatMoney(monthSpend, decimals: false)}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: PaykColors.textPrimary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: tr(locale, 'store.accrualStatLabel'),
                              value: earnPct,
                              hint: tr(locale, 'store.accrualStatHint'),
                              accent: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricTile(
                              label: tr(locale, 'store.burnStatLabel'),
                              value: tr(locale, 'store.burnStatValue', {
                                'pct': burnPct,
                              }),
                              hint: tr(locale, 'store.burnStatHint'),
                              accent: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Принципы начисления кэшбэка
              _PrinciplesCard(
                icon: Icons.trending_up_rounded,
                title: tr(locale, 'store.accrualTitle'),
                items: [
                  tr(locale, 'store.accrualRule1', {
                    'tier': tierName,
                    'pct': earnPct,
                  }),
                  tr(locale, 'store.accrualRule2'),
                  tr(locale, 'store.accrualRule3'),
                ],
              ),
              const SizedBox(height: 14),

              // Принципы списания (снятия) кэшбэка
              _PrinciplesCard(
                icon: Icons.payments_outlined,
                title: tr(locale, 'store.burnTitle'),
                items: [
                  tr(locale, 'store.burnRule1', {
                    'tier': tierName,
                    'pct': burnPct,
                  }),
                  tr(locale, 'store.burnRule2', {'pct': burnPct}),
                  tr(locale, 'store.burnRule3'),
                ],
              ),
              const SizedBox(height: 14),

              // Ставки по всем статусам именно для этого магазина
              _DirectionTiersCard(
                locale: locale,
                direction: direction,
                currentStatus: wallet.status,
                tierCount: account.tierCount,
                rulesAsync: rulesAsync,
              ),
              const SizedBox(height: 18),

              PaykPressable(
                scaleDown: PaykMotion.scaleButton,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    PaykMotion.push<void>(
                      context,
                      '/code',
                      fallback: () => const ClientCodeScreen(),
                    );
                  },
                  child: Text(tr(locale, 'store.showCodeBtn')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.label, required this.level});

  final String label;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: tierLook(level).colors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.accent,
  });

  final String label;
  final String value;
  final String hint;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent ? PaykColors.brandSoft : PaykColors.surfaceNested,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent
              ? PaykColors.primary.withValues(alpha: 0.18)
              : PaykColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: accent ? PaykColors.primary : PaykColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: accent ? PaykColors.primary : PaykColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.3,
              color: PaykColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinciplesCard extends StatelessWidget {
  const _PrinciplesCard({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PaykColors.activePill,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: PaykColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PaykColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: const BoxDecoration(
                    color: PaykColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[i],
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: PaykColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DirectionTiersCard extends StatelessWidget {
  const _DirectionTiersCard({
    required this.locale,
    required this.direction,
    required this.currentStatus,
    required this.tierCount,
    required this.rulesAsync,
  });

  final String locale;
  final StoreDirection direction;
  final int currentStatus;
  final int tierCount;
  final AsyncValue<RulesInfo> rulesAsync;

  String _thresholdText(RulesInfo rules, TierRule tier) {
    if (tier.level <= 1) return tr(locale, 'rules.start');
    final idx = tier.level - 2;
    if (idx < 0 || idx >= rules.thresholds.length) {
      return tr(locale, 'rules.start');
    }
    return tr(locale, 'rules.from', {
      'amount': formatMoney(rules.thresholds[idx], decimals: false),
    });
  }

  @override
  Widget build(BuildContext context) {
    return rulesAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PaykColors.sheet,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PaykColors.border),
        ),
        child: ShimmerSweep(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(width: 180, height: 16, radius: 6),
              SizedBox(height: 12),
              SkeletonBox(height: 48, radius: 12),
              SizedBox(height: 8),
              SkeletonBox(height: 48, radius: 12),
            ],
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (rules) {
        if (rules.statuses.isEmpty) return const SizedBox.shrink();
        final isSm = direction == StoreDirection.supermarket;
        final totalTiers = rules.statuses.length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PaykColors.sheet,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PaykColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(locale, 'store.allTiersTitle'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PaykColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < rules.statuses.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _TierRow(
                  locale: locale,
                  label: tierLabel(
                    locale,
                    rules.statuses[i].level,
                    tiers: totalTiers > 0 ? totalTiers : tierCount,
                  ),
                  threshold: _thresholdText(rules, rules.statuses[i]),
                  rate: isSm
                      ? rules.statuses[i].rates.supermarket
                      : rules.statuses[i].rates.clothes,
                  isCurrent: rules.statuses[i].level == currentStatus,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.locale,
    required this.label,
    required this.threshold,
    required this.rate,
    required this.isCurrent,
  });

  final String locale;
  final String label;
  final String threshold;
  final Rate rate;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent ? PaykColors.brandSoft : PaykColors.surfaceNested,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? PaykColors.primary : PaykColors.border,
          width: isCurrent ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isCurrent
                            ? PaykColors.primary
                            : PaykColors.textPrimary,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PaykColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tr(locale, 'store.currentBadge'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  threshold,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PaykColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tr(locale, 'store.rateEarnChip', {
                  'pct': formatPercent(rate.earn),
                }),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isCurrent
                      ? PaykColors.primary
                      : PaykColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr(locale, 'store.rateBurnChip', {
                  'pct': formatPercent(rate.burnCap),
                }),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: PaykColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
