import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../theme/payk_colors.dart';
import 'shimmer.dart';

const _headerBone = Color(0x29FFFFFF);
const _headerShine = Color(0x52FFFFFF);
const _darkCardBone = Color(0x1EFFFFFF);
const _darkCardShine = Color(0x3DFFFFFF);

/// Измеряет точную геометрию [TextPainter] для эталонной строки с тем же [TextStyle]
/// и рендерит кости-линии точно той же суммарной высоты (погрешность 0.0 px при любой
/// ширине экрана, локали RU/TJ и системном масштабе шрифта).
class _MeasuredTextBones extends StatelessWidget {
  const _MeasuredTextBones({
    required this.sample,
    required this.style,
    required this.barHeight,
    this.radius = 6,
    this.color,
    this.highlight,
    this.fixedWidth,
  });

  final String sample;
  final TextStyle style;
  final double barHeight;
  final double radius;
  final Color? color;
  final Color? highlight;
  final double? fixedWidth;

  static const _fallbackFactors = [0.92, 0.86, 0.94, 0.46];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final painter = TextPainter(
          text: TextSpan(text: sample, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: maxW > 0 ? maxW : double.infinity);

        final metrics = painter.computeLineMetrics();
        final totalHeight = painter.height;
        final lines = metrics.isEmpty ? 1 : metrics.length;
        painter.dispose();

        final slotHeight = totalHeight / lines;
        final effectiveBar = barHeight > slotHeight ? slotHeight : barHeight;

        return SizedBox(
          height: totalHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines; i++)
                SizedBox(
                  height: slotHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: fixedWidth != null
                        ? SkeletonBox(
                            width: fixedWidth,
                            height: effectiveBar,
                            radius: radius,
                            color: color,
                            highlight: highlight,
                          )
                        : FractionallySizedBox(
                            widthFactor: i < metrics.length && maxW > 0
                                ? (metrics[i].width / maxW).clamp(0.28, 0.98)
                                : _fallbackFactors[i % _fallbackFactors.length],
                            alignment: Alignment.centerLeft,
                            child: SkeletonBox(
                              height: effectiveBar,
                              radius: radius,
                              color: color,
                              highlight: highlight,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Занимает точную высоту строки текста (`fontSize * lineHeight` с учётом `textScaler`),
/// рисуя внутри скруглённую кость заданной визуальной толщины.
/// Убирает вертикальный «прыжок» при замене скелетона на реальный [Text].
class _TextLineBone extends StatelessWidget {
  const _TextLineBone({
    required this.fontSize,
    required this.barHeight,
    this.lineHeight = 1.25,
    this.width,
    this.widthFactor,
    this.radius = 6,
    this.color,
    this.highlight,
  });

  final double fontSize;
  final double barHeight;
  final double lineHeight;
  final double? width;
  final double? widthFactor;
  final double radius;
  final Color? color;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(fontSize) * lineHeight;
    final boxHeight = scaled < barHeight ? barHeight : scaled;
    Widget bar = SkeletonBox(
      width: width,
      height: barHeight,
      radius: radius,
      color: color,
      highlight: highlight,
    );
    if (widthFactor != null) {
      bar = FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: bar,
      );
    }
    return SizedBox(
      height: boxHeight,
      child: Align(alignment: Alignment.centerLeft, child: bar),
    );
  }
}

/// Главная: шапка, карта статуса, прогресс роста, приглашение, переключатель.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        children: const [
          _HomeHeaderBones(),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _LoyaltyCardBones(),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _StatusGrowthBones(),
          ),
          SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _InviteBones(),
          ),
          SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _ToggleBones(),
          ),
          SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _HomeHeaderBones extends StatelessWidget {
  const _HomeHeaderBones();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          top: -1000,
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: PaykColors.headerGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(PaykRadius.header),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    SkeletonBox(
                      width: 48,
                      height: 48,
                      circle: true,
                      color: _headerBone,
                      highlight: _headerShine,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(
                            width: 144,
                            height: 14,
                            radius: 6,
                            color: _headerBone,
                            highlight: _headerShine,
                          ),
                          SizedBox(height: 6),
                          SkeletonBox(
                            width: 98,
                            height: 11,
                            radius: 6,
                            color: _headerBone,
                            highlight: _headerShine,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    SkeletonBox(
                      width: 42,
                      height: 42,
                      radius: 14,
                      color: _headerBone,
                      highlight: _headerShine,
                    ),
                    SizedBox(width: 8),
                    SkeletonBox(
                      width: 42,
                      height: 42,
                      radius: 14,
                      color: _headerBone,
                      highlight: _headerShine,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: const [
                    _QuickActionTileBone(width: 108, hasSubtitle: false),
                    SizedBox(width: 10),
                    _QuickActionTileBone(width: 138, hasSubtitle: true),
                    SizedBox(width: 10),
                    _QuickActionTileBone(width: 138, hasSubtitle: true),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionTileBone extends StatelessWidget {
  const _QuickActionTileBone({required this.width, required this.hasSubtitle});

  final double width;
  final bool hasSubtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 114,
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SkeletonBox(width: 42, height: 42, radius: 12),
          const SizedBox(height: 8),
          SkeletonBox(width: hasSubtitle ? 84 : 62, height: 12, radius: 5),
          if (hasSubtitle) ...[
            const SizedBox(height: 5),
            const SkeletonBox(width: 48, height: 10, radius: 5),
          ],
        ],
      ),
    );
  }
}

class _LoyaltyCardBones extends StatelessWidget {
  const _LoyaltyCardBones();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF3E4454), Color(0xFF545B6E)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x283B4150),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TextLineBone(
                    fontSize: 11,
                    lineHeight: 1.1,
                    barHeight: 10,
                    width: 68,
                    radius: 4,
                    color: _darkCardBone,
                    highlight: _darkCardShine,
                  ),
                  SizedBox(height: 3),
                  _TextLineBone(
                    fontSize: 22,
                    lineHeight: 1.1,
                    barHeight: 20,
                    width: 104,
                    radius: 6,
                    color: _darkCardBone,
                    highlight: _darkCardShine,
                  ),
                ],
              ),
              Spacer(),
              SkeletonBox(
                width: 92,
                height: 29,
                radius: 20,
                color: _darkCardBone,
                highlight: _darkCardShine,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _TextLineBone(
            fontSize: 13,
            lineHeight: 1.1,
            barHeight: 11,
            width: 60,
            radius: 5,
            color: _darkCardBone,
            highlight: _darkCardShine,
          ),
          const SizedBox(height: 2),
          const _TextLineBone(
            fontSize: 34,
            lineHeight: 1.0,
            barHeight: 30,
            width: 164,
            radius: 8,
            color: _darkCardBone,
            highlight: _darkCardShine,
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: _CardRateTileBone()),
              SizedBox(width: 8),
              Expanded(child: _CardRateTileBone()),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _TextLineBone(
                fontSize: 13,
                lineHeight: 1.2,
                barHeight: 12,
                width: 128,
                radius: 5,
                color: _darkCardBone,
                highlight: _darkCardShine,
              ),
              Spacer(),
              _TextLineBone(
                fontSize: 13,
                lineHeight: 1.2,
                barHeight: 12,
                width: 68,
                radius: 5,
                color: _darkCardBone,
                highlight: _darkCardShine,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardRateTileBone extends StatelessWidget {
  const _CardRateTileBone();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x30000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1EFFFFFF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextLineBone(
            fontSize: 11,
            lineHeight: 1.15,
            barHeight: 10,
            width: 74,
            radius: 4,
            color: _darkCardBone,
            highlight: _darkCardShine,
          ),
          SizedBox(height: 4),
          _TextLineBone(
            fontSize: 15,
            lineHeight: 1.15,
            barHeight: 14,
            width: 64,
            radius: 5,
            color: _darkCardBone,
            highlight: _darkCardShine,
          ),
        ],
      ),
    );
  }
}

