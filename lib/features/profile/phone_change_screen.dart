import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Экран смены номера телефона (Л1.10):
/// Коды приходят на текущий и на новый номер, номер меняется только после ввода обоих.
class PhoneChangeScreen extends ConsumerStatefulWidget {
  const PhoneChangeScreen({super.key});

  @override
  ConsumerState<PhoneChangeScreen> createState() => _PhoneChangeScreenState();
}

class _PhoneChangeScreenState extends ConsumerState<PhoneChangeScreen> {
  final _phoneController = TextEditingController();
  final _oldCodeController = TextEditingController();
  final _newCodeController = TextEditingController();

  PhoneChangeStart? _sent;
  bool _busy = false;
  String? _error;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _oldCodeController.dispose();
    _newCodeController.dispose();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _requestCodes(String currentPhone) async {
    final rawDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (rawDigits.length != 9) {
      setState(() => _error = 'Введите 9 цифр номера');
      return;
    }
    final targetPhone = '+992$rawDigits';
    if (targetPhone == currentPhone) {
      setState(() => _error = 'Этот номер уже привязан к вашему аккаунту');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final res = await ref.read(loyaltyApiProvider).phoneStart(targetPhone);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _sent = res;
        _oldCodeController.clear();
        _newCodeController.clear();
      });
      _startTimer(res.resendIn > 0 ? res.resendIn : 60);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = errorText(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmChange() async {
    final sent = _sent;
    if (sent == null) return;

    final oldCode = _oldCodeController.text.trim();
    final newCode = _newCodeController.text.trim();

    if (oldCode.length != 6 || newCode.length != 6) {
      setState(() => _error = 'Введите 6 цифр обоих кодов');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final updated = await ref.read(loyaltyApiProvider).phoneConfirm(
            sent.phone,
            oldCode,
            newCode,
          );
      if (!mounted) return;
      ref.invalidate(meProvider);
      HapticFeedback.mediumImpact();
      showPaykMessage(context, 'Номер изменён на ${formatPhone(updated.phone)}');
      Navigator.of(context).pop();
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = errorText(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).asData?.value;
    final currentPhone = me?.member.phone ?? '';
    final sent = _sent;

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
            icon: const Icon(Icons.arrow_back, color: PaykColors.textPrimary),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
          ),
        ),
        title: const Text(
          'Смена номера',
          style: TextStyle(
            color: PaykColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Manrope',
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PaykColors.sheet,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PaykColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PaykColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.security_rounded, color: PaykColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Текущий номер: ${formatPhone(currentPhone)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: PaykColors.textPrimary,
                            fontFamily: 'Manrope',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Для защиты аккаунта коды подтверждения отправляются и на текущий, и на новый номер.',
                          style: TextStyle(
                            fontSize: 13,
                            color: PaykColors.textSecondary,
                            fontFamily: 'Manrope',
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (sent == null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaykColors.sheet,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PaykColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Новый номер телефона',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PaykColors.textSecondary,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PaykColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Text('🇹🇯', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          const Text(
                            '+992',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: PaykColors.textPrimary,
                            ),
                          ),
                          Container(
                            height: 20,
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: PaykColors.border,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: PaykColors.textPrimary,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(9),
                              ],
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: '90 123 45 67',
                                hintStyle: TextStyle(
                                  color: Color(0xFFB8B5C5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onChanged: (_) {
                                if (_error != null) setState(() => _error = null);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: PaykColors.bad, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    PaykPressable(
                      child: FilledButton(
                        onPressed: _busy ? null : () => _requestCodes(currentPhone),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: PaykColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _busy ? 'Отправка...' : 'Получить коды',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Manrope'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaykColors.sheet,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PaykColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Коды отправлены на ${sent.oldPhone} и ${formatPhone(sent.phone)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: PaykColors.textSecondary,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Код со старого номера',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PaykColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _oldCodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: PaykColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: PaykColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Код с нового номера',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PaykColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newCodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: PaykColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: PaykColors.border),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: PaykColors.bad, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    PaykPressable(
                      child: FilledButton(
                        onPressed: _busy ? null : _confirmChange,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: PaykColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _busy ? 'Проверка...' : 'Подтвердить смену',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Manrope'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: _secondsLeft > 0 || _busy
                            ? null
                            : () => _requestCodes(currentPhone),
                        child: Text(
                          _secondsLeft > 0
                              ? 'Повторный код через $_secondsLeft с'
                              : 'Отправить коды ещё раз',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PaykColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
