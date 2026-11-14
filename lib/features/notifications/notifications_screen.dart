import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../sizes/size_offers_screen.dart';

/// Отдельный полноценный экран уведомлений и сообщений в стиле UDC / Payk
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<LoyaltyMessageItem> _extraItems = <LoyaltyMessageItem>[];
  bool _loadingMore = false;
  bool? _hasMoreOverride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loyaltyApiProvider).markMessagesRead().ignore();
    });
  }

  Future<void> _loadMore(List<LoyaltyMessageItem> all) async {
    if (_loadingMore || all.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(loyaltyApiProvider)
          .messages(beforeId: all.last.id);
      if (!mounted) return;
      final existingIds = {for (final item in all) item.id};
      final fresh = page.where((item) => !existingIds.contains(item.id)).toList();
      setState(() {
        _extraItems.addAll(fresh);
        _hasMoreOverride = page.length >= 30;
      });
    } catch (_) {
      // Игнорируем сбой догрузки; пользователь может нажать снова
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _extraItems.clear();
      _hasMoreOverride = null;
    });
    ref.invalidate(messagesProvider);
    try {
      await ref.read(messagesProvider.future);
    } catch (_) {}
  }

  void _openOffers(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push('/size-offers');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SizeOffersScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
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
        title: Text(
          tr(locale, 'home.notifications'),
          style: const TextStyle(
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
                if (!mounted) return;
                setState(() {
                  _extraItems.clear();
                  _hasMoreOverride = null;
                });
                ref.invalidate(messagesProvider);
                ref.invalidate(meProvider);
              },
            ),
          ),
        ],
      ),
      body: AsyncView(
        value: messagesAsync,
        onRetry: _refresh,
        loading: const NotificationsSkeleton(),
        data: (headItems) {
          final seen = <int>{};
          final all = <LoyaltyMessageItem>[];
          for (final item in [...headItems, ..._extraItems]) {
            if (seen.add(item.id)) all.add(item);
          }

          if (all.isEmpty) {
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

          final hasMore = _hasMoreOverride ?? (headItems.length >= 30);

          return RefreshIndicator(
            color: PaykColors.violet,
            backgroundColor: Colors.white,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: all.length + (hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index >= all.length) {
                  return Center(
                    child: OutlinedButton(
                      onPressed: _loadingMore ? null : () => _loadMore(all),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PaykColors.primary,
                        side: const BorderSide(color: PaykColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _loadingMore
                            ? tr(locale, 'history.loading')
                            : tr(locale, 'history.more'),
                      ),
                    ),
                  );
                }
                return _NotificationCard(
                  item: all[index],
                  locale: locale,
                  onOpenOffers: () => _openOffers(context),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.locale,
    required this.onOpenOffers,
  });

  final LoyaltyMessageItem item;
  final String locale;
  final VoidCallback onOpenOffers;

  String _kindTitle() {
    final key = 'messages.kind.${item.kind}';
    final resolved = tr(locale, key);
    if (resolved != key) return resolved;
    return tr(locale, 'messages.kind.other');
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.read;
    final hasOffersLink = item.kind == 'size_flash' || item.kind == 'size_new';

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
                  hasOffersLink
                      ? Icons.local_offer_outlined
                      : (isUnread
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded),
                  color: isUnread ? PaykColors.primary : PaykColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kindTitle(),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: PaykColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      formatDate(item.createdAt),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: PaykColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
          if (hasOffersLink) ...[
            const SizedBox(height: 12),
            PaykPressable(
              scaleDown: PaykMotion.scaleButton,
              onTap: onOpenOffers,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: PaykColors.activePill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(locale, 'messages.openOffers'),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PaykColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: PaykColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
