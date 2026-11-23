import 'dart:async';

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
class PaykShell extends ConsumerStatefulWidget {
  const PaykShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<PaykShell> createState() => _PaykShellState();
}

class _PaykShellState extends ConsumerState<PaykShell> {
  /// Отсортированы по приоритету: сначала иконки, видимые на главном экране,
  /// затем категории/история и остальные вкладки. Прогрев идёт батчами по 4,
  /// чтобы не загружать 30+ декодеров на первом кадре после входа.
  static const _precache3dAssets = <String>[
    // Главный экран (приоритет 1)
    'assets/3d/qr-code.webp',
    'assets/3d/bell.webp',
    'assets/3d/ruler.webp',
    'assets/3d/gift.webp',
    'assets/3d/coin.webp',
    'assets/3d/ticket.webp',
    'assets/3d/cart.webp',
    'assets/3d/tshirt.webp',
    // Категории и история (приоритет 2)
    'assets/3d/receipt.webp',
    'assets/3d/bags.webp',
    'assets/3d/card.webp',
    'assets/3d/basket.webp',
    'assets/3d/cashback-plus.webp',
    'assets/3d/cashback-minus.webp',
    'assets/3d/my-receipts.webp',
    'assets/3d/coat.webp',
    // Друзья, профиль, размеры и витрина (приоритет 3)
    'assets/3d/party.webp',
    'assets/3d/telephone.webp',
    'assets/3d/gem.webp',
    'assets/3d/trophy.webp',
    'assets/3d/shirt.webp',
    'assets/3d/sneaker.webp',
    'assets/3d/jeans.webp',
    'assets/3d/my-sizes.webp',
    'assets/3d/size-offers.webp',
    'assets/3d/status-rules.webp',
    'assets/3d/store-contact.webp',
    'assets/3d/about-app.webp',
    'assets/3d/store.webp',
    'assets/3d/gear.webp',
    'assets/3d/language.webp',
  ];

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_precacheInBatches());
    });
  }

  Future<void> _precacheInBatches() async {
    final providers = <ImageProvider>[
      ResizeImage(const AssetImage('assets/images/almosi_blue.png'), width: 420),
      ResizeImage(const AssetImage('assets/images/almosi_letter.png'), width: 420),
      for (final path in _precache3dAssets) AssetImage(path),
    ];
    const batchSize = 4;
    for (var i = 0; i < providers.length; i += batchSize) {
      if (!mounted) return;
      final end = (i + batchSize < providers.length) ? i + batchSize : providers.length;
      await Future.wait([
        for (var j = i; j < end; j++)
          precacheImage(providers[j], context).catchError((_) {}),
      ]);
    }
  }

  void _go(int index) {
    widget.shell.goBranch(
      index,
      initialLocation: index == widget.shell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final atHome = widget.shell.currentIndex == 0;
    final locale = ref.watch(localeProvider);
    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || atHome) return;
        widget.shell.goBranch(0);
      },
      child: Scaffold(
        backgroundColor: PaykColors.canvas,
        extendBody: true,
        body: RepaintBoundary(child: widget.shell),
        bottomNavigationBar: RepaintBoundary(
          child: LiquidGlassBottomBar(
            currentIndex: widget.shell.currentIndex,
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
      ),
    );
  }
}
