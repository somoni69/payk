import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/payk_motion.dart';
import '../theme/payk_colors.dart';

export '../motion/payk_motion.dart';

class PaykInsets {
  static EdgeInsets list(
    BuildContext context, {
    double top = 12,
    double bottom = 104,
    double horizontal = 20,
  }) {
    final pad = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(horizontal, pad.top + top, horizontal, pad.bottom + bottom);
  }
}

class PaykPage extends StatelessWidget {
  const PaykPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: canPop ? 0 : 20,
        leading: canPop
            ? PaykPressable(
                scaleDown: PaykMotion.scaleIcon,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: PaykColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).maybePop();
                  },
                ),
              )
            : null,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: PaykColors.textPrimary,
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: body,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SoftPanel extends StatelessWidget {
  const SoftPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x061A1D29), blurRadius: 4, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x0A1A1D29), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
