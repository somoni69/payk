import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/birthday.dart';
import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_mark.dart';
import '../../core/widgets/payk_page.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: PaykColors.canvas,
      child: AsyncView(
        value: ref.watch(meProvider),
        onRetry: () => ref.invalidate(meProvider),
        data: (account) => _HomeBody(account: account, locale: ref.watch(localeProvider)),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.account, required this.locale});

  final Account account;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = account.member;
    final wallet = account.wallet;
    return ListView(
      padding: PaykInsets.list(context, top: 12, bottom: 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (account.store.isNotEmpty)
                    Text(
                      account.store,
                      style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600),
                    ),
                  if (account.store.isNotEmpty) const SizedBox(height: 4),
                  Text(
                    tr(locale, 'home.greeting', {'name': member.firstName}),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
            _MessagesButton(
              unread: account.messagesUnread,
              onTap: () => _openMessages(context, ref, locale),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!account.programEnabled)
          _Notice(
            title: tr(locale, 'home.paused'),
            body: tr(locale, 'home.pausedText'),
          ),
        _StatusCard(member: member, wallet: wallet, locale: locale, tiers: account.tierCount),
        if (_gift(member, wallet) case final gift?) ...[
          const SizedBox(height: 12),
          _Notice(
            title: tr(locale, 'home.giftTitle'),
            body: tr(locale, 'home.giftBody', {
              'amount': formatMoney(gift.amount.toDouble(), decimals: false),
              'from': formatShortDate(gift.from),
              'until': formatShortDate(gift.until),
              'cl': formatMoney(gift.minClothes.toDouble(), decimals: false),
              'sm': formatMoney(gift.minSupermarket.toDouble(), decimals: false),
            }),
          ),
        ],
        if (wallet.debt > 0) ...[
          const SizedBox(height: 12),
          _Notice(
            title: tr(locale, 'home.debtTitle', {'amount': formatMoney(-wallet.debt)}),
            body: tr(locale, 'home.debtText'),
          ),
        ],
        if (_reminder(locale, wallet, account.tierCount) case final reminder?) ...[
          const SizedBox(height: 12),
          _Notice(title: reminder, body: ''),
        ],
        const SizedBox(height: 12),
        _MonthCard(wallet: wallet, locale: locale, tiers: account.tierCount),
        if (wallet.keep != null) ...[
          const SizedBox(height: 12),
          _KeepCard(status: wallet.status, keep: wallet.keep!, next: wallet.nextMonthStatus, locale: locale, tiers: account.tierCount),
        ],
        const SizedBox(height: 12),
        _RatesCard(wallet: wallet, locale: locale, tiers: account.tierCount),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.member, required this.wallet, required this.locale, required this.tiers});

  final Member member;
  final Wallet wallet;
  final String locale;
  final int tiers;

  @override
  Widget build(BuildContext context) {
    final look = tierLook(wallet.status);
    return Container(
      height: 196,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: look.colors,
        ),
        boxShadow: [
          BoxShadow(
            color: look.colors.first.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(1, -1),
                  radius: 1.20,
                  colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
                  stops: [0, 0.60],
                ),
              ),
            ),
          ),
          Positioned(
            right: -16,
            bottom: -24,
            width: 176,
            height: 176,
            child: PaykGlyph(color: look.ink.withValues(alpha: 0.14)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: PaykGlyph(color: look.ink)),
                    const SizedBox(width: 8),
                    Text(
                      'ПАЙК',
                      style: TextStyle(
                        color: look.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: look.badge,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: look.badgeBorder),
                      ),
                      child: Text(
                        tierLabel(locale, wallet.status, tiers: tiers),
                        style: TextStyle(
                          color: look.badgeInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  tr(locale, 'home.balance'),
                  style: TextStyle(color: look.inkSoft, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: formatNumber(wallet.balance),
                    style: TextStyle(
                      color: look.ink,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -0.8,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    children: [
                      TextSpan(
                        text: '\u00A0смн',
                        style: TextStyle(
                          color: look.inkSoft,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (wallet.onHold > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      tr(locale, 'home.onHold', {'amount': formatMoney(wallet.onHold, signed: true)}),
                      style: TextStyle(color: look.inkSoft, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${member.firstName} ${member.lastName}'.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: look.inkSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      member.referralCode,
                      style: TextStyle(
                        color: look.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesButton extends StatelessWidget {
  const _MessagesButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: PaykColors.sheet,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: PaykColors.line),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_none_rounded, color: PaykColors.ink, size: 22),
              if (unread > 0)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: PaykColors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openMessages(BuildContext context, WidgetRef ref, String locale) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PaykColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _MessagesSheet(locale: locale),
  ).then((_) {
    // При закрытии модального окна обновляем профиль, чтобы сбросить счётчик
    ref.invalidate(meProvider);
  });
}

class _MessagesSheet extends ConsumerStatefulWidget {
  const _MessagesSheet({required this.locale});

  final String locale;

  @override
  ConsumerState<_MessagesSheet> createState() => _MessagesSheetState();
}

class _MessagesSheetState extends ConsumerState<_MessagesSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loyaltyApiProvider).markMessagesRead().ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PaykColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(widget.locale, 'messages.title'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(errorText(error))),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mark_chat_unread_outlined, size: 48, color: PaykColors.muted),
                            const SizedBox(height: 12),
                            Text(
                              tr(widget.locale, 'messages.empty'),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr(widget.locale, 'messages.emptyText'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: PaykColors.muted, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: PaykColors.sheet,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PaykColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  formatDate(item.createdAt),
                                  style: const TextStyle(color: PaykColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                if (!item.read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: PaykColors.violet,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.text,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.wallet, required this.locale, required this.tiers});

  final Wallet wallet;
  final String locale;
  final int tiers;

  @override
  Widget build(BuildContext context) {
    final up = wallet.up;
    final progress = up == null || up.threshold == 0
        ? 1.0
        : (wallet.spendMonth / up.threshold).clamp(0.0, 1.0);
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr(locale, 'home.monthSpend'), style: const TextStyle(color: PaykColors.muted, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text(
                wallet.daysLeft > 0 ? tr(locale, 'home.daysLeftShort', {'n': '${wallet.daysLeft}'}) : tr(locale, 'home.lastDayShort'),
                style: const TextStyle(color: PaykColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: formatNumber(wallet.spendMonth, decimals: false),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.1),
              children: const [
                TextSpan(
                  text: '\u00A0смн',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PaykColors.muted, letterSpacing: 0),
                ),
              ],
            ),
          ),
          if (up != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: PaykColors.panel,
                color: PaykColors.violet,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(locale, 'home.toNext', {
                'tier': tierLabel(locale, up.level, tiers: tiers),
                'gap': formatMoney(up.gap, decimals: false),
              }),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              up.perDay <= 0
                  ? tr(locale, 'home.nextRates', {
                      'tier': tierLabel(locale, up.level, tiers: tiers),
                      'sm': formatPercent(up.rates.supermarket.earn),
                      'cl': formatPercent(up.rates.clothes.earn),
                    })
                  : '${tr(locale, 'home.perDay', {'amount': formatMoney(up.perDay, decimals: false)})}. ${tr(locale, 'home.nextRates', {
                      'tier': tierLabel(locale, up.level, tiers: tiers),
                      'sm': formatPercent(up.rates.supermarket.earn),
                      'cl': formatPercent(up.rates.clothes.earn),
                    })}',
              style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Mini(tr(locale, 'format.SM'), formatMoney(wallet.spendSupermarket, decimals: false))),
              const SizedBox(width: 8),
              Expanded(child: _Mini(tr(locale, 'format.CL'), formatMoney(wallet.spendClothes, decimals: false))),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeepCard extends StatelessWidget {
  const _KeepCard({required this.status, required this.keep, required this.next, required this.locale, required this.tiers});

  final int status;
  final KeepInfo keep;
  final int next;
  final String locale;
  final int tiers;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            keep.kept
                ? tr(locale, 'home.kept')
                : tr(locale, 'home.keepGap', {
                    'tier': tierLabel(locale, status, tiers: tiers),
                    'gap': formatMoney(keep.gap, decimals: false),
                  }),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (!keep.kept && keep.perDay > 0) ...[
            const SizedBox(height: 6),
            Text(
              tr(locale, 'home.perDay', {'amount': formatMoney(keep.perDay, decimals: false)}),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            tr(locale, 'home.nextMonth', {'tier': tierLabel(locale, next, tiers: tiers)}),
            style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({required this.wallet, required this.locale, required this.tiers});

  final Wallet wallet;
  final String locale;
  final int tiers;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(locale, 'home.ratesTitle', {'tier': tierLabel(locale, wallet.status, tiers: tiers)}),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RateTile(
                  locale: locale,
                  title: tr(locale, 'format.SM'),
                  earn: wallet.rates.supermarket.earn,
                  burn: wallet.rates.supermarket.burnCap,
                  today: wallet.todaySupermarket,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RateTile(
                  locale: locale,
                  title: tr(locale, 'format.CL'),
                  earn: wallet.rates.clothes.earn,
                  burn: wallet.rates.clothes.burnCap,
                  today: wallet.todayClothes,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push('/rules'),
              child: Text(tr(locale, 'home.allRules')),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({
    required this.locale,
    required this.title,
    required this.earn,
    required this.burn,
    required this.today,
  });

  final String locale;
  final String title;
  final double earn;
  final double burn;
  final double today;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PaykColors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(formatPercent(earn), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          Text(tr(locale, 'home.cashback'), style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(tr(locale, 'home.burnCap', {'pct': formatPercent(burn)}), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (today > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tr(locale, 'home.todayEarned', {'amount': formatMoney(today, signed: true)}),
                style: const TextStyle(color: PaykColors.good, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.title, this.value);

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PaykColors.panel, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: PaykColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaykColors.notice,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

BirthdayGift? _gift(Member member, Wallet wallet) {
  final raw = member.birthDate;
  if (raw == null || raw.length < 10) return null;
  final birth = DateTime.tryParse(raw);
  if (birth == null) return null;
  return birthdayGift(birth, wallet.status, DateTime.now());
}

String? _reminder(String locale, Wallet wallet, int tiers) {
  const marks = {10, 7, 4, 1};
  if (!marks.contains(wallet.daysLeft)) return null;
  final keep = wallet.keep;
  if (keep != null && !keep.kept && keep.gap > 0) {
    return tr(locale, 'home.reminderKeep', {
      'days': '${wallet.daysLeft}',
      'tier': tierLabel(locale, wallet.status, tiers: tiers),
      'gap': formatMoney(keep.gap, decimals: false),
      'perDay': formatMoney(keep.perDay, decimals: false),
    });
  }
  final up = wallet.up;
  if (up != null && up.gap > 0) {
    return tr(locale, 'home.reminderUp', {
      'days': '${wallet.daysLeft}',
      'tier': tierLabel(locale, up.level, tiers: tiers),
      'gap': formatMoney(up.gap, decimals: false),
      'perDay': formatMoney(up.perDay, decimals: false),
    });
  }
  return null;
}

