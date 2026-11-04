import 'package:flutter/material.dart';

import '../theme/payk_colors.dart';
import 'shimmer.dart';

const _headerBone = Color(0x38FFFFFF);
const _headerShine = Color(0xA6FFFFFF);

/// Главная: шапка, карта статуса, приглашение, переключатель, магазины.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: ClampingScrollPhysics(),
        children: [
          _HomeHeaderBones(),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _LoyaltyCardBones(),
          ),
          SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _InviteBones(),
          ),
          SizedBox(height: 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _ToggleBones(),
          ),
          SizedBox(height: 20),
          _StoresBones(),
          SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _HomeHeaderBones extends StatelessWidget {
  const _HomeHeaderBones();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: PaykColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(PaykRadius.header)),
      ),
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            children: [
              Row(
                children: [
                  SkeletonBox(width: 48, height: 48, circle: true, color: _headerBone, highlight: _headerShine),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 148, height: 14, radius: 6, color: _headerBone, highlight: _headerShine),
                        SizedBox(height: 6),
                        SkeletonBox(width: 96, height: 11, radius: 6, color: _headerBone, highlight: _headerShine),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  SkeletonBox(width: 42, height: 42, radius: 14, color: _headerBone, highlight: _headerShine),
                  SizedBox(width: 8),
                  SkeletonBox(width: 42, height: 42, radius: 14, color: _headerBone, highlight: _headerShine),
                ],
              ),
              SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    SkeletonBox(width: 108, height: 114, radius: 18, color: _headerBone, highlight: _headerShine),
                    SizedBox(width: 10),
                    SkeletonBox(width: 108, height: 114, radius: 18, color: _headerBone, highlight: _headerShine),
                    SizedBox(width: 10),
                    SkeletonBox(width: 108, height: 114, radius: 18, color: _headerBone, highlight: _headerShine),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoyaltyCardBones extends StatelessWidget {
  const _LoyaltyCardBones();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
      padding: const EdgeInsets.fromLTRB(22, 18, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF4A5164),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 18, height: 22, radius: 4, color: _headerBone, highlight: _headerShine),
              SizedBox(width: 8),
              SkeletonBox(width: 64, height: 14, radius: 6, color: _headerBone, highlight: _headerShine),
              Spacer(),
              SkeletonBox(width: 92, height: 30, radius: 16, color: _headerBone, highlight: _headerShine),
            ],
          ),
          Spacer(),
          SkeletonBox(width: 72, height: 12, radius: 6, color: _headerBone, highlight: _headerShine),
          SizedBox(height: 8),
          SkeletonBox(width: 168, height: 32, radius: 8, color: _headerBone, highlight: _headerShine),
          Spacer(),
          Row(
            children: [
              SkeletonBox(width: 132, height: 12, radius: 6, color: _headerBone, highlight: _headerShine),
              Spacer(),
              SkeletonBox(width: 72, height: 12, radius: 6, color: _headerBone, highlight: _headerShine),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteBones extends StatelessWidget {
  const _InviteBones();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      fill: Color(0xFFF6F5FB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 220, height: 16, radius: 6),
          SizedBox(height: 8),
          SkeletonBox(width: 160, height: 16, radius: 6),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 50, radius: 16)),
              SizedBox(width: 10),
              SkeletonBox(width: 50, height: 50, radius: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleBones extends StatelessWidget {
  const _ToggleBones();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      fill: Color(0xFFF6F5FB),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: SkeletonBox(height: 14, radius: 6)),
          SizedBox(width: 16),
          SkeletonBox(width: 48, height: 28, radius: 14),
        ],
      ),
    );
  }
}

