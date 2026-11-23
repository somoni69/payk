import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_3d_icon.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../history/receipt_detail_screen.dart';
import '../sizes/size_offers_screen.dart';

/// Отдельный полноценный экран уведомлений и сообщений в стиле UDC / Payk
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.nowProvider});

  /// Опциональный источник текущего времени (удобно для детерминированных тестов).
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<LoyaltyMessageItem> _extraItems = <LoyaltyMessageItem>[];
  final Set<int> _locallyReadIds = <int>{};
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
      _locallyReadIds.clear();
      _hasMoreOverride = null;
    });
    ref.invalidate(messagesProvider);
    try {
      await ref.read(messagesProvider.future);
    } catch (_) {}
  }

  void _openOffers(BuildContext context) {
    PaykMotion.push<void>(
      context,
      '/size-offers',
      fallback: () => const SizeOffersScreen(),
    );
  }

  void _openReceipt(BuildContext context, LoyaltyMessageItem item) {
    final billId = item.billId;
    if (billId == null) return;
    HapticFeedback.lightImpact();

    if (!item.read && !_locallyReadIds.contains(item.id)) {
      setState(() => _locallyReadIds.add(item.id));
      ref
          .read(loyaltyApiProvider)
          .markMessageRead(item.id)
          .then((_) {
            if (mounted) ref.invalidate(meProvider);
          })
          .catchError((_) {});
    }

    final focusReturns = item.kind == 'purchase_return';
    final path =
        '/history/receipt/$billId${focusReturns ? '?focus=returns' : ''}';
    PaykMotion.push<void>(
      context,
      path,
      fallback: () => ReceiptDetailScreen(
        receiptId: billId,
        focusReturns: focusReturns,
      ),
    );
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
            fontFamily: 'Inter',
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
                  _locallyReadIds.clear();
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
                  iconWidget: const Bell3dIcon(size: 46),
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
          final now = (widget.nowProvider ?? DateTime.now)();
          final today = dayKeyOf(now);
          final entries = _buildFeedEntries(all, hasMore: hasMore);

          return RefreshIndicator(
            color: PaykColors.violet,
            backgroundColor: Colors.white,
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return switch (entries[index]) {
                  _DayHeaderEntry(:final day, :final count, :final isFirst) =>
                    _DaySectionHeader(
                      label: formatDayHeader(day, locale, now: now),
                      count: count,
                      isToday: isSameCalendarDay(day, today),
                      isFirst: isFirst,
                    ),
                  _NotificationCardEntry(:final item, :final isLastInGroup) =>
                    Padding(
                      padding: EdgeInsets.only(bottom: isLastInGroup ? 0 : 10),
                      child: _NotificationCard(
                        item: _locallyReadIds.contains(item.id)
                            ? item.copyWith(read: true)
                            : item,
                        locale: locale,
                        onOpenOffers: () => _openOffers(context),
                        onOpenReceipt: item.billId != null
                            ? () => _openReceipt(context, item)
                            : null,
                      ),
                    ),
                  _LoadMoreEntry() => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
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
                    ),
                  ),
                };
              },
            ),
          );
        },
      ),
    );
  }
}

sealed class _NotificationFeedEntry {
  const _NotificationFeedEntry();
}

final class _DayHeaderEntry extends _NotificationFeedEntry {
  const _DayHeaderEntry({
    required this.day,
    required this.count,
    required this.isFirst,
  });

  final DateTime day;
  final int count;
  final bool isFirst;
}

final class _NotificationCardEntry extends _NotificationFeedEntry {
  const _NotificationCardEntry({
    required this.item,
    required this.isLastInGroup,
  });

  final LoyaltyMessageItem item;
  final bool isLastInGroup;
}

final class _LoadMoreEntry extends _NotificationFeedEntry {
  const _LoadMoreEntry();
}

List<_NotificationFeedEntry> _buildFeedEntries(
  List<LoyaltyMessageItem> items, {
  required bool hasMore,
}) {
  final entries = <_NotificationFeedEntry>[];
  var index = 0;
  var groupIndex = 0;
  while (index < items.length) {
    final day = dayKeyOf(items[index].createdAt);
    var end = index + 1;
    while (end < items.length &&
        isSameCalendarDay(dayKeyOf(items[end].createdAt), day)) {
      end++;
    }
    entries.add(
      _DayHeaderEntry(
        day: day,
        count: end - index,
        isFirst: groupIndex == 0,
      ),
    );
    for (var i = index; i < end; i++) {
      entries.add(
        _NotificationCardEntry(
          item: items[i],
          isLastInGroup: i == end - 1,
        ),
      );
    }
    index = end;
    groupIndex++;
  }
  if (hasMore) {
    entries.add(const _LoadMoreEntry());
  }
  return entries;
}

class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({
    required this.label,
    required this.count,
    required this.isToday,
    required this.isFirst,
  });

  final String label;
  final int count;
  final bool isToday;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(2, isFirst ? 2 : 20, 2, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxLabelWidth =
                (constraints.maxWidth - 68).clamp(80.0, double.infinity);
            return Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxLabelWidth),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: isToday
                          ? PaykColors.primary
                          : PaykColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: PaykColors.border,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isToday
                        ? PaykColors.brandSoft
                        : PaykColors.surfaceNested,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? PaykColors.primary
                          : PaykColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.locale,
    required this.onOpenOffers,
    this.onOpenReceipt,
  });

  final LoyaltyMessageItem item;
  final String locale;
  final VoidCallback onOpenOffers;
  final VoidCallback? onOpenReceipt;

  String _kindTitle() {
    final key = 'messages.kind.${item.kind}';
    final resolved = tr(locale, key);
    if (resolved != key) return resolved;
    return tr(locale, 'messages.kind.other');
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.read;
    final hasReceiptLink = onOpenReceipt != null;
    final hasOffersLink =
        !hasReceiptLink &&
        (item.kind == 'size_flash' || item.kind == 'size_new');
    final isGiftKind =
        item.kind == 'welcome_bonus' || item.kind == 'dob_bonus';

    final card = AnimatedContainer(
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isUnread ? const Color(0xFFF3F0FC) : const Color(0xFFEFF0F2),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: isUnread ? 1.0 : 0.72,
                  child: hasOffersLink
                      ? const SizeOffers3dIcon(size: 24)
                      : isGiftKind
                      ? const Gift3dIcon(size: 24)
                      : const Bell3dIcon(size: 24),
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
                        fontFamily: 'Inter',
                        color: PaykColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      formatDateTime(item.createdAt, locale: locale),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: PaykColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
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
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
              height: 1.4,
              color: PaykColors.textPrimary,
            ),
          ),
          if (hasReceiptLink) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: PaykColors.activePill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(locale, 'messages.openReceipt'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
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
          ],
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
                        fontFamily: 'Inter',
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

    if (!hasReceiptLink) {
      return RepaintBoundary(child: card);
    }

    return RepaintBoundary(
      child: Semantics(
        button: true,
        child: PaykPressable(
          scaleDown: PaykMotion.scaleSubtle,
          onTap: onOpenReceipt,
          child: card,
        ),
      ),
    );
  }
}
