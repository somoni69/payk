import 'package:flutter/material.dart';

import '../theme/payk_colors.dart';

/// Один проход блика на весь скелетон. Кости ниже читают эту анимацию.
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
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
    return _ShimmerScope(animation: _controller, child: widget.child);
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ShimmerScope>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(covariant _ShimmerScope oldWidget) =>
      animation != oldWidget.animation;
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
        final resolved =
            width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : height);
        final painted = animation == null || reduce
            ? bone(null)
            : CustomPaint(
                painter: _BonePainter(
                  animation: animation,
                  base: base,
                  shine: shine,
                  radius: radius,
                  circle: circle,
                ),
                child: const SizedBox.expand(),
              );
        return SizedBox(width: resolved, height: height, child: painted);
      },
    );
  }
}

/// Блик рисуется в paint. Виджет не пересобирается и не вызывает localToGlobal.
class _BonePainter extends CustomPainter {
  _BonePainter({
    required this.animation,
    required this.base,
    required this.shine,
    required this.radius,
    required this.circle,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color base;
  final Color shine;
  final double radius;
  final bool circle;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = -80 + animation.value * (size.width + 160);
    final gradient = _sweep(base, shine, center, size.width);
    _paint
      ..shader = gradient?.createShader(Offset.zero & size)
      ..color = base;
    if (circle) {
      canvas.drawOval(Offset.zero & size, _paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BonePainter oldDelegate) {
    return base != oldDelegate.base ||
        shine != oldDelegate.shine ||
        radius != oldDelegate.radius ||
        circle != oldDelegate.circle;
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