class _StoresBones extends StatelessWidget {
  const _StoresBones();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SkeletonBox(width: 110, height: 18, radius: 6),
              Spacer(),
              SkeletonBox(width: 64, height: 28, radius: 10),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20),
            children: [
              SkeletonCard(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 212,
                  child: Row(
                    children: [
                      SkeletonBox(width: 48, height: 48, radius: 14),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 96, height: 13, radius: 6),
                            SizedBox(height: 8),
                            SkeletonBox(height: 11, radius: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              SkeletonCard(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 180,
                  child: Row(
                    children: [
                      SkeletonBox(width: 48, height: 48, radius: 14),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 13, radius: 6)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Вкладка профиля: шапка, способы входа, баннер, меню.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 104),
        physics: ClampingScrollPhysics(),
        children: [
          SkeletonCard(
            child: Row(
              children: [
                SkeletonBox(width: 54, height: 54, circle: true),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 16, radius: 6),
                      SizedBox(height: 8),
                      SkeletonBox(width: 88, height: 12, radius: 6),
                    ],
                  ),
                ),
                SkeletonBox(width: 18, height: 18, radius: 6),
              ],
            ),
          ),
          SizedBox(height: 12),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 140, height: 16, radius: 6),
                    Spacer(),
                    SkeletonBox(width: 52, height: 14, radius: 6),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, circle: true),
                    SizedBox(width: 12),
                    SkeletonBox(width: 40, height: 40, circle: true),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          SkeletonBox(height: 96, radius: 16),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonBox(width: 24, height: 6, radius: 3),
              SizedBox(width: 6),
              SkeletonBox(width: 6, height: 6, circle: true),
            ],
          ),
          SizedBox(height: 16),
          _MenuBone(wide: true),
          _MenuBone(),
          _MenuBone(),
          _MenuBone(),
          _MenuBone(),
          _MenuBone(wide: true),
          _MenuBone(),
          _MenuBone(),
          SizedBox(height: 12),
          _ToggleBones(),
        ],
      ),
    );
  }
}

class _MenuBone extends StatelessWidget {
  const _MenuBone({this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          const SkeletonBox(width: 24, height: 24, radius: 6),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: wide ? 180 : 140, height: 14, radius: 6),
                if (wide) ...[
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 96, height: 11, radius: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Детали профиля: аватар, пользователь, контакты, вход, удаление.
class ProfileDetailsSkeleton extends StatelessWidget {
  const ProfileDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 96),
        physics: ClampingScrollPhysics(),
        children: [
          SkeletonCard(
            child: Row(
              children: [
                SkeletonBox(width: 56, height: 56, circle: true),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 170, height: 16, radius: 6),
                      SizedBox(height: 8),
                      SkeletonBox(width: 130, height: 13, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          _InfoCardBones(rows: 3),
          SizedBox(height: 14),
          _InfoCardBones(rows: 2),
          SizedBox(height: 14),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 16, radius: 6),
                SizedBox(height: 14),
                Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, circle: true),
                    SizedBox(width: 12),
                    SkeletonBox(width: 40, height: 40, circle: true),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160, height: 16, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 180, height: 13, radius: 6),
                SizedBox(height: 14),
                SkeletonBox(height: 46, radius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCardBones extends StatelessWidget {
  const _InfoCardBones({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Column(
        children: [
          const Row(
            children: [
              SkeletonBox(width: 120, height: 16, radius: 6),
              Spacer(),
              SkeletonBox(width: 72, height: 14, radius: 6),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            const Row(
              children: [
                SkeletonBox(width: 110, height: 13, radius: 6),
                Spacer(),
                SkeletonBox(width: 88, height: 13, radius: 6),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Покупки: поиск, сетка категорий, строки операций.
class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
        physics: const ClampingScrollPhysics(),
        children: [
          const SkeletonBox(height: 52, radius: 16, color: PaykColors.surfaceNested),
          const SizedBox(height: 20),
          const SkeletonBox(width: 140, height: 18, radius: 6),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: _CategoryBone()),
              SizedBox(width: 8),
              Expanded(child: _CategoryBone()),
              SizedBox(width: 8),
              Expanded(child: _CategoryBone()),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(child: _CategoryBone()),
              SizedBox(width: 8),
              Expanded(child: _CategoryBone()),
              SizedBox(width: 8),
              Expanded(child: _CategoryBone()),
            ],
          ),
          const SizedBox(height: 20),
          SkeletonCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const Divider(height: 1, color: PaykColors.border),
                  const _HistoryRowBone(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBone extends StatelessWidget {
  const _CategoryBone();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
      decoration: BoxDecoration(
        color: PaykColors.surfaceNested,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 64, height: 12, radius: 6),
          Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: SkeletonBox(width: 36, height: 36, radius: 10),
          ),
        ],
      ),
    );
  }
}

class _HistoryRowBone extends StatelessWidget {
  const _HistoryRowBone();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SkeletonBox(width: 42, height: 42, circle: true),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 14, radius: 6),
                SizedBox(height: 6),
                SkeletonBox(width: 168, height: 12, radius: 6),
              ],
            ),
          ),
          SizedBox(width: 8),
          SkeletonBox(width: 64, height: 16, radius: 6),
        ],
      ),
    );
  }
}

