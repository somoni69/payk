import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/birthday.dart';
import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../categories/categories_screen.dart';
import '../code/client_code_screen.dart';
import '../friends/friends_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../sizes/sizes_screen.dart';
import 'home_header.dart';
import 'loyalty_card.dart';

/// Главный экран мобильного приложения Payk в стиле UDC (Milestone 2):
/// - Фиолетовая шапка с градиентом #9F72E7 -> #8574E6 и скруглением 24 dp.
/// - Круглый аватар пользователя 48x48 dp с рамкой.
/// - Персонализированное приветствие «Привет, [Имя]!» и подзаголовок «С возвращением!».
/// - Полупрозрачные кнопки QR-сканера и уведомлений (колокольчик).
/// - Карточки быстрого доступа: «QR-код», «Мои компании», «Мои сертификаты».
/// - Корректная интеграция с Riverpod (`meProvider`, `messagesProvider`, баланс, сессия).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: PaykColors.canvas,
        child: AsyncView(
          value: ref.watch(meProvider),
          onRetry: () => ref.invalidate(meProvider),
          loading: const HomeSkeleton(),
          data: (account) => _HomeBody(
            account: account,
            locale: ref.watch(localeProvider),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({
    required this.account,
    required this.locale,
  });

  final Account account;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = account.member;
    final wallet = account.wallet;

    return RefreshIndicator(
      color: PaykColors.violet,
      backgroundColor: Colors.white,
      edgeOffset: MediaQuery.paddingOf(context).top,
      displacement: 28,
      onRefresh: () async {
        ref.invalidate(meProvider);
        try {
          await ref.read(meProvider.future);
        } catch (_) {}
      },
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
        // 1. Фиолетовая шапка UDC с аватаром, кнопками и быстрыми действиями
        HomeHeader(
          account: account,
          locale: locale,
          onProfileTap: () => PaykMotion.go(
            context,
            '/profile',
            fallback: () => const ProfileScreen(),
          ),
          onScannerTap: () => PaykMotion.push<void>(
            context,
            '/code',
            fallback: () => const ClientCodeScreen(),
          ),
          onNotificationsTap: () => _openMessages(context, ref, locale),
          onCodeTap: () => PaykMotion.push<void>(
            context,
            '/code',
            fallback: () => const ClientCodeScreen(),
          ),
          onCompaniesTap: () => _openCompaniesModal(context, account, locale),
          onCertificatesTap: () => _openCertificatesModal(context, account, locale),
        ),

        const SizedBox(height: 20),

        // Системные уведомления (приостановка программы, долг, подарок на ДР)
        if (!account.programEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Notice(
              title: tr(locale, 'home.paused'),
              body: tr(locale, 'home.pausedText'),
            ),
          ),

        if (wallet.debt > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Notice(
              title: tr(locale, 'home.debtTitle', {'amount': formatMoney(-wallet.debt)}),
              body: tr(locale, 'home.debtText'),
            ),
          ),

        if (_gift(member, wallet) case final gift?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Notice(
              title: tr(locale, 'home.giftTitle'),
              body: tr(locale, 'home.giftBody', {
                'amount': formatMoney(gift.amount.toDouble(), decimals: false),
                'from': formatShortDate(gift.from),
                'until': formatShortDate(gift.until),
                'cl': formatMoney(gift.minClothes.toDouble(), decimals: false),
                'sm': formatMoney(gift.minSupermarket.toDouble(), decimals: false),
              }),
            ),
          ),

        if (!member.isSizesComplete)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Notice(
              title: tr(locale, 'sizes.bannerTitle'),
              body: tr(locale, 'sizes.bannerBody'),
              onTap: () => PaykMotion.push<void>(
                context,
                '/sizes',
                fallback: () => const SizesScreen(),
              ),
            ),
          ),

        // 1. Карта статуса: вид меняется вместе с уровнем кошелька
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LoyaltyCard(
            member: member,
            wallet: wallet,
            locale: locale,
            tiers: account.tierCount,
          ),
        ),

        const SizedBox(height: 14),

        // 2. Карточка «Дӯстонро даъват кунед» (реферальный код и шаринг)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _InviteFriendsCard(
            member: member,
            locale: locale,
          ),
        ),

        const SizedBox(height: 14),

        // 3. Плитка переключателя «Огоҳиномаҳо» (уведомления)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _NotificationToggleCard(
            initialValue: member.messages,
            locale: locale,
          ),
        ),

        const SizedBox(height: 20),

        // 4. Секция «Мағозаҳо» с карточками «СУПЕРМАРКЕТ» и «ЛИБОС»
        _StoresSection(
          wallet: wallet,
          locale: locale,
        ),

        const SizedBox(height: 96),
      ],
    ),
  );
}
}

