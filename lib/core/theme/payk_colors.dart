import 'package:flutter/material.dart';

/// Цветовая палитра Payk Ecosystem & Loyalty Brand System.
/// Чистый, контрастный премиальный стиль мобильного приложения:
/// - Белый кристальный холст (#FFFFFF) и мягкие сиреневые подложки (#F6F5FC)
/// - Фирменный электрический сине-фиолетовый Payk (#372CD2 / #2A21A5)
/// - Мягкие акцентные подложки (#EDEBFD)
/// - Глубокий высококонтрастный текст (#1B1A2E / #696780 / #A09EB5)
/// - Аккуратные границы (#ECEBF4)
abstract final class PaykColors {
  // --- Фирменная палитра Payk Brand ---
  /// Основной брендовый цвет Payk (#372CD2).
  static const primary = Color(0xFF372CD2);
  static const primaryDark = Color(0xFF2A21A5);
  static const brand = Color(0xFF372CD2);
  static const brandDark = Color(0xFF2A21A5);
  static const brandSoft = Color(0xFFEDEBFD);

  /// Градиент шапки приложения Payk (глубокий яркий индиго-фиолетовый)
  static const headerGradientStart = Color(0xFF5041EE);
  static const headerGradientEnd = Color(0xFF372CD2);
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerGradientStart, headerGradientEnd],
  );

  /// Фоновые поверхности
  static const canvas = Color(0xFFFFFFFF);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceNested = Color(0xFFF6F5FC);
  static const sheet = Color(0xFFFFFFFF);
  static const tile = Color(0xFFF6F5FC);
  static const activePill = Color(0xFFEDEBFD);
  static const chipBg = Color(0xFFEDEBFD);
  static const iconPillSoft = Color(0xFFEDEBFD);
  static const headerButtonBg = Color(0x38FFFFFF);

  /// Границы и контуры
  static const border = Color(0xFFECEBF4);
  static const navDivider = Color(0xFFECEBF4);

  /// Типографика
  static const textPrimary = Color(0xFF1B1A2E);
  static const textSecondary = Color(0xFF696780);
  static const textMuted = Color(0xFFA09EB5);
  static const textTooltip = Color(0xFFA09EB5);
  static const textOnHeader = Color(0xFFFFFFFF);
  static const textOnHeaderSubtitle = Color(0xD9FFFFFF);

  /// Статусные и семантические цвета
  static const danger = Color(0xFFC0392B);
  static const success = Color(0xFF17795E);
  static const accentGreen = Color(0xFF17795E);
  static const accentRed = Color(0xFFC0392B);
  static const accentAmber = Color(0xFFB7791F);
  static const incomeSoft = Color(0xFFE7F1EE);
  static const expenseSoft = Color(0xFFF7E7E5);
  static const amberSoft = Color(0xFFF5EEE0);

  /// Liquid Glass токены
  static const glassFill = Color(0xF2FFFFFF);
  static const glassBorder = Color(0x1F372CD2);
  static const glassShadow = Color(0x14372CD2);
  static const lensRestFill = Color(0x1F372CD2);
  static const lensHighlight = Color(0xD9FFFFFF);
  static const lensDispersionRed = Color(0x33E5484D);
  static const lensDispersionBlue = Color(0x33372CD2);

  // --- Совместимость с кодовой базой Payk ---
  static const violet = primary;
  static const violetDeep = primaryDark;
  static const logo = brand;
  static const panel = tile;
  static const ink = textPrimary;
  static const muted = textSecondary;
  static const line = border;
  static const dot = Color(0xFFFF8C1A);
  static const orange = Color(0xFFFF8A3D);
  static const pink = Color(0xFFFF4F86);
  static const coral = Color(0xFFFF8A6A);
  static const peach = Color(0xFFFFB088);
  static const good = success;
  static const bad = danger;
  static const notice = Color(0xFFFFF4E8);
  static const skeleton = Color(0xFFEDEBFD);
  static const frame = Color(0xFF141218);
  static const navShadow = Color(0x0A372CD2);

  // --- Тиры лояльности ---
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

/// Стандартная шкала отступов Payk / UDC.
abstract final class PaykSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Стандартная шкала радиусов скругления UDC.
abstract final class PaykRadius {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const pill = 18.0;
  static const lg = 20.0;
  static const header = 24.0;
  static const xl = 28.0;
}
