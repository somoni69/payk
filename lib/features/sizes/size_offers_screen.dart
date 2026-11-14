import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/size_offers_logic.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/payk_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'sizes_screen.dart';

/// Карточки предложений, которые пришли именно на размер клиента.
class SizeOffersScreen extends ConsumerStatefulWidget {
  const SizeOffersScreen({super.key, this.focusOfferId});

  final int? focusOfferId;

  @override
  ConsumerState<SizeOffersScreen> createState() => _SizeOffersScreenState();
}

class _SizeOffersScreenState extends ConsumerState<SizeOffersScreen> {
  final Map<int, GlobalKey> _cardKeys = <int, GlobalKey>{};
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _scrolledToFocus = false;
  int? _openCodeOfferId;
  BuildContext? _sheetContext;
  int? _busyOfferId;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  GlobalKey _keyFor(int offerId) {
    return _cardKeys.putIfAbsent(offerId, GlobalKey.new);
  }

  void _maybeScrollToFocus(List<SizeOffer> items) {
    final targetId = widget.focusOfferId;
    if (_scrolledToFocus || targetId == null) return;
    if (!items.any((item) => item.id == targetId)) return;
    _scrolledToFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _cardKeys[targetId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  void _checkAutoCloseCodeSheet(List<SizeOffer> items) {
    final openId = _openCodeOfferId;
    final sheetCtx = _sheetContext;
    if (openId == null || sheetCtx == null) return;
    final current = items.where((item) => item.id == openId).firstOrNull;
    final shouldStayOpen = current != null &&
        resolveOfferAction(current, liveOfferStatus(current, _now)) == OfferAction.code;
    if (!shouldStayOpen) {
      _openCodeOfferId = null;
      _sheetContext = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sheetCtx.mounted) {
          Navigator.of(sheetCtx).maybePop();
        }
      });
    }
  }

  Future<void> _claimOffer(SizeOffer offer, String locale) async {
    setState(() => _busyOfferId = offer.id);
    try {
      final outcome = await ref
          .read(sizeOffersFeedProvider.notifier)
          .claim(offer, serverClock: _now);
      if (!mounted) return;
      switch (outcome) {
        case OfferClaimSuccess(:final offer):
          final code = offer.promoCode ?? '';
          if (code.isNotEmpty) {
            await _showCodeSheet(offer, locale);
          }
        case OfferClaimConflict(:final status, :final message):
          final fallback = status == 'SOLD_OUT'
              ? tr(locale, 'offers.claimSoldOut')
              : tr(locale, 'offers.claimExpired');
          showPaykMessage(
            context,
            (message != null && message.isNotEmpty) ? message : fallback,
          );
        case OfferClaimRemoved(:final message):
          showPaykMessage(
            context,
            (message != null && message.isNotEmpty)
                ? message
                : tr(locale, 'offers.claimGone'),
          );
      }
    } catch (error) {
      if (!mounted) return;
      final text = error is ApiException ? error.message : tr(locale, 'sizes.failed');
      showPaykMessage(context, text);
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  Future<void> _showCodeSheet(SizeOffer offer, String locale) async {
    final code = offer.promoCode ?? '';
    if (code.isEmpty) return;
    _openCodeOfferId = offer.id;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PaykColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        _sheetContext = sheetCtx;
        final formatted = formatPromoCode(code);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PaykColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr(locale, 'sizes.codeTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: PaykColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(locale, 'sizes.codeHint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: PaykColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: PaykColors.tile,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PaykColors.border),
                  ),
                  child: SelectableText(
                    formatted,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: PaykColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (sheetCtx.mounted) {
                            showPaykMessage(sheetCtx, tr(locale, 'sizes.copied'));
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(tr(locale, 'code.copy')),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: PaykColors.primary,
                          side: const BorderSide(color: PaykColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetCtx).maybePop(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: PaykColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(tr(locale, 'common.close')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) {
      _openCodeOfferId = null;
      _sheetContext = null;
    }
  }

  void _openSizes(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push('/sizes');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SizesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final member = ref.watch(meProvider).asData?.value.member;
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: PaykPressable(
          scaleDown: PaykMotion.scaleIcon,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: PaykColors.textPrimary, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
          ),
        ),
        title: Text(
          tr(locale, 'sizes.offers'),
          style: const TextStyle(
            color: PaykColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Manrope',
          ),
        ),
      ),
      body: AsyncView(
        value: ref.watch(sizeOffersFeedProvider),
        onRetry: () => ref.read(sizeOffersFeedProvider.notifier).reload(),
        data: (response) {
          final offers = response.items;
          _checkAutoCloseCodeSheet(offers);
          _maybeScrollToFocus(offers);
          if (offers.isEmpty) {
            final noSizes = member != null && isSizesEmpty(member);
            return EmptyState(
              title: tr(locale, 'offers.empty'),
              body: tr(locale, noSizes ? 'offers.emptyNoSizes' : 'offers.emptyText'),
              icon: Icons.straighten_rounded,
              actionLabel: noSizes ? tr(locale, 'offers.setSizes') : null,
              onAction: noSizes ? () => _openSizes(context) : null,
            );
          }
          return RefreshIndicator(
            color: PaykColors.violet,
            backgroundColor: Colors.white,
            onRefresh: () => ref.read(sizeOffersFeedProvider.notifier).reload(),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final offer = offers[index];
                return _OfferCard(
                  key: _keyFor(offer.id),
                  offer: offer,
                  locale: locale,
                  now: _now,
                  busy: _busyOfferId == offer.id,
                  highlighted: widget.focusOfferId == offer.id,
                  onClaim: () => _claimOffer(offer, locale),
                  onOpenCode: () => _showCodeSheet(offer, locale),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  const _OfferCard({
    super.key,
    required this.offer,
    required this.locale,
    required this.now,
    required this.busy,
    required this.highlighted,
    required this.onClaim,
    required this.onOpenCode,
  });

  final SizeOffer offer;
  final String locale;
  final DateTime now;
  final bool busy;
  final bool highlighted;
  final VoidCallback onClaim;
  final VoidCallback onOpenCode;

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final locale = widget.locale;
    final status = liveOfferStatus(offer, widget.now);
    final action = resolveOfferAction(offer, status);
    final active = status == 'ACTIVE';
    final left = offer.remainingAt(widget.now);
    final photo = resolvePaykAvatarUrl(offer.imageUrl);
    final pct = discountPercent(offer.originalPrice, offer.discountPrice);
    final sizeLabel = offer.size.trim().isNotEmpty
        ? offer.size.trim()
        : tr(locale, 'sizes.cat.${offer.category}');
    final longDesc = offer.description.length > 140;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: active ? 1.0 : 0.68,
      child: Container(
        decoration: BoxDecoration(
          color: PaykColors.sheet,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.highlighted && active ? PaykColors.primary : PaykColors.border,
            width: widget.highlighted && active ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo != null)
              Stack(
                children: [
                  Image.network(
                    photo,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 120,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined, color: PaykColors.textMuted),
                      ),
                    ),
                  ),
                  if (pct != null && active && action != OfferAction.issued)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: PaykColors.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '-$pct%',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Badge(text: sizeLabel),
                      _Badge(
                        text: tr(
                          locale,
                          offer.flash ? 'offers.type.FLASH_SALE' : 'offers.type.NEW_ARRIVAL',
                        ),
                        amber: offer.flash,
                      ),
                      if (action == OfferAction.issued)
                        _Badge(text: tr(locale, 'offers.issued'), success: true)
                      else if (status == 'SOLD_OUT')
                        _Badge(text: tr(locale, 'offers.status.SOLD_OUT'), muted: true)
                      else if (status == 'EXPIRED')
                        _Badge(text: tr(locale, 'offers.status.EXPIRED'), muted: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    offer.title,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: PaykColors.textPrimary,
                    ),
                  ),
                  if (offer.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      offer.description,
                      maxLines: _expanded ? null : 4,
                      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        height: 1.35,
                        color: PaykColors.textSecondary,
                      ),
                    ),
                    if (longDesc) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          tr(locale, _expanded ? 'offers.less' : 'offers.more'),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: PaykColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (offer.flash && offer.discountPrice != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (offer.originalPrice != null) ...[
                          Text(
                            formatMoney(offer.originalPrice!, decimals: false),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              color: PaykColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          formatMoney(offer.discountPrice!, decimals: false),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: PaykColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (action != OfferAction.issued && active && left > Duration.zero) ...[
                      const SizedBox(height: 6),
                      Text(
                        tr(locale, 'sizes.left', {
                          'time': formatOfferCountdownWithDays(
                            left,
                            tr(locale, 'offers.dayShort'),
                          ),
                        }),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: PaykColors.accentAmber,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  switch (action) {
                    OfferAction.issued => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: PaykColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 18, color: PaykColors.success),
                            const SizedBox(width: 8),
                            Text(
                              tr(locale, 'offers.issued'),
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: PaykColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    OfferAction.code => PaykPressable(
                        scaleDown: PaykMotion.scaleButton,
                        onTap: widget.onOpenCode,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: PaykColors.activePill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: PaykColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                formatPromoCode(offer.promoCode!),
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: PaykColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr(locale, 'offers.showCashier'),
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: PaykColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    OfferAction.claim => FilledButton(
                        onPressed: widget.busy ? null : widget.onClaim,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          backgroundColor: PaykColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          widget.busy
                              ? tr(locale, 'profile.saving')
                              : tr(locale, 'offers.claim'),
                        ),
                      ),
                    OfferAction.none => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: PaykColors.tile,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tr(
                            locale,
                            status == 'SOLD_OUT' ? 'offers.claimSoldOut' : 'offers.claimExpired',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PaykColors.textMuted,
                          ),
                        ),
                      ),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    this.amber = false,
    this.success = false,
    this.muted = false,
  });

  final String text;
  final bool amber;
  final bool success;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final bg = success
        ? PaykColors.success.withValues(alpha: 0.12)
        : muted
            ? PaykColors.tile
            : amber
                ? PaykColors.accentAmber.withValues(alpha: 0.14)
                : PaykColors.activePill;
    final fg = success
        ? PaykColors.success
        : muted
            ? PaykColors.textMuted
            : amber
                ? PaykColors.accentAmber
                : PaykColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
