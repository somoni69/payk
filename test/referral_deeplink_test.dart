import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:payk/app/router.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/i18n/strings.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/auth_screens.dart';
import 'package:payk/features/auth/splash_screen.dart';

class _TestLocale extends LocaleController {
  _TestLocale(this.value);
  final String value;

  @override
  String build() => value;
}

class _SplashDone extends SplashGate {
  @override
  bool build() => true;
}

class _SessionStub extends SessionController {
  _SessionStub(this._initial);
  final SessionState _initial;

  RegisterInput? lastRegisterInput;

  @override
  SessionState build() => _initial;

  @override
  Future<double?> completeProfile(RegisterInput input) async {
    lastRegisterInput = input;
    state = state.copyWith(
      ready: true,
      accessToken: 'acc',
      refreshToken: 'ref',
      clearRegistration: true,
    );
    return null;
  }
}

class _FakeReferralApi extends Fake implements LoyaltyApi {
  _FakeReferralApi({
    this.matchResult = ReferralMatch.notFound,
    this.checkResult = const ReferralCheck(valid: true, firstName: 'Сомон'),
  });

  ReferralMatch matchResult;
  ReferralCheck checkResult;

  String? lastMatchCode;
  String? lastMatchInstallReferrer;
  ReferralDeviceInfo? lastMatchDevice;
  String? lastCheckedCode;

  @override
  Future<ReferralMatch> matchReferral({
    String? code,
    String? click,
    String? installReferrer,
    ReferralDeviceInfo? device,
  }) async {
    lastMatchCode = code;
    lastMatchInstallReferrer = installReferrer;
    lastMatchDevice = device;
    return matchResult;
  }

  @override
  Future<ReferralCheck> checkReferral(String code) async {
    lastCheckedCode = code;
    return checkResult;
  }
}

const _program = ProgramInfo(
  title: 'Алмоси',
  store: 'MSX Алмоси',
  enabled: true,
  countries: ['TJ', 'RU'],
  birthYearMin: 1940,
  birthYearMax: 2012,
  welcomeBonus: 100,
);

