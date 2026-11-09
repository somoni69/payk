import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/payk_motion.dart';
import '../theme/payk_colors.dart';
import '../widgets/payk_mark.dart';
import '../widgets/payk_nav_icons.dart';
import 'liquid_glass_tokens.dart';

export '../widgets/payk_nav_icons.dart';

/// Дескриптор вкладки Liquid Glass навигации
class LiquidNavItem {
  const LiquidNavItem({
    required this.label,
    this.type,
    this.icon,
    this.center = false,
  }) : assert(center || type != null);

  final PaykNavIconType? type;
  final String label;
  final IconData? icon;
  final bool center;
}

/// Суженная плавающая капсула навигации в архитектуре Liquid Glass (iOS 26+ / VisionOS).
/// - Высота капсулы: 66.0 dp (прежний комфортный вертикальный размер).
/// - Ширина капсулы: 316.0 dp.
/// - Скругление капсулы: 33.0 dp (stadium shape).
/// - Зеркальная фаска: Specular Rim Border 1.2px.
/// - Реальный оптический блур BackdropFilter (sigma 24.0).
/// - Векторные иконки из Payk Ecosystem и знак PAYK по центру («PAYK для бизнеса»).
/// - Активная капля: pill 54x40 dp со скруглением 16 dp и зеркальным кантом.
class LiquidGlassBottomBar extends StatelessWidget {
  const LiquidGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = _defaultItems,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LiquidNavItem> items;

  static const _defaultItems = <LiquidNavItem>[
    LiquidNavItem(
      type: PaykNavIconType.home,
      icon: Icons.home_rounded,
      label: 'Главная',
    ),
    LiquidNavItem(
      type: PaykNavIconType.history,
      icon: Icons.grid_view_rounded,
      label: 'Категории',
    ),
    LiquidNavItem(center: true, label: 'PAYK для бизнеса'),
    LiquidNavItem(
      type: PaykNavIconType.friends,
      icon: Icons.people_alt_rounded,
      label: 'Друзья',
    ),
    LiquidNavItem(
      type: PaykNavIconType.profile,
      icon: Icons.person_rounded,
      label: 'Профиль',
    ),
  ];

  static const double barHeight = 66.0;
  static const double barWidth = 316.0;

  void _handleTap(int index) {
    if (index != currentIndex) {
      HapticFeedback.selectionClick();
    }
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final solid = LiquidGlassTokens.shouldReduceTransparency(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = bottomInset > 0 ? bottomInset : 12.0;
    final screen = MediaQuery.sizeOf(context).width;
    final width = barWidth > screen - 16 ? screen - 16 : barWidth;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: SizedBox(
            width: width,
            height: barHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(33),
                boxShadow: LiquidGlassTokens.floatingShadow(),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(33),
                  gradient: LiquidGlassTokens.specularBorder(solid: solid),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1.2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(31.8),
                    child: solid
                        ? ColoredBox(
                            color: PaykColors.sheet,
                            child: _buildTabsRow(),
                          )
                        : BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: LiquidGlassTokens.blurLg,
                              sigmaY: LiquidGlassTokens.blurLg,
                            ),
                            child: ColoredBox(
                              color: LiquidGlassTokens.surfaceLight,
                              child: _buildTabsRow(),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabsRow() {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: _LiquidBarItemWidget(
              item: items[i],
              isSelected: i == currentIndex,
              onTap: () => _handleTap(i),
            ),
          ),
      ],
    );
  }
}

class _LiquidBarItemWidget extends StatelessWidget {
  const _LiquidBarItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final LiquidNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = PaykColors.primary;
    const inactiveColor = Color(0xFF8C8AA3);
    final strokeWidth = isSelected ? 2.1 : 1.8;

    return Semantics(
      label: item.label,
      selected: isSelected,
      button: true,
      child: PaykPressable(
        scaleDown: PaykMotion.scaleIcon,
        child: InkResponse(
          onTap: onTap,
          highlightShape: BoxShape.rectangle,
          splashColor: PaykColors.activePill,
          radius: 32,
          child: Center(
            child: AnimatedContainer(
              duration: PaykMotion.duration(context, PaykMotion.normal),
              curve: PaykMotion.easeOut,
              width: 54,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? PaykColors.activePill : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.90),
                        width: 1.0,
                      )
                    : Border.all(color: Colors.transparent, width: 1.0),
              ),
              alignment: Alignment.center,
              child: item.center
                  ? const _PaykCenterMark()
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.0 : 0.94,
                          duration: PaykMotion.duration(
                            context,
                            PaykMotion.fast,
                          ),
                          curve: PaykMotion.easeOut,
                          child: PaykNavIcon(
                            type: item.type!,
                            color: isSelected ? activeColor : inactiveColor,
                            size: 26.0,
                            strokeWidth: strokeWidth,
                          ),
                        ),
                        if (item.icon != null)
                          Opacity(
                            opacity: 0.001,
                            child: Icon(
                              item.icon,
                              size: 24,
                              color: isSelected
                                  ? PaykColors.primary
                                  : PaykColors.textMuted,
                            ),
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

class _PaykCenterMark extends StatelessWidget {
  const _PaykCenterMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 2,
            child: ExcludeSemantics(child: PaykMark(size: 28)),
          ),
          Positioned(
            right: -1,
            top: -1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF8B7FF8),
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 1.6),
                ),
              ),
              child: SizedBox(width: 8, height: 8),
            ),
          ),
        ],
      ),
    );
  }
}
