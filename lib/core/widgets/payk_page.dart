import 'package:flutter/material.dart';

import '../theme/payk_colors.dart';

class PaykInsets {
  static EdgeInsets list(
    BuildContext context, {
    double top = 12,
    double bottom = 20,
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
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: body,
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
        boxShadow: const [
          BoxShadow(color: Color(0x0A1A1D29), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0F1A1D29), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
