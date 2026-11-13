import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Единая дизайн-система анимаций и переходов Payk (Emil Kowalski Paradigm).
///
/// Строго следует 7-ступенчатой лестнице решений:
/// Частота -> Цель -> Tool -> Props (transform & opacity ONLY) -> Curve & Duration -> Interrupt -> A11y.
abstract final class PaykMotion {
  // ===========================================================================
  // 1. КАНОНИЧЕСКИЕ КРИВЫЕ (TIMING CURVES — EMIL KOWALSKI)
  // ===========================================================================

  /// Каноническая кривая входа и выхода (`--ease-out: cubic-bezier(0.23, 1, 0.32, 1)`).
  /// Мгновенный старт на максимальной скорости без задержки (0ms latency) и мягкая посадка.
  /// Применяется для всех появлений, закрытий, переходов экранов и отклика кнопок.
  static const Cubic easeOut = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Каноническая кривая перемещения между двумя точками на экране
  /// (`--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1)`).
  static const Cubic easeInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  /// Нативная кривая iOS для модальных шторок, нижних листов и глубоких переходов
  /// (`--ease-drawer: cubic-bezier(0.32, 0.72, 0, 1)`).
  static const Cubic easeDrawer = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Выразительная пружинная кривая с деликатным успокоением без мультяшного отскока
  /// (`--ease-spring-sim: cubic-bezier(0.16, 1, 0.3, 1)`).
  static const Cubic easeSpring = Cubic(0.16, 1.0, 0.3, 1.0);

  // ===========================================================================
  // 2. СТАНДАРТЫ ДЛИТЕЛЬНОСТЕЙ (DURATION TOKENS — STRICTLY < 300ms FOR UI)
  // ===========================================================================

  /// Сжатие при нажатии (`:active` down-press: 80ms).
  static const Duration pressDown = Duration(milliseconds: 80);

  /// Плавный возврат после нажатия (`100–160ms`).
  static const Duration pressUp = Duration(milliseconds: 150);

  /// Микро-взаимодействия: смена фокуса инпута, чекбоксы, иконки (`120–160ms`).
  static const Duration micro = Duration(milliseconds: 140);

  /// Переключатели сегментов, фильтрация категорий, пилюля нижнего бара (`160–200ms`).
  static const Duration fast = Duration(milliseconds: 180);

  /// Карточки, тосты, диалоги и смена состояний внутри экрана (`200–250ms`).
  static const Duration normal = Duration(milliseconds: 220);

  /// Переходы между экранами (push): 250ms (строго до 300ms для ощущения 120 FPS).
  static const Duration page = Duration(milliseconds: 250);

  /// Возврат на предыдущий экран (pop): 210ms.
  static const Duration pageReverse = Duration(milliseconds: 210);

  /// Выезд нижней модальной шторки (BottomSheet): 320ms по кривой `easeDrawer`.
  static const Duration sheet = Duration(milliseconds: 320);

  /// Скрытие нижней модальной шторки: 220ms по кривой `easeOut`.
  static const Duration sheetReverse = Duration(milliseconds: 220);

  // ===========================================================================
  // 3. ТОКЕНЫ МАСШТАБИРОВАНИЯ (COMPOSITOR PROPS — NEVER scale(0))
  // ===========================================================================

  /// Начальный масштаб появления модальных окон и экранов (никогда не 0!).
  static const double entranceScale = 0.96;

  /// Мягкое сжатие для широких карточек и строк списков.
  static const double scaleSubtle = 0.982;

  /// Стандартное сжатие для кнопок и интерактивных плиток (`scale(0.97)`).
  static const double scaleButton = 0.968;

  /// Акцентное сжатие для компактных иконочных кнопок.
  static const double scaleIcon = 0.92;

  // ===========================================================================
  // 4. ACCESSIBILITY (A11Y REDUCED MOTION GATE)
  // ===========================================================================

