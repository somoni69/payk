import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/payk_motion.dart';
import '../theme/payk_colors.dart';
import 'liquid_glass_tokens.dart';

/// Плавающая карточка Liquid Glass с зеркальной фаской и реальным размытием фона.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.blurSigma = LiquidGlassTokens.blurLg,
    this.backgroundColor = LiquidGlassTokens.surfaceLight,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final Color backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final solid = LiquidGlassTokens.shouldReduceTransparency(context);
    final effectiveColor = solid ? PaykColors.sheet : backgroundColor;

    Widget content = Container(
      padding: padding,
      color: effectiveColor,
      child: child,
    );

    if (!solid) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      );
    }

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: LiquidGlassTokens.floatingShadow(),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LiquidGlassTokens.specularBorder(solid: solid),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 1.2),
            child: content,
          ),
        ),
      ),
    );

    if (onTap != null) {
      card = PaykPressable(
        scaleDown: PaykMotion.scaleSubtle,
        haptic: true,
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Интерактивная кнопка Liquid Glass с пружинным масштабированием и зеркальным бликом.
class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius = 16.0,
    this.height = 48.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20.0),
    this.backgroundColor,
  });

  final VoidCallback onPressed;
  final Widget child;
  final double borderRadius;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl = AnimationController(
    vsync: this,
    duration: PaykMotion.pressDown,
    reverseDuration: PaykMotion.pressUp,
    lowerBound: 0.94,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!PaykMotion.shouldReduceMotion(context)) {
      _scaleCtrl.animateBack(
        0.94,
        duration: PaykMotion.pressDown,
        curve: PaykMotion.easeOut,
      );
    }
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    _scaleCtrl.animateTo(
      1.0,
      duration: PaykMotion.pressUp,
      curve: PaykMotion.easeOut,
    );
    widget.onPressed();
  }

  void _onTapCancel() {
    _scaleCtrl.animateTo(
      1.0,
      duration: PaykMotion.pressUp,
      curve: PaykMotion.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final solid = LiquidGlassTokens.shouldReduceTransparency(context);
    final bg = widget.backgroundColor ?? (solid ? PaykColors.sheet : LiquidGlassTokens.surfaceLight);

    return AnimatedBuilder(
      animation: _scaleCtrl,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleCtrl.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: LiquidGlassTokens.floatingShadow(),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LiquidGlassTokens.specularBorder(solid: solid),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius - 1.2),
                child: solid
                    ? Container(
                        padding: widget.padding,
                        color: bg,
                        alignment: Alignment.center,
                        child: widget.child,
                      )
                    : BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: LiquidGlassTokens.blurMd,
                          sigmaY: LiquidGlassTokens.blurMd,
                        ),
                        child: Container(
                          padding: widget.padding,
                          color: bg,
                          alignment: Alignment.center,
                          child: widget.child,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
