import 'package:flutter/material.dart';

import '../theme/payk_colors.dart';

/// Один проход блика на весь скелетон. Кости ниже читают эту анимацию.
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.animation;
  }

  @override
  bool updateShouldNotify(covariant _ShimmerScope oldWidget) => animation != oldWidget.animation;
}

/// Прямоугольник или круг на месте текста, иконки или карточки.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = 18,
    this.circle = false,
    this.color,
    this.highlight,
  });

  final double height;
  final double? width;
  final double radius;
  final bool circle;
  final Color? color;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final base = color ?? PaykColors.skeleton;
    final shine = highlight ?? Colors.white;
    final animation = _ShimmerScope.maybeOf(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    Widget bone(LinearGradient? gradient) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
          color: gradient == null ? base : null,
          gradient: gradient,
        ),
        child: const SizedBox.expand(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved = width ?? (constraints.maxWidth.isFinite ? constraints.maxWidth : height);
        return SizedBox(
          width: resolved,
          height: height,
          child: animation == null || reduce
              ? bone(null)
              : AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final render = context.findRenderObject();
                    if (render is! RenderBox || !render.hasSize || !render.attached) {
                      return bone(null);
                    }
                    try {
                      final origin = render.localToGlobal(Offset.zero);
                      final screen = MediaQuery.sizeOf(context).width;
                      final head = -80 + animation.value * (screen + 160);
                      return bone(_sweep(base, shine, head - origin.dx, render.size.width));
                    } catch (_) {
                      return bone(null);
                    }
                  },
                ),
        );
      },
    );
  }
}

LinearGradient? _sweep(Color base, Color shine, double center, double width) {
  if (width <= 1) return null;
  const half = 56.0;
  final a = ((center - half) / width).clamp(0.0, 1.0);
  final b = (center / width).clamp(0.0, 1.0);
  final c = ((center + half) / width).clamp(0.0, 1.0);
  if (c <= 0 || a >= 1) return null;
  final mid = b <= a ? (a + 0.02).clamp(0.0, 1.0) : b;
  final end = c <= mid ? (mid + 0.02).clamp(0.0, 1.0) : c;
  if (end <= mid || mid <= a) return null;
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [base, shine, base],
    stops: [a, mid, end],
  );
}
