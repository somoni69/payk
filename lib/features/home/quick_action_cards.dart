import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../data/models/models.dart';

/// Горизонтальный ряд карточек быстрого доступа в стиле UDC:
/// 1. «QR-код» — интерактивный QR для кассы
/// 2. «Мои компании» — стопка монет, баланс бонусов
/// 3. «Мои сертификаты» — билет со звездой, сертификаты
class QuickActionCards extends StatelessWidget {
  const QuickActionCards({
    super.key,
    required this.account,
    required this.onOpenCode,
    required this.onOpenCompanies,
    required this.onOpenCertificates,
  });

  final Account account;
  final VoidCallback onOpenCode;
  final VoidCallback onOpenCompanies;
  final VoidCallback onOpenCertificates;

  @override
  Widget build(BuildContext context) {
    final member = account.member;
    final wallet = account.wallet;
    final qrData = member.referralCode.isNotEmpty
        ? member.referralCode
        : (member.phone.isNotEmpty ? member.phone : 'PAYK-VIP');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // 1. Карточка QR-кода
          _QuickActionTile(
            width: 108,
            height: 114,
            onTap: onOpenCode,
            semanticsLabel: 'QR-код',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: qrData,
                        size: 50,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: PaykColors.primary,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: PaykColors.primary,
                        ),
                      ),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: PaykColors.primary, width: 2.0),
                        ),
                        child: Center(
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: PaykColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'QR-код',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 2. Карточка «Мои компании»
          _QuickActionTile(
            width: 138,
            height: 114,
            onTap: onOpenCompanies,
            semanticsLabel: 'Мои компании',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _CoinsIllustration(),
                const SizedBox(height: 5),
                const Text(
                  'Мои компании',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatNumber(wallet.balance, decimals: false)} смн',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 3. Карточка «Мои сертификаты»
          _QuickActionTile(
            width: 138,
            height: 114,
            onTap: onOpenCertificates,
            semanticsLabel: 'Мои сертификаты',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _TicketIllustration(),
                const SizedBox(height: 5),
                const Text(
                  'Мои сертификаты',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  wallet.status > 1 ? 'Активен' : 'Купоны',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.width,
    required this.height,
    required this.onTap,
    required this.semanticsLabel,
    required this.child,
  });

  final double width;
  final double height;
  final VoidCallback onTap;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: PaykPressable(
        scaleDown: PaykMotion.scaleButton,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: PaykColors.sheet,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PaykColors.border, width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Стилизованная 3D-иллюстрация стопки монет со звездами в стиле UDC
class _CoinsIllustration extends StatelessWidget {
  const _CoinsIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Нижняя фиолетовая монетка
          Positioned(
            left: 2,
            bottom: 2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF886CE4), Color(0xFF5B3DE6)],
                ),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2059479E),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.star_rounded, size: 12, color: Colors.white),
            ),
          ),
          // Верхняя золотая монетка
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFC837), Color(0xFFFF8008)],
                ),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x20FF8008),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.star_rounded, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Стилизованный фиолетовый билет / купон со звездочкой в стиле UDC
class _TicketIllustration extends StatelessWidget {
  const _TicketIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 30,
      child: Center(
        child: Container(
          width: 34,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9E77F0), Color(0xFF6C47E8)],
            ),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x206C47E8),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 2.5,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFD54F)),
              Container(
                width: 2.5,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
