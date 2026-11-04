import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../liquid_glass/liquid_glass_bottom_bar.dart';
import '../theme/payk_colors.dart';

export '../liquid_glass/liquid_glass_bottom_bar.dart';
export '../liquid_glass/liquid_glass_tokens.dart';
export '../liquid_glass/liquid_glass_widgets.dart';

/// Оболочка основного экрана с компактной навигационной панелью Liquid Glass.
class PaykShell extends ConsumerWidget {
  const PaykShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atHome = shell.currentIndex == 0;
    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || atHome) return;
        shell.goBranch(0);
      },
      child: Scaffold(
        backgroundColor: PaykColors.canvas,
        extendBody: true,
        body: shell,
        bottomNavigationBar: LiquidGlassBottomBar(
          currentIndex: shell.currentIndex,
          onTap: _go,
        ),
      ),
    );
  }
}