class _StatusGrowthBones extends StatelessWidget {
  const _StatusGrowthBones();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      padding: EdgeInsets.all(14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _TextLineBone(
                  fontSize: 13.5,
                  barHeight: 13,
                  width: 156,
                  radius: 5,
                ),
              ),
              SizedBox(width: 8),
              SkeletonBox(width: 68, height: 26, radius: 10),
            ],
          ),
          SizedBox(height: 10),
          SkeletonBox(height: 7, radius: 99),
          SizedBox(height: 10),
          _TextLineBone(
            fontSize: 14,
            lineHeight: 1.3,
            barHeight: 13,
            widthFactor: 0.9,
            radius: 5,
          ),
          _TextLineBone(
            fontSize: 14,
            lineHeight: 1.3,
            barHeight: 13,
            widthFactor: 0.42,
            radius: 5,
          ),
        ],
      ),
    );
  }
}

class _InviteBones extends StatelessWidget {
  const _InviteBones();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextLineBone(fontSize: 15, barHeight: 14, width: 220, radius: 6),
          SizedBox(height: 4),
          _TextLineBone(fontSize: 15, barHeight: 14, width: 150, radius: 6),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 50, radius: 16)),
              SizedBox(width: 10),
              SkeletonBox(width: 50, height: 50, radius: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleBones extends StatelessWidget {
  const _ToggleBones();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      radius: 20,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: SkeletonBox(height: 14, radius: 6)),
          SizedBox(width: 16),
          SkeletonBox(width: 48, height: 28, radius: 14),
        ],
      ),
    );
  }
}

