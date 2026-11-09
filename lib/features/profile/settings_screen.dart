import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/providers.dart';

/// Экран настроек приложения (выбор языка, разрешение на уведомления, выход из аккаунта)
/// в стиле UDC / Payk Ecosystem и loyalty-app.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _messagesUpdating = false;

  Future<void> _changeLocale(String code) async {
    HapticFeedback.selectionClick();
    await ref.read(localeProvider.notifier).set(code);
    try {
      await ref.read(loyaltyApiProvider).updateMe({'locale': code});
    } catch (_) {}
  }

  Future<void> _toggleMessages(bool value) async {
    HapticFeedback.selectionClick();
    setState(() => _messagesUpdating = true);
    try {
      await ref.read(sessionProvider.notifier).setMessages(value);
      await ref.read(loyaltyApiProvider).updateMe({'messages': value});
      ref.invalidate(meProvider);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _messagesUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final meAsync = ref.watch(meProvider);

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
          tr(locale, 'profile.menuSettings'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: PaykColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: AsyncView(
          value: meAsync,
          onRetry: () => ref.invalidate(meProvider),
          loading: const SettingsSkeleton(),
          data: (account) {
            final member = account.member;
            final isMessagesEnabled = member.messages;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                // 1. Карточка выбора языка
                _SettingsCard(
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
                            child: const Icon(
                              Icons.language_rounded,
                              size: 20,
                              color: PaykColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr(locale, 'lang.label'),
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: PaykColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Сегментированный переключатель языков
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: PaykColors.surfaceNested,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _LanguageOption(
                                label: tr(locale, 'lang.tj'),
                                isSelected: locale == 'tj',
                                onTap: () => _changeLocale('tj'),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _LanguageOption(
                                label: tr(locale, 'lang.ru'),
                                isSelected: locale == 'ru',
                                onTap: () => _changeLocale('ru'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 2. Карточка разрешения на уведомления
                _SettingsCard(
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
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              size: 20,
                              color: PaykColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr(locale, 'settings.notifications'),
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: PaykColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr(locale, 'settings.notificationsDesc'),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: PaykColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, thickness: 1, color: PaykColors.border),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(locale, 'profile.messages'),
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: PaykColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(locale, 'profile.messagesHint'),
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w500,
                                    color: PaykColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch.adaptive(
                            value: isMessagesEnabled,
                            activeThumbColor: PaykColors.primary,
                            activeTrackColor: const Color(0xFFD6CFF9),
                            onChanged: _messagesUpdating
                                ? null
                                : (val) => _toggleMessages(val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      scaleDown: PaykMotion.scaleSubtle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: PaykMotion.duration(context, PaykMotion.fast),
            curve: PaykMotion.easeOut,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15.0,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? PaykColors.primary : PaykColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
