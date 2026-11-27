import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/api/api_config.dart';
import '../motion/payk_motion.dart';
import '../theme/payk_colors.dart';

const _googleMarkSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M23.49 12.27c0-.79-.07-1.54-.2-2.27H12v4.51h6.47a5.53 5.53 0 0 1-2.4 3.63v3.02h3.88c2.27-2.09 3.54-5.17 3.54-8.89Z"/>
  <path fill="#34A853" d="M12 24c3.24 0 5.95-1.07 7.94-2.91l-3.88-3.02c-1.07.72-2.45 1.15-4.06 1.15-3.12 0-5.77-2.11-6.72-4.96H1.27v3.11A12 12 0 0 0 12 24Z"/>
  <path fill="#FBBC05" d="M5.28 14.26A7.2 7.2 0 0 1 4.9 12c0-.79.14-1.55.38-2.26V6.63H1.27a12 12 0 0 0 0 10.74l4.01-3.11Z"/>
  <path fill="#EA4335" d="M12 4.78c1.76 0 3.34.61 4.59 1.8l3.44-3.44C17.95 1.19 15.24 0 12 0A12 12 0 0 0 1.27 6.63l4.01 3.11C6.23 6.89 8.88 4.78 12 4.78Z"/>
</svg>
''';

/// Фирменный четырёхцветный знак Google.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _googleMarkSvg,
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

/// Кнопка «Продолжить с Google» / «Привязать Google» в стиле приложения.
class GoogleContinueButton extends StatelessWidget {
  const GoogleContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      enabled: !busy && onPressed != null,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: PaykColors.ink,
            side: const BorderSide(color: Color(0xFFE4E1EC), width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: PaykColors.primary,
                  ),
                )
              else
                const GoogleMark(size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Разделитель «или» между кнопкой Google и вводом номера.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(
            child: Divider(height: 1, thickness: 1, color: PaykColors.border),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PaykColors.textSecondary,
              ),
            ),
          ),
          const Expanded(
            child: Divider(height: 1, thickness: 1, color: PaykColors.border),
          ),
        ],
      ),
    );
  }
}

/// Поле со ссылкой-приглашением: без `https://`, перенос только перед `/r/…`, нажатие копирует полную ссылку.
class InviteLinkDisplay extends StatelessWidget {
  const InviteLinkDisplay({
    super.key,
    required this.link,
    required this.onCopy,
    this.semanticsLabel,
    this.textColor = PaykColors.textPrimary,
    this.iconColor = PaykColors.textSecondary,
    this.fontSize = 14.5,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final String link;
  final VoidCallback onCopy;
  final String? semanticsLabel;
  final Color textColor;
  final Color iconColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final parts = ApiConfig.inviteLinkParts(link);
    final style = TextStyle(
      fontFamily: 'Inter',
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: textColor,
      height: 1.3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Semantics(
      button: true,
      label: semanticsLabel ?? link,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onCopy();
          },
          borderRadius: borderRadius,
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(parts.host, maxLines: 1, style: style),
                      ),
                      if (parts.path.isNotEmpty)
                        Text(parts.path, maxLines: 1, style: style),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.copy_rounded, size: 18, color: iconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
