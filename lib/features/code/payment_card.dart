import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/check_quote.dart';
import '../../core/format.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Экран «Пардохт»: три режима чека, порог A и танга (Л2.2–Л2.4, Л2.16–Л2.26).
class PaymentCard extends ConsumerStatefulWidget {
  const PaymentCard({super.key, required this.check, required this.onChanged});

  final PendingCheck check;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends ConsumerState<PaymentCard> {
  late double _voluntary = widget.check.clientConfirmed ? widget.check.burnAmount : 0;
  late bool _coin = widget.check.coin;
  late bool _toTen = widget.check.toTen;
  String? _error;
  var _busy = false;

  @override
  void didUpdateWidget(covariant PaymentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.check;
    final previous = oldWidget.check;
    final reset = next.id != previous.id || next.amount != previous.amount || next.earn != previous.earn || next.maxBurn != previous.maxBurn;
    if (reset) {
      _voluntary = next.clientConfirmed ? next.burnAmount : 0;
      _coin = next.coin;
      _toTen = next.toTen;
      _error = null;
    }
  }

  CheckQuote? _quote() {
    final check = widget.check;
    final amount = check.amount;
    final rate = check.earnRate;
    final cap = check.cap;
    if (amount == null || rate == null || cap == null || amount <= 0) return null;
    return quoteCheck(
      amount: amount,
      earnRate: rate,
      burnCap: cap,
      balance: check.balance ?? ((check.maxBurn ?? 0) + amount),
      burnMin: 0.50,
      stackPct: 0.05,
      stackAbs: 9.99,
      voluntary: _voluntary,
      coin: _coin,
      toTen: _toTen,
    );
  }

  Future<void> _confirm(CheckQuote quote) async {
    final body = <String, dynamic>{
      'mode': quote.v <= 0 ? 'earn' : quote.mode,
      'burn_amount': quote.v.toStringAsFixed(2),
      'coin': _coin,
      'to_ten': _toTen,
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyApiProvider).choose(widget.check.id, body);
      if (!mounted) return;
      showPaykMessage(context, 'Кассир видит ваш выбор');
      await widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final check = widget.check;
    final amount = check.amount;
    final quote = _quote();
    final ready = amount != null && quote != null;

    final noApp = check.source == 'sms' || check.source == 'late';
    final isWholesale = check.isWholesale;
    final canBurn = (quote?.y ?? 0) >= 0.50 && !noApp && !isWholesale && (check.debt ?? 0) <= 0;
    final excluded = check.excludedAmount ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Чек № ${check.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            [if (check.store != null) check.store, check.format == 'CL' ? 'либос' : 'супермаркет'].join(' · '),
            style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (!ready)
            const Text('Касса ещё передаёт сумму чека.', style: TextStyle(fontWeight: FontWeight.w700))
          else ...[
            Text(formatMoney(amount), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (isWholesale)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Оптовый чек: списание бонусов недоступно — только начисление.',
                  style: TextStyle(color: PaykColors.orange, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              )
            else if (noApp)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Опознание по SMS: списание бонусов доступно только при показе кода из приложения.',
                  style: TextStyle(color: PaykColors.orange, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              )
            else if (excluded > 0 && check.eligible != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'В программе участвует ${formatMoney(check.eligible!)} из ${formatMoney(amount)}',
                  style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            Text(
              'Без списания ${formatMoney(quote.x0, signed: true)} · до ${formatMoney(quote.a)} кешбэк сохраняется · до ${formatMoney(quote.y)}',
              style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Choice(
                    label: 'ҶАМЪ',
                    hint: formatMoney(quote.x0, signed: true),
                    selected: _voluntary <= 0,
                    onTap: _busy ? () {} : () => setState(() => _voluntary = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Choice(
                    label: 'ХАРҶ+ҶАМЪ',
                    hint: !canBurn || quote.y < 0.50
                        ? 'недоступно'
                        : 'до ${formatMoney(quote.a < quote.y ? quote.a : quote.y)}',
                    selected: _voluntary > 0 && quote.keepsCashback,
                    onTap: _busy || !canBurn || quote.y < 0.50
                        ? () {}
                        : () => setState(() {
                            final mark = quote.a < quote.y ? quote.a : quote.y;
                            _voluntary = clampVoluntary(mark, quote.y, 0.50);
                          }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Choice(
                    label: 'ХАРҶ',
                    hint: !canBurn || quote.y <= quote.a ? 'недоступно' : 'до ${formatMoney(quote.y)}',
                    selected: _voluntary > quote.a,
                    onTap: _busy || !canBurn || quote.y <= quote.a
                        ? () {}
                        : () => setState(() => _voluntary = quote.y),
                  ),
                ),
              ],
            ),
            if (canBurn && quote.y >= 0.50) ...[
              const SizedBox(height: 8),
              Slider(
                value: _voluntary.clamp(0, quote.y).toDouble(),
                max: quote.y,
                activeColor: PaykColors.violet,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _voluntary = value <= 0.25 ? 0 : clampVoluntary(value, quote.y, 0.50)),
              ),
              Text(
                _voluntary <= 0 ? 'Списание не выбрано' : 'Списать ${formatMoney(_voluntary)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (!quote.keepsCashback) ...[
              const SizedBox(height: 8),
              const Text(
                'Кешбэк за этот чек не начислится.',
                style: TextStyle(color: PaykColors.orange, fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Танга из кешбэка', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(quote.r > 0 ? 'Закроем ${formatMoney(quote.r)}' : 'В этом чеке мелочи нет'),
              value: _coin,
              onChanged: _busy ? null : (value) => setState(() => _coin = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Думкунӣ то 10', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Округлить наличные до десятков'),
              value: _toTen,
              onChanged: _busy ? null : (value) => setState(() => _toTen = value),
            ),
            const SizedBox(height: 4),
            Text(
              quote.keepsCashback ? 'Кешбэк ${formatMoney(quote.x, signed: true)}' : 'Кешбэк 0',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (quote.r > 0) Text('Танга ${formatMoney(-quote.r, signed: true)}'),
            Text('К оплате ${formatMoney(quote.cash)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'В статус пойдёт ${formatMoney(amount)}',
              style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w600),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: PaykColors.orange, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 12),
            PaykPressable(
              enabled: !_busy,
              child: FilledButton(
                onPressed: _busy ? null : () => _confirm(quote),
                child: Text(_busy ? 'Отправляем…' : 'Подтвердить'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.hint, required this.selected, required this.onTap});

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
                  style: TextStyle(color: selected ? Colors.white : PaykColors.ink, fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: selected ? Colors.white : PaykColors.muted, fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
