import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/payk_avatar.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../friends/friends_screen.dart';
import '../rules/rules_screen.dart';
import 'connect_screen.dart';
import 'settings_screen.dart';

export 'settings_screen.dart';

// =============================================================================
// 1. ОСНОВНОЙ ЭКРАН ПРОФИЛЯ ПАЙК
// =============================================================================

/// Главный экран профиля ПАЙК (в соответствии с loyalty-app):
/// 1. Верхний виджет: карточка пользователя (Аватар + Имя + «Профиль/Профил» + «>»).
/// 2. Карточка «Тарзҳои воридшавӣ» / «Способы входа» (Дидан) с бейджами SMS и Telegram.
/// 3. Скроллящиеся баннеры-карусель под «Способами входа» («Статусҳои ПАЙК» / «Клуби дӯстон»).
/// 4. Список пунктов меню:
///    - Мағозаи ман (MSX Алмоси)
///    - Статусҳо ва қоидаҳо (/rules)
///    - Алоқа бо мағоза (WhatsApp)
///    - Дар бораи барнома (About dialog)
///    - Танзимот (ProfileDetailsScreen)
/// 5. Плитка переключателя «Кэшбэк ва статусро аз даст надиҳед — огоҳиномаҳоро фаъол кунед».
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: ref.watch(meProvider),
          onRetry: () => ref.invalidate(meProvider),
          loading: const ProfileSkeleton(),
          data: (account) {
            final member = account.member;

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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  // 1. Верхний виджет: Карточка пользователя с аватаром, именем и переходом в ProfileDetailsScreen
                  _UserProfileHeaderCard(
                    member: member,
                    locale: locale,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push<void>(
                        PaykMotion.route(const ProfileDetailsScreen()),
                      );
                    },
                  ),
                const SizedBox(height: 12),

                // 2. Карточка «Тарзҳои воридшавӣ» / «Способы входа»
                _LoginMethodsBanner(
                  locale: locale,
                  member: member,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    PaykMotion.push<void>(
                      context,
                      '/profile/connect',
                      fallback: () => const ConnectScreen(),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 3. Баннеры, которые скролятся внизу «Способы входа» (перенесены из loyalty-app)
                _ProfileBannersCarousel(locale: locale),
                const SizedBox(height: 16),

                // 4. Пункты меню без дублей покупок и сообщений
                _ProfileMenuItem(
                  icon: Icons.location_on_outlined,
                  title: tr(locale, 'profile.myStore'),
                  subtitle: account.store.isNotEmpty ? account.store : 'MSX Алмоси',
                  onTap: () => _showStoreDialog(context, account),
                ),
                _ProfileMenuItem(
                  icon: Icons.confirmation_number_outlined,
                  title: tr(locale, 'profile.statusesAndRules'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    PaykMotion.push<void>(
                      context,
                      '/rules',
                      fallback: () => const RulesScreen(),
                    );
                  },
                ),
                _ProfileMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: tr(locale, 'profile.contactStore'),
                  subtitle: 'WhatsApp',
                  onTap: () => _showStoreContactDialog(
                    context,
                    storeName: account.store.isNotEmpty ? account.store : 'MSX Алмоси',
                    locale: locale,
                  ),
                ),
                _ProfileMenuItem(
                  icon: Icons.info_outline_rounded,
                  title: tr(locale, 'profile.aboutApp'),
                  onTap: () => _showAboutDialog(context),
                ),
                _ProfileMenuItem(
                  icon: Icons.settings_outlined,
                  title: tr(locale, 'profile.menuSettings'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    PaykMotion.push<void>(
                      context,
                      '/settings',
                      fallback: () => const SettingsScreen(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ProfileNotificationToggleCard(
                  initialValue: member.messages,
                  locale: locale,
                ),
                const SizedBox(height: 20),
              ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// КОМПОНЕНТЫ ЭКРАНА ПРОФИЛЯ
// -----------------------------------------------------------------------------

/// 1. Карточка пользователя с аватаром, именем, статусом и кнопкой перехода
class _UserProfileHeaderCard extends StatelessWidget {
  const _UserProfileHeaderCard({
    required this.member,
    required this.locale,
    required this.onTap,
  });

  final Member member;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rawName = '${member.firstName} ${member.lastName}'.trim();
    final fullName = rawName.isNotEmpty ? rawName : 'Фарзод Сомони';

    return PaykPressable(
      scaleDown: PaykMotion.scaleSubtle,
      child: Container(
        decoration: BoxDecoration(
          color: PaykColors.sheet,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PaykColors.border, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  PaykAvatar(member: member, size: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: PaykColors.textPrimary,
                            fontFamily: 'Manrope',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(locale, 'profile.open'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: PaykColors.textSecondary,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: PaykColors.primary,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2. Карточка «Тарзҳои воридшавӣ» с бейджами и кнопкой «Дидан»
class _LoginMethodsBanner extends StatelessWidget {
  const _LoginMethodsBanner({
    required this.locale,
    required this.member,
    required this.onTap,
  });

  final String locale;
  final Member member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border, width: 1.0),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr(locale, 'profile.loginMethods'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: PaykColors.textPrimary,
                  fontFamily: 'Manrope',
                ),
              ),
              GestureDetector(
                onTap: onTap,
                child: Text(
                  tr(locale, 'profile.view'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.primary,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: const _SocialCheckBadge(type: _SocialBadgeType.sms),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: _SocialCheckBadge(
                  type: _SocialBadgeType.telegram,
                  isConnected: member.telegram,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SocialBadgeType { sms, telegram }

class _SocialCheckBadge extends StatelessWidget {
  const _SocialCheckBadge({
    required this.type,
    this.isConnected = true,
  });

  final _SocialBadgeType type;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final isSms = type == _SocialBadgeType.sms;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE5E5EB),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: isSms
                ? const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 22,
                    color: PaykColors.primary,
                  )
                : const Icon(
                    Icons.send_rounded,
                    size: 22,
                    color: Color(0xFF29B6F6),
                  ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: (isSms || isConnected)
                    ? const Color(0xFF1B8A5A)
                    : const Color(0xFFD6D6DA),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                (isSms || isConnected) ? Icons.check_rounded : Icons.add_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. Баннеры-карусель под «Способами входа» (перенесены из loyalty-app)
class _ProfileBannersCarousel extends StatefulWidget {
  const _ProfileBannersCarousel({required this.locale});

  final String locale;

  @override
  State<_ProfileBannersCarousel> createState() => _ProfileBannersCarouselState();
}

class _ProfileBannersCarouselState extends State<_ProfileBannersCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = [
      _BannerSlideData(
        title: tr(widget.locale, 'profile.bannerStatusTitle'),
        text: tr(widget.locale, 'profile.bannerStatusText', {'pct': '20%'}),
        imageAsset: 'assets/3d/trophy.webp',
        gradientColors: const [PaykColors.headerGradientStart, PaykColors.headerGradientEnd],
        onTap: () {
          HapticFeedback.lightImpact();
          PaykMotion.push<void>(
            context,
            '/rules',
            fallback: () => const RulesScreen(),
          );
        },
      ),
      _BannerSlideData(
        title: tr(widget.locale, 'profile.bannerFriendsTitle'),
        text: tr(widget.locale, 'profile.bannerFriendsText', {'pct': '1%'}),
        imageAsset: 'assets/3d/gift.webp',
        gradientColors: const [PaykColors.headerGradientStart, PaykColors.headerGradientEnd],
        onTap: () {
          HapticFeedback.lightImpact();
          PaykMotion.push<void>(
            context,
            '/friends',
            fallback: () => const FriendsScreen(),
          );
        },
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 96,
          child: PageView.builder(
            clipBehavior: Clip.hardEdge,
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: slides.length,
            itemBuilder: (context, index) {
              final slide = slides[index];
              return _BannerSlideCard(data: slide);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final isActive = i == _currentPage;
            return AnimatedContainer(
              duration: PaykMotion.duration(context, PaykMotion.fast),
              curve: PaykMotion.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF4A4860) : const Color(0xFFD4D2DE),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerSlideData {
  const _BannerSlideData({
    required this.title,
    required this.text,
    required this.imageAsset,
    required this.gradientColors,
    required this.onTap,
  });

  final String title;
  final String text;
  final String imageAsset;
  final List<Color> gradientColors;
  final VoidCallback onTap;
}

class _BannerSlideCard extends StatelessWidget {
  const _BannerSlideCard({required this.data});

  final _BannerSlideData data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: PaykPressable(
        scaleDown: PaykMotion.scaleSubtle,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: data.onTap,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: data.gradientColors,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            data.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'Manrope',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.92),
                              fontFamily: 'Manrope',
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Image.asset(
                        data.imageAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.star_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3. Строка меню профиля (8 пунктов как на макете)
class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      scaleDown: PaykMotion.scaleSubtle,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: PaykColors.textPrimary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                        color: PaykColors.textPrimary,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: PaykColors.textSecondary,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4. Плитка переключателя «Огоҳиномаҳо»: включение/выключение уведомлений
class _ProfileNotificationToggleCard extends ConsumerStatefulWidget {
  const _ProfileNotificationToggleCard({
    required this.initialValue,
    required this.locale,
  });

  final bool initialValue;
  final String locale;

  @override
  ConsumerState<_ProfileNotificationToggleCard> createState() =>
      _ProfileNotificationToggleCardState();
}

class _ProfileNotificationToggleCardState
    extends ConsumerState<_ProfileNotificationToggleCard> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _ProfileNotificationToggleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _enabled = widget.initialValue;
    }
  }

  Future<void> _toggle(bool value) async {
    HapticFeedback.selectionClick();
    setState(() => _enabled = value);
    try {
      await ref.read(sessionProvider.notifier).setMessages(value);
      ref.invalidate(meProvider);
    } catch (_) {
      if (mounted) setState(() => _enabled = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PaykColors.surfaceNested,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(widget.locale, 'home.notificationsPrompt'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: PaykColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 0.9,
            child: Switch.adaptive(
              value: _enabled,
              activeThumbColor: Colors.white,
              activeTrackColor: PaykColors.primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFD1D1D6),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              onChanged: _toggle,
            ),
          ),
        ],
      ),
    );
  }
}

void _showStoreDialog(BuildContext context, Account account) {
  final storeName = account.store.isNotEmpty ? account.store : 'MSX Алмоси';
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: PaykColors.canvas,
    sheetAnimationStyle: PaykMotion.sheetAnimationStyle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PaykColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              storeName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: PaykColors.textPrimary,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: PaykColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 32,
                color: PaykColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Мағозаи асосии шумо дар экосистемаи ПАЙК.\nҲамаи кэшбэкҳо ва статусҳо дар ин ҷо фаъоланд.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: PaykColors.textSecondary,
                fontFamily: 'Manrope',
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: PaykColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Фаҳмо'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showStoreContactDialog(
  BuildContext context, {
  String storeName = 'MSX Алмоси',
  String locale = 'tj',
}) {
  const rawNumber = '+992555518220';
  const formattedNumber = '+992 55 551 82 20';
  final isTj = locale == 'tj';

  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: PaykColors.canvas,
    sheetAnimationStyle: PaykMotion.sheetAnimationStyle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PaykColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7ED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      color: Color(0xFF25D366),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTj ? 'Алоқа бо мағоза' : 'Связь с магазином',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: PaykColors.textPrimary,
                            fontFamily: 'Manrope',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'WhatsApp · $storeName',
                          style: const TextStyle(
                            fontSize: 13,
                            color: PaykColors.textSecondary,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: PaykColors.textPrimary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ContactActionTile(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF25D366),
                iconBg: const Color(0xFFE8F7ED),
                title: isTj ? 'WhatsApp-и мағоза' : 'WhatsApp магазина',
                subtitle: isTj
                    ? '$formattedNumber · Чат дар WhatsApp'
                    : '$formattedNumber · Чат в WhatsApp',
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: rawNumber));
                  HapticFeedback.lightImpact();
                  Navigator.pop(ctx);
                  showPaykMessage(
                    context,
                    isTj
                        ? 'Рақами WhatsApp нусха шуд: $formattedNumber'
                        : 'Номер WhatsApp скопирован: $formattedNumber',
                  );
                },
              ),
              const SizedBox(height: 10),
              _ContactActionTile(
                icon: Icons.phone_in_talk_rounded,
                iconColor: const Color(0xFF22C55E),
                iconBg: const Color(0xFFE8F7ED),
                title: isTj ? 'Занг ба мағоза' : 'Звонок в магазин',
                subtitle: '$formattedNumber · Телефон',
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: rawNumber));
                  HapticFeedback.lightImpact();
                  Navigator.pop(ctx);
                  showPaykMessage(
                    context,
                    isTj
                        ? 'Рақами телефон нусха шуд: $formattedNumber'
                        : 'Номер телефона скопирован: $formattedNumber',
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}


// -----------------------------------------------------------------------------
// ДИАЛОГИ И МОДАЛКИ ДЛЯ ПУНКТОВ МЕНЮ
// -----------------------------------------------------------------------------

void _showAboutDialog(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: PaykColors.canvas,
    sheetAnimationStyle: PaykMotion.sheetAnimationStyle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PaykColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: PaykColors.textPrimary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: PaykColors.primary.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/payk_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: PaykColors.primary,
                            alignment: Alignment.center,
                            child: const Text(
                              'P',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Payk',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: PaykColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Единая экосистема лояльности',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: PaykColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: PaykColors.tile,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: PaykColors.border),
                      ),
                      child: const Text(
                        'Версия 1.0.0 (Build 1)',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PaykColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: PaykColors.tile,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PaykColors.border),
                ),
                child: Column(
                  children: [
                    const _AboutInfoRow(
                      icon: Icons.verified_user_outlined,
                      title: 'Разработчик',
                      value: 'Экосистема Payk',
                    ),
                    const Divider(height: 1, indent: 52, color: PaykColors.border),
                    _AboutInfoRow(
                      icon: Icons.language_rounded,
                      title: 'Официальный сайт',
                      value: 'payk.tj',
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: 'https://payk.tj'));
                        showPaykMessage(context, 'Ссылка скопирована: https://payk.tj');
                      },
                    ),
                    const Divider(height: 1, indent: 52, color: PaykColors.border),
                    _AboutInfoRow(
                      icon: Icons.description_outlined,
                      title: 'Условия использования',
                      value: 'Открыть',
                      onTap: () {
                        showPaykMessage(context, 'Пользовательское соглашение Payk');
                      },
                    ),
                    const Divider(height: 1, indent: 52, color: PaykColors.border),
                    _AboutInfoRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Политика конфиденциальности',
                      value: 'Открыть',
                      onTap: () {
                        showPaykMessage(context, 'Политика обработки данных Payk');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: PaykColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Понятно',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}



class _ContactActionTile extends StatelessWidget {
  const _ContactActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PaykColors.tile,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PaykColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PaykColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: PaykColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: PaykColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: PaykColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PaykColors.textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PaykColors.primary,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: PaykColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. ДЕТАЛЬНЫЙ ЭКРАН ПРОФИЛЯ (ТЕКУЩИЙ ЭКРАН С 7 КАРТОЧКАМИ И КНОПКОЙ ВЫХОДА)
// =============================================================================

/// Детальный экран настроек профиля:
/// Открывается при нажатии на верхний виджет пользователя на главном экране профиля.
/// Содержит AppBar с кнопкой «Выйти» и карточки профиля:
/// аватар, данные пользователя, контакты, способы входа и удаление аккаунта.
class ProfileDetailsScreen extends ConsumerWidget {
  const ProfileDetailsScreen({super.key});

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
            icon: const Icon(Icons.arrow_back, color: PaykColors.textPrimary),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                PaykMotion.go(
                  context,
                  '/profile',
                  fallback: () => const ProfileScreen(),
                );
              }
            },
            tooltip: 'Назад',
          ),
        ),
        title: const Text(
          'Профиль',
          style: TextStyle(
            color: PaykColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Manrope',
          ),
        ),
        actions: [
          PaykPressable(
            scaleDown: PaykMotion.scaleIcon,
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: PaykColors.textPrimary),
              tooltip: 'Выйти',
              onPressed: () {
                HapticFeedback.lightImpact();
                _confirmLogout(context, ref, locale);
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncView(
        value: ref.watch(meProvider),
        onRetry: () => ref.invalidate(meProvider),
        loading: const ProfileDetailsSkeleton(),
        data: (account) {
          final member = account.member;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: [
              // 1. Карточка аватара
              _ProfileAvatarCard(
                member: member,
                onAddImage: () => _pickAvatar(context, ref),
              ),
              const SizedBox(height: 14),

              // 2. Карточка «Пользователь»
              _UserInfoCard(
                member: member,
                onEdit: () => _showEditProfileSheet(context, ref, member),
              ),
              const SizedBox(height: 14),

              // 3. Карточка «Контакты»
              _ContactsCard(
                member: member,
                onChangePassword: () => showPaykMessage(context, 'Вход осуществляется по коду из SMS'),
              ),
              const SizedBox(height: 14),

              // 4. Карточка «Способы входа»
              const _LoginMethodsCard(),
              const SizedBox(height: 14),

              // 7. Карточка «Удаление аккаунта»
              _DeleteAccountCard(
                onDelete: () => _confirmDeleteAccount(context, ref),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 7 ИСХОДНЫХ КАРТОЧЕК ДЕТАЛЬНОГО ПРОФИЛЯ
// -----------------------------------------------------------------------------

Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    await ref.read(loyaltyApiProvider).uploadAvatar(picked.path);
    ref.invalidate(meProvider);
    if (context.mounted) showPaykMessage(context, 'Фото профиля обновлено');
  } catch (error) {
    if (context.mounted) showPaykMessage(context, errorText(error));
  }
}

/// 1. Карточка аватара
class _ProfileAvatarCard extends StatelessWidget {
  const _ProfileAvatarCard({
    required this.member,
    required this.onAddImage,
  });

  final Member member;
  final VoidCallback onAddImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border, width: 1.0),
      ),
      child: Row(
        children: [
          PaykAvatar(member: member, size: 56, onAdd: onAddImage),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Изображение профиля',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onAddImage,
                  child: const Text(
                    'Добавить изображение',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PaykColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. Карточка «Пользователь»
class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({
    required this.member,
    required this.onEdit,
  });

  final Member member;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final rawName = '${member.firstName} ${member.lastName}'.trim();
    final fullName = rawName.isNotEmpty ? rawName : 'Не указано';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Пользователь',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PaykColors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18, color: PaykColors.primary),
                label: const Text(
                  'Изменить',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Имя и фамилия',
            value: fullName,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Дата рождения',
            value: _birthLabel(member.birthDate),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Пол',
            value: _genderLabel(member.gender),
          ),
        ],
      ),
    );
  }
}

/// 3. Карточка «Контакты»
class _ContactsCard extends StatelessWidget {
  const _ContactsCard({
    required this.member,
    required this.onChangePassword,
  });

  final Member member;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Контакты',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PaykColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: onChangePassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Сменить пароль',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Номер телефона',
            value: formatPhone(member.phone),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Электронная почта',
            value: (member.email != null && member.email!.isNotEmpty) ? member.email! : 'Не указана',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: PaykColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PaykColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}


/// 6. Карточка «Способы входа»
class _LoginMethodsCard extends ConsumerWidget {
  const _LoginMethodsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(meProvider).asData?.value.member;
    final isTelegramLinked = member?.telegram ?? false;

    return PaykPressable(
      scaleDown: PaykMotion.scaleSubtle,
      child: Container(
        decoration: BoxDecoration(
          color: PaykColors.sheet,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PaykColors.border, width: 1.0),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              PaykMotion.push<void>(
                context,
                '/profile/connect',
                fallback: () => const ConnectScreen(),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Способы входа',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PaykColors.textPrimary,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      Text(
                        'Посмотреть',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PaykColors.primary,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const _SocialCheckBadge(type: _SocialBadgeType.sms),
                      const SizedBox(width: 12),
                      _SocialCheckBadge(
                        type: _SocialBadgeType.telegram,
                        isConnected: isTelegramLinked,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 7. Карточка «Удаление аккаунта»
class _DeleteAccountCard extends StatelessWidget {
  const _DeleteAccountCard({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Удаление аккаунта',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PaykColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Все бонусы будут удалены',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: PaykColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onDelete,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor: PaykColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ДИАЛОГИ РЕДАКТИРОВАНИЯ И ВЫХОДА ДЕТАЛЬНОГО ПРОФИЛЯ
// -----------------------------------------------------------------------------

Future<void> _showEditProfileSheet(BuildContext context, WidgetRef ref, Member member) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: PaykColors.sheet,
    sheetAnimationStyle: PaykMotion.sheetAnimationStyle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _EditProfileSheet(member: member),
  );
  if (saved == true && context.mounted) {
    ref.invalidate(meProvider);
    showPaykMessage(context, 'Профиль обновлён');
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.member});

  final Member member;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _first = TextEditingController(text: widget.member.firstName);
  late final TextEditingController _last = TextEditingController(text: widget.member.lastName);
  late DateTime? _birth = DateTime.tryParse(widget.member.birthDate ?? '');
  late String _gender = widget.member.gender == 'm' || widget.member.gender == 'f' ? widget.member.gender! : '';
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final first = DateTime(1920);
    final year = now.year - 14;
    final lastDay = DateTime(year, now.month + 1, 0).day;
    final last = DateTime(year, now.month, now.day > lastDay ? lastDay : now.day);
    final initial = _clampDate(_birth ?? DateTime(last.year, 6, 15), first, last);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Дата рождения',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (picked != null && mounted) setState(() => _birth = picked);
  }

  Future<void> _save() async {
    final firstName = _first.text.trim();
    final lastName = _last.text.trim();
    if (!_hasLetter(firstName) || !_hasLetter(lastName)) {
      setState(() => _error = 'Напишите имя и фамилию');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final birthDate = _birth == null
        ? ''
        : '${_birth!.year.toString().padLeft(4, '0')}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(sessionProvider.notifier).updateProfile(
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            gender: _gender,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PaykColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Изменить профиль',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: PaykColors.textPrimary, letterSpacing: -0.3),
              ),
              const SizedBox(height: 4),
              const Text(
                'Имя, дата рождения и пол',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: PaykColors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _first,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
                decoration: _fieldDecoration('Имя'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _last,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                enabled: !_busy,
                decoration: _fieldDecoration('Фамилия'),
              ),
              const SizedBox(height: 18),
              const Text(
                'Дата рождения',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PaykColors.textSecondary),
              ),
              const SizedBox(height: 8),
              _SheetTile(
                icon: Icons.calendar_today_rounded,
                title: _birth == null ? 'Не указана' : formatDate(_birth!),
                subtitle: 'День, месяц и год',
                onTap: _busy ? null : _pickBirth,
                trailing: _birth == null
                    ? const Icon(Icons.chevron_right_rounded, color: PaykColors.textSecondary)
                    : IconButton(
                        onPressed: _busy ? null : () => setState(() => _birth = null),
                        icon: const Icon(Icons.close_rounded, size: 18, color: PaykColors.textSecondary),
                        tooltip: 'Убрать дату',
                      ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Пол',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PaykColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _GenderChoice(
                      label: 'Мужской',
                      selected: _gender == 'm',
                      onTap: _busy ? null : () => setState(() => _gender = _gender == 'm' ? '' : 'm'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GenderChoice(
                      label: 'Женский',
                      selected: _gender == 'f',
                      onTap: _busy ? null : () => setState(() => _gender = _gender == 'f' ? '' : 'f'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(color: PaykColors.danger, fontWeight: FontWeight.w600, height: 1.3),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Сохраняем…' : 'Сохранить'),
              ),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PaykColors.tile,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: PaykColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: PaykColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: PaykColors.textSecondary),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderChoice extends StatelessWidget {
  const _GenderChoice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      enabled: onTap != null,
      scaleDown: PaykMotion.scaleButton,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: PaykMotion.duration(context, PaykMotion.fast),
            curve: PaykMotion.easeOut,
            decoration: BoxDecoration(
              color: selected ? PaykColors.primary : PaykColors.tile,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : PaykColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: PaykColors.tile,
  );
}

bool _hasLetter(String value) => value.runes.any((code) => String.fromCharCode(code).contains(RegExp(r'\p{L}', unicode: true)));

DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
}

String _birthLabel(String? raw) {
  if (raw == null || raw.isEmpty) return 'Не указана';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return formatDate(parsed);
}

String _genderLabel(String? raw) {
  return switch (raw) {
    'm' => 'Мужской',
    'f' => 'Женский',
    _ => 'Не указан',
  };
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref, String locale) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Выйти из аккаунта?'),
      content: const Text('Вы будете перенаправлены на экраны заставки и авторизации.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: PaykColors.bad),
          child: const Text('Выйти'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(sessionProvider.notifier).logout();
    ref.invalidate(meProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(friendsProvider);
  }
}

Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Удалить аккаунт?'),
      content: const Text('Все ваши накопленные бонусы, статус и история операций будут безвозвратно удалены. Вы уверены?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: PaykColors.bad),
          child: const Text('Удалить навсегда'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(sessionProvider.notifier).logout();
    ref.invalidate(meProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(friendsProvider);
  }
}
