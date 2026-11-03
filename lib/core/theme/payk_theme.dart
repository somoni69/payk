import 'package:flutter/material.dart';

import 'payk_colors.dart';

abstract final class PaykTheme {
  static ThemeData get light {
    const radius = PaykRadius.md;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: PaykColors.line),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: PaykColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PaykColors.violet,
        primary: PaykColors.violet,
        surface: PaykColors.sheet,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Manrope',
        bodyColor: PaykColors.ink,
        displayColor: PaykColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: PaykColors.sheet,
        foregroundColor: PaykColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: PaykColors.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PaykColors.violet,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
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
          foregroundColor: PaykColors.ink,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: PaykColors.line),
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
          vertical: 18,
        ),
        hintStyle: const TextStyle(
          color: PaykColors.muted,
          fontWeight: FontWeight.w500,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: PaykColors.violet, width: 1.6),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PaykColors.ink,
      ),
      dividerColor: PaykColors.line,
      splashFactory: InkRipple.splashFactory,
    );
  }
}
