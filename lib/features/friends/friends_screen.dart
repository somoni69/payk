import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/payk_page.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final store = ref.watch(meProvider).asData?.value.store ?? '';
    return ColoredBox(
      color: PaykColors.canvas,
      child: AsyncView(
        value: ref.watch(friendsProvider),
        onRetry: () => ref.invalidate(friendsProvider),
        data: (friends) => _FriendsBody(friends: friends, store: store, locale: locale),
      ),
    );
  }
}

class _FriendsBody extends StatelessWidget {
  const _FriendsBody({required this.friends, required this.store, required this.locale});

  final FriendsInfo friends;
  final String store;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final where = store.isEmpty ? '' : ' в $store';
    final link = friends.link;
    final text =
        'Присоединяйтесь к бонусной программе ПАЙК$where — кэшбэк с каждой покупки. Мой код приглашения: ${friends.code}${link == null ? '' : '\n$link'}';
    return ListView(
      padding: PaykInsets.list(context, top: 16),
      children: [
        Text(tr(locale, 'friends.title'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(locale, 'friends.heroTitle'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                tr(locale, 'friends.explain', {
                  'l1': formatPercent(friends.level1),
                  'l2': formatPercent(friends.level2),
                  'months': '${friends.months}',
                }),
                style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600, height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _Chain(tr(locale, 'friends.chainYou'), 'М1')),
                  const Icon(Icons.arrow_forward_rounded, color: PaykColors.muted, size: 18),
                  Expanded(child: _Chain('${friends.countL1}', tr(locale, 'friends.chainM2'))),
                  const Icon(Icons.arrow_forward_rounded, color: PaykColors.muted, size: 18),
                  Expanded(child: _Chain('${friends.countL2}', tr(locale, 'friends.chainM3'))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr(locale, 'friends.chainNote', {
                  'l1': formatPercent(friends.level1),
                  'l2': formatPercent(friends.level2),
                }),
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
              ),
              const SizedBox(height: 14),
              Text(tr(locale, 'friends.yourCode'), style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                friends.code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: PaykColors.violet,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final result = await SharePlus.instance.share(ShareParams(text: text));
                  if (!context.mounted) return;
                  if (result.status == ShareResultStatus.unavailable) {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    showPaykMessage(context, tr(locale, 'friends.copied'));
                  }
                },
                child: Text(tr(locale, 'friends.share')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Stat(tr(locale, 'friends.l1'), '${friends.countL1}')),
            const SizedBox(width: 8),
            Expanded(child: _Stat(tr(locale, 'friends.l2'), '${friends.countL2}')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Stat(tr(locale, 'friends.total'), formatMoney(friends.total))),
            const SizedBox(width: 8),
            Expanded(child: _Stat(tr(locale, 'friends.month'), formatMoney(friends.month))),
          ],
        ),
        const SizedBox(height: 18),
        SectionTitle(tr(locale, 'friends.list')),
        if (friends.invitees.isEmpty)
          SoftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(locale, 'friends.empty'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  tr(locale, 'friends.emptyText'),
                  style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ],
            ),
          )
        else
          SoftPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < friends.invitees.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(
                      friends.invitees[i].firstName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        friends.invitees[i].level <= 2 ? tr(locale, 'friends.level2') : tr(locale, 'friends.level3'),
                        friends.invitees[i].phone,
                        'до ${formatShortDate(friends.invitees[i].activeUntil)}',
                      ].join(' · '),
                    ),
                    trailing: Text(
                      formatMoney(friends.invitees[i].earned, signed: true),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: PaykColors.good),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Chain extends StatelessWidget {
  const _Chain(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: PaykColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
