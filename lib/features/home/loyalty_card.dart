import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_mark.dart';
import '../../data/models/models.dart';

/// Уровень карты с тем же сжатием, что и подпись статуса:
/// при четырёх порогах 4-й уровень рисуется как «Алмаз».
int loyaltyTierLevel(int level, {int tiers = 5}) {
  final mapped = tiers <= 4 && level >= 4 ? 5 : level;
  if (mapped < 1) return 1;
  if (mapped > 5) return 5;
  return mapped;
}

/// Материал пластиковой карты. Меняется целиком вместе со статусом.
class LoyaltyCardFace {
  const LoyaltyCardFace({
    required this.colors,
    required this.ink,
    required this.inkSoft,
    required this.pill,
    required this.pillInk,
    required this.mark,
    required this.shadow,
    this.sheen,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  final List<Color> colors;
  final Color ink;
  final Color inkSoft;
  final Color pill;
  final Color pillInk;
  final Color mark;
  final Color shadow;
  final Color? sheen;
  final Alignment begin;
  final Alignment end;
}

/// Пять разных карт: сланец, серебро, золото, графит, фиолетовый алмаз.
LoyaltyCardFace loyaltyCardFace(int level) {
  return switch (level) {
    2 => const LoyaltyCardFace(
      colors: [Color(0xFFF7F9FC), Color(0xFFE6ECF3), Color(0xFFC5D0DE)],
      ink: Color(0xFF1C2430),
      inkSoft: Color(0xFF5C6776),
      pill: Color(0xFF2A3140),
      pillInk: Colors.white,
      mark: Color(0x2E1C2430),
      shadow: Color(0x332A3544),
      sheen: Color(0xCCFFFFFF),
    ),
    3 => const LoyaltyCardFace(
      colors: [Color(0xFFF8E7B2), Color(0xFFE8C15A), Color(0xFFD4A03A)],
      ink: Color(0xFF3D2A08),
      inkSoft: Color(0xFF6B4E16),
      pill: Color(0xFF3D2A08),
      pillInk: Colors.white,
      mark: Color(0x333D2A08),
      shadow: Color(0x40C4922A),
      sheen: Color(0x99FFFFFF),
    ),
    4 => const LoyaltyCardFace(
      colors: [Color(0xFF141A22), Color(0xFF2A3644), Color(0xFF465668)],
      ink: Colors.white,
      inkSoft: Color(0xD6FFFFFF),
      pill: Color(0xFF0E141C),
      pillInk: Colors.white,
      mark: Color(0x38FFFFFF),
      shadow: Color(0x66141A22),
      sheen: Color(0x28FFFFFF),
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    5 => const LoyaltyCardFace(
      colors: [Color(0xFF241C88), Color(0xFF372CD2), Color(0xFF6248EE)],
      ink: Colors.white,
      inkSoft: Color(0xE6FFFFFF),
      pill: Color(0xFF1A1460),
      pillInk: Colors.white,
      mark: Color(0x38FFFFFF),
      shadow: Color(0x55372CD2),
      sheen: Color(0x22FFFFFF),
    ),
    _ => const LoyaltyCardFace(
      colors: PaykColors.tierStandard,
      ink: Colors.white,
      inkSoft: Color(0xE6FFFFFF),
      pill: Color(0xFF2C3344),
      pillInk: Colors.white,
      mark: Color(0x38FFFFFF),
      shadow: Color(0x403B4150),
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
  };
}

/// Карта лояльности и магазина «Алмоси» на главной: бренд, баланс, имя и код.
/// Вид берётся из статуса.
class LoyaltyCard extends StatelessWidget {
  const LoyaltyCard({
    super.key,
    required this.member,
    required this.wallet,
    required this.locale,
    this.tiers = 5,
    this.onTap,
  });

  final Member member;
  final Wallet wallet;
  final String locale;
  final int tiers;
  final VoidCallback? onTap;

  static const _radius = 26.0;
  static const _minHeight = 204.0;

  @override
  Widget build(BuildContext context) {
    final level = loyaltyTierLevel(wallet.status, tiers: tiers);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final name = _holderName(member);
    final code = member.referralCode.trim();

    final card = AnimatedSwitcher(
      duration: reduce ? Duration.zero : PaykMotion.page,
      switchInCurve: PaykMotion.easeOut,
      switchOutCurve: PaykMotion.easeOut,
      transitionBuilder: (child, animation) {
        final scale = Tween<double>(
          begin: PaykMotion.entranceScale,
          end: 1.0,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        );
      },
      child: _LoyaltyCardSurface(
        key: ValueKey('loyalty-face-$level'),
        face: loyaltyCardFace(level),
        tier: tierLabel(locale, wallet.status, tiers: tiers),
        storeLabel: tr(locale, 'store.label'),
        brandTitle: tr(locale, 'store.brand'),
        balanceLabel: tr(locale, 'home.balance'),
        amount: formatNumber(wallet.balance),
        name: name,
        code: code,
        showChevron: onTap != null,
      ),
    );

    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: '${tr(locale, 'store.label')} ${tr(locale, 'store.brand')}',
      child: PaykPressable(
        scaleDown: PaykMotion.scaleSubtle,
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _LoyaltyCardSurface extends StatelessWidget {
  const _LoyaltyCardSurface({
    super.key,
    required this.face,
    required this.tier,
    required this.storeLabel,
    required this.brandTitle,
    required this.balanceLabel,
    required this.amount,
    required this.name,
    required this.code,
    required this.showChevron,
  });

  final LoyaltyCardFace face;
  final String tier;
  final String storeLabel;
  final String brandTitle;
  final String balanceLabel;
  final String amount;
  final String name;
  final String code;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        constraints: const BoxConstraints(minHeight: LoyaltyCard._minHeight),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LoyaltyCard._radius),
          gradient: LinearGradient(begin: face.begin, end: face.end, colors: face.colors),
          boxShadow: [
            BoxShadow(color: face.shadow, blurRadius: 26, offset: const Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LoyaltyCard._radius),
          child: Stack(
            children: [
              if (face.sheen != null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomCenter,
                        colors: [face.sheen!, const Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              Positioned.fill(child: _WatermarkSlot(letter: face.ink)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 20,
                          child: PaykGlyph(color: face.ink),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ПАЙК',
                          style: _cardText(
                            color: face.ink,
                            size: 15,
                            weight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: _StatusPill(
                                label: tier,
                                fill: face.pill,
                                ink: face.pillInk,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          size: 13,
                          color: face.inkSoft,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          storeLabel.toUpperCase(),
                          style: _cardText(
                            color: face.inkSoft,
                            size: 11,
                            weight: FontWeight.w700,
                            letterSpacing: 0.9,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            brandTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _cardText(
                              color: face.ink,
                              size: 22,
                              weight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (showChevron) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: face.inkSoft,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      balanceLabel,
                      style: _cardText(
                        color: face.inkSoft,
                        size: 13,
                        weight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: amount,
                              style: _cardText(
                                color: face.ink,
                                size: 34,
                                weight: FontWeight.w800,
                                letterSpacing: -1.1,
                                features: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            TextSpan(
                              text: ' смн',
                              style: _cardText(
                                color: face.ink,
                                size: 16,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(inherit: false),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _cardText(
                              color: face.ink,
                              size: 13,
                              weight: FontWeight.w700,
                              letterSpacing: 0.4,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (code.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Text(
                            code,
                            style: _cardText(
                              color: face.ink,
                              size: 13,
                              weight: FontWeight.w700,
                              letterSpacing: 0.6,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Знак Алмосӣ справа на карте. Буква берёт цвет текста текущего материала.
class _WatermarkSlot extends StatelessWidget {
  const _WatermarkSlot({required this.letter});

  final Color letter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned(
              right: 12,
              top: height * 0.16,
              width: width * 0.40,
              height: height * 0.68,
              child: _AlmosiLogo(letter: letter),
            ),
          ],
        );
      },
    );
  }
}

class _AlmosiLogo extends StatelessWidget {
  const _AlmosiLogo({required this.letter});

  final Color letter;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/almosi_blue.png',
            fit: BoxFit.contain,
            cacheWidth: 420,
          ),
          ColorFiltered(
            colorFilter: ColorFilter.mode(letter, BlendMode.srcIn),
            child: Image.asset(
              'assets/images/almosi_letter.png',
              fit: BoxFit.contain,
              cacheWidth: 420,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.fill, required this.ink});

  final String label;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Text(
          label,
          maxLines: 1,
          style: _cardText(
            color: ink,
            size: 13.5,
            weight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// Системный шрифт. Manrope с темы сюда не проходит: `inherit: false`.
TextStyle _cardText({
  required Color color,
  required double size,
  required FontWeight weight,
  double height = 1,
  double letterSpacing = 0,
  List<FontFeature>? features,
}) {
  return TextStyle(
    inherit: false,
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: features,
  );
}

String _holderName(Member member) {
  final parts = [member.lastName.trim(), member.firstName.trim()].where((part) => part.isNotEmpty);
  return parts.join(' ').toUpperCase();
}