  /// Проверяет системную настройку `prefers-reduced-motion: reduce`.
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
  }

  /// Возвращает `Duration.zero`, если у пользователя отключены анимации.
  static Duration duration(BuildContext context, Duration standard) {
    return shouldReduceMotion(context) ? Duration.zero : standard;
  }

  // ===========================================================================
  // 5. ЕДИНЫЙ СТИЛЬ МОДАЛЬНЫХ ШТОРОК И ДИАЛОГОВ
  // ===========================================================================

  /// Канонический стиль анимации для всех `showModalBottomSheet`.
  static final AnimationStyle sheetAnimationStyle = AnimationStyle(
    duration: sheet,
    reverseDuration: sheetReverse,
    curve: easeDrawer,
    reverseCurve: easeOut,
  );

  // ===========================================================================
  // 6. ПЕРЕХОДЫ МЕЖДУ ЭКРАНАМИ (COMPOSITOR-ONLY: TRANSFORM + OPACITY)
  // ===========================================================================

  /// Глобальная тема переходов для `ThemeData.pageTransitionsTheme`.
  /// Гарантирует единую плавную анимацию для всех `MaterialPageRoute` на всех платформах.
  static const PageTransitionsTheme pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: PaykPageTransitionsBuilder(),
      TargetPlatform.iOS: PaykPageTransitionsBuilder(),
      TargetPlatform.windows: PaykPageTransitionsBuilder(),
      TargetPlatform.macOS: PaykPageTransitionsBuilder(),
      TargetPlatform.linux: PaykPageTransitionsBuilder(),
      TargetPlatform.fuchsia: PaykPageTransitionsBuilder(),
    },
  );

  /// Строит плавный пространственный переход для `GoRoute` (push/pop).
  /// Использует исключительно GPU-свойства `transform` (translate + scale) и `opacity`.
  static CustomTransitionPage<T> buildPage<T>({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      name: state.name ?? state.path,
      child: child,
      transitionDuration: page,
      reverseTransitionDuration: pageReverse,
      transitionsBuilder: buildSharedSlideTransition,
    );
  }

  /// Строит мягкий переход проявления с масштабом (`scale(0.96 -> 1.0)` + `opacity`)
  /// для корневых экранов (`/splash`, `/onboarding`, `/auth/phone`, `/home`).
  static CustomTransitionPage<T> buildFadeScalePage<T>({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      name: state.name ?? state.path,
      child: child,
      transitionDuration: normal,
      reverseTransitionDuration: fast,
      transitionsBuilder: buildFadeScaleTransition,
    );
  }

  /// Создаёт `PageRoute` с фирменной плавной анимацией Payk (для прямого `Navigator.push`).
  static PageRouteBuilder<T> route<T>(
    Widget pageWidget, {
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: page,
      reverseTransitionDuration: pageReverse,
      pageBuilder: (context, animation, secondaryAnimation) => pageWidget,
      transitionsBuilder: buildSharedSlideTransition,
    );
  }

  /// Единый безопасный переход `push`:
  /// использует `GoRouter` при его наличии в контексте, либо плавный `PaykMotion.route` в изолированных тестах.
  static Future<T?> push<T>(
    BuildContext context,
    String location, {
    Widget Function()? fallback,
    Object? extra,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      return context.push<T>(location, extra: extra);
    }
    if (fallback != null) {
      return Navigator.of(context).push<T>(route<T>(fallback()));
    }
    return Future<T?>.value(null);
  }

  /// Единый безопасный переход `go`:
  /// переключает маршрут через `GoRouter`, либо открывает плавный `PaykMotion.route` в изолированных тестах.
  static void go(
    BuildContext context,
    String location, {
    Widget Function()? fallback,
    Object? extra,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.go(location, extra: extra);
      return;
    }
    if (fallback != null) {
      Navigator.of(context).push<void>(route<void>(fallback()));
    }
  }

  /// Входящий экран: сдвиг `6.5%` по X + масштаб `0.985 -> 1.0` + проявление.
  ///
  /// Нижний экран не сдвигаем. Под ним живой блюр нижнего бара: параллакс
  /// пересчитывал бы его на каждом кадре и давал фриз при открытии профиля,
  /// шторок и диалогов.
  static Widget buildSharedSlideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> _,
    Widget child,
  ) {
    if (shouldReduceMotion(context)) return child;
    return _PaykSharedSlide(animation: animation, child: child);
  }

  /// Композиторный переход `Fade + Scale(0.96 -> 1.0)` для корневых состояний.
  /// Нижний экран остаётся на месте, чтобы не гонять блюр на каждом кадре.
  static Widget buildFadeScaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> _,
    Widget child,
  ) {
    if (shouldReduceMotion(context)) return child;
    return _PaykFadeScale(animation: animation, child: child);
  }
}

