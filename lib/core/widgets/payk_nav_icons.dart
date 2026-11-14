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
        '<path d="M4.4 13.3C2.1 9.9 3.5 5.2 7.5 5.2c1.6 0 2.9.2 4 .4"/><path d="M19.3 11.9C21.6 9.1 20.3 4.8 16.3 4.8c-2.5 0-5.3.9-7.3 1.7-1 .4-1.1 1.7-.2 2.3.8.5 1.8.2 3.1-.6.5-.3 1-.2 1.5.1l5.9 3.6"/><path d="M19.3 11.9c1 .7.8 2.3-.7 3 .5.9-.3 2.1-1.7 2.1 0 1-1.1 1.6-2.4 1.3-.5.8-1.9.8-2.8.1"/><path d="M18.6 14.9 17 13.4M16.9 17l-1.6-1.5M14.5 18.3l-3.3-2.7"/><path d="M6 14.6 7.1 13.5a1.2 1.2 0 0 0-1.7-1.7L4.3 12.9a1.2 1.2 0 0 0 1.7 1.7Z"/><path d="M7.45 16.05 8.55 14.95a1.2 1.2 0 0 0-1.7-1.7l-1.1 1.1a1.2 1.2 0 0 0 1.7 1.7Z"/><path d="M8.9 17.5 9.95 16.45a1.2 1.2 0 0 0-1.7-1.7L7.2 15.8a1.2 1.2 0 0 0 1.7 1.7Z"/><path d="M10.3 18.85 11.15 18a1.15 1.15 0 0 0-1.63-1.63l-.85.85a1.15 1.15 0 0 0 1.63 1.63Z"/>',
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
