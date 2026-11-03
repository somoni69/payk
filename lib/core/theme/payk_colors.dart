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
  static const tierSilver = [Color(0xFF5E6E84), Color(0xFF738399), Color(0xFF8EA0B5)];
  static const tierGold = [Color(0xFF6B430A), Color(0xFF8A5A12), Color(0xFFC48A2A)];
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
  const commonInk = Colors.white;
  final commonInkSoft = Colors.white.withValues(alpha: 0.90);
  final commonBadge = Colors.black.withValues(alpha: 0.22);
  const commonBadgeInk = Colors.white;
  final commonBadgeBorder = Colors.white.withValues(alpha: 0.20);

  switch (level) {
    case 2:
      return TierLook(
        colors: PaykColors.tierSilver,
        ink: commonInk,
        inkSoft: commonInkSoft,
        badge: commonBadge,
        badgeInk: commonBadgeInk,
        badgeBorder: commonBadgeBorder,
      );
    case 3:
      return TierLook(
        colors: PaykColors.tierGold,
        ink: commonInk,
        inkSoft: commonInkSoft,
        badge: commonBadge,
        badgeInk: commonBadgeInk,
        badgeBorder: commonBadgeBorder,
      );
    case 4:
      return TierLook(
        colors: PaykColors.tierPlatinum,
        ink: commonInk,
        inkSoft: commonInkSoft,
        badge: commonBadge,
        badgeInk: commonBadgeInk,
        badgeBorder: commonBadgeBorder,
      );
    case 5:
      return TierLook(
        colors: PaykColors.tierDiamond,
        ink: commonInk,
        inkSoft: commonInkSoft,
        badge: commonBadge,
        badgeInk: commonBadgeInk,
        badgeBorder: commonBadgeBorder,
      );
    default:
      return TierLook(
        colors: PaykColors.tierStandard,
        ink: commonInk,
        inkSoft: commonInkSoft,
        badge: commonBadge,
        badgeInk: commonBadgeInk,
        badgeBorder: commonBadgeBorder,
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
