import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/theme/payk_colors.dart';
import 'package:payk/core/theme/payk_theme.dart';

void main() {
  group('Design System — Color Tokens (PaykColors / Loyalty Brand System)', () {
    test('Primary and brand purple tokens match Payk Brand specification', () {
      expect(PaykColors.primary, equals(const Color(0xFF372CD2)),
          reason: 'Primary purple must strictly match Payk Brand token #372CD2');
      expect(PaykColors.primaryDark, equals(const Color(0xFF2A21A5)),
          reason: 'Dark primary purple must match #2A21A5');
      expect(PaykColors.violet, equals(PaykColors.primary),
          reason: 'violet alias must point to primary Payk purple');
      expect(PaykColors.violetDeep, equals(PaykColors.primaryDark),
          reason: 'violetDeep alias must point to primaryDark');
    });

    test('Header gradient tokens match Payk Brand gradient (#5041EE -> #372CD2)', () {
      expect(PaykColors.headerGradientStart, equals(const Color(0xFF5041EE)),
          reason: 'Header gradient start must match #5041EE');
      expect(PaykColors.headerGradientEnd, equals(const Color(0xFF372CD2)),
          reason: 'Header gradient end must match #372CD2');

      final gradient = PaykColors.headerGradient;
      expect(gradient.colors, equals([const Color(0xFF5041EE), const Color(0xFF372CD2)]));
      expect(gradient.begin, equals(Alignment.topLeft));
      expect(gradient.end, equals(Alignment.bottomRight));
    });

    test('Surfaces and background tokens match Payk Loyalty palette', () {
      expect(PaykColors.canvas, equals(const Color(0xFFFFFFFF)),
          reason: 'Canvas background must be pure white #FFFFFF');
      expect(PaykColors.sheet, equals(const Color(0xFFFFFFFF)),
          reason: 'Sheet/Card background must be pure white #FFFFFF');
      expect(PaykColors.tile, equals(const Color(0xFFF6F5FC)),
          reason: 'Category and soft tiles must use Payk soft lavender background #F6F5FC');
      expect(PaykColors.activePill, equals(const Color(0xFFEDEBFD)),
          reason: 'Active navigation capsule must use lavender #EDEBFD');
      expect(PaykColors.chipBg, equals(const Color(0xFFEDEBFD)),
          reason: 'Chip background must use soft lavender #EDEBFD');
      expect(PaykColors.iconPillSoft, equals(const Color(0xFFEDEBFD)),
          reason: 'Icon container pill must use #EDEBFD');
      expect(PaykColors.headerButtonBg, equals(const Color(0x38FFFFFF)),
          reason: 'Header button background must have 22% white alpha');
    });

    test('Border and outline tokens match Payk Brand specification', () {
      expect(PaykColors.border, equals(const Color(0xFFECEBF4)),
          reason: 'Border outline must match light gray #ECEBF4');
      expect(PaykColors.navDivider, equals(const Color(0xFFECEBF4)),
          reason: 'Nav bar top divider must match #ECEBF4');
    });

    test('Semantic status tokens match Payk Brand specification', () {
      expect(PaykColors.danger, equals(const Color(0xFFC0392B)),
          reason: 'Danger action color must match crimson #C0392B');
      expect(PaykColors.success, equals(const Color(0xFF17795E)),
          reason: 'Success badge color must match green #17795E');
    });

    test('Typography color tokens match Payk Brand contrast guidelines', () {
      expect(PaykColors.textPrimary, equals(const Color(0xFF1B1A2E)),
          reason: 'Primary high-contrast text must match #1B1A2E');
      expect(PaykColors.textSecondary, equals(const Color(0xFF696780)),
          reason: 'Secondary caption text must match #696780');
      expect(PaykColors.textMuted, equals(const Color(0xFFA09EB5)),
          reason: 'Muted navigation icons must match #A09EB5');
      expect(PaykColors.textOnHeader, equals(const Color(0xFFFFFFFF)),
          reason: 'Text on purple header must be white');
      expect(PaykColors.textOnHeaderSubtitle, equals(const Color(0xD9FFFFFF)),
          reason: 'Header subtitle text must have 85% opacity');
    });
  });

  group('UDC Design System — Radius and Spacing Tokens', () {
    test('Radius tokens adhere to UDC geometry hierarchy', () {
      expect(PaykRadius.xs, equals(8.0));
      expect(PaykRadius.sm, equals(12.0));
      expect(PaykRadius.md, equals(16.0), reason: 'Standard card radius must be 16 dp');
      expect(PaykRadius.pill, equals(18.0), reason: 'Active nav capsule radius must be 18 dp');
      expect(PaykRadius.header, equals(24.0), reason: 'Header bottom corner radius must be 24 dp');
      expect(PaykRadius.xl, equals(28.0));
    });

    test('Space tokens adhere to 4dp/8dp grid system', () {
      expect(PaykSpace.xxs, equals(4.0));
      expect(PaykSpace.xs, equals(8.0));
      expect(PaykSpace.sm, equals(12.0));
      expect(PaykSpace.md, equals(16.0));
      expect(PaykSpace.lg, equals(20.0), reason: 'Standard screen horizontal margin is 20 dp');
      expect(PaykSpace.xl, equals(24.0));
      expect(PaykSpace.xxl, equals(32.0));
    });
  });

  group('UDC Design System — Theme Configuration (PaykTheme.light)', () {
    final theme = PaykTheme.light;

    test('Theme basic properties configure Material 3 and Manrope font', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.scaffoldBackgroundColor, equals(PaykColors.canvas));
      expect(theme.textTheme.bodyMedium?.fontFamily, equals('Manrope'));
      expect(theme.textTheme.titleLarge?.fontFamily, equals('Manrope'));
    });

    test('ColorScheme properly binds UDC tokens', () {
      final scheme = theme.colorScheme;
      expect(scheme.primary, equals(PaykColors.primary));
      expect(scheme.surface, equals(PaykColors.sheet));
      expect(scheme.onSurface, equals(PaykColors.textPrimary));
      expect(scheme.error, equals(PaykColors.danger));
    });

    test('CardThemeData enforces 16dp radius and 1dp border', () {
      final cardTheme = theme.cardTheme;
      expect(cardTheme.color, equals(PaykColors.sheet));
      expect(cardTheme.elevation, equals(0));
      expect(cardTheme.shape, isA<RoundedRectangleBorder>());
      final shape = cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, equals(BorderRadius.circular(16.0)));
      expect(shape.side.color, equals(PaykColors.border));
      expect(shape.side.width, equals(1.0));
    });

    test('Button themes enforce Manrope font, 16dp radius and proper colors', () {
      final filledStyle = theme.filledButtonTheme.style;
      expect(filledStyle, isNotNull);
      final shape = filledStyle!.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(shape?.borderRadius, equals(BorderRadius.circular(16.0)));

      final outlinedStyle = theme.outlinedButtonTheme.style;
      expect(outlinedStyle, isNotNull);
      final outlinedShape = outlinedStyle!.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(outlinedShape?.borderRadius, equals(BorderRadius.circular(16.0)));
    });

    test('InputDecorationTheme configures clean borders and Manrope hint', () {
      final inputTheme = theme.inputDecorationTheme;
      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, equals(PaykColors.sheet));
      expect(inputTheme.hintStyle?.fontFamily, equals('Manrope'));
      expect(inputTheme.hintStyle?.color, equals(PaykColors.textSecondary));
      expect(inputTheme.border, isA<OutlineInputBorder>());
      final border = inputTheme.border as OutlineInputBorder;
      expect(border.borderRadius, equals(BorderRadius.circular(16.0)));
    });
  });
}
