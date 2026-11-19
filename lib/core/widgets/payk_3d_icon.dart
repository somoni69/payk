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
