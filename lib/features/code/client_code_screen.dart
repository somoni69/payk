import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/payment_choice.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/screen_skeletons.dart';
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

const _screenChannel = MethodChannel('app.payk.payk/screen');

class _ClientCodeScreenState extends ConsumerState<ClientCodeScreen> {
  Timer? _clock;
  Timer? _poll;
  CashierCode? _code;
  DateTime? _deadline;
  int _ttl = 40;
  String? _codeError;
  var _codeLoading = true;
  var _refreshing = false;
  PendingCheck? _pending;
  DateTime _fetchedAt = DateTime.now();
  var _paymentHidden = false;
  var _seenClosed = false;
  int? _closedId;

  @override
  void initState() {
    super.initState();
    unawaited(_shield(true));
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
    unawaited(_shield(false));
    _clock?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _shield(bool on) async {
    try {
      await _screenChannel.invokeMethod<void>('setSecure', on);
    } catch (_) {}
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
        _ttl = ttl;
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
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _pollPending() async {
    if (!ref.read(sessionProvider).loggedIn) return;
    try {
      final snapshot = await ref.read(loyaltyApiProvider).pending();
      if (!mounted) return;
      final previous = _pending;
      setState(() {
        final next = snapshot.pending;
        if (next?.id != _pending?.id) _paymentHidden = false;
        _pending = next;
        _fetchedAt = DateTime.now();
      });
      _noteClosed(snapshot.lastClosed, previous);
    } catch (_) {
      // Следующий опрос повторит запрос. Код кассы при этом остаётся на экране.
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

  Widget _paymentChild(String locale) {
    final check = _pending;
    if (check == null || !needsChoice(check)) {
      return const SizedBox.shrink(key: ValueKey('no_pending'));
    }
    if (_paymentHidden) {
      return Padding(
        key: ValueKey('hidden_${check.id}'),
        padding: const EdgeInsets.only(top: 16),
        child: Material(
          color: PaykColors.ink,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _paymentHidden = false),
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
        ),
      );
    }
    return Padding(
      key: ValueKey('pending_${check.id}'),
      padding: const EdgeInsets.only(top: 16),
      child: PaymentCard(
        check: check,
        fetchedAt: _fetchedAt,
        onChanged: _pollPending,
        onHide: () => setState(() => _paymentHidden = true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final code = _code;
    final left = _deadline == null
        ? 0
        : _deadline!.difference(DateTime.now()).inSeconds.clamp(0, 999);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: canPop ? 0 : 20,
        leading: canPop
            ? PaykPressable(
                scaleDown: PaykMotion.scaleIcon,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: PaykColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).maybePop();
                  },
                ),
              )
            : null,
        title: Text(
          tr(locale, 'code.title'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: PaykColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            if (_codeLoading && code == null)
              const CodeSkeleton()
            else if (_codeError != null || code == null)
              ErrorState(
                message: _codeError ?? 'Не удалось получить код',
                onRetry: _loadCode,
              )
            else ...[
              _CodeCard(
                code: code,
                secondsLeft: left,
                totalTtl: _ttl,
                isUpdating: _refreshing,
                onRefresh: _loadCode,
                locale: locale,
              ),
              const SizedBox(height: 12),
              _BottomCashierHint(totalTtl: _ttl, locale: locale),
            ],
            AnimatedSwitcher(
              duration: PaykMotion.duration(context, PaykMotion.normal),
              switchInCurve: PaykMotion.easeOut,
              switchOutCurve: PaykMotion.easeOut,
              child: _paymentChild(locale),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.secondsLeft,
    required this.totalTtl,
    required this.isUpdating,
    required this.onRefresh,
    required this.locale,
  });

  final CashierCode code;
  final int secondsLeft;
  final int totalTtl;
  final bool isUpdating;
  final VoidCallback onRefresh;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final digits = code.code;
    final half = (digits.length / 2).ceil();
    final spaced = digits.length <= 4
        ? digits
        : '${digits.substring(0, half)} ${digits.substring(half)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaykColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Контейнер QR-кода
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E5EB), width: 1.0),
            ),
            alignment: Alignment.center,
            child: QrImageView(
              data: code.qr,
              size: 240,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 20),

          // Заголовок «Рамз барои ворид кардан»
          Text(
            tr(locale, 'code.digitsLabel'),
            style: const TextStyle(
              fontFamily: 'Manrope',
              color: PaykColors.textSecondary,
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),

          // Крупные цифры кода «4244 7996»
          Text(
            spaced,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              color: PaykColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),

          // Плашка таймера и кнопки обновления
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: PaykColors.surfaceNested,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PaykColors.border),
            ),
            child: Row(
              children: [
                _CountdownRing(
                  secondsLeft: secondsLeft,
                  totalSeconds: totalTtl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isUpdating
                        ? tr(locale, 'code.updating')
                        : tr(locale, 'code.expiresIn', {'s': '$secondsLeft'}),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      color: PaykColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _RefreshButton(
                  loading: isUpdating,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onRefresh();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.secondsLeft, required this.totalSeconds});

  final int secondsLeft;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0
        ? (secondsLeft / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: PaykColors.border,
            color: PaykColors.primary,
            strokeWidth: 3.5,
            strokeCap: StrokeCap.round,
          ),
          Text(
            '$secondsLeft',
            style: const TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.w700,
              color: PaykColors.textPrimary,
              fontFamily: 'Manrope',
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      enabled: !loading,
      scaleDown: PaykMotion.scaleIcon,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: Color(0xFFE5E5EB))),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: loading ? null : onTap,
            child: Center(
              child: AnimatedSwitcher(
                duration: PaykMotion.duration(context, PaykMotion.micro),
                switchInCurve: PaykMotion.easeOut,
                switchOutCurve: PaykMotion.easeOut,
                child: loading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        key: ValueKey('refresh'),
                        size: 20,
                        color: PaykColors.textPrimary,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomCashierHint extends StatelessWidget {
  const _BottomCashierHint({required this.totalTtl, required this.locale});

  final int totalTtl;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PaykColors.surfaceNested,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              'assets/3d/cart.webp',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.shopping_cart_outlined,
                size: 36,
                color: PaykColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(locale, 'code.hint'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16.0,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr(locale, 'code.hintSub'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: PaykColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(locale, 'code.oneTime', {'ttl': '$totalTtl'}),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: PaykColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
