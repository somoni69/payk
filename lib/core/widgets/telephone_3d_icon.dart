import 'package:flutter/material.dart';

import '../theme/payk_colors.dart';
import 'payk_3d_icon.dart';

/// 3D-виджет телефонной трубки (`assets/3d/telephone.webp`) для блоков, где указан номер телефона.
class Telephone3dIcon extends StatelessWidget {
  const Telephone3dIcon({
    super.key,
    this.size = 24,
    this.fallbackColor = PaykColors.primary,
  });

  static const assetPath = 'assets/3d/telephone.webp';

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Payk3dIcon(
      assetPath: assetPath,
      fallbackIcon: Icons.phone_rounded,
      size: size,
      fallbackColor: fallbackColor,
    );
  }
}
