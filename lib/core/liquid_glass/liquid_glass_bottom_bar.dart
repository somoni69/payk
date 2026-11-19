import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../motion/payk_motion.dart';
import '../theme/payk_colors.dart';
import '../widgets/payk_mark.dart';
import '../widgets/payk_nav_icons.dart';
import 'liquid_glass_tokens.dart';

export '../widgets/payk_nav_icons.dart';

/// Дескриптор вкладки Liquid Glass навигации.
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

/// Чистый Apple VisionOS / iOS 26+ Liquid Glass Bottom App Bar на чистом Flutter SDK.
///
/// Архитектура `/liquid-glass-flutter`:
/// - **Zero 3rd-party shaders**: только `dart:ui`, `flutter/physics.dart`, `CustomClipper`, `Matrix4`.
/// - **Magic-Lens Double Rendering**: внешний слой вырезан через `PathOperation.difference`,
///   внутренний увеличен (`1.28x`) из оптического центра линзы в фирменном акценте.
/// - **Spring Physics & Scrubbing**: `SpringSimulation` (`mass: 1, stiffness: 380, damping: 26`),
///   непрерывное перетаскивание пальцем с отложенным переключением экрана и rubber-band
///   сопротивлением на краях капсулы.
/// - **Fluid Droplet Dynamics**: динамический squash & stretch по скорости и вертикальный
///   выход капли за пределы капсулы (`78 dp` поверх `68 dp`), хроматическая аберрация
///   и зеркальный specular bevel.
/// - **Apple HIG Guardrails**: один `BackdropFilter` (`blurLg = 24`) без glass-on-glass,
///   автоматический solid fallback при `highContrast` / `accessibleNavigation`,
///   уважение `disableAnimations`.
class LiquidGlassBottomBar extends StatefulWidget {
  const LiquidGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = _defaultItems,
  }) : assert(items.length >= 2, 'LiquidGlassBottomBar requires at least 2 items.');

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LiquidNavItem> items;

  static const double barHeight = 68.0;
  static const double barWidth = 340.0;
  static const double _trackHorizontalInset = 6.0;
  static const double _restingDropletHeight = 54.0;
  static const double _liftedDropletHeight = 78.0;

  static const Key lensKey = ValueKey('liquid-glass-lens');
  static const Key restingPillKey = ValueKey('liquid-glass-resting-pill');

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

  /// Один и тот же фильтр на все пересборки бара, чтобы слой блюра не пересоздавался.
  static final ui.ImageFilter _barBlur = ui.ImageFilter.blur(
    sigmaX: LiquidGlassTokens.blurLg,
    sigmaY: LiquidGlassTokens.blurLg,
  );

  @override
  State<LiquidGlassBottomBar> createState() => _LiquidGlassBottomBarState();
}

