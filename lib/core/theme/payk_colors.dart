import 'package:flutter/material.dart';

abstract final class PaykColors {
  static const violet = Color(0xFF6C4DFF);
  static const violetDeep = Color(0xFF4E32E6);
  /// Синий поля знака из файла логотипа.
  static const logo = Color(0xFF362CD1);
  static const canvas = Color(0xFFF4F5F7);
  static const panel = Color(0xFFEEF0F3);
  static const ink = Color(0xFF1C1C1E);
  static const muted = Color(0xFF8A8698);
  static const line = Color(0xFFE6E6EA);
  /// Оранжевая точка знака, как у UDS. Не путать с предупреждением [orange].
  static const dot = Color(0xFFFF8C1A);
  static const orange = Color(0xFFFF8A3D);
  static const pink = Color(0xFFFF4F86);
  static const coral = Color(0xFFFF8A6A);
  static const peach = Color(0xFFFFB088);
  static const sheet = Color(0xFFFFFFFF);
  static const good = Color(0xFF1F8A4C);
  static const notice = Color(0xFFFFF4E8);
  static const skeleton = Color(0xFFE4DEF4);
  static const frame = Color(0xFF141218);
  static const navShadow = Color(0x14372CD2);

  static const tierStandard = [Color(0xFF3B4150), Color(0xFF4F5567), Color(0xFF60677A)];
  static const tierSilver = [Color(0xFFF1F4F8), Color(0xFFD5DCE5), Color(0xFFB4BFCD)];
  static const tierGold = [Color(0xFFE8B423), Color(0xFFF6D35A), Color(0xFFFFE9A8)];
  static const tierPlatinum = [Color(0xFF2C3844), Color(0xFF4C5B6A), Color(0xFF6E7C8C)];
  static const tierDiamond = [Color(0xFF261E9A), Color(0xFF372CD2), Color(0xFF6248EE)];
}

class TierLook {
  const TierLook({
    required this.colors,
    required this.ink,
    required this.inkSoft,
    required this.badge,
    required this.badgeInk,
    required this.badgeBorder,
  });

  final List<Color> colors;
  final Color ink;
  final Color inkSoft;
  final Color badge;
  final Color badgeInk;
  final Color badgeBorder;
}

TierLook tierLook(int level) {
  switch (level) {
    case 2:
      return TierLook(
        colors: PaykColors.tierSilver,
        ink: const Color(0xFF1E2633),
        inkSoft: const Color(0xFF3A4556),
        badge: Colors.white.withValues(alpha: 0.70),
        badgeInk: const Color(0xFF1E2633),
        badgeBorder: const Color(0x1A1E2633),
      );
    case 3:
      return const TierLook(
        colors: PaykColors.tierGold,
        ink: Color(0xFF3A2A08),
        inkSoft: Color(0xFF5C4510),
        badge: Color(0xB3FFFFFF),
        badgeInk: Color(0xFF3A2A08),
        badgeBorder: Color(0x333A2A08),
      );
    case 4:
      return TierLook(
        colors: PaykColors.tierPlatinum,
        ink: Colors.white,
        inkSoft: Colors.white.withValues(alpha: 0.90),
        badge: Colors.black.withValues(alpha: 0.20),
        badgeInk: Colors.white,
        badgeBorder: Colors.white.withValues(alpha: 0.20),
      );
    case 5:
      return TierLook(
        colors: PaykColors.tierDiamond,
        ink: Colors.white,
        inkSoft: Colors.white.withValues(alpha: 0.90),
        badge: Colors.black.withValues(alpha: 0.20),
        badgeInk: Colors.white,
        badgeBorder: Colors.white.withValues(alpha: 0.20),
      );
    default:
      return TierLook(
        colors: PaykColors.tierStandard,
        ink: Colors.white,
        inkSoft: Colors.white.withValues(alpha: 0.90),
        badge: Colors.black.withValues(alpha: 0.20),
        badgeInk: Colors.white,
        badgeBorder: Colors.white.withValues(alpha: 0.20),
      );
  }
}

/// Шаг 4. Экранные поля уже стоят на 20.
abstract final class PaykSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Контрол 16, панель 22, карта и QR 28. Промежуточные 18 и 24 уберём при правке экранов.
abstract final class PaykRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}
