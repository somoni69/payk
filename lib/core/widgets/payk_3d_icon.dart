import 'package:flutter/material.dart';

import '../theme/payk_colors.dart';

/// Базовый 3D-виджет из `assets/3d/` с запасной векторной иконкой при ошибке загрузки.
class Payk3dIcon extends StatelessWidget {
  const Payk3dIcon({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Icon(
        fallbackIcon,
        size: size * 0.78,
        color: fallbackColor,
      ),
    );
  }
}

/// 3D-виджет колокольчика (`assets/3d/bell.webp`) для экрана уведомлений и настроек.
class Bell3dIcon extends StatelessWidget {
  const Bell3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/bell.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.notifications_none_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет билета/сертификата (`assets/3d/ticket.webp`) для модалки «Мои сертификаты».
class Ticket3dIcon extends StatelessWidget {
  const Ticket3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/ticket.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.confirmation_number_outlined,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет кристалла (`assets/3d/gem.webp`) для модалки «Мой магазин».
class Gem3dIcon extends StatelessWidget {
  const Gem3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/gem.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.storefront_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет линейки (`assets/3d/ruler.webp`) для подсказки и пустого состояния размеров.
class Ruler3dIcon extends StatelessWidget {
  const Ruler3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/ruler.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.straighten_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет начисления кэшбэка (`assets/3d/cashback-plus.webp`).
class CashbackPlus3dIcon extends StatelessWidget {
  const CashbackPlus3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/cashback-plus.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.trending_up_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет списания кэшбэка (`assets/3d/cashback-minus.webp`).
class CashbackMinus3dIcon extends StatelessWidget {
  const CashbackMinus3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/cashback-minus.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.payments_outlined,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет QR-лого (`assets/3d/qr-code.webp`) для карточки быстрого доступа на главной.
class QrCode3dIcon extends StatelessWidget {
  const QrCode3dIcon({
    super.key,
    this.size = 50,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/qr-code.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.qr_code_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет «Мои размеры» (`assets/3d/my-sizes.webp`).
class MySizes3dIcon extends StatelessWidget {
  const MySizes3dIcon({
    super.key,
    this.size = 28,
    this.fallbackColor = PaykColors.textPrimary,
  });

  static const assetPath = 'assets/3d/my-sizes.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.straighten_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет «Мои чеки» (`assets/3d/my-receipts.webp`).
class MyReceipts3dIcon extends StatelessWidget {
  const MyReceipts3dIcon({
    super.key,
    this.size = 28,
    this.fallbackColor = PaykColors.textPrimary,
  });

  static const assetPath = 'assets/3d/my-receipts.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.receipt_long_outlined,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет «Предложения по размеру» (`assets/3d/size-offers.webp`).
class SizeOffers3dIcon extends StatelessWidget {
  const SizeOffers3dIcon({
    super.key,
    this.size = 28,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/size-offers.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.local_offer_outlined,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет «Статусы и правила» (`assets/3d/status-rules.webp`).
class StatusRules3dIcon extends StatelessWidget {
  const StatusRules3dIcon({
    super.key,
    this.size = 28,
    this.fallbackColor = PaykColors.textPrimary,
  });

  static const assetPath = 'assets/3d/status-rules.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.confirmation_number_outlined,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет «Связь с магазином» (`assets/3d/store-contact.webp`).
class StoreContact3dIcon extends StatelessWidget {
  const StoreContact3dIcon({
    super.key,
    this.size = 28,
    this.fallbackColor = PaykColors.textPrimary,
  });

  static const assetPath = 'assets/3d/store-contact.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.help_outline_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет «О приложении» (`assets/3d/about-app.webp`).
class AboutApp3dIcon extends StatelessWidget {
  const AboutApp3dIcon({
    super.key,
    this.size = 28,
    this.fallbackColor = PaykColors.textPrimary,
  });

  static const assetPath = 'assets/3d/about-app.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.info_outline_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет «Мой магазин» (`assets/3d/store.webp`).
class Store3dIcon extends StatelessWidget {
  const Store3dIcon({
    super.key,
    this.size = 28,
    this.fallbackColor = PaykColors.textPrimary,
  });

  static const assetPath = 'assets/3d/store.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.location_on_outlined,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет «Настройки» (`assets/3d/gear.webp`).
class Gear3dIcon extends StatelessWidget {
  const Gear3dIcon({
    super.key,
    this.size = 28,
    this.fallbackColor = PaykColors.textPrimary,
  });

  static const assetPath = 'assets/3d/gear.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.settings_outlined,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет выбора языка (`assets/3d/language.webp`) для экрана настроек.
class Language3dIcon extends StatelessWidget {
  const Language3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/language.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.language_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет подарка (`assets/3d/gift.webp`) для бонусов и акций.
class Gift3dIcon extends StatelessWidget {
  const Gift3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/gift.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.card_giftcard_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет кубка (`assets/3d/trophy.webp`) для выигрышей и розыгрышей.
class Trophy3dIcon extends StatelessWidget {
  const Trophy3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/trophy.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.emoji_events_outlined,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}

/// 3D-виджет покупок (`assets/3d/bags.webp`) для секции «Покупки» в настройках.
class Bags3dIcon extends StatelessWidget {
  const Bags3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/bags.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.shopping_bag_outlined,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}
