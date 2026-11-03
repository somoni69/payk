import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_mark.dart';
import '../../data/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with TickerProviderStateMixin {
  static const _pages = 5;
  static const _ease = Cubic(0.22, 1, 0.36, 1);

  static const _cards = <Widget>[
    _CashbackCard(),
    SizedBox.shrink(),
    _CashierCard(),
    _FriendsCard(),
    _EnterCard(),
  ];

  late final AnimationController _page = AnimationController.unbounded(vsync: this);
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.96,
    upperBound: 1,
    value: 1,
  );
  var _target = 0;

  @override
  void dispose() {
    _page.dispose();
    _press.dispose();
    super.dispose();
  }

  void _go(int index) {
    final next = index.clamp(0, _pages - 1);
    if (next == _target && (_page.value - next).abs() < 0.02) return;
    setState(() => _target = next);
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      _page.value = next.toDouble();
      return;
    }
    _page.animateTo(next.toDouble(), duration: const Duration(milliseconds: 440), curve: _ease);
  }

  Future<void> _finish() async {
    HapticFeedback.selectionClick();
    await ref.read(sessionProvider.notifier).finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _page,
                builder: (context, _) => _TopBar(
                  page: _page.value,
                  canBack: _target > 0,
                  onBack: () => _go(_target - 1),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedBuilder(
                  animation: _page,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        for (var i = 0; i < _pages; i++)
                          _Layer(
                            delta: _page.value - i,
                            child: i == 1 ? _StatusCard(playing: (_page.value - 1).abs() < 0.6) : _cards[i],
                          ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(
                height: 148,
                child: AnimatedBuilder(
                  animation: _page,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        for (var i = 0; i < _pages; i++)
                          _Layer(
                            delta: _page.value - i,
                            child: _Copy(
                              title: tr(locale, 'onboard.${i + 1}.title'),
                              body: tr(locale, 'onboard.${i + 1}.body'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTapDown: (_) => _press.reverse(),
                onTapCancel: () => _press.forward(),
                onTapUp: (_) {
                  _press.forward();
                  if (_target >= _pages - 1) {
                    _finish();
                  } else {
                    _go(_target + 1);
                  }
                },
                child: ScaleTransition(
                  scale: _press,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: PaykColors.violet,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          tr(locale, _target >= _pages - 1 ? 'onboard.start' : 'onboard.next'),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.page, required this.canBack, required this.onBack});

  final double page;
  final bool canBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Opacity(
          opacity: canBack ? 1 : 0.35,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: canBack ? onBack : null,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 6.0;
              final width = (constraints.maxWidth - gap * 4) / 5;
              return SizedBox(
                height: 4,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < 5; i++) ...[
                          if (i > 0) const SizedBox(width: gap),
                          Container(
                            width: width,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE4E2EA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Transform.translate(
                      offset: Offset(page.clamp(0, 4) * (width + gap), 0),
                      child: Container(
                        width: width,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PaykColors.violet,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Layer extends StatelessWidget {
  const _Layer({required this.delta, required this.child});

  final double delta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final distance = delta.abs();
    if (distance > 1.05) return const SizedBox.shrink();
    final raw = (1 - distance).clamp(0.0, 1.0);
    final visibility = const Cubic(0.22, 1, 0.36, 1).transform(raw);
    return IgnorePointer(
      child: Opacity(
        opacity: visibility,
        child: Transform.translate(
          offset: Offset(-delta * 56, distance * 12),
          child: child,
        ),
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.4),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600, height: 1.35),
        ),
      ],
    );
  }
}

class _CashbackCard extends StatelessWidget {
  const _CashbackCard();

  @override
  Widget build(BuildContext context) {
    return const _LoyaltyFace(
      status: 'Стандарт',
      chip: '+2%',
      colors: [Color(0xFF2A3040), Color(0xFF4E5668), Color(0xFF6A7386)],
      ink: Colors.white,
      soft: Color(0xCCFFFFFF),
      code: Color(0xD9FFFFFF),
      mark: Color(0x22FFFFFF),
      pillFill: Color(0x33FFFFFF),
      pillInk: Colors.white,
      shadow: Color(0x402A3040),
    );
  }
}

class _StatusCard extends StatefulWidget {
  const _StatusCard({required this.playing});

  final bool playing;

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  static const _hold = Duration(seconds: 4);
  static const _ease = Cubic(0.23, 1, 0.32, 1);
  static const _faces = <Widget>[
    _LoyaltyFace(
      key: ValueKey('silver'),
      status: 'Силвер',
      chip: '+4%',
      from: 'от 1 800 смн',
      clothes: 'Либос 10%',
      colors: [Color(0xFFF7F9FC), Color(0xFFE4E9F0), Color(0xFFC5CEDA)],
      ink: Color(0xFF1E2633),
      soft: Color(0xFF5A6576),
      code: Color(0xFF3A4556),
      mark: Color(0x221E2633),
      pillFill: Color(0xB3FFFFFF),
      pillInk: Color(0xFF1E2633),
      shadow: Color(0x332A3544),
    ),
    _LoyaltyFace(
      key: ValueKey('gold'),
      status: 'Голд',
      chip: '+6%',
      from: 'от 4 000 смн',
      clothes: 'Либос 15%',
      colors: PaykColors.tierGold,
      ink: Color(0xFF3A2A08),
      soft: Color(0xFF5C4510),
      code: Color(0xFF4A3810),
      mark: Color(0x333A2A08),
      pillFill: Color(0xB3FFFFFF),
      pillInk: Color(0xFF3A2A08),
      shadow: Color(0x40E8B423),
    ),
    _LoyaltyFace(
      key: ValueKey('diamond'),
      status: 'Алмаз',
      chip: '+8%',
      from: 'от 10 000 смн',
      clothes: 'Либос 20%',
      colors: [Color(0xFF6248EE), Color(0xFF372CD2), Color(0xFF261E9A)],
      ink: Colors.white,
      soft: Color(0xE6FFFFFF),
      code: Color(0xD9FFFFFF),
      mark: Color(0x24FFFFFF),
      pillFill: Color(0x33000000),
      pillInk: Colors.white,
      shadow: Color(0x40372CD2),
    ),
  ];

  var _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _StatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) return;
    if (widget.playing) _index = 0;
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (!widget.playing) return;
    _timer = Timer.periodic(_hold, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _faces.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final face = _faces[_index];
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
            switchInCurve: _ease,
            switchOutCurve: _ease,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) {
              final incoming = child.key == face.key;
              return AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (context, child) {
                  final t = animation.value;
                  final dy = (1 - t) * (incoming ? 16.0 : -14.0);
                  return Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(offset: Offset(0, dy), child: child),
                  );
                },
              );
            },
            child: face,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _faces.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: i == _index ? PaykColors.violet : const Color(0xFFD5D2DE),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 6, height: 6),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LoyaltyFace extends StatelessWidget {
  const _LoyaltyFace({
    super.key,
    required this.status,
    required this.chip,
    required this.colors,
    required this.ink,
    required this.soft,
    required this.code,
    required this.mark,
    required this.pillFill,
    required this.pillInk,
    required this.shadow,
    this.from = '',
    this.clothes = '',
  });

  final String status;
  final String chip;
  final String from;
  final String clothes;
  final List<Color> colors;
  final Color ink;
  final Color soft;
  final Color code;
  final Color mark;
  final Color pillFill;
  final Color pillInk;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: clothes.isEmpty ? '$status, $chip' : '$status, супермаркет $chip, $clothes, $from',
      child: SizedBox(
        width: 280,
        height: 240,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8,
              right: 20,
              top: 28,
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                    boxShadow: [BoxShadow(color: shadow, blurRadius: 22, offset: const Offset(0, 14))],
                  ),
                  child: Stack(
                    children: [
                      Positioned(right: -8, bottom: -18, child: SizedBox(width: 92, height: 92, child: PaykGlyph(color: mark))),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const PaykMark(size: 30),
                              const SizedBox(width: 8),
                              Text('ПАЙК', style: TextStyle(color: ink, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                              const Spacer(),
                              _Pill(status, fill: pillFill, ink: pillInk),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Text('Баланс', style: TextStyle(color: soft, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('0,00 смн', style: TextStyle(color: ink, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.05)),
                          if (clothes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(clothes, style: TextStyle(color: soft, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text('SO-4654', style: TextStyle(color: code, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                              const Spacer(),
                              if (from.isNotEmpty) Text(from, style: TextStyle(color: soft, fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(top: 8, right: 0, child: _Chip(chip, PaykColors.violet)),
          ],
        ),
      ),
    );
  }
}

class _CashierCard extends StatelessWidget {
  const _CashierCard();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: SizedBox(
        width: 236,
        child: DecoratedBox(
          decoration: _sheet,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QrMark(),
                SizedBox(height: 14),
                Text('4455 5802', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                SizedBox(height: 4),
                Text('обновится через 39 с', style: TextStyle(color: PaykColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendsCard extends StatelessWidget {
  const _FriendsCard();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Node('М1', 'Вы', true),
              _Link(),
              _Node('М2', 'Друг', false),
              _Link(),
              _Node('М3', 'Его друг', false),
            ],
          ),
          SizedBox(height: 18),
          _Chip('1% · 12 месяцев', PaykColors.violet),
        ],
      ),
    );
  }
}

class _EnterCard extends StatelessWidget {
  const _EnterCard();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: SizedBox(
        width: 260,
        child: DecoratedBox(
          decoration: _sheet,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Телефон', style: TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFF3F1F8), borderRadius: BorderRadius.all(Radius.circular(14))),
                  child: SizedBox(
                    height: 50,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('+992 XX XXX XX XX', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.4)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(color: PaykColors.violet, borderRadius: BorderRadius.all(Radius.circular(14))),
                  child: SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: Center(child: Text('Получить код', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _sheet = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(26)),
  boxShadow: [BoxShadow(color: Color(0x1A1A1D29), blurRadius: 18, offset: Offset(0, 10))],
);

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.fill, required this.ink});

  final String text;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(text, style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x406C4DFF), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node(this.code, this.label, this.filled);

  final String code;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: filled ? PaykColors.violet : Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x141A1D29), blurRadius: 10, offset: Offset(0, 5))],
          ),
          child: SizedBox(
            width: 58,
            height: 58,
            child: Center(
              child: Text(
                code,
                style: TextStyle(fontWeight: FontWeight.w800, color: filled ? Colors.white : PaykColors.ink),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PaykColors.muted)),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(6, 20, 6, 0),
      child: Icon(Icons.arrow_forward_rounded, size: 16, color: PaykColors.muted),
    );
  }
}

class _QrMark extends StatelessWidget {
  const _QrMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 120, height: 120, child: CustomPaint(painter: _QrPainter()));
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter();

  static const _cells = [
    '11111110101',
    '10000010111',
    '10111010001',
    '10111010111',
    '10111010000',
    '10000010101',
    '11111110111',
    '00000001010',
    '11011110101',
    '00100011110',
    '11101101011',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1C1C1E);
    final cell = size.width / _cells.length;
    for (var y = 0; y < _cells.length; y++) {
      for (var x = 0; x < _cells[y].length; x++) {
        if (_cells[y][x] != '1') continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * cell + 0.7, y * cell + 0.7, cell - 1.4, cell - 1.4),
            const Radius.circular(1.6),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