/// Кривые создаются один раз. `buildTransitions` вызывается на каждом кадре,
/// и новый [CurvedAnimation] там навсегда подписывался на маршрут.
class _PaykSharedSlide extends StatefulWidget {
  const _PaykSharedSlide({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_PaykSharedSlide> createState() => _PaykSharedSlideState();
}

class _PaykSharedSlideState extends State<_PaykSharedSlide> {
  late CurvedAnimation _primary;
  late CurvedAnimation _fadeCurve;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bind(widget.animation);
  }

  void _bind(Animation<double> animation) {
    _primary = CurvedAnimation(
      parent: animation,
      curve: PaykMotion.easeOut,
      reverseCurve: PaykMotion.easeOut,
    );
    _fadeCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.8, curve: PaykMotion.easeOut),
      reverseCurve: const Interval(0.2, 1.0, curve: PaykMotion.easeOut),
    );
    _fade = Tween<double>(begin: 0.01, end: 1).animate(_fadeCurve);
    _slide = Tween<Offset>(
      begin: const Offset(0.065, 0),
      end: Offset.zero,
    ).animate(_primary);
    _scale = Tween<double>(begin: 0.985, end: 1).animate(_primary);
  }

  @override
  void didUpdateWidget(covariant _PaykSharedSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _release();
      _bind(widget.animation);
    }
  }

  void _release() {
    _primary.dispose();
    _fadeCurve.dispose();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

class _PaykFadeScale extends StatefulWidget {
  const _PaykFadeScale({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_PaykFadeScale> createState() => _PaykFadeScaleState();
}

class _PaykFadeScaleState extends State<_PaykFadeScale> {
  late CurvedAnimation _primary;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bind(widget.animation);
  }

  void _bind(Animation<double> animation) {
    _primary = CurvedAnimation(
      parent: animation,
      curve: PaykMotion.easeOut,
      reverseCurve: PaykMotion.easeOut,
    );
    _fade = Tween<double>(begin: 0.01, end: 1).animate(_primary);
    _scale = Tween<double>(
      begin: PaykMotion.entranceScale,
      end: 1,
    ).animate(_primary);
  }

  @override
  void didUpdateWidget(covariant _PaykFadeScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _primary.dispose();
      _bind(widget.animation);
    }
  }

  @override
  void dispose() {
    _primary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Строитель переходов страниц для `ThemeData.pageTransitionsTheme`.
class PaykPageTransitionsBuilder extends PageTransitionsBuilder {
  const PaykPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return PaykMotion.buildSharedSlideTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Высокопроизводительный прерываемый (interruptible) обёрточный виджет нажатия
/// по Рецепту №1 Emil Kowalski (`transform: scale(0.97)` за `80ms` на сжатие и `150ms` `ease-out` на возврат).
///
/// - Работает исключительно на GPU (`Transform.scale`), не вызывая пересчёта layout.
/// - Использует `Listener` для отслеживания касаний, поэтому НЕ блокирует и не конфликтует
///   с внутренними `InkWell`, `FilledButton`, `OutlinedButton` или `IconButton`.
/// - При передаче `onTap` также может самостоятельно обрабатывать нажатие.
/// - При скролле пальцем (сдвиг > `kTouchSlop`) автоматически плавно отменяет сжатие.
class PaykPressable extends StatefulWidget {
  const PaykPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.scaleDown = PaykMotion.scaleButton,
    this.haptic = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double scaleDown;
  final bool haptic;

  @override
  State<PaykPressable> createState() => _PaykPressableState();
}

class _PaykPressableState extends State<PaykPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PaykMotion.pressDown,
    reverseDuration: PaykMotion.pressUp,
    value: 0.0,
  );

  Offset? _downPosition;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _downPosition = event.position;
    if (PaykMotion.shouldReduceMotion(context)) return;
    _controller.animateTo(
      1.0,
      duration: PaykMotion.pressDown,
      curve: PaykMotion.easeOut,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _downPosition;
    if (start == null) return;
    if ((event.position - start).distance > 18.0) {
      _downPosition = null;
      _release();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _downPosition = null;
    _release();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _downPosition = null;
    _release();
  }

  void _release() {
    if (!mounted) return;
    if (_controller.value == 0.0 && !_controller.isAnimating) return;
    _controller.animateBack(
      0.0,
      duration: PaykMotion.pressUp,
      curve: PaykMotion.easeOut,
    );
  }

  void _handleTap() {
    if (!widget.enabled) return;
    if (widget.haptic) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget current = widget.child;

    if (widget.onTap != null) {
      current = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _handleTap : null,
        child: current,
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedBuilder(
        animation: _controller,
        child: current,
        builder: (context, child) {
          final t = _controller.value;
          final scale = 1.0 - (1.0 - widget.scaleDown) * t;
          return Transform.scale(scale: scale, child: child);
        },
      ),
    );
  }
}
