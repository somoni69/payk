import 'package:flutter/material.dart';

import '../motion/payk_motion.dart';
import 'payk_colors.dart';
import 'payk_typography.dart';

export '../motion/payk_motion.dart';
export 'payk_typography.dart';

abstract final class PaykTheme {
  static ThemeData get light {
    const radius = PaykRadius.md; // 16 dp
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: PaykColors.border, width: 1.0),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: PaykColors.canvas,
      colorScheme: const ColorScheme.light(
        primary: PaykColors.primary,
        onPrimary: Colors.white,
        surface: PaykColors.sheet,
        onSurface: PaykColors.textPrimary,
        error: PaykColors.danger,
        onError: Colors.white,
      ),
    );

    return base.copyWith(
      textTheme: PaykTypography.buildTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: PaykColors.sheet,
        foregroundColor: PaykColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: PaykColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: PaykColors.sheet,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: PaykColors.border, width: 1.0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PaykColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PaykColors.textPrimary,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: PaykColors.border, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PaykColors.sheet,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Manrope',
          color: PaykColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: PaykColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: PaykColors.danger, width: 1.2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PaykColors.textPrimary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PaykColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      pageTransitionsTheme: PaykMotion.pageTransitionsTheme,
      dividerColor: PaykColors.border,
      splashFactory: InkRipple.splashFactory,
    );
  }
}
