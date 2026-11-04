import 'package:flutter/material.dart';

import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../theme/payk_colors.dart';

/// Общий аватар главной и профиля: фото, если оно есть, иначе инициалы.
class PaykAvatar extends StatelessWidget {
  const PaykAvatar({
    super.key,
    required this.member,
    this.size = 48,
    this.ring = false,
    this.onAdd,
  });

  final Member member;
  final double size;
  final bool ring;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(member);
    final photo = resolvePaykAvatarUrl(member.avatarUrl);
    final face = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: PaykColors.headerGradient,
        border: ring ? Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2) : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: photo == null
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
              ),
            )
          : Image.network(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );

    if (onAdd == null) return face;

    final badge = size * 0.38;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          face,
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: Colors.white,
              elevation: 1,
              shadowColor: const Color(0x33000000),
              shape: const CircleBorder(side: BorderSide(color: PaykColors.primary, width: 1.5)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAdd,
                child: SizedBox(
                  width: badge,
                  height: badge,
                  child: Icon(Icons.add_rounded, size: badge * 0.72, color: PaykColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(Member member) {
  final first = member.firstName.trim();
  final last = member.lastName.trim();
  final letters = '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'.toUpperCase();
  return letters.isEmpty ? 'П' : letters;
}

String? resolvePaykAvatarUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final root = ApiConfig.root.replaceAll(RegExp(r'/+$'), '');
  return raw.startsWith('/') ? '$root$raw' : '$root/$raw';
}