/// Вкладка профиля: шапка, способы входа, баннер, меню.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 104),
        physics: ClampingScrollPhysics(),
        children: [
          SkeletonCard(
            child: Row(
              children: [
                SkeletonBox(width: 54, height: 54, circle: true),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 16, radius: 6),
                      SizedBox(height: 8),
                      SkeletonBox(width: 88, height: 12, radius: 6),
                    ],
                  ),
                ),
                SkeletonBox(width: 18, height: 18, radius: 6),
              ],
            ),
          ),
          SizedBox(height: 12),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 140, height: 16, radius: 6),
                    Spacer(),
                    SkeletonBox(width: 52, height: 14, radius: 6),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, circle: true),
                    SizedBox(width: 12),
                    SkeletonBox(width: 40, height: 40, circle: true),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          SkeletonBox(height: 96, radius: 16),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonBox(width: 24, height: 6, radius: 3),
              SizedBox(width: 6),
              SkeletonBox(width: 6, height: 6, circle: true),
            ],
          ),
          SizedBox(height: 16),
          _MenuBone(wide: true),
          _MenuBone(),
          _MenuBone(wide: true),
          _MenuBone(),
          _MenuBone(),
          SizedBox(height: 12),
          _ToggleBones(),
        ],
      ),
    );
  }
}

