import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/payk_page.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'payment_card.dart';

class ClientCodeScreen extends ConsumerStatefulWidget {
  const ClientCodeScreen({super.key});

  @override
  ConsumerState<ClientCodeScreen> createState() => _ClientCodeScreenState();
}

class _ClientCodeScreenState extends ConsumerState<ClientCodeScreen> {
  Timer? _clock;
  Timer? _poll;
  CashierCode? _code;
  DateTime? _deadline;
  String? _codeError;
  var _codeLoading = true;
  var _refreshing = false;
  PendingCheck? _pending;
  var _seenClosed = false;
  int? _closedId;

  @override
  void initState() {
    super.initState();
    _loadCode();
    _pollPending();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final deadline = _deadline;
      setState(() {});
      if (deadline != null && DateTime.now().isAfter(deadline)) _loadCode();
    });
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _pollPending());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadCode() async {
    if (_refreshing) return;
    _refreshing = true;
    if (_code == null && mounted) setState(() => _codeLoading = true);
    try {
      final code = await ref.read(loyaltyApiProvider).code();
      if (!mounted) return;
      final ttl = code.ttl < 5 ? 5 : code.ttl;
      setState(() {
        _code = code;
        _deadline = DateTime.now().add(Duration(seconds: ttl));
        _codeError = null;
        _codeLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _code = null;
        _deadline = null;
        _codeError = errorText(error);
        _codeLoading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _pollPending() async {
    if (!ref.read(sessionProvider).loggedIn) return;
    try {
      final snapshot = await ref.read(loyaltyApiProvider).pending();
      if (!mounted) return;
      setState(() => _pending = snapshot.pending);
      _noteClosed(snapshot.lastClosed);
    } catch (_) {
      // Следующий опрос повторит запрос. Код кассы при этом остаётся на экране.
    }
  }

  void _noteClosed(ClosedBill? closed) {
    if (!_seenClosed) {
      _seenClosed = true;
      _closedId = closed?.id;
      return;
    }
    if (closed == null || closed.id == _closedId) return;
    _closedId = closed.id;
    if (!mounted) return;
    if (closed.state == 'cancelled') {
      showPaykMessage(context, 'Чек отменён');
      return;
    }
    final burn = closed.burn ?? 0;
    final earn = closed.earn ?? 0;
    if (burn > 0 && earn > 0) {
      showPaykMessage(context, 'Покупка записана: ${formatMoney(burn)} бонусами, кешбэк +${formatMoney(earn)}');
    } else if (burn > 0) {
      showPaykMessage(context, 'Покупка записана: ${formatMoney(burn)} оплачено бонусами');
    } else if (earn > 0) {
      showPaykMessage(context, 'Покупка записана: +${formatMoney(earn)} кэшбэк');
    } else {
      showPaykMessage(context, 'Покупка записана');
    }
    ref.invalidate(meProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(friendsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final code = _code;
    final left = _deadline == null ? 0 : _deadline!.difference(DateTime.now()).inSeconds.clamp(0, 999);
    return ColoredBox(
      color: PaykColors.canvas,
      child: ListView(
        padding: PaykInsets.list(context, top: 16),
        children: [
            Text(tr(locale, 'code.title'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              tr(locale, 'code.hint'),
              style: TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 16),
            if (_codeLoading && code == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()))
            else if (_codeError != null || code == null)
              ErrorState(message: _codeError ?? 'Не удалось получить код', onRetry: _loadCode)
            else
              _CodeCard(code: code, secondsLeft: left, locale: locale),
            if (_pending != null) ...[
              const SizedBox(height: 12),
              PaymentCard(check: _pending!, onChanged: _pollPending),
            ],
            ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.secondsLeft, required this.locale});

  final CashierCode code;
  final int secondsLeft;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final digits = code.code;
    final half = (digits.length / 2).ceil();
    final spaced = digits.length <= 4 ? digits : '${digits.substring(0, half)} ${digits.substring(half)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          QrImageView(
            data: code.qr,
            size: 220,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(tr(locale, 'code.digitsLabel'), style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(spaced, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(tr(locale, 'code.expiresIn', {'s': '$secondsLeft'}), style: const TextStyle(fontWeight: FontWeight.w700)),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: digits));
              if (!context.mounted) return;
              showPaykMessage(context, tr(locale, 'code.copied'));
            },
            child: Text(tr(locale, 'code.copy')),
          ),
        ],
      ),
    );
  }
}
