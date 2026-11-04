import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/locale_controller.dart';
import '../core/theme/payk_colors.dart';
import '../core/theme/payk_theme.dart';
import 'router.dart';

class PaykApp extends ConsumerWidget {
  const PaykApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        final wrapped = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: textClamped,
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