/// Друзья: баннер с кодом, сетка статистики, список.
class FriendsSkeleton extends StatelessWidget {
  const FriendsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 104),
        physics: ClampingScrollPhysics(),
        children: [
          SkeletonCard(
            padding: EdgeInsets.zero,
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ColoredBox(
                  color: Color(0xFF4C40E6),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 160, height: 18, radius: 6, color: _headerBone, highlight: _headerShine),
                              SizedBox(height: 10),
                              SkeletonBox(height: 12, radius: 6, color: _headerBone, highlight: _headerShine),
                              SizedBox(height: 6),
                              SkeletonBox(width: 120, height: 12, radius: 6, color: _headerBone, highlight: _headerShine),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        SkeletonBox(width: 72, height: 72, radius: 16, color: _headerBone, highlight: _headerShine),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 110, height: 12, radius: 6),
                      SizedBox(height: 8),
                      SkeletonBox(height: 52, radius: 14),
                      SizedBox(height: 14),
                      SkeletonBox(height: 50, radius: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatBone()),
              SizedBox(width: 10),
              Expanded(child: _StatBone()),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _StatBone()),
              SizedBox(width: 10),
              Expanded(child: _StatBone()),
            ],
          ),
          SizedBox(height: 18),
          SkeletonBox(width: 150, height: 18, radius: 6),
          SizedBox(height: 10),
          SkeletonCard(
            padding: EdgeInsets.zero,
            radius: 20,
            child: Column(
              children: [
                _HistoryRowBone(),
                Divider(height: 1, color: PaykColors.border),
                _HistoryRowBone(),
                Divider(height: 1, color: PaykColors.border),
                _HistoryRowBone(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBone extends StatelessWidget {
  const _StatBone();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 88, height: 12, radius: 6),
          SizedBox(height: 10),
          SkeletonBox(width: 56, height: 20, radius: 6),
        ],
      ),
    );
  }
}

/// Уведомления: карточки с иконкой и двумя строками текста.
class NotificationsSkeleton extends StatelessWidget {
  const NotificationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 96),
        physics: ClampingScrollPhysics(),
        children: [
          _NoticeBone(),
          SizedBox(height: 12),
          _NoticeBone(),
          SizedBox(height: 12),
          _NoticeBone(),
          SizedBox(height: 12),
          _NoticeBone(),
        ],
      ),
    );
  }
}

class _NoticeBone extends StatelessWidget {
  const _NoticeBone();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 36, height: 36, radius: 10),
              SizedBox(width: 10),
              SkeletonBox(width: 96, height: 12, radius: 6),
              Spacer(),
              SkeletonBox(width: 8, height: 8, circle: true),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(height: 14, radius: 6),
          SizedBox(height: 8),
          SkeletonBox(width: 220, height: 14, radius: 6),
        ],
      ),
    );
  }
}

