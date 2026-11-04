import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Отдельный полноценный экран уведомлений и сообщений в стиле UDC / Payk
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loyaltyApiProvider).markMessagesRead().ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider);

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: PaykPressable(
          scaleDown: PaykMotion.scaleIcon,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: PaykColors.textPrimary,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.invalidate(meProvider);
              Navigator.of(context).maybePop();
            },
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Уведомления',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: PaykColors.textPrimary,
          ),
        ),
        actions: [
          PaykPressable(
            scaleDown: PaykMotion.scaleIcon,
            child: IconButton(
              icon: const Icon(
                Icons.done_all_rounded,
                color: PaykColors.primary,
                size: 22,
              ),
              tooltip: 'Прочитать все',
              onPressed: () async {
                HapticFeedback.lightImpact();
                await ref.read(loyaltyApiProvider).markMessagesRead();
                ref.invalidate(messagesProvider);
                ref.invalidate(meProvider);
              },
            ),
          ),
        ],
      ),
      body: AsyncView(
        value: messagesAsync,
        onRetry: () => ref.invalidate(messagesProvider),
        loading: const NotificationsSkeleton(),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Уведомлений пока нет',
                  body: 'Здесь будут появляться персональные акции, новости партнеров и начисления бонусов.',
                  actionLabel: 'На главную',
                  onAction: () {
                    ref.invalidate(meProvider);
                    Navigator.of(context).maybePop();
                  },
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _NotificationCard(item: items[index]),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final LoyaltyMessageItem item;

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.read;

    return AnimatedContainer(
      duration: PaykMotion.duration(context, PaykMotion.normal),
      curve: PaykMotion.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? Colors.white : PaykColors.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? PaykColors.primary.withValues(alpha: 0.35)
              : PaykColors.border,
          width: isUnread ? 1.2 : 1.0,
        ),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: PaykColors.primary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isUnread ? const Color(0xFFF3F0FC) : const Color(0xFFEFF0F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isUnread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: isUnread ? PaykColors.primary : PaykColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  formatDate(item.createdAt),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: PaykColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: PaykColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.text,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
              height: 1.4,
              color: PaykColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
