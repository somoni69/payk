import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/countries.dart';
import '../../core/format.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_mark.dart';
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
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) {
      setState(() => _error = 'Введите номер полностью');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).requestCode('+992$digits');
      if (!mounted) return;
      context.push('/auth/code');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const PaykWordmark(width: 220),
            const SizedBox(height: 22),
            const Text(
              'Войти в Payk',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Номер телефона станет вашей картой лояльности.',
              style: TextStyle(
                color: PaykColors.muted,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: InputDecoration(
                prefixText: '+992 ',
                prefixStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PaykColors.ink,
                ),
                hintText: '90 123 45 67',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Отправляем код…' : 'Получить код'),
            ),
          ],
        ),
      ),
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
  String? _error;
  var _busy = false;

  @override
  void dispose() {
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
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(backgroundColor: PaykColors.canvas),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          const Text(
            'Код из сообщения',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            phone == null || phone.isEmpty
                ? 'Введите 6 цифр из SMS.'
                : 'Мы отправили код на $phone.',
            style: const TextStyle(color: PaykColors.muted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 12),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              hintText: '6 цифр',
              hintStyle: TextStyle(
                letterSpacing: 0,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PaykColors.muted,
              ),
            ).copyWith(errorText: _error),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Проверяем…' : 'Подтвердить'),
          ),
        ],
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
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
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Открываем карту…' : 'Открыть карту'),
          ),
        ],
      ),
    );
  }
}
