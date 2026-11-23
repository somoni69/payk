import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/payment_choice.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'payment_card.dart';

class ClientCodeScreen extends ConsumerStatefulWidget {
  const ClientCodeScreen({super.key, this.nowProvider});

  /// Источник текущего времени (в тестах позволяет сдвигать часы без ожидания).
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<ClientCodeScreen> createState() => _ClientCodeScreenState();
}

class _ClientCodeScreenState extends ConsumerState<ClientCodeScreen>
    with WidgetsBindingObserver {
  Timer? _clock;
  Timer? _poll;
  CashierCode? _code;
  DateTime? _deadline;
  int _ttl = 40;
  String? _codeError;
  var _codeLoading = true;
  var _refreshing = false;
  var _again = false;
  late var _appActive =
      (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
      AppLifecycleState.resumed;
  CodeChoice? _choice;
  String? _shownChoiceKey;
  PendingCheck? _pending;
  late DateTime _fetchedAt = _now();
  var _paymentHidden = false;
  var _seenClosed = false;
  int? _closedId;

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(sessionProvider).loggedIn) {
      Future.microtask(() {
        if (mounted) ref.invalidate(meProvider);
      });
    }
    _loadCode();
    _pollPending();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final deadline = _deadline;
      setState(() {});
      if (_appActive && deadline != null && _now().isAfter(deadline)) {
        _loadCode();
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _pollPending());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _appActive = active;
    if (!active || !mounted) return;
    if (ref.read(sessionProvider).loggedIn) {
      ref.invalidate(meProvider);
    }
    setState(() {});
    final deadline = _deadline;
    if (deadline != null && _now().isAfter(deadline)) {
      unawaited(_loadCode());
    }
  }

  Future<void> _loadCode() async {
    if (_refreshing) {
      _again = true;
      return;
    }
    _refreshing = true;
    _again = false;
    final wanted = _choice;
    if (mounted) {
      setState(() {
        if (_code == null) _codeLoading = true;
      });
    }
    try {
      final code = await ref.read(loyaltyApiProvider).code(choice: wanted);
      if (!mounted) return;
      final ttl = code.ttl < 5 ? 5 : code.ttl;
      final issued = code.spendPref == null
          ? null
          : CodeChoice(
              spend: code.spendPref!,
              coupon: code.useCoupon ?? true,
            );
      setState(() {
        if (_choice == null && issued != null) {
          _choice = issued;
        }
        _code = code;
        _ttl = ttl;
        _deadline = _now().add(Duration(seconds: ttl));
        _shownChoiceKey = issued?.key;
        _codeError = null;
        _codeLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _code = null;
        _deadline = null;
        _shownChoiceKey = null;
        _codeError = errorText(error);
        _codeLoading = false;
      });
    } finally {
      _refreshing = false;
      if (mounted) {
        setState(() {});
        if (_again) {
          _again = false;
          unawaited(_loadCode());
        }
      }
    }
  }

  void _pickChoice(CodeChoice next) {
    if (_choice == next) return;
    HapticFeedback.selectionClick();
    setState(() => _choice = next);
    unawaited(_loadCode());
  }

  void _manualRefresh() {
    if (ref.read(sessionProvider).loggedIn) {
      ref.invalidate(meProvider);
    }
    unawaited(_loadCode());
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
        _fetchedAt = _now();
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
    final account = ref.watch(meProvider).asData?.value;
    final code = _code;
    final choice = _choice;
    final now = _now();
    final leftMs = _deadline == null
        ? 0
        : _deadline!.difference(now).inMilliseconds;
    final left = leftMs <= 0 ? 0 : (leftMs / 1000).ceil().clamp(0, _ttl);
    final expired = code != null && _deadline != null && now.isAfter(_deadline!);
    final outdated =
        code != null &&
        choice != null &&
        _shownChoiceKey != null &&
        _shownChoiceKey != choice.key;
    final stale = _refreshing || expired || outdated;
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
            fontFamily: 'Inter',
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
            else
              _CodeCard(
                code: code,
                secondsLeft: left,
                totalTtl: _ttl,
                isUpdating: _refreshing,
                isOutdated: outdated,
                isStale: stale,
                onRefresh: _manualRefresh,
                locale: locale,
              ),
            if (choice != null) ...[
              const SizedBox(height: 12),
              _SpendChoiceCard(
                choice: choice,
                account: account,
                locale: locale,
                onPick: _pickChoice,
              ),
            ],
            if (_codeError == null && code != null) ...[
              const SizedBox(height: 12),
              _BottomCashierHint(totalTtl: _ttl, locale: locale),
            ],
            AnimatedSwitcher(
              duration: PaykMotion.duration(context, PaykMotion.normal),
              switchInCurve: PaykMotion.easeOut,
              switchOutCurve: PaykMotion.easeOut,
              layoutBuilder: PaykMotion.topAlignedLayoutBuilder,
              child: _paymentChild(locale),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isLongCode(int ttlSeconds) => ttlSeconds >= 120;

/// Короткий код (<2 мин): секунды «39»; от 2 минут — «29:58»; от часа — «5:59:58».
String _countdownLabel(int secondsLeft, int totalTtl) {
  final safeLeft = secondsLeft < 0 ? 0 : secondsLeft;
  if (!_isLongCode(totalTtl)) return '$safeLeft';
  String pad2(int value) => value.toString().padLeft(2, '0');
  if (safeLeft >= 3600) {
    final hours = safeLeft ~/ 3600;
    final minutes = (safeLeft % 3600) ~/ 60;
    final seconds = safeLeft % 60;
    return '$hours:${pad2(minutes)}:${pad2(seconds)}';
  }
  final minutes = safeLeft ~/ 60;
  final seconds = safeLeft % 60;
  return '$minutes:${pad2(seconds)}';
}

String _oneTimeHintText(String locale, int totalTtl) {
  if (totalTtl >= 3600 && totalTtl % 3600 == 0) {
    final hours = totalTtl ~/ 3600;
    return tr(locale, 'code.oneTimeHours', {
      'h': '$hours',
      'unit': plural(hours, 'час', 'часа', 'часов'),
    });
  }
  if (_isLongCode(totalTtl)) {
    final minutes = (totalTtl / 60).round();
    return tr(locale, 'code.oneTimeMin', {
      'm': '$minutes',
      'unit': plural(minutes, 'минуту', 'минуты', 'минут'),
    });
  }
  return tr(locale, 'code.oneTime', {'ttl': '$totalTtl'});
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.secondsLeft,
    required this.totalTtl,
    required this.isUpdating,
    required this.isOutdated,
    required this.isStale,
    required this.onRefresh,
    required this.locale,
  });

  final CashierCode code;
  final int secondsLeft;
  final int totalTtl;
  final bool isUpdating;
  final bool isOutdated;
  final bool isStale;
  final VoidCallback onRefresh;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final digits = code.code;
    final half = (digits.length / 2).ceil();
    final spaced = digits.length <= 4
        ? digits
        : '${digits.substring(0, half)} ${digits.substring(half)}';
    final longCode = _isLongCode(totalTtl);
    final leftLabel = _countdownLabel(secondsLeft, totalTtl);
    final statusText = isOutdated
        ? tr(locale, 'code.spend.saving')
        : isUpdating
        ? tr(locale, 'code.updating')
        : longCode
        ? tr(locale, 'code.expiresInMin', {'t': leftLabel})
        : tr(locale, 'code.expiresIn', {'s': leftLabel});
    final fadeDuration = PaykMotion.duration(context, PaykMotion.fast);

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
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: isStale ? 0.35 : 1.0,
                  duration: fadeDuration,
                  curve: PaykMotion.easeOut,
                  child: RepaintBoundary(
                    child: QrImageView(
                      data: code.qr,
                      size: 240,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (isStale)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: PaykColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Заголовок «Рамз барои ворид кардан»
          Text(
            tr(locale, 'code.digitsLabel'),
            style: const TextStyle(
              fontFamily: 'Inter',
              color: PaykColors.textSecondary,
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),

          // Крупные цифры кода («123 456» или «1234 5678»)
          AnimatedOpacity(
            opacity: isStale ? 0.35 : 1.0,
            duration: fadeDuration,
            curve: PaykMotion.easeOut,
            child: Text(
              spaced,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                color: PaykColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
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
                  pendingText: isUpdating || isOutdated,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      fontFamily: 'Inter',
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
  const _CountdownRing({
    required this.secondsLeft,
    required this.totalSeconds,
    this.pendingText = false,
  });

  final int secondsLeft;
  final int totalSeconds;
  final bool pendingText;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0
        ? (secondsLeft / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final compact = _isLongCode(totalSeconds);
    final hasHours = compact && secondsLeft >= 3600;
    final label = _countdownLabel(secondsLeft, totalSeconds);

    return RepaintBoundary(
      child: SizedBox(
        width: 54,
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress),
                duration: PaykMotion.duration(context, PaykMotion.normal),
                curve: PaykMotion.easeOut,
                builder: (context, animatedProgress, _) {
                  return CircularProgressIndicator(
                    value: animatedProgress,
                    backgroundColor: PaykColors.border,
                    color: PaykColors.primary,
                    strokeWidth: 3.5,
                    strokeCap: StrokeCap.round,
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hasHours ? 9 : 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pendingText ? '…' : label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: hasHours ? 10.5 : (compact ? 12.0 : 15.0),
                    fontWeight: FontWeight.w700,
                    color: PaykColors.textPrimary,
                    fontFamily: 'Inter',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendChoiceCard extends StatelessWidget {
  const _SpendChoiceCard({
    required this.choice,
    required this.account,
    required this.locale,
    required this.onPick,
  });

  final CodeChoice choice;
  final Account? account;
  final String locale;
  final ValueChanged<CodeChoice> onPick;

  @override
  Widget build(BuildContext context) {
    final wallet = account?.wallet;
    final rawCoupon = account?.coupon;
    final coupon =
        rawCoupon != null && rawCoupon.status == 'issued' ? rawCoupon : null;
    final couponMins = coupon == null
        ? ''
        : [
            '${tr(locale, 'format.CL')} — ${formatMoneyAuto(coupon.minBillCl)}',
            '${tr(locale, 'format.SM')} — ${formatMoneyAuto(coupon.minBillSm)}',
          ].join(', ');

    return Container(
      key: const ValueKey('spend-choice-card'),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(locale, 'code.spend.title'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: PaykColors.textPrimary,
            ),
          ),
          if (wallet != null) ...[
            const SizedBox(height: 3),
            Text(
              tr(locale, 'code.spend.balance', {
                'amount': formatMoney(wallet.balance),
              }),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PaykColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: PaykColors.surfaceNested,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PaykColors.border),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < SpendPref.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: _SpendOptionButton(
                        key: ValueKey('spend-${SpendPref.values[i].apiValue}'),
                        label: tr(
                          locale,
                          'code.spend.${SpendPref.values[i].apiValue}',
                        ),
                        selected: choice.spend == SpendPref.values[i],
                        onTap: () => onPick(
                          choice.copyWith(spend: SpendPref.values[i]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(locale, 'code.spend.${choice.spend.apiValue}Text'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: PaykColors.textPrimary,
            ),
          ),
          if (wallet != null && wallet.debt > 0 && choice.spend != SpendPref.earn) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: PaykColors.expenseSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tr(locale, 'code.spend.debt'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: PaykColors.danger,
                ),
              ),
            ),
          ],
          if (wallet != null && wallet.reserved > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: PaykColors.surfaceNested,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PaykColors.border),
              ),
              child: Text(
                tr(locale, 'code.spend.reserved', {
                  'amount': formatMoney(wallet.reserved),
                }),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: PaykColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
          if (coupon != null) ...[
            const SizedBox(height: 12),
            Material(
              color: PaykColors.surfaceNested,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: const ValueKey('spend-coupon-toggle'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => onPick(choice.copyWith(coupon: !choice.coupon)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: PaykColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(locale, 'code.coupon', {
                                'amount': formatMoneyAuto(coupon.amount),
                              }),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: PaykColors.textPrimary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tr(locale, 'code.couponHint', {
                                'mins': couponMins,
                              }),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                color: PaykColors.textSecondary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Transform.scale(
                        scale: 0.9,
                        child: Switch.adaptive(
                          value: choice.coupon,
                          activeThumbColor: Colors.white,
                          activeTrackColor: PaykColors.primary,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFD1D1D6),
                          trackOutlineColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          onChanged: (value) =>
                              onPick(choice.copyWith(coupon: value)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            tr(locale, 'code.spend.note'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: PaykColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendOptionButton extends StatelessWidget {
  const _SpendOptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: PaykPressable(
        scaleDown: PaykMotion.scaleSubtle,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: PaykMotion.duration(context, PaykMotion.fast),
              curve: PaykMotion.easeOut,
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? PaykColors.primary
                      : PaykColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
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
                    fontFamily: 'Inter',
                    fontSize: 16.0,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr(locale, 'code.hintSub'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: PaykColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _oneTimeHintText(locale, totalTtl),
                  style: const TextStyle(
                    fontFamily: 'Inter',
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
