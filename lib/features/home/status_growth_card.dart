import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../data/models/models.dart';

/// Подсказка по росту статуса: сколько ещё нужно купить в сомони до следующего уровня,
/// текущий прогресс за месяц и прогноз сохранения/изменения на следующий месяц.
class StatusGrowthCard extends StatelessWidget {
  const StatusGrowthCard({
    super.key,
    required this.wallet,
    required this.locale,
    this.tierCount = 5,
    this.compact = true,
    this.onTap,
  });

  final Wallet wallet;
  final String locale;
  final int tierCount;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final up = wallet.up;
    final keep = wallet.keep;
    final nextTier = up == null
        ? null
        : tierLabel(locale, up.level, tiers: tierCount);
    final daysText = wallet.daysLeft > 0
        ? tr(locale, 'home.daysLeftShort', {'n': '${wallet.daysLeft}'})
        : tr(locale, 'home.lastDayShort');
    final progress = up != null && up.threshold > 0
        ? (wallet.spendMonth / up.threshold).clamp(0.0, 1.0)
        : 1.0;
    final visualProgress = progress > 0 && progress < 0.04 ? 0.04 : progress;

    final card = Container(
      key: ValueKey(compact ? 'home-status-growth' : 'store-status-growth'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
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
              Expanded(
                child: compact
                    ? Text(
                        '${tr(locale, 'home.monthSpend')}: ${formatMoney(wallet.spendMonth, decimals: false)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: PaykColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(locale, 'home.monthSpend'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: PaykColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatMoney(wallet.spendMonth, decimals: false),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: PaykColors.textPrimary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: PaykColors.surfaceNested,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PaykColors.border),
                ),
                child: Text(
                  daysText,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.textSecondary,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: PaykColors.textMuted,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Своя дорожка прогресса без LinearProgressIndicator (единый плоский стиль и совместимость с тестами).
          Container(
            height: 7,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: PaykColors.activePill,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: visualProgress,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: up == null ? PaykColors.success : PaykColors.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (up != null && nextTier != null) ...[
            Text(
              tr(locale, 'store.toNextGap', {
                'tier': nextTier,
                'gap': formatMoneyWhole(up.gap),
              }),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: PaykColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (!compact && up.perDay > 0) ...[
              const SizedBox(height: 3),
              Text(
                tr(locale, 'home.perDay', {
                  'amount': formatMoneyWhole(up.perDay),
                }),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: PaykColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ] else
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: PaykColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr(locale, 'home.topTier'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PaykColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          if (keep != null && (!compact || !keep.kept)) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: keep.kept ? PaykColors.incomeSoft : PaykColors.amberSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                keep.kept
                    ? tr(locale, 'home.kept')
                    : [
                        tr(locale, 'home.keepGap', {
                          'tier': tierLabel(
                            locale,
                            wallet.status,
                            tiers: tierCount,
                          ),
                          'gap': formatMoneyWhole(keep.gap),
                        }),
                        if (wallet.nextMonthStatus != wallet.status)
                          tr(locale, 'store.nextMonthProjected', {
                            'tier': tierLabel(
                              locale,
                              wallet.nextMonthStatus,
                              tiers: tierCount,
                            ),
                          }),
                      ].join(' · '),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: keep.kept
                      ? PaykColors.success
                      : PaykColors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
          if (!compact) ...[
            const SizedBox(height: 10),
            Text(
              tr(locale, 'store.monthlyNote'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: PaykColors.textSecondary,
              ),
            ),
          ],
          for (final format in StoreWallets.formats)
            if (wallet.storeWallets.byFormat(format).onHold > 0) ...[
              const SizedBox(height: 8),
              Text(
                tr(locale, 'home.onHoldWallet', {
                  'store': tr(locale, 'wallet.$format'),
                  'amount': formatMoney(
                    wallet.storeWallets.byFormat(format).onHold,
                    signed: true,
                  ),
                }),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: PaykColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
        ],
      ),
    );

    if (onTap == null) return RepaintBoundary(child: card);
    return RepaintBoundary(
      child: PaykPressable(
        scaleDown: PaykMotion.scaleSubtle,
        onTap: onTap,
        child: card,
      ),
    );
  }
}
