import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_3d_icon.dart';
import '../../core/widgets/payk_page.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

String _promoUnit(String locale, int count) {
  if (locale == 'tj') return 'промокод';
  return plural(count, 'промокод', 'промокода', 'промокодов');
}

String _rafflePeriod(String startsOn, String endsOn) {
  String fmt(String raw) {
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : formatShortDate(parsed);
  }

  return '${fmt(startsOn)} — ${fmt(endsOn)}';
}

/// Экран «Мои промокоды» (ТЗ 24.11.2026, п. 3): текущий розыгрыш, правила, коды клиента и итоги прошедших.
class RafflesScreen extends ConsumerWidget {
  const RafflesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return PaykPage(
      title: tr(locale, 'raffle.title'),
      body: AsyncView(
        value: ref.watch(rafflesProvider),
        onRetry: () => ref.invalidate(rafflesProvider),
        data: (data) {
          final currentId = data.current?.id;
          RaffleInfo? current;
          final past = <RaffleInfo>[];
          for (final raffle in data.raffles) {
            if (currentId != null && raffle.id == currentId) {
              current = raffle;
            } else {
              past.add(raffle);
            }
          }

          return RefreshIndicator(
            color: PaykColors.violet,
            backgroundColor: Colors.white,
            onRefresh: () async {
              ref.invalidate(rafflesProvider);
              try {
                await ref.read(rafflesProvider.future);
              } catch (_) {}
            },
            child: ListView(
              padding: PaykInsets.list(context, top: 8, bottom: 28),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                if (current == null && past.isEmpty)
                  SoftPanel(
                    child: EmptyState(
                      iconWidget: const Ticket3dIcon(size: 46),
                      title: tr(locale, 'raffle.none'),
                      body: tr(locale, 'raffle.noneText'),
                    ),
                  )
                else ...[
                  if (current != null)
                    _RaffleCard(
                      raffle: current,
                      current: true,
                      locale: locale,
                    ),
                  if (past.isNotEmpty) ...[
                    if (current != null) const SizedBox(height: 20),
                    SectionTitle(tr(locale, 'raffle.past')),
                    for (var i = 0; i < past.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _RaffleCard(
                        raffle: past[i],
                        current: false,
                        locale: locale,
                      ),
                    ],
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RaffleCard extends StatelessWidget {
  const _RaffleCard({
    required this.raffle,
    required this.current,
    required this.locale,
  });

  final RaffleInfo raffle;
  final bool current;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final liveCount = raffle.liveCodesCount;
    final stateKey = 'raffle.state.${raffle.state}';
    final stateText = tr(locale, stateKey);

    return Container(
      key: ValueKey('raffle-card-${raffle.id}'),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x061A1D29), blurRadius: 4, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x0A1A1D29), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: current
                ? PaykColors.brandSoft.withValues(alpha: 0.6)
                : PaykColors.sheet,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                raffle.isDrawn
                    ? const Trophy3dIcon(size: 44)
                    : const Ticket3dIcon(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        raffle.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: PaykColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_rafflePeriod(raffle.startsOn, raffle.endsOn)} · $stateText',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: PaykColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (current) ...[
                  Text(
                    tr(locale, 'raffle.rule', {
                      'amount': formatMoneyAuto(raffle.stepAmount),
                    }),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: PaykColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (raffle.prizes.trim().isNotEmpty) ...[
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
                        Text(
                          tr(locale, 'raffle.prizes'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: PaykColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          raffle.prizes,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: PaykColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  liveCount > 0
                      ? tr(locale, 'raffle.myCodes', {
                          'n': '$liveCount',
                          'unit': _promoUnit(locale, liveCount),
                        })
                      : tr(locale, 'raffle.noCodes'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.textPrimary,
                  ),
                ),
                if (raffle.codes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 8.0;
                      final itemWidth = (constraints.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final code in raffle.codes)
                            SizedBox(
                              width: itemWidth,
                              child: _CodeChip(code: code, locale: locale),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                if (raffle.isDrawn && raffle.winners.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PaykColors.sheet,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: PaykColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.emoji_events_outlined,
                              size: 17,
                              color: PaykColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tr(locale, 'raffle.winners'),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: PaykColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final winner in raffle.winners)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${winner.place}.',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: PaykColors.textSecondary,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                Text(
                                  winner.code,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: PaykColors.textPrimary,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code, required this.locale});

  final RaffleCode code;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final won = code.isWon;
    final cancelled = code.isCancelled;
    final bgColor = won
        ? PaykColors.incomeSoft
        : cancelled
        ? PaykColors.surfaceNested
        : PaykColors.sheet;
    final borderColor = won
        ? PaykColors.success.withValues(alpha: 0.4)
        : cancelled
        ? PaykColors.border
        : PaykColors.primary.withValues(alpha: 0.25);

    return Container(
      key: ValueKey('raffle-code-${code.code}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code.code,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: cancelled ? PaykColors.textMuted : PaykColors.textPrimary,
              decoration: cancelled ? TextDecoration.lineThrough : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            won
                ? tr(locale, 'raffle.won', {'n': '${code.place ?? ''}'})
                : cancelled
                ? tr(locale, 'raffle.cancelled')
                : tr(locale, 'raffle.active'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: won ? FontWeight.w700 : FontWeight.w500,
              color: won ? PaykColors.success : PaykColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
