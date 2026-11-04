import 'package:flutter/material.dart';

import 'payk_colors.dart';

/// Единая типографическая дизайн-система Payk (iOS HIG / Material 3 & Manrope).
///
/// Устраняет дробные и случайные размеры шрифтов, обеспечивая строгую
/// иерархию, выверенный line-height (высоту строки) и letterSpacing (межбуквенный интервал).
abstract final class PaykTypography {
  static const String fontFamily = 'Manrope';

  // ---------------------------------------------------------------------------
  // 1. КАНОНИЧЕСКИЕ РАЗМЕРЫ ШРИФТОВ (FONT SIZE TOKENS)
  // ---------------------------------------------------------------------------

  /// 36 pt: Баланс кошелька, крупные цифры QR-кода
  static const double display = 36.0;

  /// 32 pt: Акцентные заголовки онбординга и сумм
  static const double hero = 32.0;

  /// 24 pt: Крупные заголовки экранов (H1)
  static const double h1 = 24.0;

  /// 20 pt: Заголовки секций списков и экранов (H2)
  static const double h2 = 20.0;

  /// 18 pt: Заголовки AppBar, диалогов и модальных шторок (H3)
  static const double h3 = 18.0;

  /// 16 pt: Названия карточек, заголовки плашек, основной текст кнопок
  static const double title = 16.0;

  /// 15 pt: Базовый читаемый размер для iOS Human Interface Guidelines
  static const double bodyLarge = 15.0;

  /// 14 pt: Основной текст описаний, поля ввода, ячейки таблиц
  static const double body = 14.0;

  /// 13 pt: Вторичные подписи, пояснительный текст
  static const double caption = 13.0;

  /// 12 pt: Таймстампы, даты, счетчики, вторичные статусы
  static const double footnote = 12.0;

  /// 11 pt: Бейджи кэшбэка, чипы категорий капсом, микро-статусы
  static const double badge = 11.0;

  // ---------------------------------------------------------------------------
  // 2. ГОТОВЫЕ СТИЛИ ТЕКСТА (TYPOGRAPHY STYLES)
  // ---------------------------------------------------------------------------

  /// Баланс и большие цифры
  static const TextStyle displayStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: display,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.15,
    color: PaykColors.textPrimary,
  );

  /// Акцентный заголовок онбординга / приветствия
  static const TextStyle heroStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: hero,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.2,
    color: PaykColors.textPrimary,
  );

  /// H1: Крупный заголовок экрана
  static const TextStyle h1Style = TextStyle(
    fontFamily: fontFamily,
    fontSize: h1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.25,
    color: PaykColors.textPrimary,
  );

  /// H2: Заголовок секции
  static const TextStyle h2Style = TextStyle(
    fontFamily: fontFamily,
    fontSize: h2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.3,
    color: PaykColors.textPrimary,
  );

  /// H3: Заголовок шторки / карточки
  static const TextStyle h3Style = TextStyle(
    fontFamily: fontFamily,
    fontSize: h3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.3,
    color: PaykColors.textPrimary,
  );

  /// Title: Акцентная плашка / заголовок строки
  static const TextStyle titleStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: title,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: PaykColors.textPrimary,
  );

  /// Body Large: Читаемый текст / инпуты
  static const TextStyle bodyLargeStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: bodyLarge,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: PaykColors.textPrimary,
  );

  /// Body: Стандартный текст списков и описаний
  static const TextStyle bodyStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: body,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: PaykColors.textPrimary,
  );

  /// Caption: Вторичные подписи
  static const TextStyle captionStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: caption,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: PaykColors.textSecondary,
  );

  /// Footnote: Мелкие даты, счетчики
  static const TextStyle footnoteStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: footnote,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: PaykColors.textSecondary,
  );

  /// Badge: Чипы, бейджи кэшбэка, категории
  static const TextStyle badgeStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: badge,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    height: 1.2,
    color: PaykColors.primary,
  );

  // ---------------------------------------------------------------------------
  // 3. ПОЛНАЯ ТЕМА TEXTTHEME ДЛЯ FLUTTER MATERIAL 3
  // ---------------------------------------------------------------------------

  static TextTheme buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: display,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.15,
        color: PaykColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: hero,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.2,
        color: PaykColors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.25,
        color: PaykColors.textPrimary,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: h1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.25,
        color: PaykColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: h2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
        color: PaykColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: h3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        height: 1.3,
        color: PaykColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: h3,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: PaykColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: title,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: PaykColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodyLarge,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: PaykColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: bodyLarge,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: PaykColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: body,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: PaykColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: caption,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: PaykColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: title,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: PaykColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: footnote,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: PaykColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: badge,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.2,
        color: PaykColors.primary,
      ),
    );
  }
}