class _LiquidGlassBottomBarState extends State<LiquidGlassBottomBar>
    with TickerProviderStateMixin {
  /// Непрерывная координата линзы (`0.0 .. items.length - 1.0`).
  late final AnimationController _positionController;

  /// Прогресс подъёма капли (`0.0` — спокойная капсула, `1.0` — объёмная линза).
  late final AnimationController _liftController;

  bool _isDragging = false;
  double _dragVelocityX = 0.0;
  double _lastDragX = 0.0;
  int _lastScrubSlot = 0;
  DateTime _lastDragTime = DateTime.now();

  static const SpringDescription _spring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 26.0,
  );

  int get _clampedCurrentIndex =>
      widget.currentIndex.clamp(0, widget.items.length - 1);

  @override
  void initState() {
    super.initState();
    _lastScrubSlot = _clampedCurrentIndex;
    _positionController = AnimationController.unbounded(
      vsync: this,
      value: _clampedCurrentIndex.toDouble(),
    );
    _liftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didUpdateWidget(covariant LiquidGlassBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxIndex = (widget.items.length - 1).toDouble();
    if (_positionController.value > maxIndex) {
      _positionController.value = _clampedCurrentIndex.toDouble();
    }
    if (widget.currentIndex != oldWidget.currentIndex && !_isDragging) {
      _lastScrubSlot = _clampedCurrentIndex;
      _springToTab(_clampedCurrentIndex);
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    _liftController.dispose();
    super.dispose();
  }

  void _springToTab(int targetIndex, {double velocity = 0.0}) {
    final target = targetIndex.clamp(0, widget.items.length - 1).toDouble();
    if (PaykMotion.shouldReduceMotion(context)) {
      _positionController.stop();
      _positionController.value = target;
      _liftController.value = 0.0;
      _dragVelocityX = 0.0;
      return;
    }

    final from = _positionController.value;
    if ((from - target).abs() < 0.001 && velocity.abs() < 0.05) {
      _positionController.value = target;
      _liftController.reverse();
      return;
    }

    final simulation = SpringSimulation(_spring, from, target, velocity);
    _liftController.forward();
    _positionController.animateWith(simulation).whenCompleteOrCancel(() {
      if (!_isDragging && mounted) {
        _dragVelocityX = 0.0;
        _liftController.reverse();
      }
    });
  }

  /// Rubber-band сопротивление при выходе пальца за крайние вкладки.
  double _applyRubberBand(double value, double min, double max) {
    if (value < min) {
      final diff = min - value;
      return min - (1.0 - (1.0 / ((diff * 0.45) + 1.0))) * 0.38;
    }
    if (value > max) {
      final diff = value - max;
      return max + (1.0 - (1.0 / ((diff * 0.45) + 1.0))) * 0.38;
    }
    return value;
  }

  void _selectTab(int targetIndex) {
    final clamped = targetIndex.clamp(0, widget.items.length - 1);
    _dragVelocityX = 0.0;
    if (clamped != widget.currentIndex) {
      HapticFeedback.lightImpact();
    }
    widget.onTap(clamped);
    _springToTab(clamped);
  }

  int _indexFromDx(double dx, double tabWidth) {
    final local = dx - LiquidGlassBottomBar._trackHorizontalInset;
    return (local / tabWidth).floor().clamp(0, widget.items.length - 1);
  }

  void _onTapDown(TapDownDetails details) {
    if (_isDragging || PaykMotion.shouldReduceMotion(context)) return;
    _liftController.animateTo(
      0.32,
      duration: PaykMotion.pressDown,
      curve: PaykMotion.easeOut,
    );
  }

  void _onTapCancel() {
    if (!_isDragging && mounted) {
      _liftController.reverse();
    }
  }

  void _onTapUp(TapUpDetails details, double tabWidth) {
    final tappedIndex = _indexFromDx(details.localPosition.dx, tabWidth);
    _selectTab(tappedIndex);
  }

  void _onHorizontalDragStart(DragStartDetails details, double tabWidth) {
    _isDragging = true;
    _lastDragX = details.localPosition.dx;
    _lastDragTime = DateTime.now();
    _dragVelocityX = 0.0;
    _lastScrubSlot = _positionController.value.round().clamp(
      0,
      widget.items.length - 1,
    );
    _positionController.stop();
    if (!PaykMotion.shouldReduceMotion(context)) {
      _liftController.forward();
    }
    HapticFeedback.selectionClick();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double tabWidth) {
    final now = DateTime.now();
    final dt = now.difference(_lastDragTime).inMicroseconds / 1000000.0;
    final dx = details.localPosition.dx - _lastDragX;

    if (dt > 0.001) {
      final instantVelocity = dx / dt;
      _dragVelocityX =
          ui.lerpDouble(_dragVelocityX, instantVelocity, 0.35) ?? 0.0;
    }

    _lastDragX = details.localPosition.dx;
    _lastDragTime = now;

    final trackDx = details.localPosition.dx - LiquidGlassBottomBar._trackHorizontalInset;
    final rawIndex = (trackDx / tabWidth) - 0.5;
    final maxIndex = (widget.items.length - 1).toDouble();
    final clamped = _applyRubberBand(rawIndex, 0.0, maxIndex);
    _positionController.value = clamped;

    final hoveredSlot = clamped.round().clamp(0, widget.items.length - 1);
    if (hoveredSlot != _lastScrubSlot) {
      _lastScrubSlot = hoveredSlot;
      HapticFeedback.selectionClick();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details, double tabWidth) {
    _isDragging = false;
    final maxIndex = widget.items.length - 1;
    final velocityInTabs = details.velocity.pixelsPerSecond.dx / tabWidth;

    final int targetIndex;
    if (velocityInTabs.abs() > 1.2) {
      targetIndex = (_positionController.value + velocityInTabs.sign * 0.4)
          .round()
          .clamp(0, maxIndex);
    } else {
      targetIndex = _positionController.value.round().clamp(0, maxIndex);
    }

    _dragVelocityX = 0.0;
    if (targetIndex != widget.currentIndex) {
      HapticFeedback.mediumImpact();
      widget.onTap(targetIndex);
    }
    _springToTab(targetIndex, velocity: velocityInTabs);
  }

  void _onHorizontalDragCancel() {
    _isDragging = false;
    _dragVelocityX = 0.0;
    _springToTab(_clampedCurrentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final solid = LiquidGlassTokens.shouldReduceTransparency(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = bottomInset > 0 ? bottomInset : 12.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final capsuleWidth = (screenWidth - 28.0).clamp(
      260.0,
      LiquidGlassBottomBar.barWidth,
    );
    final trackWidth =
        capsuleWidth - LiquidGlassBottomBar._trackHorizontalInset * 2;
    final tabWidth = trackWidth / widget.items.length;

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
            width: capsuleWidth,
            height: LiquidGlassBottomBar.barHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _onTapDown,
              onTapCancel: _onTapCancel,
              onTapUp: (details) => _onTapUp(details, tabWidth),
              onHorizontalDragStart: (details) =>
                  _onHorizontalDragStart(details, tabWidth),
              onHorizontalDragUpdate: (details) =>
                  _onHorizontalDragUpdate(details, tabWidth),
              onHorizontalDragEnd: (details) =>
                  _onHorizontalDragEnd(details, tabWidth),
              onHorizontalDragCancel: _onHorizontalDragCancel,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _positionController,
                  _liftController,
                ]),
                builder: (context, _) {
                  return _buildCapsule(
                    capsuleWidth: capsuleWidth,
                    tabWidth: tabWidth,
                    solid: solid,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsule({
    required double capsuleWidth,
    required double tabWidth,
    required bool solid,
  }) {
    const barHeight = LiquidGlassBottomBar.barHeight;
    const barRadius = barHeight / 2.0;
    const inset = LiquidGlassBottomBar._trackHorizontalInset;

    final pos = _positionController.value;
    final lift = solid ? 0.0 : _liftController.value;
    final speed = _isDragging
        ? _dragVelocityX.abs()
        : (_positionController.velocity * tabWidth).abs();

    final dropletCenterX = inset + (pos + 0.5) * tabWidth;
    const dropletCenterY = barHeight / 2.0;

    final baseWidth = (tabWidth - 4.0).clamp(48.0, 68.0);
    final stretchX = (speed * 0.032).clamp(0.0, 22.0) * lift;
    final squashY = (speed * 0.012).clamp(0.0, 7.0) * lift;

    final dropletWidth = baseWidth + (22.0 * lift) + stretchX;
    final dropletHeight =
        ui.lerpDouble(
          LiquidGlassBottomBar._restingDropletHeight,
          LiquidGlassBottomBar._liftedDropletHeight,
          lift,
        )! -
        squashY;
    final dropletRadius = dropletHeight / 2.0;

    final dropletRect = Rect.fromCenter(
      center: Offset(dropletCenterX, dropletCenterY),
      width: dropletWidth,
      height: dropletHeight,
    );
    final dropletRRect = RRect.fromRectAndRadius(
      dropletRect,
      Radius.circular(dropletRadius),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Парящая стеклянная капсула (один BackdropFilter на всю Z-плоскость).
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(barRadius),
              boxShadow: LiquidGlassTokens.floatingShadow(),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(barRadius),
                gradient: LiquidGlassTokens.specularBorder(solid: solid),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(barRadius - 1.2),
                  child: solid
                      ? const ColoredBox(color: PaykColors.sheet)
                      : BackdropFilter(
                          filter: LiquidGlassBottomBar._barBlur,
                          child: const ColoredBox(
                            color: LiquidGlassTokens.surfaceLight,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),

        // 2. Спокойная активная подложка (плавно растворяется при подъёме линзы).
        if (lift < 0.99)
          Positioned.fromRect(
            rect: dropletRect,
            child: DecoratedBox(
              key: LiquidGlassBottomBar.restingPillKey,
              decoration: BoxDecoration(
                color: PaykColors.activePill.withValues(
                  alpha: (1.0 - lift).clamp(0.0, 1.0),
                ),
                borderRadius: BorderRadius.circular(dropletRadius),
                border: Border.all(
                  color: (solid ? PaykColors.border : Colors.white).withValues(
                    alpha: (solid ? 1.0 : 0.90) * (1.0 - lift).clamp(0.0, 1.0),
                  ),
                  width: 1.0,
                ),
              ),
            ),
          ),

        // 3. LAYER 1 (Внешний слой иконок — вырезан по форме линзы через PathOperation.difference).
        Positioned.fill(
          child: ExcludeSemantics(
            child: ClipPath(
              clipper: _HoleCutoutClipper(dropletRRect),
              child: _buildIconsRow(
                tabWidth: tabWidth,
                isMagnified: false,
                highlightIndex: _clampedCurrentIndex,
              ),
            ),
          ),
        ),

        // 4. LAYER 2 (Объёмная оптическая линза Liquid Glass с увеличением 1.28x).
        Positioned.fromRect(
          rect: dropletRect,
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: _buildDropletLens(
                dropletRRect: dropletRRect,
                dropletWidth: dropletWidth,
                dropletHeight: dropletHeight,
                lift: lift,
                solid: solid,
                capsuleWidth: capsuleWidth,
                tabWidth: tabWidth,
                centerX: dropletCenterX,
                centerY: dropletCenterY,
              ),
            ),
          ),
        ),

        // 5. Семантический слой и доступность для скринридеров (без обрезки ClipPath).
        Positioned.fill(
          child: _buildSemanticsOverlay(tabWidth: tabWidth),
        ),
      ],
    );
  }

  Widget _buildDropletLens({
    required RRect dropletRRect,
    required double dropletWidth,
    required double dropletHeight,
    required double lift,
    required bool solid,
    required double capsuleWidth,
    required double tabWidth,
    required double centerX,
    required double centerY,
  }) {
    const barHeight = LiquidGlassBottomBar.barHeight;
    final radius = dropletHeight / 2.0;
    final scale = ui.lerpDouble(1.0, 1.28, lift)!;
    final pivot = FractionalOffset(
      (centerX / capsuleWidth).clamp(0.0, 1.0),
      (centerY / barHeight).clamp(0.0, 1.0),
    );

    return DecoratedBox(
      key: LiquidGlassBottomBar.lensKey,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: !solid && lift > 0.05
            ? [
                BoxShadow(
                  color: PaykColors.primary.withValues(alpha: 0.18 * lift),
                  blurRadius: 18.0 * lift,
                  spreadRadius: -2.0,
                  offset: Offset(0, 6.0 * lift),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10 * lift),
                  blurRadius: 12.0 * lift,
                  offset: Offset(0, 4.0 * lift),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Мягкий стеклянный градиент тела линзы при подъёме.
            if (!solid && lift > 0.02)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.72 * lift),
                      Colors.white.withValues(alpha: 0.34 * lift),
                    ],
                  ),
                ),
              ),

            // Увеличенный внутренний слой вкладок (выровнен в системе координат капсулы).
            Positioned(
              left: -dropletRRect.left,
              top: -dropletRRect.top,
              width: capsuleWidth,
              height: barHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Симуляция хроматической аберрации на гранях капли при движении.
                  if (!solid && lift > 0.1) ...[
                    Transform.translate(
                      offset: Offset(-1.5 * lift, 0.0),
                      child: Opacity(
                        opacity: 0.22 * lift,
                        child: Transform(
                          alignment: pivot,
                          transform: Matrix4.diagonal3Values(scale, scale, 1.0),
                          child: _buildIconsRow(
                            tabWidth: tabWidth,
                            isMagnified: true,
                            customColor: const Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(1.5 * lift, 0.0),
                      child: Opacity(
                        opacity: 0.18 * lift,
                        child: Transform(
                          alignment: pivot,
                          transform: Matrix4.diagonal3Values(scale, scale, 1.0),
                          child: _buildIconsRow(
                            tabWidth: tabWidth,
                            isMagnified: true,
                            customColor: const Color(0xFFFF007A),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Основной резкий увеличенный слой внутри линзы.
                  Transform(
                    alignment: pivot,
                    transform: Matrix4.diagonal3Values(scale, scale, 1.0),
                    child: _buildIconsRow(
                      tabWidth: tabWidth,
                      isMagnified: true,
                    ),
                  ),
                ],
              ),
            ),

            // Зеркальный кант и градиент отражения линзы (Specular Bevel).
            if (!solid && lift > 0.05)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85 * lift),
                    width: 1.2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.55 * lift),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.20 * lift),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),

            // Верхний световой блик (Specular Gloss Line).
            if (!solid && lift > 0.1)
              Positioned(
                top: 3.0,
                left: dropletWidth * 0.18,
                right: dropletWidth * 0.18,
                height: 2.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1.0),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.85 * lift),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconsRow({
    required double tabWidth,
    required bool isMagnified,
    int? highlightIndex,
    Color? customColor,
  }) {
    const activeColor = PaykColors.primary;
    const inactiveColor = Color(0xFF8C8AA3);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LiquidGlassBottomBar._trackHorizontalInset,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.items.length; i++)
            SizedBox(
              width: tabWidth,
              height: LiquidGlassBottomBar.barHeight,
              child: Center(
                child: _buildIconGlyph(
                  item: widget.items[i],
                  isActive: isMagnified || i == highlightIndex,
                  color: customColor ??
                      (isMagnified || i == highlightIndex
                          ? activeColor
                          : inactiveColor),
                  isChromaticLayer: customColor != null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconGlyph({
    required LiquidNavItem item,
    required bool isActive,
    required Color color,
    required bool isChromaticLayer,
  }) {
    if (item.center) {
      if (isChromaticLayer) {
        return ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          child: const _PaykCenterMark(showDot: false),
        );
      }
      return const _PaykCenterMark();
    }

    return PaykNavIcon(
      type: item.type!,
      color: color,
      size: 26.0,
      strokeWidth: isActive ? 2.1 : 1.8,
    );
  }

  Widget _buildSemanticsOverlay({required double tabWidth}) {
    final activeIndex = _clampedCurrentIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LiquidGlassBottomBar._trackHorizontalInset,
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.items.length; i++)
            SizedBox(
              width: tabWidth,
              height: LiquidGlassBottomBar.barHeight,
              child: Semantics(
                label: widget.items[i].label,
                selected: i == activeIndex,
                button: true,
                onTap: () => _selectTab(i),
                child: Center(
                  child: widget.items[i].icon != null
                      ? Opacity(
                          opacity: 0.0,
                          child: Icon(
                            widget.items[i].icon,
                            size: 24,
                            color: i == activeIndex
                                ? PaykColors.primary
                                : PaykColors.textMuted,
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaykCenterMark extends StatelessWidget {
  const _PaykCenterMark({this.showDot = true});

  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 2,
            top: 2,
            child: ExcludeSemantics(child: PaykMark(size: 28)),
          ),
          if (showDot)
            const Positioned(
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

/// Маска выреза линзы через [PathOperation.difference],
/// исключающая двоение иконок под увеличительной каплей.
class _HoleCutoutClipper extends CustomClipper<Path> {
  const _HoleCutoutClipper(this.holeRRect);

  final RRect holeRRect;

  @override
  Path getClip(Size size) {
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(holeRRect);
    return Path.combine(PathOperation.difference, fullPath, holePath);
  }

  @override
  bool shouldReclip(covariant _HoleCutoutClipper oldClipper) {
    return oldClipper.holeRRect != holeRRect;
  }
}
