import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../i18n/locale_controller.dart';
import '../theme/payk_colors.dart';

class PaykShell extends ConsumerWidget {
  const PaykShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      extendBody: true,
      body: shell,
      bottomNavigationBar: _GlassBar(
        index: shell.currentIndex,
        onSelect: _go,
        labels: [
          t(ref, 'nav.home'),
          t(ref, 'nav.history'),
          '',
          t(ref, 'nav.friends'),
          t(ref, 'nav.profile'),
        ],
      ),
    );
  }
}

class _GlassBar extends StatefulWidget {
  const _GlassBar({
    required this.index,
    required this.onSelect,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<String> labels;

  @override
  State<_GlassBar> createState() => _GlassBarState();
}

class _GlassBarState extends State<_GlassBar> with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(mass: 1, stiffness: 380, damping: 26);
  static const _icons = [
    Icons.home_outlined,
    Icons.receipt_long_outlined,
    Icons.qr_code_rounded,
    Icons.group_outlined,
    Icons.person_outline,
  ];

  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.index.toDouble(),
  );

  @override
  void didUpdateWidget(covariant _GlassBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = widget.index.toDouble();
      return;
    }
    _position.animateWith(
      SpringSimulation(_spring, _position.value, widget.index.toDouble(), _position.velocity),
    );
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _tap(int index) {
    if (index != widget.index) HapticFeedback.selectionClick();
    widget.onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    final solid = MediaQuery.of(context).highContrast || MediaQuery.accessibleNavigationOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A1D29).withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: solid ? 1 : 0.90),
                    Colors.white.withValues(alpha: solid ? 1 : 0.22),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30.8),
                  child: SizedBox(
                    height: 68,
                    child: Stack(
                      children: [
                        const RepaintBoundary(child: _GlassPlate()),
                        AnimatedBuilder(
                          animation: _position,
                          builder: (context, _) {
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final tab = constraints.maxWidth / _icons.length;
                                final travel = _position.value.clamp(0.0, _icons.length - 1.0);
                                final awayFromCode = (travel - 2).abs().clamp(0.0, 1.0);
                                return Stack(
                                  children: [
                                    Opacity(
                                      opacity: awayFromCode,
                                      child: Transform.translate(
                                        offset: Offset(travel * tab + 6, 10),
                                        child: SizedBox(
                                          width: tab - 12,
                                          height: 48,
                                          child: const DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Color(0xFFF4F1FF),
                                              borderRadius: BorderRadius.all(Radius.circular(18)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        for (var i = 0; i < _icons.length; i++)
                                          Expanded(
                                            child: _Slot(
                                              icon: _icons[i],
                                              label: widget.labels[i],
                                              center: i == 2,
                                              proximity: (travel - i).abs().clamp(0.0, 1.0),
                                              onTap: () => _tap(i),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPlate extends StatelessWidget {
  const _GlassPlate();

  @override
  Widget build(BuildContext context) {
    final solid = MediaQuery.of(context).highContrast || MediaQuery.accessibleNavigationOf(context);
    if (solid) {
      return const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox.expand());
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: const ColoredBox(color: Color(0x73FFFFFF), child: SizedBox.expand()),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.icon,
    required this.label,
    required this.center,
    required this.proximity,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool center;
  final double proximity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final focus = 1 - proximity;
    final color = Color.lerp(PaykColors.muted, PaykColors.violet, focus)!;
    final scale = lerpDouble(1, 1.08, focus)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (center)
            Transform.scale(
              scale: lerpDouble(1, 1.06, focus)!,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: focus > 0.5 ? PaykColors.violetDeep : PaykColors.violet,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PaykColors.violet.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            )
          else ...[
            Transform.scale(
              scale: scale,
              child: Icon(icon, color: color, size: 23, weight: 300, fill: 0),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
