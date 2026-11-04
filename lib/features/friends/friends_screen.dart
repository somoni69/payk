import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

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

/// Экран раздела «Друзья» (Дӯстон) в фирменном стиле Payk Ecosystem.
/// Полностью соответствует дизайну loyalty-app:
/// 1. Hero-карточка: градиентный баннер с 3D-подарком (`assets/3d/gift.webp`),
///    пунктирный контейнер с кодом приглашения и кнопка «Даъват фиристодан».
/// 2. Сетка статистики 2x2 (Дӯстони шумо, Дӯстони онҳо, Ҳамагӣ гирифтед, Дар ин моҳ).
/// 3. Секция «Даъватшудагон» с 3D-хлопушкой (`assets/3d/party.webp`) для пустого состояния
///    или списком приглашённых с аватаром, уровнем и суммой кэшбэка.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final store = ref.watch(meProvider).asData?.value.store ?? '';
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      body: AsyncView(
        value: ref.watch(friendsProvider),
        onRetry: () => ref.invalidate(friendsProvider),
        loading: const FriendsSkeleton(),
        data: (friends) => _FriendsBody(
          friends: friends,
          store: store,
          locale: locale,
          canPop: canPop,
        ),
      ),
    );
  }
}

class _FriendsBody extends StatelessWidget {
  const _FriendsBody({
    required this.friends,
    required this.store,
    required this.locale,
    required this.canPop,
  });

  final FriendsInfo friends;
  final String store;
  final String locale;
  final bool canPop;

  Future<void> _share(BuildContext context) async {
    final where = store.isEmpty ? '' : ' в $store';
    final link = friends.link;
    final text =
        'Присоединяйтесь к бонусной программе ПАЙК$where — кэшбэк с каждой покупки. Мой код приглашения: ${friends.code}${link == null ? '' : '\n$link'}';

    final result = await SharePlus.instance.share(ShareParams(text: text));
    if (!context.mounted) return;
    if (result.status == ShareResultStatus.unavailable) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      showPaykMessage(context, tr(locale, 'friends.copied'));
    }
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: friends.code));
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    showPaykMessage(context, tr(locale, 'friends.copied'));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 104),
      physics: const ClampingScrollPhysics(),
      children: [
        // 1. Баннер приглашения на всю ширину, на месте заголовка
        Container(
          decoration: const BoxDecoration(
            color: PaykColors.sheet,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Градиентная верхняя часть
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PaykColors.headerGradientStart,
                      PaykColors.headerGradientEnd,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, canPop ? 0 : 16, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canPop)
                            PaykPressable(
                              scaleDown: PaykMotion.scaleIcon,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).maybePop();
                                },
                              ),
                            ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.68,
                            ),
                            child: Text(
                              tr(locale, 'friends.heroTitle'),
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(right: 108),
                            child: Text(
                              tr(locale, 'friends.explain', {
                                'l1': formatPercent(friends.level1),
                                'l2': formatPercent(friends.level2),
                                'months': '${friends.months}',
                              }),
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.92),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 8,
                      child: Image.asset(
                        'assets/3d/gift.webp',
                        width: 128,
                        height: 128,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ],
                  ),
                ),
              ),

              // Белая нижняя часть с кодом и кнопкой
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(locale, 'friends.yourCode'),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PaykColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Пунктирный блок кода
                    CustomPaint(
                      painter: _DashedBorderPainter(
                        color: PaykColors.primary.withValues(alpha: 0.35),
                        strokeWidth: 1.5,
                        dashWidth: 6.0,
                        dashSpace: 4.0,
                        radius: 14.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: PaykColors.activePill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                friends.code,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  color: PaykColors.primary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                             PaykPressable(
                               scaleDown: PaykMotion.scaleIcon,
                               child: IconButton(
                                 icon: const Icon(
                                   Icons.copy_rounded,
                                   color: PaykColors.primary,
                                   size: 22,
                                 ),
                                 onPressed: () => _copyCode(context),
                                 tooltip: tr(locale, 'code.copy'),
                               ),
                             ),
                           ],
                         ),
                       ),
                     ),
                     const SizedBox(height: 14),

                     // Кнопка «Даъват фиристодан»
                     PaykPressable(
                       child: SizedBox(
                         width: double.infinity,
                         height: 50,
                         child: FilledButton.icon(
                           style: FilledButton.styleFrom(
                             backgroundColor: PaykColors.primary,
                             foregroundColor: Colors.white,
                             elevation: 0,
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(14),
                             ),
                           ),
                           onPressed: () {
                             HapticFeedback.lightImpact();
                             _share(context);
                           },
                           icon: const Icon(Icons.share_outlined, size: 19),
                           label: Text(
                             tr(locale, 'friends.share'),
                             style: const TextStyle(
                               fontFamily: 'Manrope',
                               fontSize: 16,
                               fontWeight: FontWeight.w700,
                             ),
                           ),
                         ),
                       ),
                     ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Сетка статистики 2x2
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
          children: [
            Expanded(
              child: _StatCard(
                label: tr(locale, 'friends.l1'),
                value: '${friends.countL1}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: tr(locale, 'friends.l2'),
                value: '${friends.countL2}',
              ),
            ),
          ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
          children: [
            Expanded(
              child: _StatCard(
                label: tr(locale, 'friends.total'),
                value: formatMoney(friends.total),
                isIncome: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: tr(locale, 'friends.month'),
                value: formatMoney(friends.month),
              ),
            ),
          ],
          ),
        ),

        const SizedBox(height: 18),

        // 3. Заголовок секции списка приглашённых
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
          tr(locale, 'friends.list'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: PaykColors.textPrimary,
          ),
          ),
        ),
        const SizedBox(height: 10),

        // Карточка пустого состояния или списка
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
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
          clipBehavior: Clip.antiAlias,
          child: friends.invitees.isEmpty
              ? _EmptyFriends(locale: locale)
              : _InviteesList(invitees: friends.invitees, locale: locale),
          ),
        ),
      ],
    );
  }
}

