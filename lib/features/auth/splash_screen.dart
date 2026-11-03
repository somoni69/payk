import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/payk_colors.dart';
import '../../data/providers.dart';

final splashFinishedProvider = NotifierProvider<SplashGate, bool>(SplashGate.new);

class SplashGate extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() {
    if (!state) state = true;
  }
}

/// Первый кадр запуска: знак держится, затем уходит вниз, на его месте «PAYK».
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  static const _ease = Cubic(0.23, 1, 0.32, 1);

  late final AnimationController _motion;
  var _left = false;

  @override
  void initState() {
    super.initState();
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _motion = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: reduce ? 1 : 1680),
    );
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.completed) _tryLeave();
    });
    _motion.forward();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _tryLeave() {
    if (_left || !mounted || !_motion.isCompleted) return;
    if (!ref.read(sessionProvider).ready) return;
    _left = true;
    ref.read(splashFinishedProvider.notifier).complete();
  }

  double _span(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return _ease.transform((t - start) / (end - start));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (next.ready) _tryLeave();
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: PaykColors.logo,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: PaykColors.logo,
        body: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
            final t = _motion.value;
            final handoff = _span(t, 0.28, 0.62);
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: 1 - handoff,
                  child: Transform.translate(
                    offset: Offset(0, 80 * handoff),
                    child: const _Mark(),
                  ),
                ),
                Opacity(
                  opacity: handoff,
                  child: Transform.scale(
                    scale: lerpDouble(1.06, 1, handoff)!,
                    child: const _Word(),
                  ),
                ),
              ],
            );
            },
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/payk_icon.png',
      width: 260,
      height: 260,
      fit: BoxFit.contain,
      semanticLabel: 'PAYK',
    );
  }
}

class _Word extends StatelessWidget {
  const _Word();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/payk_word_white.png',
      width: 232,
      fit: BoxFit.contain,
      semanticLabel: 'PAYK',
    );
  }
}