/// Правила: вводный текст и карточки статусов.
class RulesSkeleton extends StatelessWidget {
  const RulesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
        physics: ClampingScrollPhysics(),
        children: [
          SkeletonBox(height: 14, radius: 6),
          SizedBox(height: 8),
          SkeletonBox(width: 240, height: 14, radius: 6),
          SizedBox(height: 8),
          SkeletonBox(width: 180, height: 14, radius: 6),
          SizedBox(height: 18),
          _TierBone(),
          SizedBox(height: 12),
          _TierBone(),
          SizedBox(height: 12),
          _TierBone(),
          SizedBox(height: 12),
          _TierBone(),
        ],
      ),
    );
  }
}

class _TierBone extends StatelessWidget {
  const _TierBone();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      child: Column(
        children: [
          Row(
            children: [
              SkeletonBox(width: 88, height: 28, radius: 12),
              Spacer(),
              SkeletonBox(width: 72, height: 13, radius: 6),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 72, radius: 12)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 72, radius: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Настройки: язык и уведомления.
class SettingsSkeleton extends StatelessWidget {
  const SettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        physics: ClampingScrollPhysics(),
        children: [
          SkeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 36, height: 36, radius: 10),
                    SizedBox(width: 12),
                    SkeletonBox(width: 80, height: 16, radius: 6),
                  ],
                ),
                SizedBox(height: 14),
                SkeletonBox(height: 44, radius: 14),
              ],
            ),
          ),
          SizedBox(height: 14),
          SkeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 36, height: 36, radius: 10),
                    SizedBox(width: 12),
                    SkeletonBox(width: 140, height: 16, radius: 6),
                  ],
                ),
                SizedBox(height: 12),
                SkeletonBox(height: 13, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 200, height: 13, radius: 6),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 14, radius: 6)),
                    SizedBox(width: 16),
                    SkeletonBox(width: 48, height: 28, radius: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Способы входа: SMS и Telegram.
class ConnectSkeleton extends StatelessWidget {
  const ConnectSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView(
        padding: EdgeInsets.all(16),
        physics: ClampingScrollPhysics(),
        children: [
          _MethodBone(),
          SizedBox(height: 12),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MethodLine(),
                SizedBox(height: 16),
                SkeletonBox(height: 46, radius: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodBone extends StatelessWidget {
  const _MethodBone();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(child: _MethodLine());
  }
}

class _MethodLine extends StatelessWidget {
  const _MethodLine();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(width: 44, height: 44, radius: 12),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 90, height: 16, radius: 6),
              SizedBox(height: 6),
              SkeletonBox(width: 160, height: 12, radius: 6),
            ],
          ),
        ),
      ],
    );
  }
}

/// Код кассы: квадрат QR, цифры и строка таймера.
class CodeSkeleton extends StatelessWidget {
  const CodeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: SkeletonCard(
        radius: 24,
        padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            SkeletonBox(height: 272, radius: 20),
            SizedBox(height: 20),
            SkeletonBox(width: 160, height: 13, radius: 6),
            SizedBox(height: 10),
            SkeletonBox(width: 210, height: 36, radius: 8),
            SizedBox(height: 20),
            SkeletonBox(height: 62, radius: 16),
          ],
        ),
      ),
    );
  }
}

/// Регистрация: заголовок и поля анкеты.
class RegisterSkeleton extends StatelessWidget {
  const RegisterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      body: SafeArea(
        child: ShimmerSweep(
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
            physics: ClampingScrollPhysics(),
            children: [
              SkeletonBox(width: 200, height: 32, radius: 8),
              SizedBox(height: 12),
              SkeletonBox(height: 14, radius: 6),
              SizedBox(height: 8),
              SkeletonBox(width: 220, height: 14, radius: 6),
              SizedBox(height: 28),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 12),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 12),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 12),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 12),
              SkeletonBox(height: 54, radius: 16),
              SizedBox(height: 24),
              SkeletonBox(height: 54, radius: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.fill = PaykColors.sheet,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: PaykColors.border),
      ),
      child: child,
    );
  }
}
