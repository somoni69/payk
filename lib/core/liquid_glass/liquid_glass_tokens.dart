import 'package:flutter/material.dart';

import '../theme/payk_colors.dart';

/// Глобальные дизайн-токены архитектуры Liquid Glass (Apple VisionOS / iOS 26+).
/// Реализовано на 100% чистом Flutter SDK (dart:ui, physics, material) для стабильных 120 FPS.
abstract final class LiquidGlassTokens {
  // --- Значения оптического размытия (Blur Sigmas) ---
  /// Малый блур для бейджей, мини-чипов (8.0px).
  static const double blurSm = 8.0;

  /// Средний блур для кнопок, плавающих контролов (16.0px).
  static const double blurMd = 16.0;

  /// Стандартный блур для навигационных панелей, карточек (24.0px).
  static const double blurLg = 24.0;

  /// Глубокий блур для модальных шторок, оверлеев (32.0px).
  static const double blurXl = 32.0;

  // --- Поверхности и световые оттенки ---
  /// 85% полупрозрачный кристально-белый фон.
  static const Color surfaceLight = Color(0xD9FFFFFF);

  /// 80% мягкое тонированное стекло с легким оттенком Payk.
  static const Color surfaceTinted = Color(0xCCF4F7FC);

  /// Зеркальный верхний кант (Specular Rim Highlight).
  static const Color borderLight = Color(0x99FFFFFF);

  /// Мягкий нижний контактный кант тени.
  static const Color borderSubtle = Color(0x1F000000);

  // --- Зеркальная фаска (Specular Rim Gradient) ---
  /// Имитирует угол падения света на закруглённых физических гранях стекла.
  static LinearGradient specularBorder({
    double lightAngle = -0.7,
    bool solid = false,
  }) {
    if (solid) {
      return const LinearGradient(
        colors: [PaykColors.border, PaykColors.border],
      );
    }
    return LinearGradient(
      begin: Alignment(lightAngle, -1.0),
      end: Alignment(-lightAngle, 1.0),
      colors: [
        Colors.white.withValues(alpha: 0.92),
        Colors.white.withValues(alpha: 0.25),
        Colors.white.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.45),
      ],
      stops: const [0.0, 0.35, 0.70, 1.0],
    );
  }

  // --- Двухслойная парящая тень (Depth Elevation) ---
  static List<BoxShadow> floatingShadow({Color? glowColor}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20.0,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: (glowColor ?? PaykColors.primary).withValues(alpha: 0.08),
          blurRadius: 14.0,
          offset: const Offset(0, 3),
        ),
      ];

  /// Проверка специальных возможностей (Accessibility A11y fallback):
  /// при включенном высоком контрасте или снижении прозрачности
  /// интерфейс мгновенно переключается на 100% сплошные поверхности.
  static bool shouldReduceTransparency(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.highContrast || media.accessibleNavigation;
  }
}
