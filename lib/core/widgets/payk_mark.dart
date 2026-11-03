import 'package:flutter/material.dart';

class PaykMark extends StatelessWidget {
  const PaykMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/payk_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Payk',
    );
  }
}

/// Буква знака — водяной знак на карте статуса.
class PaykGlyph extends StatelessWidget {
  const PaykGlyph({super.key, this.color = const Color(0x1FFFFFFF)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GlyphPainter(color),
      child: const SizedBox.expand(),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.color);

  final Color color;
  static final Path _path = _svgPath(_glyph);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(452, 586, 410, 384);
    final fitted = applyBoxFit(BoxFit.contain, bounds.size, size);
    final dest = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    final transform = Matrix4.identity()
      ..translateByDouble(dest.left, dest.top, 0, 1)
      ..scaleByDouble(dest.width / bounds.width, dest.height / bounds.height, 1, 1)
      ..translateByDouble(-bounds.left, -bounds.top, 0, 1);
    canvas.drawPath(_path.transform(transform.storage), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) => oldDelegate.color != color;
}

Path _svgPath(String source) {
  final path = Path();
  final tokens = RegExp(r'[MLCZ]|-?\d*\.?\d+').allMatches(source).map((match) => match.group(0)!);
  final list = tokens.toList();
  var index = 0;
  var command = '';
  while (index < list.length) {
    final token = list[index];
    if (RegExp(r'^[MLCZ]$').hasMatch(token)) {
      command = token;
      index++;
      if (command == 'Z') path.close();
      continue;
    }
    double next() => double.parse(list[index++]);
    switch (command) {
      case 'M':
        path.moveTo(next(), next());
      case 'L':
        path.lineTo(next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      default:
        index++;
    }
  }
  return path;
}

const _glyph =
    'M502.59,963.18C493.53,963.18 484.47,963.20 475.41,963.18C461.63,963.14 456.77,957.16 459.79,943.94C465.31,919.81 470.86,895.69 476.41,871.57C492.54,801.47 508.73,731.38 524.80,661.27C533.85,621.80 569.31,593.31 609.76,593.25C623.47,593.23 637.18,593.18 650.89,593.27C667.53,593.37 675.73,603.54 672.03,619.62C651.51,708.89 630.54,798.06 610.64,887.46C604.56,914.79 591.73,936.41 567.84,951.17C554.94,959.13 540.93,963.51 525.60,963.21C517.93,963.05 510.26,963.18 502.59,963.18ZM717.21,814.51C706.52,814.51 695.83,814.55 685.14,814.50C672.35,814.44 667.32,808.34 670.15,795.88C675.84,770.85 681.75,745.86 687.51,720.84C695.60,685.68 703.68,650.51 711.70,615.33C715.45,598.84 722.26,593.36 739.40,593.36C758.22,593.36 777.05,593.20 795.87,593.40C832.55,593.79 855.53,621.92 847.82,657.54C841.17,688.29 834.14,718.96 826.59,749.49C817.18,787.55 782.19,814.41 743.00,814.51C734.40,814.53 725.81,814.51 717.21,814.51Z';

class PaykWordmark extends StatelessWidget {
  const PaykWordmark({super.key, this.width = 240});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/payk_logo.png',
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'Payk',
    );
  }
}
