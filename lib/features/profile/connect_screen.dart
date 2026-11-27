import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/google_widgets.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Экран «Способы входа» (перенесён из loyalty-app/src/app/(app)/profile/connect/page.tsx)
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  TelegramLinks? _link;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  bool _opened = false;
  bool _googleBusy = false;
  GoogleLinkStart? _googlePending;

  @override
  void initState() {
    super.initState();
    _load(announce: false);
  }

  Future<void> _load({required bool announce}) async {
    setState(() {
      _loading = _link == null;
      _error = null;
    });

    try {
      final fresh = await ref.read(loyaltyApiProvider).telegram();
      if (!mounted) return;

      final previousLinked = _link?.linked;
      setState(() {
        _link = fresh;
        _loading = false;
        _error = null;
      });

      if (announce && fresh.linked && previousLinked == false) {
        final locale = ref.read(localeProvider);
        showPaykMessage(context, tr(locale, 'connect.linked'));
        ref.invalidate(meProvider);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _unlink() async {
    final locale = ref.read(localeProvider);
    setState(() => _busy = true);

    try {
      await ref.read(loyaltyApiProvider).unlinkTelegram();
      if (!mounted) return;

      setState(() {
        _link = _link != null
            ? TelegramLinks(
                bot: _link!.bot,
                appLink: _link!.appLink,
                webLink: _link!.webLink,
                token: _link!.token,
                linked: false,
              )
            : null;
        _opened = false;
      });

      ref.invalidate(meProvider);
      showPaykMessage(context, tr(locale, 'connect.unlinked'));
    } catch (e) {
      if (mounted) showPaykMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTelegram() async {
    final locale = ref.read(localeProvider);
    if (_link == null) return;

    setState(() => _opened = true);
    HapticFeedback.lightImpact();

    // Копируем команду активации бота
    final cmd = '/start ${_link!.token}'.trim();
    await Clipboard.setData(ClipboardData(text: cmd));
    if (mounted) {
      showPaykMessage(context, tr(locale, 'connect.manual', {'bot': _link!.bot}));
    }
  }

  Future<void> _recheck() async {
    final locale = ref.read(localeProvider);
    setState(() => _busy = true);
    await _load(announce: true);
    if (!mounted) return;
    setState(() => _busy = false);

    if (_link != null && !_link!.linked) {
      showPaykMessage(context, tr(locale, 'connect.notYet'));
    }
  }

  Future<void> _copyStartCommand() async {
    final locale = ref.read(localeProvider);
    if (_link == null) return;

    final cmd = '/start ${_link!.token}'.trim();
    await Clipboard.setData(ClipboardData(text: cmd));
    HapticFeedback.lightImpact();
    if (mounted) {
      showPaykMessage(context, tr(locale, 'common.copied'));
    }
  }

  Future<void> _linkGoogle() async {
    if (_googleBusy) return;
    final locale = ref.read(localeProvider);
    setState(() => _googleBusy = true);
    try {
      final idToken = await ref.read(googleAuthServiceProvider).requestIdToken();
      if (!mounted) return;
      if (idToken == null || idToken.isEmpty) return;

      final res = await ref.read(loyaltyApiProvider).linkGoogle(idToken);
      if (!mounted) return;
      if (res.needsConfirm) {
        setState(() => _googlePending = res);
      } else {
        ref.invalidate(meProvider);
        showPaykMessage(context, tr(locale, 'connect.googleLinked'));
      }
    } on ApiException catch (error) {
      if (mounted) showPaykMessage(context, errorText(error));
    } catch (error, stackTrace) {
      debugPrint('Google link failed: $error\n$stackTrace');
      if (mounted) showPaykMessage(context, tr(locale, 'google.failed'));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _unlinkGoogle() async {
    if (_googleBusy) return;
    final locale = ref.read(localeProvider);
    setState(() => _googleBusy = true);
    try {
      await ref.read(loyaltyApiProvider).unlinkGoogle();
      if (!mounted) return;
      ref.invalidate(meProvider);
      showPaykMessage(context, tr(locale, 'connect.googleUnlinked'));
    } catch (error) {
      if (mounted) showPaykMessage(context, errorText(error));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  void _finishGoogleLink() {
    final locale = ref.read(localeProvider);
    setState(() => _googlePending = null);
    ref.invalidate(meProvider);
    showPaykMessage(context, tr(locale, 'connect.googleLinked'));
  }

  void _cancelGoogleLink() {
    setState(() => _googlePending = null);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final meAsync = ref.watch(meProvider);

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.sheet,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: PaykPressable(
          scaleDown: PaykMotion.scaleIcon,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: PaykColors.textPrimary, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
          ),
        ),
        title: Text(
          tr(locale, 'connect.title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: PaykColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: PaykColors.border, height: 1),
        ),
      ),
      body: AsyncView(
        value: meAsync,
        loading: const ConnectSkeleton(),
        onRetry: () {
          ref.invalidate(meProvider);
          _load(announce: false);
        },
        data: (account) {
          final member = account.member;
          final isLinked = _link?.linked ?? member.telegram;
          final googleLink = member.google;
          final googleAvailable = ref.watch(googleAuthServiceProvider).isAvailable;
          final showGoogleCard =
              googleLink != null || _googlePending != null || googleAvailable;

          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: [
              // Карточка 1: SMS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaykColors.sheet,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PaykColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _MethodIcon(
                      ok: true,
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: PaykColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(locale, 'connect.sms'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: PaykColors.textPrimary,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(locale, 'connect.smsText', {'phone': formatPhone(member.phone)}),
                            style: const TextStyle(
                              fontSize: 14.0,
                              color: PaykColors.textSecondary,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Карточка 2: Google (на Android или если уже привязан)
              if (showGoogleCard) ...[
                Container(
                  key: const ValueKey('connect-google'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PaykColors.sheet,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PaykColors.border),
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
                      Row(
                        children: [
                          _MethodIcon(
                            ok: googleLink != null,
                            child: const GoogleMark(size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: PaykColors.textPrimary,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  googleLink != null
                                      ? tr(locale, 'connect.googleOn', {
                                          'email': googleLink.email,
                                        })
                                      : tr(locale, 'connect.googleOff'),
                                  key: const ValueKey('connect-google-state'),
                                  style: const TextStyle(
                                    fontSize: 14.0,
                                    color: PaykColors.textSecondary,
                                    fontFamily: 'Inter',
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_googlePending != null) ...[
                        const SizedBox(height: 16),
                        _GoogleLinkConfirm(
                          pending: _googlePending!,
                          locale: locale,
                          onDone: _finishGoogleLink,
                          onCancel: _cancelGoogleLink,
                        ),
                      ] else if (googleLink != null) ...[
                        const SizedBox(height: 16),
                        PaykPressable(
                          enabled: !_googleBusy,
                          child: SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton(
                              key: const ValueKey('connect-google-unlink'),
                              onPressed: _googleBusy ? null : _unlinkGoogle,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                foregroundColor: const Color(0xFFEF4444),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _googleBusy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      tr(locale, 'connect.googleDisconnect'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ] else if (googleAvailable) ...[
                        const SizedBox(height: 16),
                        GoogleContinueButton(
                          key: const ValueKey('connect-google-link'),
                          label: tr(locale, 'connect.googleConnect'),
                          busy: _googleBusy,
                          onPressed: _linkGoogle,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Карточка 3: Telegram
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PaykColors.sheet,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PaykColors.border),
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
                    Row(
                      children: [
                        _MethodIcon(
                          ok: isLinked,
                          child: const Icon(
                            Icons.send_rounded,
                            color: Color(0xFF229ED9),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Telegram',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: PaykColors.textPrimary,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isLinked
                                    ? tr(locale, 'connect.telegramOn')
                                    : tr(locale, 'connect.telegramOff'),
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  color: PaykColors.textSecondary,
                                  fontFamily: 'Inter',
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_loading) ...[
                      const SizedBox(height: 16),
                      const ShimmerSweep(child: SkeletonBox(height: 46, radius: 14)),
                    ] else if (_error != null && _link == null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFE53935), fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _load(announce: false),
                        child: Text(tr(locale, 'common.retry')),
                      ),
                    ] else if (isLinked) ...[
                      const SizedBox(height: 16),
                      PaykPressable(
                        enabled: !_busy,
                        child: SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: _busy ? null : _unlink,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              foregroundColor: const Color(0xFFEF4444),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    tr(locale, 'connect.disconnect'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      PaykPressable(
                        enabled: !_busy,
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _openTelegram,
                            style: FilledButton.styleFrom(
                              backgroundColor: PaykColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              tr(locale, 'connect.connect'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_opened) ...[
                        const SizedBox(height: 10),
                        PaykPressable(
                          enabled: !_busy,
                          child: SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _busy ? null : _recheck,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: PaykColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      tr(locale, 'connect.refresh'),
                                      style: const TextStyle(
                                        color: PaykColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                      if (_link != null && _link!.token.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: PaykColors.tile,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: PaykColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(locale, 'connect.manual', {'bot': _link!.bot}),
                                style: const TextStyle(
                                  fontSize: 13.0,
                                  color: PaykColors.textSecondary,
                                  fontFamily: 'Inter',
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: PaykColors.border),
                                      ),
                                      child: Text(
                                        '/start ${_link!.token}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: PaykColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PaykPressable(
                                    scaleDown: PaykMotion.scaleIcon,
                                    child: IconButton(
                                      onPressed: _copyStartCommand,
                                      icon: const Icon(Icons.copy_rounded, color: PaykColors.primary, size: 20),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: const BorderSide(color: PaykColors.border),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GoogleLinkConfirm extends ConsumerStatefulWidget {
  const _GoogleLinkConfirm({
    required this.pending,
    required this.locale,
    required this.onDone,
    required this.onCancel,
  });

  final GoogleLinkStart pending;
  final String locale;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  ConsumerState<_GoogleLinkConfirm> createState() => _GoogleLinkConfirmState();
}

class _GoogleLinkConfirmState extends ConsumerState<_GoogleLinkConfirm> {
  final _code = TextEditingController();
  Timer? _timer;
  DateTime? _resendAt;
  String? _debugCode;
  String? _error;
  bool _sending = false;
  bool _busy = false;
  String _lastTried = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sendCode();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _resendAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  int get _resendLeft {
    final target = _resendAt;
    if (target == null) return 0;
    final left = target.difference(DateTime.now()).inSeconds;
    return left > 0 ? left : 0;
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _abort(Object error) {
    if (!mounted) return;
    showPaykMessage(context, errorText(error));
    widget.onCancel();
  }

  Future<void> _sendCode() async {
    final ticket = widget.pending.ticket;
    if (ticket == null || ticket.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final res = await ref.read(loyaltyApiProvider).googleLinkCode(ticket);
      if (!mounted) return;
      setState(() {
        _resendAt = DateTime.now().add(Duration(seconds: res.resendIn));
        _debugCode = res.debugCode;
        _code.clear();
        _lastTried = '';
      });
    } on ApiException catch (error) {
      if (error.status == 401) {
        _abort(error);
      } else if (mounted) {
        setState(() => _error = errorText(error));
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirm(String digits) async {
    final ticket = widget.pending.ticket;
    if (ticket == null || ticket.isEmpty || _busy) return;
    _lastTried = digits;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyApiProvider).googleLinkConfirm(ticket, digits);
      if (!mounted) return;
      widget.onDone();
    } on ApiException catch (error) {
      if (error.status == 401 || error.status == 409) {
        _abort(error);
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = errorText(error);
        _code.clear();
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorText(error);
        _code.clear();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final left = _resendLeft;

    return Column(
      key: const ValueKey('connect-google-confirm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(locale, 'connect.googleConfirm', {
            'email': widget.pending.email ?? '',
            'phone': formatPhone(widget.pending.phone ?? ''),
          }),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: PaykColors.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('connect-google-code'),
          controller: _code,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: PaykColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            labelText: tr(locale, 'connect.googleCode'),
            errorText: _error,
          ),
          onChanged: (value) {
            final digits = value.replaceAll(RegExp(r'\D'), '');
            if (_error != null) setState(() => _error = null);
            if (digits.length == 6 && digits != _lastTried && !_busy) {
              unawaited(_confirm(digits));
            }
          },
        ),
        if (_debugCode != null && _debugCode!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _debugCode!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: PaykColors.textMuted,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PaykColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr(locale, 'login.verifying'),
                style: const TextStyle(
                  fontSize: 13,
                  color: PaykColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (left > 0)
              Text(
                tr(locale, 'login.resendIn', {'time': _formatCountdown(left)}),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: PaykColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )
            else
              TextButton(
                key: const ValueKey('connect-google-resend'),
                onPressed: (_sending || _busy) ? null : _sendCode,
                child: Text(tr(locale, 'login.resend')),
              ),
            TextButton(
              key: const ValueKey('connect-google-cancel'),
              onPressed: _busy ? null : widget.onCancel,
              child: Text(tr(locale, 'connect.googleCancel')),
            ),
          ],
        ),
      ],
    );
  }
}

class _MethodIcon extends StatelessWidget {
  const _MethodIcon({required this.ok, required this.child});

  final bool ok;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PaykColors.border, width: 1.0),
            ),
            alignment: Alignment.center,
            child: child,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: ok ? PaykColors.success : const Color(0xFFE3E1EC),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Icon(
                ok ? Icons.check_rounded : Icons.add_rounded,
                size: 11,
                color: ok ? Colors.white : const Color(0xFF6F7073),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
