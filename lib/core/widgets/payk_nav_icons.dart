import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PaykNavIconType {
  home,
  history,
  friends,
  profile,
}

class PaykNavIcon extends StatelessWidget {
  const PaykNavIcon({
    super.key,
    required this.type,
    required this.color,
    this.size = 25.0,
    this.strokeWidth = 2.0,
  });

  final PaykNavIconType type;
  final Color color;
  final double size;
  final double strokeWidth;

  static const _paths = {
    PaykNavIconType.home:
        '<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/><path d="M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    PaykNavIconType.history:
        '<path d="M21 6H3"/><path d="M10 12H3"/><path d="M10 18H3"/><circle cx="17" cy="15" r="3"/><path d="m21 19-1.9-1.9"/>',
    PaykNavIconType.friends:
        '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/><path d="M12 5 9.04 7.96a2.17 2.17 0 0 0 0 3.08c.82.82 2.13.85 3 .07l2.07-1.9a2.82 2.82 0 0 1 3.79 0l2.96 2.66"/><path d="m18 15-2-2"/><path d="m15 18-2-2"/>',
    PaykNavIconType.profile:
        '<circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" x2="9.01" y1="9" y2="9"/><line x1="15" x2="15.01" y1="9" y2="9"/>',
  };

  @override
  Widget build(BuildContext context) {
    final inner = _paths[type]!;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">$inner</svg>';

    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
