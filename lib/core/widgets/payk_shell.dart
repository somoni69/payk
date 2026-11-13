import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../i18n/locale_controller.dart';
import '../i18n/strings.dart';
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
    final locale = ref.watch(localeProvider);
    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || atHome) return;
        shell.goBranch(0);
      },
      child: Scaffold(
        backgroundColor: PaykColors.canvas,
        extendBody: true,
        body: RepaintBoundary(child: shell),
        bottomNavigationBar: LiquidGlassBottomBar(
          currentIndex: shell.currentIndex,
          onTap: _go,
          items: [
            LiquidNavItem(
              type: PaykNavIconType.home,
              icon: Icons.home_rounded,
              label: tr(locale, 'nav.home'),
            ),
            LiquidNavItem(
              type: PaykNavIconType.history,
              icon: Icons.grid_view_rounded,
              label: tr(locale, 'nav.categories'),
            ),
            LiquidNavItem(center: true, label: tr(locale, 'nav.payk')),
            LiquidNavItem(
              type: PaykNavIconType.friends,
              icon: Icons.people_alt_rounded,
              label: tr(locale, 'nav.friends'),
            ),
            LiquidNavItem(
              type: PaykNavIconType.profile,
              icon: Icons.person_rounded,
              label: tr(locale, 'nav.profile'),
            ),
          ],
        ),
      ),
    );
  }
}