const _androidDevice = ReferralDeviceInfo(
  platform: 'android',
  osVersion: '14',
  model: 'Pixel 8',
  language: 'ru-RU',
  timezone: 'Asia/Dushanbe',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Referral URI parsing and models (0074)', () {
    test('extracts and normalizes code from Universal/App Link and query params', () {
      expect(
        parseReferralCodeFromUri(
          Uri.parse('https://payk-loyalty.vercel.app/r/az-4821'),
        ),
        'AZ-4821',
      );
      expect(
        parseReferralCodeFromUri(Uri.parse('/r/so-6850/')),
        'SO-6850',
      );
      expect(
        parseReferralCodeFromUri(
          Uri.parse('https://payk-loyalty.vercel.app/?payk_ref=ab-1234'),
        ),
        'AB-1234',
      );
      expect(
        parseReferralCodeFromUri(
          Uri.parse('https://payk-loyalty.vercel.app/r/!bad!'),
        ),
        isNull,
      );
      expect(normalizeReferralCode('  a1 '), isNull);
    });

    test('RegisterInput serializes referral_declined, install_referrer, device and locale', () {
      const input = RegisterInput(
        registrationToken: 'token-1234567890',
        firstName: 'Фарзод',
        lastName: 'Сомони',
        birthYear: 1995,
        birthDate: '1995-05-10',
        country: 'TJ',
        consentPd: true,
        consentMessages: false,
        referralCode: null,
        referralDeclined: true,
        installReferrer: 'payk_ref=AZ-4821&payk_click=tok123',
        device: _androidDevice,
        locale: 'tj',
      );
      final json = input.toJson();

      expect(json['referral_code'], isNull);
      expect(json['referral_declined'], isTrue);
      expect(json['install_referrer'], 'payk_ref=AZ-4821&payk_click=tok123');
      expect(json['locale'], 'tj');
      expect(json['device'], {
        'platform': 'android',
        'os_version': '14',
        'model': 'Pixel 8',
        'language': 'ru-RU',
        'timezone': 'Asia/Dushanbe',
      });
    });

    test('gift.text capitalizes and quotes Супермаркет in RU and TJ (2d058c1)', () {
      expect(tr('ru', 'gift.text'), contains('«Супермаркете»'));
      expect(tr('tj', 'gift.text'), contains('«Супермаркет»'));
    });

    test('ReferralService reads initial link + install referrer, matches via API, and clears pending', () async {
      final api = _FakeReferralApi(
        matchResult: const ReferralMatch(
          found: true,
          code: 'AZ-4821',
          firstName: 'Азиз',
          source: 'install',
        ),
      );
      final service = ReferralService(
        readInitialLink: () async => 'https://payk-loyalty.vercel.app/r/AZ-4821',
        readInstallReferrer: () async => 'payk_ref=AZ-4821&payk_click=clk99',
        readDeviceInfo: () async => _androidDevice,
      );
      addTearDown(service.dispose);

      final ctx = await service.matchBeforeRegister(api);

      expect(ctx.match.found, isTrue);
      expect(ctx.match.code, 'AZ-4821');
      expect(ctx.match.firstName, 'Азиз');
      expect(ctx.installReferrer, 'payk_ref=AZ-4821&payk_click=clk99');
      expect(api.lastMatchCode, 'AZ-4821');
      expect(api.lastMatchInstallReferrer, 'payk_ref=AZ-4821&payk_click=clk99');
      expect(api.lastMatchDevice?.model, 'Pixel 8');

      await service.clearPending();
      expect(service.pendingCode, isNull);
      expect(service.installReferrer, isNull);
    });
  });

  group('Router /r/:code Universal & App Link handling', () {
    testWidgets('captures referral code and redirects logged-out user to /auth/phone', (
      tester,
    ) async {
      final referral = ReferralService(
        readInitialLink: () async => null,
        readInstallReferrer: () async => null,
        readDeviceInfo: () async => null,
      );
      addTearDown(referral.dispose);

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => _SessionStub(
              const SessionState(ready: true, onboardingSeen: true),
            ),
          ),
          splashFinishedProvider.overrideWith(_SplashDone.new),
          programProvider.overrideWith((ref) => _program),
          referralServiceProvider.overrideWithValue(referral),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: PaykTheme.light, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/r/az-4821');
      await tester.pumpAndSettle();

      expect(referral.pendingCode, 'AZ-4821');
      expect(router.state.matchedLocation, '/auth/phone');
    });
  });

  group('ProfileSetupScreen automatic referral binding', () {
    Future<void> fillRequiredFields(WidgetTester tester) async {
      await tester.enterText(find.widgetWithText(TextField, 'Имя'), 'Фарзод');
      await tester.enterText(find.widgetWithText(TextField, 'Фамилия'), 'Сомони');
      await tester.enterText(find.widgetWithText(TextField, 'День'), '10');
      await tester.tap(find.byIcon(Icons.expand_more_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Май').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Год'), '1995');

      final consent = find.text('Согласие на обработку персональных данных');
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
    }

    testWidgets('shows «Вас пригласил …» banner and submits auto referral + device + install_referrer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _FakeReferralApi(
        matchResult: const ReferralMatch(
          found: true,
          code: 'AZ-4821',
          firstName: 'Азиз',
          source: 'install',
        ),
      );
      final referral = ReferralService(
        readInitialLink: () async => null,
        readInstallReferrer: () async => 'payk_ref=AZ-4821&payk_click=tok1',
        readDeviceInfo: () async => _androidDevice,
      );
      addTearDown(referral.dispose);
      final session = _SessionStub(
        const SessionState(
          ready: true,
          onboardingSeen: true,
          pendingPhone: '+992900000000',
          registrationToken: 'reg-token-1234567890',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          localeProvider.overrideWith(() => _TestLocale('ru')),
          programProvider.overrideWith((ref) => _program),
          loyaltyApiProvider.overrideWithValue(api),
          referralServiceProvider.overrideWithValue(referral),
          sessionProvider.overrideWith(() => session),
          splashFinishedProvider.overrideWith(_SplashDone.new),
          meProvider.overrideWith((ref) => throw UnimplementedError()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const ProfileSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('register-invited-banner')), findsOneWidget);
      expect(find.text('Вас пригласил Азиз'), findsOneWidget);
      expect(find.text('Приглашение засчитается автоматически'), findsOneWidget);
      expect(find.text('Не тот?'), findsOneWidget);
      expect(find.byKey(const ValueKey('register-referral-input')), findsNothing);

      await fillRequiredFields(tester);

      final submit = find.text('Открыть карту');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      final sent = session.lastRegisterInput;
      expect(sent, isNotNull);
      expect(sent!.referralCode, 'AZ-4821');
      expect(sent.referralDeclined, isFalse);
      expect(sent.installReferrer, 'payk_ref=AZ-4821&payk_click=tok1');
      expect(sent.device?.platform, 'android');
      expect(sent.device?.model, 'Pixel 8');
      expect(referral.installReferrer, isNull);
    });

    testWidgets('tapping «Не тот?» hides banner, shows manual field, and sends referral_declined: true when left empty', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _FakeReferralApi(
        matchResult: const ReferralMatch(
          found: true,
          code: 'AZ-4821',
          firstName: 'Азиз',
          source: 'match',
        ),
      );
      final referral = ReferralService(
        readInitialLink: () async => null,
        readInstallReferrer: () async => null,
        readDeviceInfo: () async => _androidDevice,
      );
      addTearDown(referral.dispose);
      final session = _SessionStub(
        const SessionState(
          ready: true,
          onboardingSeen: true,
          pendingPhone: '+992900000000',
          registrationToken: 'reg-token-1234567890',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            programProvider.overrideWith((ref) => _program),
            loyaltyApiProvider.overrideWithValue(api),
            referralServiceProvider.overrideWithValue(referral),
            sessionProvider.overrideWith(() => session),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const ProfileSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('register-invited-not-this')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('register-invited-banner')), findsNothing);
      expect(find.byKey(const ValueKey('register-referral-input')), findsOneWidget);

      await fillRequiredFields(tester);

      final submit = find.text('Открыть карту');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      final sent = session.lastRegisterInput;
      expect(sent, isNotNull);
      expect(sent!.referralCode, isNull);
      expect(sent.referralDeclined, isTrue);
    });

    testWidgets('manual code after «Не тот?» checks via API and sends referral_declined: false', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final api = _FakeReferralApi(
        matchResult: const ReferralMatch(
          found: true,
          code: 'AZ-4821',
          firstName: 'Азиз',
          source: 'match',
        ),
        checkResult: const ReferralCheck(valid: true, firstName: 'Сомон'),
      );
      final referral = ReferralService(
        readInitialLink: () async => null,
        readInstallReferrer: () async => null,
        readDeviceInfo: () async => _androidDevice,
      );
      addTearDown(referral.dispose);
      final session = _SessionStub(
        const SessionState(
          ready: true,
          onboardingSeen: true,
          pendingPhone: '+992900000000',
          registrationToken: 'reg-token-1234567890',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            programProvider.overrideWith((ref) => _program),
            loyaltyApiProvider.overrideWithValue(api),
            referralServiceProvider.overrideWithValue(referral),
            sessionProvider.overrideWith(() => session),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const ProfileSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('register-invited-not-this')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('register-referral-input')),
        'sm-7777',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(api.lastCheckedCode, 'SM-7777');
      expect(find.text('Вас пригласил Сомон'), findsOneWidget);

      await fillRequiredFields(tester);

      final submit = find.text('Открыть карту');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      final sent = session.lastRegisterInput;
      expect(sent, isNotNull);
      expect(sent!.referralCode, 'SM-7777');
      expect(sent.referralDeclined, isFalse);
    });
  });
}
