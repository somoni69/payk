import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/payk_colors.dart';

/// Единая диагональная волна блика на весь экран скелетона.
/// Все [SkeletonBox] внутри читают общую анимацию и координаты предка,
/// благодаря чему свет плавно скользит одним синхронным потоком по всем костям.
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
    duration: const Duration(milliseconds: 1600),
  );

  RenderBox? _rootBox() {
    if (!mounted) return null;
    final ro = context.findRenderObject();
    return ro is RenderBox ? ro : null;
  }

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
    return RepaintBoundary(
      child: _ShimmerScope(
        animation: _controller,
        rootBox: _rootBox,
        child: widget.child,
      ),
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({
    required this.animation,
    required this.rootBox,
    required super.child,
  });

  final Animation<double> animation;
  final RenderBox? Function() rootBox;

  static _ShimmerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerScope>();
  }

  @override
  bool updateShouldNotify(covariant _ShimmerScope oldWidget) =>
      animation != oldWidget.animation || rootBox != oldWidget.rootBox;
}

/// Прямоугольник или круг на месте текста, иконки или карточки.
/// Рисует единую экранную диагональную волну в paint без пересборки виджетов.
class SkeletonBox extends LeafRenderObjectWidget {
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
  RenderObject createRenderObject(BuildContext context) {
    final scope = _ShimmerScope.maybeOf(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return _RenderSkeletonBox(
      width,
      height,
      radius,
      circle,
      color ?? PaykColors.skeleton,
      highlight ?? PaykColors.skeletonHighlight,
      reduce ? null : scope?.animation,
      scope?.rootBox,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final scope = _ShimmerScope.maybeOf(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    (renderObject as _RenderSkeletonBox)
      ..desiredWidth = width
      ..desiredHeight = height
      ..radius = radius
      ..circle = circle
      ..baseColor = color ?? PaykColors.skeleton
      ..shineColor = highlight ?? PaykColors.skeletonHighlight
      ..animation = reduce ? null : scope?.animation
      ..rootBox = scope?.rootBox;
  }
}

class _RenderSkeletonBox extends RenderBox {
  _RenderSkeletonBox(
    this._desiredWidth,
    this._desiredHeight,
    this._radius,
    this._circle,
    this._baseColor,
    this._shineColor,
    this._animation,
    this._rootBox,
  );

  // Угол волны ~18° (cos 18° ≈ 0.9511, sin 18° ≈ 0.3090).
  static const _dx = 0.9511;
  static const _dy = 0.3090;
  static const _activeFraction = 0.78;

  final Paint _paint = Paint()..isAntiAlias = true;

  double? _desiredWidth;
  set desiredWidth(double? value) {
    if (_desiredWidth == value) return;
    _desiredWidth = value;
    markNeedsLayout();
  }

  double _desiredHeight;
  set desiredHeight(double value) {
    if (_desiredHeight == value) return;
    _desiredHeight = value;
    markNeedsLayout();
  }

  double _radius;
  set radius(double value) {
    if (_radius == value) return;
    _radius = value;
    markNeedsPaint();
  }

  bool _circle;
  set circle(bool value) {
    if (_circle == value) return;
    _circle = value;
    markNeedsPaint();
  }

  Color _baseColor;
  set baseColor(Color value) {
    if (_baseColor == value) return;
    _baseColor = value;
    markNeedsPaint();
  }

  Color _shineColor;
  set shineColor(Color value) {
    if (_shineColor == value) return;
    _shineColor = value;
    markNeedsPaint();
  }

  Animation<double>? _animation;
  set animation(Animation<double>? value) {
    if (_animation == value) return;
    if (attached) _animation?.removeListener(markNeedsPaint);
    _animation = value;
    if (attached) _animation?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  RenderBox? Function()? _rootBox;
  set rootBox(RenderBox? Function()? value) {
    if (_rootBox == value) return;
    _rootBox = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    final fallbackHeight = _desiredHeight.isFinite
        ? _desiredHeight
        : (constraints.maxHeight.isFinite ? constraints.maxHeight : 16.0);
    final resolvedWidth = _desiredWidth ??
        (constraints.maxWidth.isFinite ? constraints.maxWidth : fallbackHeight);
    size = constraints.constrain(Size(resolvedWidth, fallbackHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;

    final rect = offset & size;
    final anim = _animation;
    final raw = anim?.value;

    if (raw == null || raw >= _activeFraction) {
      _paint
        ..shader = null
        ..color = _baseColor;
    } else {
      final eased = Curves.easeInOutSine.transform(raw / _activeFraction);

      Size sweepSize = size;
      Offset originInRoot = Offset.zero;
      final root = _rootBox?.call();
      if (root != null &&
          root.attached &&
          attached &&
          root.hasSize &&
          root.size.width > 1) {
        try {
          final transform = getTransformTo(root);
          originInRoot = MatrixUtils.transformPoint(transform, Offset.zero);
          sweepSize = root.size;
        } catch (_) {
          originInRoot = Offset.zero;
          sweepSize = size;
        }
      }

      final spanW = sweepSize.width.clamp(120.0, 1200.0);
      final spanH = sweepSize.height.clamp(0.0, 900.0);
      final totalSpan = spanW * _dx + spanH * _dy;
      final bandHalf = (spanW * 0.36).clamp(110.0, 210.0);
      final wavePos = -bandHalf + eased * (totalSpan + bandHalf * 2);

      final rootOrigin = offset - originInRoot;
      final start = Offset(
        rootOrigin.dx + _dx * (wavePos - bandHalf),
        rootOrigin.dy + _dy * (wavePos - bandHalf),
      );
      final end = Offset(
        rootOrigin.dx + _dx * (wavePos + bandHalf),
        rootOrigin.dy + _dy * (wavePos + bandHalf),
      );

      final midColor = Color.lerp(_baseColor, _shineColor, 0.42)!;
      _paint
        ..color = _baseColor
        ..shader = ui.Gradient.linear(
          start,
          end,
          [_baseColor, midColor, _shineColor, midColor, _baseColor],
          const [0.0, 0.28, 0.5, 0.72, 1.0],
          TileMode.clamp,
        );
    }

    final canvas = context.canvas;
    if (_circle) {
      canvas.drawOval(rect, _paint);
    } else if (_radius <= 0) {
      canvas.drawRect(rect, _paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(_radius)),
        _paint,
      );
    }
  }
}
