import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../categories/categories_screen.dart';

class CompanyModel {
  const CompanyModel({
    required this.name,
    required this.category,
    required this.cashback,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.badgeText,
    this.badgeIcon,
  });

  final String name;
  final String category;
  final String cashback;
  final Color badgeColor;
  final Color badgeTextColor;
  final String badgeText;
  final IconData? badgeIcon;
}

const defaultNewCompanies = <CompanyModel>[
  CompanyModel(
    name: 'ELITESTORE',
    category: 'Одежда и обувь',
    cashback: 'до 10%',
    badgeColor: Color(0xFFFFB2C9),
    badgeTextColor: Colors.white,
    badgeText: 'es',
  ),
  CompanyModel(
    name: 'A-99',
    category: 'Супермаркет',
    cashback: 'до 7%',
    badgeColor: Color(0xFFFFF0F0),
    badgeTextColor: Color(0xFFE53935),
    badgeText: 'A·99',
  ),
  CompanyModel(
    name: 'PAYK STORE',
    category: 'Флагманский магазин',
    cashback: 'до 12%',
    badgeColor: Color(0xFFEDEAFB),
    badgeTextColor: Color(0xFF6248EE),
    badgeText: 'PAYK',
  ),
  CompanyModel(
    name: 'ALMOSI',
    category: 'Сеть супермаркетов',
    cashback: 'до 5%',
    badgeColor: Color(0xFFE8F5E9),
    badgeTextColor: Color(0xFF2E7D32),
    badgeText: 'MSX',
  ),
  CompanyModel(
    name: 'BEAUTY LAB',
    category: 'Красота и косметика',
    cashback: 'до 8%',
    badgeColor: Color(0xFFF3E5F5),
    badgeTextColor: Color(0xFF8E24AA),
    badgeText: 'BL',
  ),
];

/// Секция «Новые компании» в стиле UDC:
/// Заголовок «Новые компании» + чип «Все», горизонтальный скролл карточек.
class NewCompaniesSection extends StatelessWidget {
  const NewCompaniesSection({
    super.key,
    required this.onViewAll,
    this.onCompanyTap,
    this.companies = defaultNewCompanies,
  });

  final VoidCallback onViewAll;
  final ValueChanged<CompanyModel>? onCompanyTap;
  final List<CompanyModel> companies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Новые компании',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: PaykColors.textPrimary,
                ),
              ),
              PaykPressable(
                scaleDown: PaykMotion.scaleIcon,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onViewAll();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: PaykColors.chipBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Все',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PaykColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Горизонтальный список карточек
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: companies.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final company = companies[index];
              return _CompanyCard(
                company: company,
                onTap: () => onCompanyTap?.call(company),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.company,
    required this.onTap,
  });

  final CompanyModel company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      scaleDown: PaykMotion.scaleSubtle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: 236,
            height: 76,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PaykColors.sheet,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PaykColors.border, width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Логотип компании
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: company.badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: company.badgeIcon != null
                        ? Icon(company.badgeIcon, color: company.badgeTextColor, size: 24)
                        : Text(
                            company.badgeText,
                            style: TextStyle(
                              color: company.badgeTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Название, категория и кэшбэк
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        company.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: PaykColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              company.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: PaykColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: PaykColors.activePill,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              company.cashback,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: PaykColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Показ карточки деталей компании в BottomSheet
void showCompanyDetailsModal(BuildContext context, CompanyModel company) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: PaykColors.canvas,
    sheetAnimationStyle: PaykMotion.sheetAnimationStyle,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: company.badgeColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        company.badgeText,
                        style: TextStyle(
                          color: company.badgeTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: PaykColors.textPrimary,
                          ),
                        ),
                        Text(
                          company.category,
                          style: const TextStyle(
                            fontSize: 13,
                            color: PaykColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PaykColors.activePill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: PaykColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Кэшбэк: ${company.cashback} на карту Payk',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: PaykColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: PaykPressable(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PaykColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      PaykMotion.go(
                        context,
                        '/categories',
                        fallback: () => const CategoriesScreen(),
                      );
                    },
                    child: const Text(
                      'Посмотреть каталог товаров',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
