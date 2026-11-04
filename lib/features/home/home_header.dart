import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_avatar.dart';
import '../../data/models/models.dart';
import 'quick_action_cards.dart';

/// Фиолетовая шапка Главного экрана в стиле UDC:
/// - Градиент Color(0xFF9F72E7) -> Color(0xFF8574E6)
/// - Скругление нижних углов 24 dp
/// - Аватар 48x48 dp с рамкой
/// - Заголовок «Привет, [Имя]!» и подзаголовок «С возвращением!»
/// - Кнопки QR-сканера и уведомлений в контейнерах 0x38FFFFFF
/// - Встроенные карточки быстрого доступа QuickActionCards
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.account,
    required this.onScannerTap,
    required this.onNotificationsTap,
    required this.onCodeTap,
    required this.onCompaniesTap,
    required this.onCertificatesTap,
  });

  final Account account;
  final VoidCallback onScannerTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onCodeTap;
  final VoidCallback onCompaniesTap;
  final VoidCallback onCertificatesTap;

  @override
  Widget build(BuildContext context) {
    final member = account.member;
    final rawName = member.firstName.trim();
    final firstName = rawName.isNotEmpty ? rawName : 'Фарзод';

    return Container(
      decoration: const BoxDecoration(
        gradient: PaykColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(PaykRadius.header)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Верхняя панель: Аватар + Приветствие + Кнопки действий
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  PaykAvatar(member: member, size: 48, ring: true),
                  const SizedBox(width: 12),

                  // Текстовый блок: Приветствие
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Привет, $firstName!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: PaykColors.textOnHeader,
                          ),
                        ),
                        const SizedBox(height: 1.5),
                        const Text(
                          'С возвращением!',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: PaykColors.textOnHeaderSubtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Кнопка уведомлений (колокольчик)
                  _HeaderIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Уведомления',
                    onTap: onNotificationsTap,
                    badgeCount: account.messagesUnread,
                  ),
                  const SizedBox(width: 8),

                  // Кнопка QR-сканера
                  _HeaderIconButton(
                    icon: Icons.qr_code_scanner_rounded,
                    tooltip: 'Сканер QR-кода',
                    onTap: onScannerTap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Горизонтальные карточки быстрых действий
            QuickActionCards(
              account: account,
              onOpenCode: onCodeTap,
              onOpenCompanies: onCompaniesTap,
              onOpenCertificates: onCertificatesTap,
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

/// Полупрозрачная квадратная кнопка хедера 42x42 dp со скруглением 14 dp
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: PaykPressable(
        scaleDown: PaykMotion.scaleIcon,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: PaykColors.headerButtonBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  if (badgeCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: PaykColors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
