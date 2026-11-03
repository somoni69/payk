import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/countries.dart';
import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/payk_page.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: PaykColors.canvas,
      child: AsyncView(
        value: ref.watch(meProvider),
        onRetry: () => ref.invalidate(meProvider),
        data: (account) {
          final member = account.member;
          final locale = ref.watch(localeProvider);
          return ListView(
            padding: PaykInsets.list(context, top: 16),
            children: [
                Text(tr(locale, 'profile.title'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '${member.firstName} ${member.lastName}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(formatPhone(member.phone), style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _line(tr(locale, 'profile.phone'), formatPhone(member.phone)),
                _line(tr(locale, 'profile.birth'), member.birthDate ?? member.birthYear?.toString() ?? '—'),
                _line(tr(locale, 'profile.country'), countryName(member.country)),
                _line(tr(locale, 'profile.referral'), member.referralCode.isEmpty ? '—' : member.referralCode),
                Text(tr(locale, 'lang.label'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'ru', label: Text(tr(locale, 'lang.ru'))),
                    ButtonSegment(value: 'tj', label: Text(tr(locale, 'lang.tj'))),
                  ],
                  selected: {locale},
                  onSelectionChanged: (value) async {
                    final next = value.first;
                    await ref.read(localeProvider.notifier).set(next);
                    if (!ref.read(sessionProvider).loggedIn) return;
                    try {
                      await ref.read(loyaltyApiProvider).updateMe({'locale': next});
                    } catch (_) {}
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(locale, 'profile.edit'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _edit(context, ref, member, locale),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(locale, 'profile.coin'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(tr(locale, 'profile.coinHint')),
                  value: member.coinRounding,
                  onChanged: (value) async {
                    try {
                      await ref.read(sessionProvider.notifier).setCoinRounding(value);
                      ref.invalidate(meProvider);
                    } catch (error) {
                      if (!context.mounted) return;
                      showPaykMessage(context, errorText(error));
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(locale, 'profile.messages'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(tr(locale, 'profile.messagesHint')),
                  value: member.messages,
                  onChanged: (value) async {
                    try {
                      await ref.read(sessionProvider.notifier).setMessages(value);
                      ref.invalidate(meProvider);
                    } catch (error) {
                      if (!context.mounted) return;
                      showPaykMessage(context, errorText(error));
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(locale, 'profile.rules'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/rules'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(sessionProvider.notifier).logout();
                    ref.invalidate(meProvider);
                    ref.invalidate(historyProvider);
                    ref.invalidate(friendsProvider);
                    if (!context.mounted) return;
                    context.go('/auth/phone');
                  },
                  child: Text(tr(locale, 'profile.logout')),
                ),
              ],
          );
        },
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600))),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

Future<void> _edit(BuildContext context, WidgetRef ref, Member member, String locale) async {
  final first = TextEditingController(text: member.firstName);
  final last = TextEditingController(text: member.lastName);
  final email = TextEditingController(text: member.email ?? '');
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: first, decoration: InputDecoration(labelText: tr(locale, 'profile.firstName'))),
            const SizedBox(height: 8),
            TextField(controller: last, decoration: InputDecoration(labelText: tr(locale, 'profile.lastName'))),
            const SizedBox(height: 8),
            TextField(controller: email, decoration: InputDecoration(labelText: tr(locale, 'profile.email'))),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(locale, 'profile.save')),
            ),
          ],
        ),
      );
    },
  );
  if (saved == true) {
    try {
      await ref.read(sessionProvider.notifier).updateProfile(
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        email: email.text.trim(),
      );
      ref.invalidate(meProvider);
      if (context.mounted) showPaykMessage(context, tr(locale, 'profile.saved'));
    } catch (error) {
      if (context.mounted) showPaykMessage(context, errorText(error));
    }
  }
  first.dispose();
  last.dispose();
  email.dispose();
}