/// Виджет одной карточки статистики
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.isIncome = false,
  });

  final String label;
  final String value;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: PaykColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isIncome ? PaykColors.success : PaykColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Виджет пустого состояния с 3D-хлопушкой
class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PaykColors.activePill,
            ),
            child: Center(
              child: Image.asset(
                'assets/3d/party.webp',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(locale, 'friends.empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PaykColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(locale, 'friends.emptyText'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: PaykColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Список приглашённых пользователей
class _InviteesList extends StatelessWidget {
  const _InviteesList({
    required this.invitees,
    required this.locale,
  });

  final List<Invitee> invitees;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < invitees.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              thickness: 1,
              color: PaykColors.border,
            ),
          _InviteeRow(
            invitee: invitees[i],
            locale: locale,
          ),
        ],
      ],
    );
  }
}

class _InviteeRow extends StatelessWidget {
  const _InviteeRow({
    required this.invitee,
    required this.locale,
  });

  final Invitee invitee;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final own = invitee.level <= 2;
    final initial = (invitee.firstName.isNotEmpty ? invitee.firstName[0] : '?')
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: own ? PaykColors.activePill : PaykColors.tile,
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: own ? PaykColors.primary : PaykColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitee.firstName,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  invitee.phone,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    color: PaykColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${own ? tr(locale, 'friends.level2') : tr(locale, 'friends.level3')} · ${tr(locale, 'friends.activeUntil', {'date': formatShortDate(invitee.activeUntil)})}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: PaykColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(invitee.earned, signed: true),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: invitee.earned > 0
                  ? PaykColors.success
                  : PaykColors.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Рисовальщик пунктирной рамки со скруглёнными углами
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.radius = 14.0,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.radius != radius;
  }
}
