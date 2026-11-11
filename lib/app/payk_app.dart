import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/locale_controller.dart';
import '../core/notifications/push_notification_service.dart';
import '../core/theme/payk_colors.dart';
import '../core/theme/payk_theme.dart';
import '../data/providers.dart';
import '../features/code/pending_payment_host.dart';
import 'router.dart';

class PaykApp extends ConsumerStatefulWidget {
  const PaykApp({super.key});

  @override
  ConsumerState<PaykApp> createState() => _PaykAppState();
}

class _PaykAppState extends ConsumerState<PaykApp> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initNotifications();
      });
    }
  }

  void _initNotifications() {
    final router = ref.read(routerProvider);
    ref
        .read(pushNotificationServiceProvider)
        .initialize(
          onNotificationTap: (route) {
            if (mounted) {
              router.push(route);
            }
          },
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

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (prev, next) {
      if ((prev == null || !prev.loggedIn) && next.loggedIn) {
        final token = ref.read(pushNotificationServiceProvider).fcmToken;
        if (token != null) {
          ref.read(loyaltyApiProvider).updateMe({'fcm_token': token}).ignore();
        }
      }
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
