import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_auth/smart_auth.dart';

import '../../core/countries.dart';
import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/widgets/birth_date_fields.dart';
import '../../core/widgets/google_widgets.dart';
import '../../core/widgets/payk_3d_icon.dart';
import '../../core/widgets/tajik_phone_field.dart';
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
  String? _googleError;
  var _busy = false;
  var _googleBusy = false;
  var _googleDisabledByServer = false;

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

  Future<void> _continueWithGoogle() async {
    if (_googleBusy || _busy) return;
    final locale = ref.read(localeProvider);
    setState(() {
      _googleBusy = true;
      _googleError = null;
      _error = null;
    });
    try {
      final idToken = await ref.read(googleAuthServiceProvider).requestIdToken();
      if (!mounted) return;
      if (idToken == null || idToken.isEmpty) {
        return;
      }
      final loggedIn = await ref
          .read(sessionProvider.notifier)
          .loginWithGoogle(idToken);
      if (!mounted) return;
      if (loggedIn) {
        GoRouter.maybeOf(context)?.go('/home');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.status == 503) _googleDisabledByServer = true;
        _googleError = errorText(error);
      });
    } catch (error, stackTrace) {
      debugPrint('Google Sign-In failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _googleError = tr(locale, 'google.failed'));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  void _dropGoogle() {
    HapticFeedback.lightImpact();
    ref.read(sessionProvider.notifier).clearPendingGoogle();
    setState(() {
      _error = null;
      _googleError = null;
    });
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
    final locale = ref.watch(localeProvider);
    final welcomeBonus = ref.watch(programProvider).asData?.value.welcomeBonus;
    final pendingGoogle = ref.watch(
      sessionProvider.select((s) => s.pendingGoogle),
    );
    final showGoogleButton =
        pendingGoogle == null &&
        !_googleDisabledByServer &&
        ref.watch(googleAuthServiceProvider).isAvailable;

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            Text(
              pendingGoogle != null
                  ? tr(locale, 'google.confirmTitle')
                  : 'Войти в Payk',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: PaykColors.ink,
              ),
            ),
            if (pendingGoogle != null) ...[
              const SizedBox(height: 14),
              Container(
                key: const ValueKey('google-pending'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: PaykColors.sheet,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PaykColors.border),
                ),
                child: Row(
                  children: [
                    const GoogleMark(size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(locale, 'google.account', {
                              'email': pendingGoogle.email,
                            }),
                            key: const ValueKey('google-pending-email'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: PaykColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(locale, 'google.confirmText'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: PaykColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
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
              if (showGoogleButton) ...[
                const SizedBox(height: 24),
                GoogleContinueButton(
                  key: const ValueKey('google-continue-btn'),
                  label: tr(locale, 'google.continue'),
                  busy: _googleBusy,
                  onPressed: _busy ? null : _continueWithGoogle,
                ),
                if (_googleError != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    key: const ValueKey('google-error'),
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 15,
                        color: PaykColors.bad,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _googleError!,
                          style: const TextStyle(
                            color: PaykColors.bad,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                OrDivider(label: tr(locale, 'google.or')),
              ] else
                const SizedBox(height: 32),
            ],
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
                      inputFormatters: const [
                        TajikPhoneFormatter(),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
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
            AnimatedSize(
              duration: PaykMotion.duration(context, PaykMotion.micro),
              curve: PaykMotion.easeOut,
              alignment: Alignment.topLeft,
              child: AnimatedSwitcher(
                duration: PaykMotion.duration(context, PaykMotion.micro),
                switchInCurve: PaykMotion.easeOut,
                switchOutCurve: PaykMotion.easeOut,
                layoutBuilder: PaykMotion.topAlignedLayoutBuilder,
                child: _error != null
                    ? Padding(
                        key: ValueKey('phone-err-$_error'),
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
                      )
                    : const SizedBox.shrink(key: ValueKey('phone-err-none')),
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
            if (pendingGoogle != null) ...[
              const SizedBox(height: 10),
              TextButton(
                key: const ValueKey('google-pending-cancel'),
                onPressed: _busy ? null : _dropGoogle,
                child: Text(
                  tr(locale, 'google.cancelHint'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.textSecondary,
                  ),
                ),
              ),
            ],
            if (welcomeBonus != null && welcomeBonus > 0) ...[
              const SizedBox(height: 20),
              Container(
                key: const ValueKey('login-welcome-promo'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaykColors.brandSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: PaykColors.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    const Gift3dIcon(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(locale, 'login.giftTitle', {
                              'amount': formatMoneyAuto(welcomeBonus),
                            }),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: PaykColors.textPrimary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tr(locale, 'login.giftText'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: PaykColors.textSecondary,
                            ),
                          ),
                        ],
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

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _focusNode = FocusNode();
  final _sms = SmartAuth.instance;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    unawaited(_listenForSms());
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_sms.removeUserConsentApiListener());
    }
    _focusNode.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Android показывает системное подтверждение и кладёт код в поле.
  /// iOS отдаёт код через подсказку клавиатуры в то же поле.
  Future<void> _listenForSms() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final result = await _sms.getSmsWithUserConsentApi(matcher: r'\d{6}');
    if (!mounted || !result.hasData) return;
    final code = result.data?.code;
    if (code == null) return;
    _applyCode(code);
  }

  void _applyCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6 || _busy) return;
    _code.value = TextEditingValue(
      text: digits,
      selection: const TextSelection.collapsed(offset: 6),
    );
    setState(() => _error = null);
    _submit();
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
    final session = ref.watch(sessionProvider);
    final phone = session.pendingPhone;
    final pendingGoogle = session.pendingGoogle;
    final locale = ref.watch(localeProvider);
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
      body: AutofillGroup(
        child: SafeArea(
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
            if (pendingGoogle != null) ...[
              const SizedBox(height: 10),
              Row(
                key: const ValueKey('google-pending-code'),
                children: [
                  const GoogleMark(size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(locale, 'google.account', {
                        'email': pendingGoogle.email,
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: PaykColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
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
            AnimatedSize(
              duration: PaykMotion.duration(context, PaykMotion.micro),
              curve: PaykMotion.easeOut,
              alignment: Alignment.topLeft,
              child: AnimatedSwitcher(
                duration: PaykMotion.duration(context, PaykMotion.micro),
                switchInCurve: PaykMotion.easeOut,
                switchOutCurve: PaykMotion.easeOut,
                layoutBuilder: PaykMotion.topAlignedLayoutBuilder,
                child: _error != null
                    ? Padding(
                        key: ValueKey('otp-err-$_error'),
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
                      )
                    : const SizedBox.shrink(key: ValueKey('otp-err-none')),
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
  final _day = TextEditingController();
  final _year = TextEditingController();
  int? _month;
  late String _country;
  var _consent = false;
  var _messages = false;
  var _busy = false;
  String? _error;

  ReferralContext _referralCtx = ReferralContext.empty;
  var _referralDeclined = false;
  var _matchSeq = 0;

  Timer? _referralDebounce;
  var _checkSeq = 0;
  var _checkingManualReferral = false;
  ReferralCheck? _manualReferralCheck;
  late final ReferralService _referralService;

  @override
  void initState() {
    super.initState();
    final info = widget.info;
    _country = info.countries.contains('TJ')
        ? 'TJ'
        : (info.countries.isEmpty ? 'TJ' : info.countries.first);
    final pendingGoogle = ref.read(sessionProvider).pendingGoogle;
    if (pendingGoogle != null) {
      if (pendingGoogle.firstName.isNotEmpty) {
        _name.text = pendingGoogle.firstName;
      }
      if (pendingGoogle.lastName.isNotEmpty) {
        _lastName.text = pendingGoogle.lastName;
      }
      if (pendingGoogle.email.isNotEmpty) {
        _email.text = pendingGoogle.email;
      }
    }
    _referral.addListener(_onManualReferralChanged);
    _referralService = ref.read(referralServiceProvider);
    _referralService.pendingCodeListenable.addListener(_onIncomingReferralLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadReferralMatch();
    });
  }

  @override
  void dispose() {
    _referralDebounce?.cancel();
    _referral.removeListener(_onManualReferralChanged);
    _referralService.pendingCodeListenable.removeListener(
      _onIncomingReferralLink,
    );
    _name.dispose();
    _lastName.dispose();
    _email.dispose();
    _referral.dispose();
    _day.dispose();
    _year.dispose();
    super.dispose();
  }

  void _onIncomingReferralLink() {
    if (!mounted || _referralDeclined) return;
    _loadReferralMatch();
  }

  Future<void> _loadReferralMatch() async {
    final seq = ++_matchSeq;
    final api = ref.read(loyaltyApiProvider);
    final ctx = await _referralService.matchBeforeRegister(api);
    if (!mounted || seq != _matchSeq) return;
    setState(() => _referralCtx = ctx);
  }

  void _onManualReferralChanged() {
    _referralDebounce?.cancel();
    final code = normalizeReferralCode(_referral.text);
    if (code == null) {
      if (_checkingManualReferral || _manualReferralCheck != null) {
        setState(() {
          _checkingManualReferral = false;
          _manualReferralCheck = null;
        });
      }
      return;
    }
    setState(() {
      _checkingManualReferral = true;
      _manualReferralCheck = null;
    });
    final seq = ++_checkSeq;
    _referralDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final res = await ref.read(loyaltyApiProvider).checkReferral(code);
        if (!mounted || seq != _checkSeq) return;
        setState(() {
          _checkingManualReferral = false;
          _manualReferralCheck = res;
        });
      } catch (_) {
        if (!mounted || seq != _checkSeq) return;
        setState(() {
          _checkingManualReferral = false;
          _manualReferralCheck = null;
        });
      }
    });
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final last = _lastName.text.trim();
    final locale = ref.read(localeProvider);
    final birth = parseBirthDate(
      day: _day.text,
      month: _month == null ? '' : '$_month',
      year: _year.text,
      first: DateTime(minBirthYear),
      last: DateTime(maxBirthYear, 12, 31),
    );
    if (name.length < 2 || last.length < 2) {
      setState(() => _error = 'Напишите имя и фамилию');
      return;
    }
    if (!birth.isOk) {
      setState(() => _error = birthDateError(locale, birth, DateTime(minBirthYear), DateTime(maxBirthYear, 12, 31)));
      return;
    }
    if (!_consent) {
      setState(() => _error = 'Нужно согласие на обработку данных');
      return;
    }
    final pendingGoogle = ref.read(sessionProvider).pendingGoogle;
    final email = pendingGoogle?.email.isNotEmpty == true
        ? pendingGoogle!.email
        : _email.text.trim();
    final autoMatched = _referralCtx.match.found && !_referralDeclined;
    final rawManual = _referral.text.trim().toUpperCase();
    if (!autoMatched &&
        rawManual.isNotEmpty &&
        _manualReferralCheck != null &&
        !_manualReferralCheck!.valid) {
      setState(() => _error = tr(locale, 'reg.referralInvalid'));
      return;
    }
    final effectiveReferral = autoMatched
        ? _referralCtx.match.code
        : (rawManual.isEmpty ? null : rawManual);
    final referralDeclined = _referralDeclined && rawManual.isEmpty;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device =
          _referralCtx.device ?? await _referralService.collectDeviceInfo();
      final gift = await ref.read(sessionProvider.notifier).completeProfile(
        RegisterInput(
          registrationToken: ref.read(sessionProvider).registrationToken ?? '',
          firstName: name,
          lastName: last,
          birthYear: birth.date!.year,
          birthDate: '${birth.date!.year.toString().padLeft(4, '0')}-${birth.date!.month.toString().padLeft(2, '0')}-${birth.date!.day.toString().padLeft(2, '0')}',
          country: _country,
          consentPd: true,
          consentMessages: _messages,
          email: email.isEmpty ? null : email,
          referralCode: effectiveReferral,
          referralDeclined: referralDeclined,
          installReferrer: _referralCtx.installReferrer,
          device: device,
          locale: locale,
        ),
      );
      await _referralService.clearPending();
      if (!mounted) return;
      GoRouter.maybeOf(context)?.go((gift ?? 0) > 0 ? '/welcome-gift' : '/home');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get minBirthYear {
    final info = widget.info;
    return info.birthYearMin <= info.birthYearMax ? info.birthYearMin : info.birthYearMax;
  }

  int get maxBirthYear {
    final info = widget.info;
    return info.birthYearMax >= info.birthYearMin ? info.birthYearMax : info.birthYearMin;
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final locale = ref.watch(localeProvider);
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
          const SizedBox(height: 20),
          if (info.welcomeBonus != null && info.welcomeBonus! > 0) ...[
            Container(
              key: const ValueKey('register-gift-banner'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: PaykColors.brandSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: PaykColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  const Gift3dIcon(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr(locale, 'reg.giftBanner', {
                        'amount': formatMoneyAuto(info.welcomeBonus!),
                      }),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: PaykColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
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
          Text(
            tr(locale, 'profile.birth'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          BirthDateFields(
            day: _day,
            month: _month,
            year: _year,
            locale: locale,
            onMonth: (value) => setState(() => _month = value),
            dayLabel: tr(locale, 'profile.birthDay'),
            monthLabel: tr(locale, 'profile.birthMonth'),
            yearLabel: tr(locale, 'profile.birthYear'),
            enabled: !_busy,
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
          Builder(
            builder: (context) {
              final googleEmail = ref.watch(
                sessionProvider.select((s) => s.pendingGoogle?.email),
              );
              final locked = googleEmail != null && googleEmail.isNotEmpty;
              return TextField(
                key: ValueKey(locked ? 'register-email-google' : 'register-email'),
                controller: _email,
                readOnly: locked,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Почта, если есть',
                  helperText: locked ? tr(locale, 'reg.emailGoogle') : null,
                  prefixIcon: locked
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: GoogleMark(size: 18),
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: PaykMotion.duration(context, PaykMotion.fast),
            curve: PaykMotion.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: PaykMotion.duration(context, PaykMotion.fast),
              switchInCurve: PaykMotion.easeOut,
              switchOutCurve: PaykMotion.easeOut,
              layoutBuilder: PaykMotion.topAlignedLayoutBuilder,
              child: (_referralCtx.match.found && !_referralDeclined)
                  ? Container(
                      key: const ValueKey('register-invited-banner'),
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                      decoration: BoxDecoration(
                        color: PaykColors.incomeSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: PaykColors.success.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: PaykColors.success,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(locale, 'reg.invitedBy', {
                                    'name':
                                        (_referralCtx.match.firstName != null &&
                                            _referralCtx.match.firstName!.isNotEmpty)
                                        ? _referralCtx.match.firstName!
                                        : (_referralCtx.match.code ?? ''),
                                  }),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: PaykColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(locale, 'reg.invitedHint'),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: PaykColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('register-invited-not-this'),
                            onPressed: _busy
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _referralDeclined = true;
                                      _referral.clear();
                                      _manualReferralCheck = null;
                                      _checkingManualReferral = false;
                                    });
                                  },
                            child: Text(
                              tr(locale, 'reg.invitedNotThis'),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: PaykColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      key: const ValueKey('register-referral-input'),
                      controller: _referral,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(16)],
                      decoration: InputDecoration(
                        hintText: 'Код приглашения, если есть',
                        helperText: _checkingManualReferral
                            ? tr(locale, 'reg.referralChecking')
                            : (_manualReferralCheck?.valid == true
                                  ? (_manualReferralCheck!.firstName != null &&
                                            _manualReferralCheck!.firstName!.isNotEmpty
                                        ? tr(locale, 'reg.referralValid', {
                                            'name': _manualReferralCheck!.firstName!,
                                          })
                                        : tr(locale, 'reg.referralValidNoName'))
                                  : null),
                        helperStyle: TextStyle(
                          color: _manualReferralCheck?.valid == true
                              ? PaykColors.success
                              : PaykColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        errorText:
                            (_manualReferralCheck != null &&
                                !_manualReferralCheck!.valid)
                            ? tr(locale, 'reg.referralInvalid')
                            : null,
                      ),
                    ),
            ),
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

/// Экран «Подарок» сразу после регистрации, если сервер начислил `welcome_bonus`.
class WelcomeGiftScreen extends ConsumerStatefulWidget {
  const WelcomeGiftScreen({super.key, this.amount});

  /// Явная сумма (для тестов); в приложении берётся из `sessionProvider.pendingWelcomeBonus`.
  final double? amount;

  @override
  ConsumerState<WelcomeGiftScreen> createState() => _WelcomeGiftScreenState();
}

class _WelcomeGiftScreenState extends ConsumerState<WelcomeGiftScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: PaykMotion.normal,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _enter,
    curve: PaykMotion.easeSpring,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: PaykMotion.entranceScale,
    end: 1.0,
  ).animate(_curve);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.03),
    end: Offset.zero,
  ).animate(_curve);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (PaykMotion.shouldReduceMotion(context)) {
      _enter.value = 1.0;
    } else {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _finish(BuildContext context) {
    HapticFeedback.lightImpact();
    ref.read(sessionProvider.notifier).dismissWelcomeBonus();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/home');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final bonus =
        widget.amount ?? ref.watch(sessionProvider).pendingWelcomeBonus ?? 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(context);
      },
      child: Scaffold(
        backgroundColor: PaykColors.canvas,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: FadeTransition(
                opacity: _curve,
                child: SlideTransition(
                  position: _slide,
                  child: ScaleTransition(
                    scale: _scale,
                    child: RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Gift3dIcon(size: 112),
                          const SizedBox(height: 20),
                          Text(
                            tr(locale, 'gift.title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: PaykColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '+${formatMoneyAuto(bonus)}',
                            key: const ValueKey('welcome-gift-amount'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: PaykColors.success,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Text(
                              tr(locale, 'gift.text'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                                color: PaykColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          PaykPressable(
                            child: FilledButton(
                              key: const ValueKey('welcome-gift-done'),
                              onPressed: () => _finish(context),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                tr(locale, 'gift.cta'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
