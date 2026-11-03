import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payk/app/router.dart';
import 'package:payk/data/session/session_controller.dart';
import 'package:payk/features/auth/splash_screen.dart';

void main() {
  testWidgets('Fresh install navigates to onboarding after splash without redirect loop', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _FreshSessionController()),
        splashFinishedProvider.overrideWith(() => _FinishedSplashGate()),
      ],
    );

    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify errorBuilder was NOT triggered
    expect(find.text("Страница не найдена"), findsNothing);
    // Verify we are at onboarding
    expect(router.state.matchedLocation, equals('/onboarding'));
  });

  testWidgets('User with completed onboarding navigates to /auth/phone', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _OnboardingSeenSessionController()),
        splashFinishedProvider.overrideWith(() => _FinishedSplashGate()),
      ],
    );

    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("Страница не найдена"), findsNothing);
    expect(router.state.matchedLocation, equals('/auth/phone'));
  });
}

class _FreshSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(ready: true, onboardingSeen: false);
}

class _OnboardingSeenSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(ready: true, onboardingSeen: true);
}

class _FinishedSplashGate extends SplashGate {
  @override
  bool build() => true;
}
