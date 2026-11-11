import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/payment_choice.dart';
import '../../core/theme/payk_colors.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

enum _Phase { choose, sending, waiting }

/// Окно оплаты чека. Цифры считает сервер (пробный расчёт), оформление — прежняя карточка.
class PaymentCard extends ConsumerStatefulWidget {
  const PaymentCard({
    super.key,
    required this.check,
    required this.fetchedAt,
    required this.onChanged,
    this.onHide,
  });

  final PendingCheck check;
  final DateTime fetchedAt;
  final Future<void> Function() onChanged;
  final VoidCallback? onHide;

  @override
  ConsumerState<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends ConsumerState<PaymentCard> {
  late double _burn = widget.check.v;
  late bool _coin10 = widget.check.coin10;
  late bool _noCoin = widget.check.coinDeclined && !widget.check.coin10;
  var _phase = _Phase.choose;
  var _confirmed = false;
  var _editing = false;
  String? _notice;
  String? _error;
  String? _quoteMessage;
  String? _quoteKey;
  PendingCheck? _quoted;
  var _quoteSeq = 0;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    _applyCheck(widget.check, fresh: true);
  }

  @override
  void didUpdateWidget(covariant PaymentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.check;
    final previous = oldWidget.check;
    if (next.id != previous.id) {
      _quoteTimer?.cancel();
      _quoteSeq++;
      setState(() => _applyCheck(next, fresh: true));
      return;
    }
    if (_phase == _Phase.sending) return;

    final changed = !sameCheckNumbers(previous, next);
    if (!next.clientConfirmed &&
        (_phase == _Phase.waiting || (_editing && _confirmed))) {
      _quoteTimer?.cancel();
      _quoteSeq++;
      setState(() {
        _phase = _Phase.choose;
        _confirmed = false;
        _editing = false;
        _notice = changed ? 'amount' : 'reset';
        _error = null;
        _quoteKey = null;
        _quoted = null;
        _quoteMessage = null;
        _burn = clampBurn(_burn, next);
        _coin10 = _coin10 && next.coin10Available;
        _noCoin = false;
      });
      _scheduleQuote();
      return;
    }
    if (_phase == _Phase.choose && next.clientConfirmed && !_editing) {
      setState(() {
        _phase = _Phase.waiting;
        _confirmed = true;
      });
      return;
    }
    if (changed && _phase == _Phase.choose) {
      _quoteTimer?.cancel();
      _quoteSeq++;
      setState(() {
        _notice = 'amount';
        _quoteKey = null;
        _quoted = null;
        _quoteMessage = null;
        _burn = clampBurn(_burn, next);
        _coin10 = _coin10 && next.coin10Available;
      });
      _scheduleQuote();
    }
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  void _applyCheck(PendingCheck check, {required bool fresh}) {
    _burn = check.v;
    _coin10 = check.coin10;
    _noCoin = check.coinDeclined && !check.coin10;
    _phase = check.clientConfirmed ? _Phase.waiting : _Phase.choose;
    _confirmed = check.clientConfirmed;
    _editing = false;
    _notice = null;
    _error = null;
    _quoteMessage = null;
    _quoteKey = fresh ? choiceKeyOf(check) : null;
    _quoted = null;
  }

  String get _selectionKey => choiceKey(_burn, _coin10, _noCoin);

  void _scheduleQuote() {
    _quoteTimer?.cancel();
    final key = _selectionKey;
    final alreadyKnown = key == choiceKeyOf(widget.check) && _quoteKey == key;
    if (_phase != _Phase.choose || alreadyKnown) {
      return;
    }
    final seq = ++_quoteSeq;
    final id = widget.check.id;
    final burn = _burn;
    final coin10 = _coin10;
    final noCoin = _noCoin;
    _quoteTimer = Timer(const Duration(milliseconds: 280), () async {
      try {
        final result = await ref
            .read(loyaltyApiProvider)
            .quote(id, burn: burn, coin10: coin10, noCoin: noCoin);
        if (!mounted || seq != _quoteSeq) return;
        setState(() {
          _quoteKey = key;
          if (result.preview != null) _quoted = result.preview;
          _quoteMessage = result.message;
        });
      } catch (error) {
        if (!mounted || seq != _quoteSeq) return;
        setState(() {
          _quoteKey = key;
          _quoteMessage = errorText(error);
        });
      }
    });
  }

  void _setBurn(double value) {
    setState(() {
      _burn = clampBurn(value, widget.check);
      _error = null;
    });
    _scheduleQuote();
  }

  Future<void> _confirm() async {
    if (_phase == _Phase.sending) return;
    final key = _selectionKey;
    if (_quoteKey != key || _quoteMessage != null) return;
    final id = widget.check.id;
    _quoteTimer?.cancel();
    _quoteSeq++;
    setState(() {
      _phase = _Phase.sending;
      _error = null;
    });
    try {
      await ref
          .read(loyaltyApiProvider)
          .choose(id, burn: _burn, coin10: _coin10, noCoin: _noCoin);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.waiting;
        _confirmed = true;
        _editing = false;
        _notice = null;
      });
      await widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.choose;
        _error = errorText(error);
      });
      _scheduleQuote();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final check = widget.check;
    final amount = check.amount;
    final waiting = _phase == _Phase.waiting;
    final key = _selectionKey;
    final settled = _quoteKey == key;
    final calculating = !waiting && !settled;
    final view = waiting
        ? check
        : (settled && _quoted != null
              ? _quoted!
              : (key == choiceKeyOf(check) ? check : (_quoted ?? check)));
    final canBurn = canBurnOn(check);
    final y = check.y ?? 0;
    final min = burnMinOf(check);
    final aStar = check.aStar ?? 0;
    final pristine = !waiting && !_confirmed && key == choiceKeyOf(check);
    final canConfirm = settled && _quoteMessage == null && !calculating;
    final loses =
        !waiting &&
        canBurn &&
        _burn > paymentAmountEps &&
        aStar > 0 &&
        _burn > aStar + paymentAmountEps;
    final excluded = check.excludedAmount ?? 0;
    final noApp = isNoAppCheck(check);
    final reason = check.isWholesale
        ? 'pay.noBurnWholesale'
        : noApp
        ? 'pay.noBurnNoApp'
        : (check.debt ?? 0) > 0
        ? 'pay.noBurnDebt'
        : (check.balance ?? 0) <= 0
        ? 'pay.noBurnBalance'
        : 'pay.noBurnCheck';
    final cash = view.cashToPay ?? view.toPay;
    final left = _secondsLeft(check);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(locale, 'pay.check', {'id': check.billExtId ?? '${check.id}'}),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (check.store != null) check.store,
              tr(locale, check.format == 'CL' ? 'format.CL' : 'format.SM'),
            ].join(' · '),
            style: const TextStyle(
              color: PaykColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (amount == null)
            Text(
              tr(locale, 'pay.waitingAmount'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            )
          else ...[
            Text(
              formatMoney(amount),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (check.isWholesale)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  tr(locale, 'pay.wholesale'),
                  style: const TextStyle(
                    color: PaykColors.orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              )
            else if (noApp)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  tr(locale, 'pay.noBurnNoApp'),
                  style: const TextStyle(
                    color: PaykColors.orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              )
            else if (excluded > 0 && check.eligible != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  tr(locale, 'pay.eligible', {
                    'eligible': formatMoney(check.eligible!),
                    'amount': formatMoney(amount),
                  }),
                  style: const TextStyle(
                    color: PaykColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            if (_notice != null && _phase == _Phase.choose) ...[
              Text(
                tr(
                  locale,
                  _notice == 'amount'
                      ? 'pay.amountChanged'
                      : 'pay.recalculated',
                ),
                style: const TextStyle(
                  color: PaykColors.orange,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (waiting) ...[
              Text(
                tr(locale, 'pay.confirmed'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                tr(locale, 'pay.waiting'),
                style: const TextStyle(
                  color: PaykColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              tr(locale, 'pay.limits', {
                'x0': formatMoney(check.x0 ?? 0, signed: true),
                'a': formatMoney(aStar),
                'y': formatMoney(y),
              }),
              style: const TextStyle(
                color: PaykColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (!waiting) ...[
              const SizedBox(height: 12),
              if (canBurn) ...[
                Row(
                  children: [
                    Expanded(
                      child: _Choice(
                        label: 'ҶАМЪ',
                        hint: formatMoney(check.x0 ?? 0, signed: true),
                        selected: _burn <= 0,
                        onTap: _phase == _Phase.sending
                            ? () {}
                            : () => _setBurn(0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Choice(
                        label: 'ХАРҶ+ҶАМЪ',
                        hint: y < min
                            ? tr(locale, 'pay.unavailable')
                            : tr(locale, 'pay.keepUpTo', {
                                'a': formatMoney(aStar < y ? aStar : y),
                              }),
                        selected:
                            _burn > 0 &&
                            (aStar <= 0 || _burn <= aStar + paymentAmountEps),
                        onTap: _phase == _Phase.sending || y < min
                            ? () {}
                            : () => _setBurn(
                                aStar >= min && aStar <= y ? aStar : y,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Choice(
                        label: 'ХАРҶ',
                        hint: y <= aStar
                            ? tr(locale, 'pay.unavailable')
                            : tr(locale, 'pay.upTo', {'y': formatMoney(y)}),
                        selected: aStar > 0 && _burn > aStar + paymentAmountEps,
                        onTap: _phase == _Phase.sending || y <= aStar
                            ? () {}
                            : () => _setBurn(y),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _burn.clamp(0, y).toDouble(),
                  max: y,
                  activeColor: PaykColors.violet,
                  onChanged: _phase == _Phase.sending
                      ? null
                      : (value) => _setBurn(value <= min / 2 ? 0 : value),
                ),
                Text(
                  _burn <= 0
                      ? tr(locale, 'pay.spendOff')
                      : tr(locale, 'pay.spendNow', {
                          'amount': formatMoney(_burn),
                        }),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (aStar > min && aStar < y)
                  Text(
                    tr(locale, 'pay.keepUpTo', {'a': formatMoney(aStar)}),
                    style: const TextStyle(
                      color: PaykColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ] else
                Text(
                  tr(locale, reason),
                  style: const TextStyle(
                    color: PaykColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              if (loses) ...[
                const SizedBox(height: 8),
                Text(
                  tr(locale, 'pay.loseCashback', {'a': formatMoney(aStar)}),
                  style: const TextStyle(
                    color: PaykColors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (check.coin10Available)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    check.coinSuggested
                        ? '${tr(locale, 'pay.coinSuggested')} · ${tr(locale, 'pay.coin10')}'
                        : tr(locale, 'pay.coin10'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(tr(locale, 'pay.coin10Hint')),
                  value: _coin10,
                  onChanged: _phase == _Phase.sending
                      ? null
                      : (value) {
                          setState(() {
                            _coin10 = value;
                            if (value) _noCoin = false;
                            _error = null;
                          });
                          _scheduleQuote();
                        },
                ),
              if (view.r > 0 || view.coinDeclined || _noCoin)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    tr(locale, 'pay.noCoin'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(tr(locale, 'pay.noCoinHint')),
                  value: _noCoin,
                  onChanged: _phase == _Phase.sending
                      ? null
                      : (value) {
                          setState(() {
                            _noCoin = value;
                            if (value) _coin10 = false;
                            _error = null;
                          });
                          _scheduleQuote();
                        },
                ),
            ],
            const SizedBox(height: 8),
            Text(
              tr(locale, 'pay.cashbackLine', {
                'amount': formatMoney(view.x ?? 0, signed: true),
              }),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (view.v > 0)
              Text(
                tr(locale, 'pay.spendLine', {'amount': formatMoney(view.v)}),
              ),
            if (view.r > 0)
              Text(tr(locale, 'pay.coinLine', {'amount': formatMoney(view.r)})),
            if (view.cardAmount > 0)
              Text(
                tr(locale, 'pay.cardLine', {
                  'amount': formatMoney(view.cardAmount),
                }),
              ),
            if (cash != null)
              Text(
                tr(locale, 'pay.cashLine', {'amount': formatMoney(cash)}),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            if (view.why == 'off' && view.r <= 0)
              Text(
                tr(locale, 'pay.coinOff'),
                style: const TextStyle(
                  color: PaykColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (_quoteMessage != null && !waiting) ...[
              const SizedBox(height: 8),
              Text(
                _quoteMessage!,
                style: const TextStyle(
                  color: PaykColors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: PaykColors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (pristine) ...[
              const SizedBox(height: 8),
              Text(
                (view.x ?? 0) > 0
                    ? tr(locale, 'pay.auto', {
                        'x': formatMoney(view.x ?? 0, signed: true),
                      })
                    : tr(locale, 'pay.autoNoCashback'),
                style: const TextStyle(
                  color: PaykColors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 12),
            PaykPressable(
              enabled:
                  _phase != _Phase.sending &&
                  (waiting || pristine || canConfirm),
              child: FilledButton(
                onPressed: _phase == _Phase.sending
                    ? null
                    : waiting
                    ? () {
                        setState(() {
                          _phase = _Phase.choose;
                          _editing = true;
                          _burn = check.v;
                          _coin10 = check.coin10;
                          _noCoin = check.coinDeclined && !check.coin10;
                          _quoteKey = choiceKeyOf(check);
                          _quoted = null;
                          _quoteMessage = null;
                        });
                      }
                    : pristine
                    ? widget.onHide
                    : (canConfirm ? _confirm : null),
                child: Text(
                  _phase == _Phase.sending
                      ? tr(locale, 'pay.sending')
                      : waiting
                      ? tr(locale, 'pay.change')
                      : pristine
                      ? tr(locale, 'pay.ok')
                      : tr(locale, 'pay.confirm'),
                ),
              ),
            ),
            if (left != null || check.balance != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (left != null)
                    left <= 0
                        ? tr(locale, 'pay.expired')
                        : tr(locale, 'pay.expiresIn', {'time': _clock(left)}),
                  if (check.balance != null)
                    tr(locale, 'pay.balance', {
                      'amount': formatMoney(check.balance!),
                    }),
                ].join(' · '),
                style: const TextStyle(
                  color: PaykColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  int? _secondsLeft(PendingCheck check) {
    final expires = check.expiresAt;
    if (expires == null) return null;
    final server = check.serverNow;
    final now = server == null
        ? DateTime.now()
        : DateTime.now().add(server.difference(widget.fetchedAt));
    return expires.difference(now).inSeconds;
  }
}

String _clock(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = safe ~/ 60;
  final rest = safe % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      scaleDown: PaykMotion.scaleButton,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: PaykMotion.duration(context, PaykMotion.fast),
            curve: PaykMotion.easeOut,
            decoration: BoxDecoration(
              color: selected ? PaykColors.violet : PaykColors.canvas,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : PaykColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : PaykColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
