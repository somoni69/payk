import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/payk_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Карточки предложений, которые пришли именно на размер клиента.
class SizeOffersScreen extends ConsumerWidget {
  const SizeOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
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
        value: ref.watch(sizeOffersProvider),
        onRetry: () => ref.invalidate(sizeOffersProvider),
        data: (offers) {
          if (offers.isEmpty) {
            return EmptyState(
              title: tr(locale, 'sizes.emptyTitle'),
              body: tr(locale, 'sizes.emptyBody'),
              icon: Icons.straighten_rounded,
            );
          }
          return RefreshIndicator(
            color: PaykColors.violet,
            backgroundColor: Colors.white,
            onRefresh: () async {
              ref.invalidate(sizeOffersProvider);
              try {
                await ref.read(sizeOffersProvider.future);
              } catch (_) {}
            },
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _OfferCard(offer: offers[index], locale: locale),
            ),
          );
        },
      ),
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.offer, required this.locale});

  final SizeOffer offer;
  final String locale;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  Timer? _ticker;
  var _busy = false;
  late SizeOffer _offer = widget.offer;

  @override
  void initState() {
    super.initState();
    if (_offer.flash && _offer.expiresAt != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant _OfferCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer.id != widget.offer.id || oldWidget.offer.promoCode != widget.offer.promoCode) {
      _offer = widget.offer;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final next = await ref.read(loyaltyApiProvider).claimSizeOffer(_offer.id);
      ref.invalidate(sizeOffersProvider);
      if (!mounted) return;
      setState(() => _offer = next);
      await _showCode(next.promoCode ?? '');
    } catch (error) {
      if (!mounted) return;
      final text = error is ApiException ? error.message : tr(widget.locale, 'sizes.failed');
      showPaykMessage(context, text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCode(String code) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(widget.locale, 'sizes.codeTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(widget.locale, 'sizes.codeHint')),
            const SizedBox(height: 12),
            SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: PaykColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) showPaykMessage(context, tr(widget.locale, 'sizes.copied'));
            },
            child: Text(tr(widget.locale, 'code.copy')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(widget.locale, 'common.done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    final locale = widget.locale;
    final photo = resolvePaykAvatarUrl(offer.imageUrl);
    final left = offer.remainingAt(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photo != null)
            Image.network(
              photo,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 120,
                child: Center(child: Icon(Icons.image_not_supported_outlined, color: PaykColors.textMuted)),
              ),
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
                    _Badge(text: tr(locale, 'sizes.yourSize', {'size': offer.size})),
                    _Badge(text: tr(locale, 'sizes.exclusive')),
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
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      height: 1.35,
                      color: PaykColors.textSecondary,
                    ),
                  ),
                ],
                if (offer.flash && offer.discountPrice != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (offer.originalPrice != null)
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
                  const SizedBox(height: 6),
                  Text(
                    tr(locale, 'sizes.left', {'time': formatOfferCountdown(left)}),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PaykColors.accentAmber,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (offer.claimed && (offer.promoCode ?? '').isNotEmpty)
                  FilledButton(
                    onPressed: () => _showCode(offer.promoCode!),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: PaykColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(tr(locale, 'sizes.showCode', {'code': offer.promoCode!})),
                  )
                else
                  FilledButton(
                    onPressed: _busy ? null : _claim,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: PaykColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_busy ? tr(locale, 'profile.saving') : tr(locale, 'sizes.claim')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PaykColors.activePill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: PaykColors.primary,
        ),
      ),
    );
  }
}
