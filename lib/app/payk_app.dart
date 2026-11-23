import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/locale_controller.dart';
import '../core/notifications/push_notification_service.dart';
import '../core/theme/payk_colors.dart';
import '../core/theme/payk_theme.dart';
import '../data/providers.dart';
import '../features/auth/splash_screen.dart';
import '../features/code/pending_payment_host.dart';
import 'router.dart';

class PaykApp extends ConsumerStatefulWidget {
  const PaykApp({super.key});

  @override
  ConsumerState<PaykApp> createState() => _PaykAppState();
}

class _PaykAppState extends ConsumerState<PaykApp> {
  String? _pendingNotificationRoute;
  var _flushScheduled = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initNotifications();
        ref.read(referralServiceProvider).initialize().ignore();
      });
    }
  }

  void _initNotifications() {
    ref
        .read(pushNotificationServiceProvider)
        .initialize(
          onNotificationTap: _handleNotificationTap,
          onForegroundMessage: _refreshNotificationData,
          onTokenUpdate: (token) async {
            try {
              if (ref.read(sessionProvider).loggedIn) {
                await ref.read(loyaltyApiProvider).updateMe({
                  'fcm_token': token,
                });
              }
            } catch (_) {}
          },
        );
  }

  void _refreshNotificationData() {
    if (!mounted || !ref.read(sessionProvider).loggedIn) return;
    ref.invalidate(messagesProvider);
    ref.invalidate(meProvider);
  }

  void _handleNotificationTap(String route) {
    if (!mounted) return;
    final target = route.startsWith('/') ? route : '/notifications';
    final session = ref.read(sessionProvider);
    final splashDone = ref.read(splashFinishedProvider);

    if (!session.ready || !splashDone || !session.loggedIn) {
      _pendingNotificationRoute = target;
      return;
    }

    _openNotificationRoute(target);
  }

  void _flushPendingNotification() {
    if (_pendingNotificationRoute == null || _flushScheduled || !mounted) {
      return;
    }
    final session = ref.read(sessionProvider);
    final splashDone = ref.read(splashFinishedProvider);
    if (!session.ready || !splashDone || !session.loggedIn) {
      return;
    }

    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (!mounted) return;
      final currentSession = ref.read(sessionProvider);
      if (!currentSession.ready ||
          !currentSession.loggedIn ||
          !ref.read(splashFinishedProvider)) {
        return;
      }
      final target = _pendingNotificationRoute;
      if (target == null) return;
      _pendingNotificationRoute = null;
      _openNotificationRoute(target);
    });
  }

  void _openNotificationRoute(String target) {
    _refreshNotificationData();
    final router = ref.read(routerProvider);
    if (router.state.matchedLocation != target) {
      router.push(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (prev, next) {
      if ((prev == null || !prev.loggedIn) && next.loggedIn) {
        final token = ref.read(pushNotificationServiceProvider).fcmToken;
        if (token != null) {
          ref.read(loyaltyApiProvider).updateMe({'fcm_token': token}).ignore();
        }
      }
      if (prev?.loggedIn == true && !next.loggedIn) {
        _pendingNotificationRoute = null;
      } else {
        _flushPendingNotification();
      }
    });

    ref.listen(splashFinishedProvider, (prev, next) {
      if (next) _flushPendingNotification();
    });

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Payk',
      theme: PaykTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        final textClamped = MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.25,
          child: content,
        );
        final wrapped = PendingPaymentHost(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: textClamped,
          ),
        );

        if (!kIsWeb) {
          return wrapped;
        }

        return ColoredBox(
          color: PaykColors.frame,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: wrapped,
            ),
          ),
        );
      },
      locale: Locale(ref.watch(localeProvider) == 'tj' ? 'ru' : 'ru'),
      supportedLocales: const [Locale('ru'), Locale('tg')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