/// 2. Карточка «Дӯстонро даъват кунед»: приглашение друзей, реферальный код и шаринг
class _InviteFriendsCard extends StatelessWidget {
  const _InviteFriendsCard({
    required this.member,
    required this.locale,
  });

  final Member member;
  final String locale;

  Future<void> _share(BuildContext context, String code) async {
    HapticFeedback.lightImpact();
    final text = 'Присоединяйтесь к бонусной программе ПАЙК — кэшбэк с каждой покупки. Мой код приглашения: $code';
    try {
      final res = await SharePlus.instance.share(ShareParams(text: text));
      if (res.status == ShareResultStatus.unavailable && context.mounted) {
        await Clipboard.setData(ClipboardData(text: code));
        if (context.mounted) {
          showPaykMessage(context, tr(locale, 'friends.copied'));
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: code));
      if (context.mounted) {
        showPaykMessage(context, tr(locale, 'friends.copied'));
      }
    }
  }

  Future<void> _copy(BuildContext context, String code) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      showPaykMessage(context, tr(locale, 'friends.copied'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawCode = member.referralCode.trim();
    final code = rawCode.isNotEmpty ? rawCode : 'SO-4654';
    final displayCode = code.contains('-') ? code.replaceAll('-', ' - ') : code;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F5FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBE9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  tr(locale, 'home.inviteFriends'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PaykColors.textPrimary,
                    height: 1.3,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PaykPressable(
                scaleDown: PaykMotion.scaleIcon,
                haptic: true,
                onTap: () => PaykMotion.push<void>(
                  context,
                  '/friends',
                  fallback: () => const FriendsScreen(),
                ),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: PaykColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PaykPressable(
                  scaleDown: PaykMotion.scaleSubtle,
                  onTap: () => _copy(context, code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PaykColors.border),
                    ),
                    child: Text(
                      displayCode,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: PaykColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PaykPressable(
                scaleDown: PaykMotion.scaleIcon,
                onTap: () => _share(context, code),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: PaykColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 3. Плитка переключателя «Огоҳиномаҳо»: включение/выключение уведомлений
class _NotificationToggleCard extends ConsumerStatefulWidget {
  const _NotificationToggleCard({
    required this.initialValue,
    required this.locale,
  });

  final bool initialValue;
  final String locale;

  @override
  ConsumerState<_NotificationToggleCard> createState() => _NotificationToggleCardState();
}

class _NotificationToggleCardState extends ConsumerState<_NotificationToggleCard> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _NotificationToggleCard oldWidget) {
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
        color: const Color(0xFFF6F5FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE9F2)),
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

/// 4. Секция «Мағозаҳо» с кнопкой «Ҳама» и карточками супермаркета и одежды
class _StoresSection extends StatelessWidget {
  const _StoresSection({
    required this.wallet,
    required this.locale,
  });

  final Wallet wallet;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final smRate = wallet.rates.supermarket.earn > 0 ? wallet.rates.supermarket.earn : 0.02;
    final smBurn = wallet.rates.supermarket.burnCap > 0 ? wallet.rates.supermarket.burnCap : 0.01;
    final clRate = wallet.rates.clothes.earn > 0 ? wallet.rates.clothes.earn : 0.05;
    final clBurn = wallet.rates.clothes.burnCap > 0 ? wallet.rates.clothes.burnCap : 0.10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr(locale, 'home.stores'),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: PaykColors.textPrimary,
                ),
              ),
              PaykPressable(
                scaleDown: PaykMotion.scaleIcon,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    PaykMotion.go(
                      context,
                      '/categories',
                      fallback: () => const CategoriesScreen(),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: PaykColors.chipBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tr(locale, 'home.all'),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PaykColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _StoreRateCard(
                locale: locale,
                title: tr(locale, 'format.SM').toUpperCase(),
                assetImage: 'assets/3d/cart.webp',
                iconBgColor: const Color(0xFFF1F3F9),
                cashbackPercent: formatPercent(smRate),
                burnCapPercent: formatPercent(smBurn),
                onTap: () {
                  HapticFeedback.lightImpact();
                  PaykMotion.go(
                    context,
                    '/categories',
                    fallback: () => const CategoriesScreen(),
                  );
                },
              ),
              const SizedBox(width: 12),
              _StoreRateCard(
                locale: locale,
                title: tr(locale, 'format.CL').toUpperCase(),
                assetImage: 'assets/3d/tshirt.webp',
                iconBgColor: const Color(0xFFEBF7EE),
                cashbackPercent: formatPercent(clRate),
                burnCapPercent: formatPercent(clBurn),
                onTap: () {
                  HapticFeedback.lightImpact();
                  PaykMotion.go(
                    context,
                    '/categories',
                    fallback: () => const CategoriesScreen(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreRateCard extends StatelessWidget {
  const _StoreRateCard({
    required this.locale,
    required this.title,
    required this.assetImage,
    required this.iconBgColor,
    required this.cashbackPercent,
    required this.burnCapPercent,
    required this.onTap,
  });

  final String locale;
  final String title;
  final String assetImage;
  final Color iconBgColor;
  final String cashbackPercent;
  final String burnCapPercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      scaleDown: PaykMotion.scaleSubtle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
          width: 236,
          height: 82,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEBE9F0), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Image.asset(
                    assetImage,
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: PaykColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: tr(locale, 'home.cashbackLine', {'pct': cashbackPercent}),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              color: PaykColors.primary,
                            ),
                          ),
                          const TextSpan(
                            text: ' · ',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: PaykColors.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: tr(locale, 'home.burnLine', {'pct': burnCapPercent}),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                              color: PaykColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

/// Системное уведомление / баннер
class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body, this.onTap});

  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaykColors.notice,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: PaykColors.textPrimary,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                color: PaykColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return card;
    return PaykPressable(onTap: tap, child: card);
  }
}

/// Проверка подарка ко дню рождения
BirthdayGift? _gift(Member member, Wallet wallet) {
  final raw = member.birthDate;
  if (raw == null || raw.length < 10) return null;
  final birth = DateTime.tryParse(raw);
  if (birth == null) return null;
  return birthdayGift(birth, wallet.status, DateTime.now());
}

/// Навигация на отдельный экран «Уведомления»
void _openMessages(BuildContext context, WidgetRef ref, String locale) {
  PaykMotion.push<void>(
    context,
    '/notifications',
    fallback: () => const NotificationsScreen(),
  ).then((_) {
    ref.invalidate(meProvider);
  });
}

/// Модальный лист «Мои компании» с информацией о балансе и партнерских сетях
void _openCompaniesModal(BuildContext context, Account account, String locale) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: PaykColors.canvas,
    sheetAnimationStyle: PaykMotion.sheetAnimationStyle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final wallet = account.wallet;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr(locale, 'home.companies'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: PaykColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaykColors.tile,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PaykColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: PaykColors.activePill,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: PaykColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(locale, 'home.bonusBalance'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: PaykColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatNumber(wallet.balance)} смн',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: PaykColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr(locale, 'home.partners'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PaykColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _CompanyListTile(
                name: account.store.isNotEmpty ? account.store : 'Payk Ecosystem',
                category: tr(locale, 'home.mainNetwork'),
                status: tr(locale, 'home.networkActive'),
              ),
              const SizedBox(height: 8),
              _CompanyListTile(
                name: 'ELITESTORE',
                category: tr(locale, 'home.clothesShoes'),
                status: tr(locale, 'home.cashbackUpTo', {'pct': '10%'}),
              ),
              const SizedBox(height: 8),
              _CompanyListTile(
                name: 'A-99',
                category: tr(locale, 'format.SM'),
                status: tr(locale, 'home.cashbackUpTo', {'pct': '7%'}),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CompanyListTile extends StatelessWidget {
  const _CompanyListTile({
    required this.name,
    required this.category,
    required this.status,
  });

  final String name;
  final String category;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PaykColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: PaykColors.textPrimary,
                ),
              ),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 12,
                  color: PaykColors.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: PaykColors.activePill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PaykColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Модальный лист «Мои сертификаты»
void _openCertificatesModal(BuildContext context, Account account, String locale) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: PaykColors.canvas,
    sheetAnimationStyle: PaykMotion.sheetAnimationStyle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final gift = _gift(account.member, account.wallet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr(locale, 'home.certificates'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: PaykColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (gift != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEDEAFB), Color(0xFFF8F7FD)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PaykColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: PaykColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(locale, 'home.giftCoupon'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: PaykColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tr(locale, 'home.discountUntil', {
                                'amount': formatMoney(gift.amount.toDouble(), decimals: false),
                                'date': formatShortDate(gift.until),
                              }),
                              style: const TextStyle(
                                fontSize: 13,
                                color: PaykColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PaykColors.tile,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PaykColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        size: 40,
                        color: PaykColors.textMuted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(locale, 'home.noCoupons'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: PaykColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(locale, 'home.noCouponsText'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PaykColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
