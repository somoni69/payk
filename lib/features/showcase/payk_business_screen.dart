import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_mark.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'lead_sheet.dart';
import 'showcase_card.dart';

/// «PAYK для бизнеса» — центр нижнего меню.
/// Карточки ведёт владелец PAYK; «Хочу PAYK» — заявка в его «Заявки».
class PaykBusinessScreen extends ConsumerStatefulWidget {
  const PaykBusinessScreen({super.key});

  @override
  ConsumerState<PaykBusinessScreen> createState() => _PaykBusinessScreenState();
}

class _PaykBusinessScreenState extends ConsumerState<PaykBusinessScreen>
    with WidgetsBindingObserver {
  ShowcaseFeed? _feed;
  String? _error;
  var _armed = false;
  var _visible = false;
  var _ticket = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) _load();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    try {
      final feed = await ref.read(loyaltyApiProvider).showcase();
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _feed = feed;
        _error = null;
      });
    } catch (error) {
      if (!mounted || ticket != _ticket) return;
      setState(() => _error = errorText(error));
    }
  }

  void _openLead(int? cardId) {
    final feed = _feed;
    if (feed == null) return;
    showPaykLeadSheet(
      context: context,
      cardId: cardId,
      contact: feed.contact,
      onSent: () {
        if (!mounted) return;
        setState(() {
          final current = _feed;
          if (current == null) return;
          _feed = current.copyWith(leadSentToday: true);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = Visibility.of(context);
    _visible = visible;
    if (visible && !_armed) {
      _armed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    if (!visible && _feed == null && _error == null) {
      return const SizedBox.shrink();
    }

    final locale = ref.watch(localeProvider);
    final feed = _feed;

    final loading = feed == null && _error == null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: PaykColors.canvas,
        body: loading
            ? const PaykBusinessSkeleton()
            : RefreshIndicator(
                color: PaykColors.violet,
                backgroundColor: Colors.white,
                edgeOffset: MediaQuery.paddingOf(context).top,
                displacement: 28,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 104),
                  children: [
                    _Hero(locale: locale),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ..._feedBody(
                            locale: locale,
                            feed: feed,
                            error: _error,
                            onRetry: _load,
                            onWant: _openLead,
                          ),
                          if (feed != null) ...[
                            const SizedBox(height: 16),
                            const _PoweredBy(),
                          ],
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

List<Widget> _feedBody({
  required String locale,
  required ShowcaseFeed? feed,
  required String? error,
  required VoidCallback onRetry,
  required void Function(int? cardId) onWant,
}) {
  if (feed == null) {
    return [
      SizedBox(
        height: 280,
        child: ErrorState(
          message: (error == null || error.isEmpty)
              ? tr(locale, 'payk.loadError')
              : error,
          onRetry: onRetry,
        ),
      ),
    ];
  }
  if (feed.cards.isEmpty) {
    return [
      _FallbackCard(
        locale: locale,
        sent: feed.leadSentToday,
        onWant: () => onWant(null),
      ),
    ];
  }
  return [
    for (var i = 0; i < feed.cards.length; i++) ...[
      if (i > 0) const SizedBox(height: 16),
      ShowcaseCardView(
        card: feed.cards[i],
        locale: locale,
        sent: feed.leadSentToday,
        onWant: () => onWant(feed.cards[i].id),
      ),
    ],
  ];
}

class _Hero extends StatelessWidget {
  const _Hero({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Тянется выше экрана: при оттягивании на iOS шапка уезжает вниз, цвет остаётся.
        const Positioned(
          top: -1000,
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: PaykColors.headerGradient),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(locale, 'payk.title'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr(locale, 'payk.subtitle'),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PoweredBy extends ConsumerWidget {
  const _PoweredBy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ExcludeSemantics(child: PaykMark(size: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              tr(locale, 'payk.poweredBy'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PaykColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackCard extends StatelessWidget {
  const _FallbackCard({
    required this.locale,
    required this.sent,
    required this.onWant,
  });

  final String locale;
  final bool sent;
  final VoidCallback onWant;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('showcase-fallback'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PaykColors.activePill,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/3d/sparkles.webp',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(locale, 'payk.fallbackTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PaykColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(locale, 'payk.fallbackText'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: PaykColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          WantButton(locale: locale, sent: sent, onPressed: onWant),
        ],
      ),
    );
  }
}
