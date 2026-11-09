import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_mark.dart';
import '../../data/api/api_config.dart';
import '../../data/models/models.dart';

const showcaseArts = <String>{
  'sparkles',
  'receipt',
  'cart',
  'speech',
  'gem',
  'money-bag',
  'trophy',
  'gear',
  'telephone',
  'crown',
};

String showcaseArtAsset(String art) {
  final name = showcaseArts.contains(art) ? art : 'sparkles';
  return 'assets/3d/$name.webp';
}

/// Карточка рекламы PAYK: картинка владельца или фирменная подложка с 3D-иллюстрацией.
class ShowcaseCardView extends StatelessWidget {
  const ShowcaseCardView({
    super.key,
    required this.card,
    required this.locale,
    required this.sent,
    required this.onWant,
  });

  final ShowcaseCard card;
  final String locale;
  final bool sent;
  final VoidCallback onWant;

  @override
  Widget build(BuildContext context) {
    final title = card.titleFor(locale);
    final text = card.textFor(locale);
    final image = card.imageUrl;

    return Container(
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null && image.isNotEmpty)
            AspectRatio(
              aspectRatio: card.aspectRatio,
              child: Image.network(
                ApiConfig.url(image),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    ArtCanvas(art: card.art),
              ),
            )
          else
            ArtPanel(art: card.art),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: PaykColors.textPrimary,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: PaykColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                WantButton(locale: locale, sent: sent, onPressed: onWant),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WantButton extends StatelessWidget {
  const WantButton({
    super.key,
    required this.locale,
    required this.sent,
    required this.onPressed,
  });

  final String locale;
  final bool sent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (sent) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PaykColors.incomeSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: PaykColors.success,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              tr(locale, 'payk.sentBadge'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PaykColors.success,
              ),
            ),
          ],
        ),
      );
    }

    return PaykPressable(
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: PaykColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 19),
          label: Text(
            tr(locale, 'payk.want'),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Подложка без картинки: сиреневый градиент, знак PAYK и 3D-иллюстрация.
class ArtPanel extends StatelessWidget {
  const ArtPanel({super.key, required this.art});

  final String art;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 2, child: ArtCanvas(art: art));
  }
}

/// Заливка карточки без собственной пропорции — для ошибки загрузки картинки.
class ArtCanvas extends StatelessWidget {
  const ArtCanvas({super.key, required this.art});

  final String art;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3F1FF), Color(0xFFE3DEFD)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(
                left: -40,
                top: -56,
                child: _Blob(size: 176, color: Color(0x73FFFFFF)),
              ),
              const Positioned(
                right: 40,
                bottom: -64,
                child: _Blob(size: 160, color: Color(0x12372CD2)),
              ),
              const Positioned(left: 16, top: 16, child: _PaykBadge()),
              Positioned(
                right: constraints.maxWidth * 0.07,
                bottom: constraints.maxHeight * 0.08,
                child: Image.asset(
                  showcaseArtAsset(art),
                  height: constraints.maxHeight * 0.76,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PaykBadge extends StatelessWidget {
  const _PaykBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: PaykMark(size: 14)),
          SizedBox(width: 6),
          Text(
            'PAYK',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: PaykColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
