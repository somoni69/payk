import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';

/// Превью основных категорий на Главном экране в точном соответствии с референсом UDC:
/// Карточки быстрого доступа («Спорт», «Парфюмерия», «Все компании») с пастельным фоном #F8F9FD
class CategoriesPreviewSection extends StatelessWidget {
  const CategoriesPreviewSection({
    super.key,
    required this.onViewAll,
    this.onCategorySelect,
  });

  final VoidCallback onViewAll;
  final ValueChanged<String>? onCategorySelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _CategoryPreviewCard(
              title: 'Спорт',
              onTap: () {
                final select = onCategorySelect;
                if (select != null) {
                  select('Спорт');
                } else {
                  onViewAll();
                }
              },
              illustration: const _SportIllustration(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CategoryPreviewCard(
              title: 'Парфюмерия',
              onTap: () {
                final select = onCategorySelect;
                if (select != null) {
                  select('Парфюмерия');
                } else {
                  onViewAll();
                }
              },
              illustration: const _PerfumeIllustration(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CategoryPreviewCard(
              title: 'Все компании',
              onTap: onViewAll,
              illustration: const _AllCompaniesIllustration(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPreviewCard extends StatelessWidget {
  const _CategoryPreviewCard({
    required this.title,
    required this.onTap,
    required this.illustration,
  });

  final String title;
  final VoidCallback onTap;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
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
            height: 110,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              color: PaykColors.tile,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PaykColors.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                Center(child: illustration),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SportIllustration extends StatelessWidget {
  const _SportIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 2,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.fitness_center_rounded, size: 24, color: Color(0xFF2E7D32)),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFC8E6C9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_run_rounded, size: 20, color: Color(0xFF1B5E20)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerfumeIllustration extends StatelessWidget {
  const _PerfumeIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_florist_rounded, size: 24, color: Color(0xFFE65100)),
            ),
          ),
          Positioned(
            right: 2,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sanitizer_rounded, size: 20, color: Color(0xFFC2185B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllCompaniesIllustration extends StatelessWidget {
  const _AllCompaniesIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Center(
        child: Container(
          width: 58,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9E7DF7), Color(0xFF6B48EF)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x206248EE),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Text(
                'PAYK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFC837),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
