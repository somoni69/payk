import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/countries.dart';
import '../../core/format.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) {
      setState(() => _error = 'Введите 9 цифр номера');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).requestCode('+992$digits');
      if (!mounted) return;
      HapticFeedback.lightImpact();
      PaykMotion.push<void>(context, '/auth/code', fallback: () => const OtpScreen());
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final isFocused = _focusNode.hasFocus;
    final hasError = _error != null;

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            const Text(
              'Войти в Payk',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: PaykColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Номер телефона станет вашей картой лояльности.',
              style: TextStyle(
                color: PaykColors.muted,
                fontWeight: FontWeight.w500,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            AnimatedContainer(
              duration: PaykMotion.duration(context, PaykMotion.micro),
              curve: PaykMotion.easeOut,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasError
                      ? PaykColors.bad
                      : (isFocused ? PaykColors.violet : const Color(0xFFE4E1EC)),
                  width: isFocused || hasError ? 1.8 : 1.2,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: PaykColors.violet.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('🇹🇯', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  const Text(
                    '+992',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PaykColors.ink,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Container(
                    height: 24,
                    width: 1.2,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: const Color(0xFFEAE8F2),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: PaykColors.ink,
                        letterSpacing: 0.8,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                        _TajikistanPhoneFormatter(),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: '90 123 45 67',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB8B5C5),
                          letterSpacing: 0.8,
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {
                          if (_error != null) _error = null;
                        });
                      },
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: PaykMotion.duration(context, PaykMotion.micro),
                    switchInCurve: PaykMotion.easeOut,
                    switchOutCurve: PaykMotion.easeOut,
                    child: _phone.text.isNotEmpty
                        ? GestureDetector(
                            key: const ValueKey('clear_phone'),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _phone.clear();
                              setState(() {
                                _error = null;
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F0F6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: PaykColors.muted,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty_phone')),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 15, color: PaykColors.bad),
                    const SizedBox(width: 6),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: PaykColors.bad,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            PaykPressable(
              enabled: !_busy && digits.length >= 9,
              child: FilledButton(
                onPressed: _busy || digits.length < 9 ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _busy ? 'Отправляем код…' : 'Получить код',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TajikistanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 9 ? digits.substring(0, 9) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2 || i == 5 || i == 7) {
        buffer.write(' ');
      }
      buffer.write(limited[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final digits = _code.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      setState(() => _error = 'Введите 6 цифр из SMS');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final loggedIn = await ref.read(sessionProvider.notifier).confirmCode(digits);
      if (!mounted) return;
      context.go(loggedIn ? '/home' : '/auth/profile');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(sessionProvider).pendingPhone;
    final digits = _code.text.replaceAll(RegExp(r'\D'), '');
    final isFocused = _focusNode.hasFocus;
    final hasError = _error != null;

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            const Text(
              'Код из сообщения',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: PaykColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              phone == null || phone.isEmpty
                  ? 'Введите 6 цифр из SMS.'
                  : 'Мы отправили код на $phone.',
              style: const TextStyle(
                color: PaykColors.muted,
                fontWeight: FontWeight.w500,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            AnimatedContainer(
              duration: PaykMotion.duration(context, PaykMotion.micro),
              curve: PaykMotion.easeOut,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasError
                      ? PaykColors.bad
                      : (isFocused ? PaykColors.violet : const Color(0xFFE4E1EC)),
                  width: isFocused || hasError ? 1.8 : 1.2,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: PaykColors.violet.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _code,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 14,
                  color: PaykColors.ink,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 12,
                    color: Color(0xFFB8B5C5),
                  ),
                ),
                onChanged: (value) {
                  final raw = value.replaceAll(RegExp(r'\D'), '');
                  setState(() {
                    if (_error != null) _error = null;
                  });
                  if (raw.length == 6 && !_busy) {
                    _submit();
                  }
                },
                onSubmitted: (_) => _busy ? null : _submit(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 15, color: PaykColors.bad),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: PaykColors.bad,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            PaykPressable(
              enabled: !_busy && digits.length >= 6,
              child: FilledButton(
                onPressed: _busy || digits.length < 6 ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _busy ? 'Проверяем…' : 'Подтвердить',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider);
    return program.when(
      loading: () => const RegisterSkeleton(),
      error: (error, stackTrace) => Scaffold(
        body: ErrorState(
          message: errorText(error),
          onRetry: () => ref.invalidate(programProvider),
        ),
      ),
      data: (info) => _ProfileForm(info: info),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.info});

  final ProgramInfo info;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _referral = TextEditingController();
  DateTime? _birthDate;
  late String _country;
  var _consent = false;
  var _messages = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final info = widget.info;
    _country = info.countries.contains('TJ')
        ? 'TJ'
        : (info.countries.isEmpty ? 'TJ' : info.countries.first);
  }

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    _email.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final last = _lastName.text.trim();
    final birth = _birthDate;
    if (name.length < 2 || last.length < 2) {
      setState(() => _error = 'Напишите имя и фамилию');
      return;
    }
    if (birth == null) {
      setState(() => _error = 'Укажите дату рождения');
      return;
    }
    if (!_consent) {
      setState(() => _error = 'Нужно согласие на обработку данных');
      return;
    }
    final email = _email.text.trim();
    final referral = _referral.text.trim().toUpperCase();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).completeProfile(
        RegisterInput(
          registrationToken: ref.read(sessionProvider).registrationToken ?? '',
          firstName: name,
          lastName: last,
          birthYear: birth.year,
          birthDate: '${birth.year.toString().padLeft(4, '0')}-${birth.month.toString().padLeft(2, '0')}-${birth.day.toString().padLeft(2, '0')}',
          country: _country,
          consentPd: true,
          consentMessages: _messages,
          email: email.isEmpty ? null : email,
          referralCode: referral.isEmpty ? null : referral,
        ),
      );
      if (!mounted) return;
      context.go('/home');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final minYear = info.birthYearMin <= info.birthYearMax ? info.birthYearMin : info.birthYearMax;
    final maxYear = info.birthYearMax >= info.birthYearMin ? info.birthYearMax : info.birthYearMin;
    final countries = info.countries.isEmpty ? const ['TJ'] : info.countries;
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(backgroundColor: PaykColors.canvas),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          const Text(
            'Регистрация',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            info.store.isEmpty
                ? 'Номер подтверждён. Так карта программы будет на ваше имя.'
                : 'Номер подтверждён. Карта ${info.store} будет на ваше имя.',
            style: const TextStyle(
              color: PaykColors.muted,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: 'Имя', errorText: _error),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Фамилия'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Дата рождения', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_birthDate == null ? 'День, месяц и год' : formatShortDate(_birthDate!)),
            trailing: const Icon(Icons.calendar_today_rounded),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ?? DateTime(maxYear, now.month, now.day),
                firstDate: DateTime(minYear),
                lastDate: DateTime(maxYear, 12, 31),
                helpText: 'Дата рождения',
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _country,
            decoration: const InputDecoration(labelText: 'Страна'),
            items: [
              for (final code in countries)
                DropdownMenuItem(value: code, child: Text(countryName(code))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _country = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Почта, если есть'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referral,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Код приглашения, если есть'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _consent,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Согласие на обработку персональных данных'),
            onChanged: (value) => setState(() => _consent = value ?? false),
          ),
          CheckboxListTile(
            value: _messages,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Сообщения о бонусах и акциях'),
            onChanged: (value) => setState(() => _messages = value ?? false),
          ),
          const SizedBox(height: 8),
          PaykPressable(
            enabled: !_busy,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Открываем карту…' : 'Открыть карту'),
            ),
          ),
        ],
      ),
    );
  }
}
