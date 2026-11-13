import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/payment_choice.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'payment_card.dart';

/// Чек на кассе виден на любом экране, не только на коде. На экране кода карточка своя.
class PendingPaymentHost extends ConsumerStatefulWidget {
  const PendingPaymentHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PendingPaymentHost> createState() => _PendingPaymentHostState();
}

class _PendingPaymentHostState extends ConsumerState<PendingPaymentHost> {
  Timer? _poll;
  Timer? _clock;
  GoRouter? _router;
  PendingCheck? _pending;
  DateTime _fetchedAt = DateTime.now();
  var _hidden = false;
  var _seenClosed = false;
  int? _closedId;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = GoRouter.maybeOf(context);
    if (!identical(next, _router)) {
      _router?.routerDelegate.removeListener(_onRoute);
      _router = next;
      _router?.routerDelegate.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() => _tick();

  bool get _onCode {
    final path = _router?.state.uri.path ?? '';
    return path == '/code';
  }

  Future<void> _tick() async {
    if (!mounted || _busy || _onCode) return;
    if (!ref.read(sessionProvider).loggedIn) return;
    _busy = true;
    try {
      final snapshot = await ref.read(loyaltyApiProvider).pending();
      if (!mounted || _onCode) return;
      final previous = _pending;
      final next = snapshot.pending;
      setState(() {
        if (next?.id != _pending?.id) _hidden = false;
        _pending = next;
        _fetchedAt = DateTime.now();
      });
      _noteClosed(snapshot.lastClosed, previous);
      _syncClock();
    } catch (_) {
      // Следующий опрос повторит запрос.
    } finally {
      _busy = false;
    }
  }

  void _syncClock() {
    final open = _pending != null && needsChoice(_pending!) && !_hidden;
    if (open && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!open) {
      _clock?.cancel();
      _clock = null;
    }
  }

  void _noteClosed(ClosedBill? closed, PendingCheck? previous) {
    if (!_seenClosed) {
      _seenClosed = true;
      _closedId = closed?.id;
      return;
    }
    if (closed == null || closed.id == _closedId) return;
    _closedId = closed.id;
    if (!mounted) return;
    if (!shouldAnnounceClose(closed: closed, previous: previous)) return;
    showPaykMessage(context, closedCheckText(ref.read(localeProvider), closed));
    ref.invalidate(meProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(friendsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final check = _pending;
    final open = check != null && needsChoice(check) && !_hidden && !_onCode;
    return Stack(
      children: [
        widget.child,
        if (check != null && needsChoice(check) && _hidden && !_onCode)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: _HiddenCheck(
              onOpen: () => setState(() {
                _hidden = false;
                _syncClock();
              }),
            ),
          ),
        if (open)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() {
                _hidden = true;
                _syncClock();
              }),
              child: ColoredBox(
                color: PaykColors.ink.withValues(alpha: 0.45),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: () {},
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: PaymentCard(
                          key: ValueKey(check.id),
                          check: check,
                          fetchedAt: _fetchedAt,
                          onChanged: _tick,
                          onHide: () => setState(() {
                            _hidden = true;
                            _syncClock();
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HiddenCheck extends ConsumerWidget {
  const _HiddenCheck({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Material(
      color: PaykColors.ink,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tr(locale, 'pay.open'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                tr(locale, 'pay.openAction'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
