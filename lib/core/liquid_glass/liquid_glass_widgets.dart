import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

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

  static final ImageFilter _defaultBlur = ImageFilter.blur(
    sigmaX: LiquidGlassTokens.blurLg,
    sigmaY: LiquidGlassTokens.blurLg,
  );

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
        filter: blurSigma == LiquidGlassTokens.blurLg
            ? _defaultBlur
            : ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      );
    }

    Widget card = RepaintBoundary(
      child: Container(
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

/// Интерактивная кнопка Liquid Glass с прерываемым масштабированием и зеркальным бликом.
class LiquidGlassButton extends StatelessWidget {
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

  static final ImageFilter _buttonBlur = ImageFilter.blur(
    sigmaX: LiquidGlassTokens.blurMd,
    sigmaY: LiquidGlassTokens.blurMd,
  );

  @override
  Widget build(BuildContext context) {
    final solid = LiquidGlassTokens.shouldReduceTransparency(context);
    final bg =
        backgroundColor ?? (solid ? PaykColors.sheet : LiquidGlassTokens.surfaceLight);

    return PaykPressable(
      scaleDown: 0.94,
      haptic: true,
      onTap: onPressed,
      child: RepaintBoundary(
        child: Container(
          height: height,
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
                child: solid
                    ? Container(
                        padding: padding,
                        color: bg,
                        alignment: Alignment.center,
                        child: child,
                      )
                    : BackdropFilter(
                        filter: _buttonBlur,
                        child: Container(
                          padding: padding,
                          color: bg,
                          alignment: Alignment.center,
                          child: child,
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