class _MenuBone extends StatelessWidget {
  const _MenuBone({this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          const SkeletonBox(width: 24, height: 24, radius: 6),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: wide ? 180 : 140, height: 14, radius: 6),
                if (wide) ...[
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 96, height: 11, radius: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Детали профиля: аватар, пользователь, контакты, вход, удаление.
class ProfileDetailsSkeleton extends StatelessWidget {
  const ProfileDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 96),
        physics: ClampingScrollPhysics(),
        children: [
          SkeletonCard(
            child: Row(
              children: [
                SkeletonBox(width: 56, height: 56, circle: true),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 170, height: 16, radius: 6),
                      SizedBox(height: 8),
                      SkeletonBox(width: 130, height: 13, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          _InfoCardBones(rows: 3),
          SizedBox(height: 14),
          _InfoCardBones(rows: 2),
          SizedBox(height: 14),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 16, radius: 6),
                SizedBox(height: 14),
                Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, circle: true),
                    SizedBox(width: 12),
                    SkeletonBox(width: 40, height: 40, circle: true),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160, height: 16, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 180, height: 13, radius: 6),
                SizedBox(height: 14),
                SkeletonBox(height: 46, radius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCardBones extends StatelessWidget {
  const _InfoCardBones({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Column(
        children: [
          const Row(
            children: [
              SkeletonBox(width: 120, height: 16, radius: 6),
              Spacer(),
              SkeletonBox(width: 72, height: 14, radius: 6),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            const Row(
              children: [
                SkeletonBox(width: 110, height: 13, radius: 6),
                Spacer(),
                SkeletonBox(width: 88, height: 13, radius: 6),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Покупки: сетка категорий и строки операций (шапка уже отрендерена сверху).
class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        physics: const ClampingScrollPhysics(),
        children: [
          const _MeasuredTextBones(
            sample: 'Категории',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            barHeight: 16,
            fixedWidth: 118,
            radius: 6,
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: _CategoryBone()),
              SizedBox(width: 8),
              Expanded(child: _CategoryBone()),
              SizedBox(width: 8),
              Expanded(child: _CategoryBone()),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(child: _CategoryBone()),
              SizedBox(width: 8),
              Expanded(child: _CategoryBone()),
              SizedBox(width: 8),
              Expanded(child: _CategoryBone()),
            ],
          ),
          const SizedBox(height: 20),
          SkeletonCard(
            padding: EdgeInsets.zero,
            radius: 20,
            child: Column(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 70,
                      endIndent: 14,
                      color: PaykColors.border,
                    ),
                  const _HistoryRowBone(squareIcon: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBone extends StatelessWidget {
  const _CategoryBone();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
      decoration: BoxDecoration(
        color: PaykColors.surfaceNested,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 64, height: 12, radius: 5),
          Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: SkeletonBox(width: 38, height: 38, radius: 11),
          ),
        ],
      ),
    );
  }
}

class _HistoryRowBone extends StatelessWidget {
  const _HistoryRowBone({this.squareIcon = false});

  final bool squareIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            width: 44,
            height: 44,
            circle: !squareIcon,
            radius: squareIcon ? 14 : 0,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TextLineBone(
                        fontSize: 14.5,
                        lineHeight: 1.25,
                        barHeight: 13,
                        widthFactor: 0.78,
                        radius: 5,
                      ),
                    ),
                    SizedBox(width: 12),
                    SkeletonBox(width: 82, height: 24, radius: 9),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 92, height: 11, radius: 5),
                    SkeletonBox(width: 96, height: 11, radius: 5),
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

/// Друзья: точная геометрия шапки (1:1 с _FriendsBody), блока кода, сетки 2x2 и списка.
class FriendsSkeleton extends StatelessWidget {
  const FriendsSkeleton({
    super.key,
    this.locale = 'ru',
    this.canPop = false,
  });

  final String locale;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 104),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          Container(
            decoration: const BoxDecoration(
              color: PaykColors.sheet,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned(
                      top: -1000,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: PaykColors.headerGradient,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(PaykRadius.header),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              canPop ? 0 : 16,
                              24,
                              28,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (canPop)
                                  const SizedBox(
                                    height: 40,
                                    width: 40,
                                    child: Center(
                                      child: SkeletonBox(
                                        width: 24,
                                        height: 24,
                                        radius: 8,
                                        color: _headerBone,
                                        highlight: _headerShine,
                                      ),
                                    ),
                                  ),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width * 0.68,
                                  ),
                                  child: _MeasuredTextBones(
                                    sample: tr(locale, 'friends.heroTitle'),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                      letterSpacing: -0.4,
                                    ),
                                    barHeight: 24,
                                    radius: 8,
                                    color: _headerBone,
                                    highlight: _headerShine,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.only(right: 108),
                                  child: _MeasuredTextBones(
                                    sample: tr(locale, 'friends.explain', {
                                      'l1': '1%',
                                      'l2': '1%',
                                      'months': '12',
                                    }),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                    barHeight: 12,
                                    radius: 5,
                                    color: _headerBone,
                                    highlight: _headerShine,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Positioned(
                            right: 16,
                            bottom: 8,
                            child: SizedBox(
                              width: 128,
                              height: 128,
                              child: Center(
                                child: SkeletonBox(
                                  width: 108,
                                  height: 108,
                                  radius: 26,
                                  color: _headerBone,
                                  highlight: _headerShine,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MeasuredTextBones(
                        sample: tr(locale, 'friends.yourCode'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        barHeight: 12,
                        fixedWidth: 148,
                        radius: 5,
                      ),
                      const SizedBox(height: 8),
                      // Высота 64 = vertical: 8*2 + IconButton 48 (1:1 с блоком кода).
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: PaykColors.surfaceNested,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: PaykColors.border),
                        ),
                        child: const Row(
                          children: [
                            SkeletonBox(width: 136, height: 22, radius: 7),
                            Spacer(),
                            SkeletonBox(width: 24, height: 24, radius: 7),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const SkeletonBox(height: 50, radius: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _StatBone(locale: locale)),
                const SizedBox(width: 10),
                Expanded(child: _StatBone(locale: locale)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _StatBone(locale: locale)),
                const SizedBox(width: 10),
                Expanded(child: _StatBone(locale: locale)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MeasuredTextBones(
              sample: tr(locale, 'friends.list'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              barHeight: 16,
              fixedWidth: 148,
              radius: 6,
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SkeletonCard(
              padding: EdgeInsets.zero,
              radius: 20,
              child: Column(
                children: [
                  _HistoryRowBone(),
                  Divider(height: 1, color: PaykColors.border),
                  _HistoryRowBone(),
                  Divider(height: 1, color: PaykColors.border),
                  _HistoryRowBone(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточки-заглушки для «PAYK для бизнеса» (используются и под живым _Hero, и в полном скелетоне).
class PaykBusinessCardsSkeleton extends StatelessWidget {
  const PaykBusinessCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerSweep(
      child: Column(
        children: [
          _OfferBone(),
          SizedBox(height: 16),
          _OfferBone(),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Center(
              child: SkeletonBox(width: 180, height: 12, radius: 6),
            ),
          ),
        ],
      ),
    );
  }
}

/// PAYK для бизнеса: полный скелетон с точной 1:1 геометрией шапки _Hero и двух карточек.
class PaykBusinessSkeleton extends StatelessWidget {
  const PaykBusinessSkeleton({super.key, this.locale = 'ru'});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 104),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                top: -1000,
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: PaykColors.headerGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(PaykRadius.header),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MeasuredTextBones(
                        sample: tr(locale, 'payk.title'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.4,
                        ),
                        barHeight: 24,
                        radius: 8,
                        color: _headerBone,
                        highlight: _headerShine,
                      ),
                      const SizedBox(height: 10),
                      _MeasuredTextBones(
                        sample: tr(locale, 'payk.subtitle'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        barHeight: 12,
                        radius: 5,
                        color: _headerBone,
                        highlight: _headerShine,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _OfferBone(),
                SizedBox(height: 16),
                _OfferBone(),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: Center(
                    child: SkeletonBox(width: 180, height: 12, radius: 6),
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

class _OfferBone extends StatelessWidget {
  const _OfferBone();

  @override
  Widget build(BuildContext context) {
    return const ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      child: SkeletonCard(
        padding: EdgeInsets.zero,
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2,
              child: SkeletonBox(height: double.infinity, radius: 0),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TextLineBone(
                    fontSize: 18,
                    lineHeight: 1.25,
                    barHeight: 16,
                    widthFactor: 0.78,
                    radius: 6,
                  ),
                  _TextLineBone(
                    fontSize: 18,
                    lineHeight: 1.25,
                    barHeight: 16,
                    widthFactor: 0.42,
                    radius: 6,
                  ),
                  SizedBox(height: 6),
                  _TextLineBone(
                    fontSize: 15,
                    lineHeight: 1.45,
                    barHeight: 12,
                    widthFactor: 0.96,
                    radius: 5,
                  ),
                  _TextLineBone(
                    fontSize: 15,
                    lineHeight: 1.45,
                    barHeight: 12,
                    widthFactor: 0.88,
                    radius: 5,
                  ),
                  _TextLineBone(
                    fontSize: 15,
                    lineHeight: 1.45,
                    barHeight: 12,
                    widthFactor: 0.56,
                    radius: 5,
                  ),
                  SizedBox(height: 16),
                  SkeletonBox(height: 50, radius: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBone extends StatelessWidget {
  const _StatBone({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MeasuredTextBones(
            sample: tr(locale, 'friends.l1'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            barHeight: 11,
            fixedWidth: 86,
            radius: 5,
          ),
          const SizedBox(height: 4),
          const _MeasuredTextBones(
            sample: '0,00 смн',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            barHeight: 18,
            fixedWidth: 64,
            radius: 6,
          ),
        ],
      ),
    );
  }
}

/// Уведомления: карточки с иконкой и двумя строками текста.
class NotificationsSkeleton extends StatelessWidget {
  const NotificationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 96),
        physics: ClampingScrollPhysics(),
        children: [
          Row(
            children: [
              SkeletonBox(width: 128, height: 14, radius: 7),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(width: double.infinity, height: 1, radius: 1)),
              SizedBox(width: 10),
              SkeletonBox(width: 24, height: 18, radius: 9),
            ],
          ),
          SizedBox(height: 10),
          _NoticeBone(),
          SizedBox(height: 10),
          _NoticeBone(),
          SizedBox(height: 20),
          Row(
            children: [
              SkeletonBox(width: 112, height: 14, radius: 7),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(width: double.infinity, height: 1, radius: 1)),
              SizedBox(width: 10),
              SkeletonBox(width: 24, height: 18, radius: 9),
            ],
          ),
          SizedBox(height: 10),
          _NoticeBone(),
          SizedBox(height: 10),
          _NoticeBone(),
        ],
      ),
    );
  }
}

class _NoticeBone extends StatelessWidget {
  const _NoticeBone();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 36, height: 36, radius: 10),
              SizedBox(width: 10),
              SkeletonBox(width: 96, height: 12, radius: 6),
              Spacer(),
              SkeletonBox(width: 8, height: 8, circle: true),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(height: 14, radius: 6),
          SizedBox(height: 8),
          SkeletonBox(width: 220, height: 14, radius: 6),
        ],
      ),
    );
  }
}

/// Правила: вводный текст и карточки статусов.
class RulesSkeleton extends StatelessWidget {
  const RulesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
        physics: ClampingScrollPhysics(),
        children: [
          SkeletonBox(height: 14, radius: 6),
          SizedBox(height: 8),
          SkeletonBox(width: 240, height: 14, radius: 6),
          SizedBox(height: 8),
          SkeletonBox(width: 180, height: 14, radius: 6),
          SizedBox(height: 18),
          _TierBone(),
          SizedBox(height: 12),
          _TierBone(),
          SizedBox(height: 12),
          _TierBone(),
          SizedBox(height: 12),
          _TierBone(),
        ],
      ),
    );
  }
}

class _TierBone extends StatelessWidget {
  const _TierBone();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Column(
        children: [
          Row(
            children: [
              SkeletonBox(width: 88, height: 28, radius: 12),
              Spacer(),
              SkeletonBox(width: 72, height: 13, radius: 6),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 72, radius: 12)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 72, radius: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Настройки: язык и уведомления.
class SettingsSkeleton extends StatelessWidget {
  const SettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        physics: ClampingScrollPhysics(),
        children: [
          SkeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 36, height: 36, radius: 10),
                    SizedBox(width: 12),
                    SkeletonBox(width: 80, height: 16, radius: 6),
                  ],
                ),
                SizedBox(height: 14),
                SkeletonBox(height: 44, radius: 14),
              ],
            ),
          ),
          SizedBox(height: 14),
          SkeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 36, height: 36, radius: 10),
                    SizedBox(width: 12),
                    SkeletonBox(width: 140, height: 16, radius: 6),
                  ],
                ),
                SizedBox(height: 12),
                SkeletonBox(height: 13, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 200, height: 13, radius: 6),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 14, radius: 6)),
                    SizedBox(width: 16),
                    SkeletonBox(width: 48, height: 28, radius: 14),
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

/// Способы входа: SMS и Telegram.
class ConnectSkeleton extends StatelessWidget {
  const ConnectSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.all(16),
        physics: ClampingScrollPhysics(),
        children: [
          _MethodBone(),
          SizedBox(height: 12),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MethodLine(),
                SizedBox(height: 16),
                SkeletonBox(height: 46, radius: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodBone extends StatelessWidget {
  const _MethodBone();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(child: _MethodLine());
  }
}

class _MethodLine extends StatelessWidget {
  const _MethodLine();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(width: 44, height: 44, radius: 12),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 90, height: 16, radius: 6),
              SizedBox(height: 6),
              SkeletonBox(width: 160, height: 12, radius: 6),
            ],
          ),
        ),
      ],
    );
  }
}

/// Код кассы: квадрат QR, цифры и строка таймера.
class CodeSkeleton extends StatelessWidget {
  const CodeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: SkeletonCard(
        radius: 24,
        padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            SkeletonBox(height: 272, radius: 20),
            SizedBox(height: 20),
            SkeletonBox(width: 160, height: 13, radius: 6),
            SizedBox(height: 10),
            SkeletonBox(width: 210, height: 36, radius: 8),
            SizedBox(height: 20),
            SkeletonBox(height: 62, radius: 16),
          ],
        ),
      ),
    );
  }
}

/// Регистрация: заголовок и поля анкеты.
class RegisterSkeleton extends StatelessWidget {
  const RegisterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      body: SafeArea(
        child: ShimmerSweep(
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
            physics: ClampingScrollPhysics(),
            children: [
              SkeletonBox(width: 200, height: 32, radius: 8),
              SizedBox(height: 12),
              SkeletonBox(height: 14, radius: 6),
              SizedBox(height: 8),
              SkeletonBox(width: 220, height: 14, radius: 6),
              SizedBox(height: 28),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 12),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 12),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 12),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 12),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 24),
              SkeletonBox(height: 54, radius: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.fill = PaykColors.sheet,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: PaykColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
