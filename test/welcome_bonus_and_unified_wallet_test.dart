import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payk/app/router.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/core/widgets/payk_3d_icon.dart';
import 'package:payk/data/api/api_client.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/auth_screens.dart';
import 'package:payk/features/auth/splash_screen.dart';
import 'package:payk/features/notifications/notifications_screen.dart';
import 'package:payk/features/rules/rules_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestLocale extends LocaleController {
  _TestLocale(this._locale);
  final String _locale;

  @override
  String build() => _locale;
}

class _FakeRegisterApi extends Fake implements LoyaltyApi {
  _FakeRegisterApi({this.welcomeBonus});

  final double? welcomeBonus;

  @override
  Future<RegisterResult> register(RegisterInput input) async {
    return RegisterResult(
      tokens: const TokenPair(
        accessToken: 'acc_tok',
        refreshToken: 'ref_tok',
      ),
      welcomeBonus: welcomeBonus,
    );
  }

  @override
  Future<int> markMessagesRead({int? upToId}) async => 0;
}

class _ReadyRegistrationSession extends SessionController {
  @override
  SessionState build() => const SessionState(
    ready: true,
    onboardingSeen: true,
    pendingPhone: '+992900000000',
    registrationToken: 'reg_tok_1',
  );
}

class _ImmediateSplash extends SplashGate {
  @override
  bool build() => true;
}

Account _sampleAccount() {
  return const Account(
    member: Member(
      firstName: 'Фарзод',
      lastName: 'Сомони',
      phone: '+992900000000',
      referralCode: 'SO-4654',
    ),
    wallet: Wallet(
      status: 1,
      balance: 100,
      onHold: 0,
      debt: 0,
      spendMonth: 0,
      spendSupermarket: 0,
      spendClothes: 0,
      daysLeft: 10,
      keep: null,
      up: null,
      nextMonthStatus: 1,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.02, burnCap: 0.01),
        clothes: Rate(earn: 0.05, burnCap: 0.10),
      ),
      todaySupermarket: 0,
      todayClothes: 0,
    ),
    store: 'MSX Алмоси',
    programEnabled: true,
  );
}

void main() {
  group('Welcome bonus models & API parsing', () {
    test('ProgramInfo, RulesInfo, and RegisterResult parse welcome_bonus cleanly', () {
      final pWith = ProgramInfo.fromJson({
        'title': 'ПАЙК',
        'store': 'Алмоси',
        'enabled': true,
        'countries': ['TJ'],
        'birth_year_min': 1930,
        'birth_year_max': 2012,
        'welcome_bonus': 100,
      });
      expect(pWith.welcomeBonus, 100.0);

      final pZero = ProgramInfo.fromJson({
        'title': 'ПАЙК',
        'store': 'Алмоси',
        'enabled': true,
        'countries': ['TJ'],
        'birth_year_min': 1930,
        'birth_year_max': 2012,
        'welcome_bonus': 0,
      });
      expect(pZero.welcomeBonus, isNull);

      final rWith = RulesInfo.fromJson({
        'thresholds': [1800],
        'statuses': [],
        'referral': {'levels': [0.01], 'months': 12},
        'welcome_bonus': 100.5,
      });
      expect(rWith.welcomeBonus, 100.5);

      final rNull = RulesInfo.fromJson({
        'thresholds': [1800],
        'statuses': [],
        'referral': {'levels': [0.01], 'months': 12},
        'welcome_bonus': null,
      });
      expect(rNull.welcomeBonus, isNull);

      final reg = RegisterResult.fromJson({
        'access_token': 'a1',
        'refresh_token': 'r1',
        'welcome_bonus': 100,
      });
      expect(reg.tokens.accessToken, 'a1');
      expect(reg.welcomeBonus, 100.0);
    });

    test('LoyaltyApi.register parses tokens and welcome_bonus', () async {
      final client = ApiClient(
        readTokens: () => null,
        writeTokens: (_, _) {},
        onExpired: () {},
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, endsWith('/register'));
          return http.Response(
            jsonEncode({
              'status': 'login',
              'access_token': 'tok_a',
              'refresh_token': 'tok_r',
              'welcome_bonus': 100,
            }),
            201,
          );
        }),
      );
      final api = LoyaltyApi(client);
      final res = await api.register(
        const RegisterInput(
          registrationToken: 'reg',
          firstName: 'Иван',
          lastName: 'Петров',
          birthYear: 1995,
          birthDate: '1995-05-10',
          country: 'TJ',
          consentPd: true,
          consentMessages: false,
        ),
      );
      expect(res.tokens.accessToken, 'tok_a');
      expect(res.welcomeBonus, 100.0);
    });
  });

  group('Welcome bonus UI flow', () {
    testWidgets('PhoneScreen shows welcome gift promo when enabled and hides when null', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            programProvider.overrideWith(
              (ref) async => const ProgramInfo(
                title: 'ПАЙК',
                store: 'Алмоси',
                enabled: true,
                countries: ['TJ'],
                birthYearMin: 1930,
                birthYearMax: 2012,
                welcomeBonus: 100,
              ),
            ),
          ],
          child: MaterialApp(theme: PaykTheme.light, home: const PhoneScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login-welcome-promo')), findsOneWidget);
      expect(find.text('100 смн в подарок'), findsOneWidget);
      expect(find.byType(Gift3dIcon), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            programProvider.overrideWith(
              (ref) async => const ProgramInfo(
                title: 'ПАЙК',
                store: 'Алмоси',
                enabled: true,
                countries: ['TJ'],
                birthYearMin: 1930,
                birthYearMax: 2012,
                welcomeBonus: null,
              ),
            ),
          ],
          child: MaterialApp(theme: PaykTheme.light, home: const PhoneScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login-welcome-promo')), findsNothing);
    });

    testWidgets('ProfileSetupScreen shows gift banner and routes to WelcomeGiftScreen after register', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'payk.onboarding': true});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          localeProvider.overrideWith(() => _TestLocale('ru')),
          loyaltyApiProvider.overrideWithValue(_FakeRegisterApi(welcomeBonus: 100)),
          sessionProvider.overrideWith(_ReadyRegistrationSession.new),
          splashFinishedProvider.overrideWith(_ImmediateSplash.new),
          meProvider.overrideWith((ref) => _sampleAccount()),
          sizeOffersPreviewProvider.overrideWith(
            (ref) async => SizeOffersResponse(
              items: const [],
              serverNow: DateTime(2026, 11, 23),
            ),
          ),
          programProvider.overrideWith(
            (ref) async => const ProgramInfo(
              title: 'ПАЙК',
              store: 'Алмоси',
              enabled: true,
              countries: ['TJ'],
              birthYearMin: 1930,
              birthYearMax: 2012,
              welcomeBonus: 100,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      router.go('/auth/profile');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: PaykTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('register-gift-banner')), findsOneWidget);
      expect(
        find.text('После регистрации — 100 смн бонусами в подарок'),
        findsOneWidget,
      );

      // Завершаем регистрацию напрямую через SessionController и проверяем редирект на /welcome-gift
      final granted = await container.read(sessionProvider.notifier).completeProfile(
        const RegisterInput(
          registrationToken: 'reg_tok_1',
          firstName: 'Фарзод',
          lastName: 'Сомони',
          birthYear: 1995,
          birthDate: '1995-05-10',
          country: 'TJ',
          consentPd: true,
          consentMessages: false,
        ),
      );
      expect(granted, 100.0);
      await tester.pumpAndSettle();

      expect(find.text('Подарок для вас!'), findsOneWidget);
      expect(find.text('+100 смн'), findsOneWidget);
      expect(find.byType(Gift3dIcon), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('welcome-gift-done')));
      await tester.pumpAndSettle();

      expect(container.read(sessionProvider).pendingWelcomeBonus, isNull);
      expect(find.text('Подарок для вас!'), findsNothing);
      expect(find.text('Алмоси'), findsOneWidget);
    });

    testWidgets('RulesScreen displays welcome bonus card when configured', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            rulesProvider.overrideWith(
              (ref) async => const RulesInfo(
                thresholds: [1800],
                statuses: [],
                referralLevels: [0.01, 0.01],
                months: 12,
                welcomeBonus: 100,
              ),
            ),
          ],
          child: MaterialApp(theme: PaykTheme.light, home: const RulesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rules-welcome')), findsOneWidget);
      expect(
        find.text('Подарок за регистрацию: 100 смн бонусами — один раз.'),
        findsOneWidget,
      );
      expect(find.byType(Gift3dIcon), findsOneWidget);
    });

    testWidgets('NotificationsScreen renders welcome_bonus with gift icon and title', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            loyaltyApiProvider.overrideWithValue(_FakeRegisterApi()),
            messagesProvider.overrideWith(
              (ref) async => [
                LoyaltyMessageItem(
                  id: 101,
                  kind: 'welcome_bonus',
                  text: 'Вам начислено 100 смн в подарок за регистрацию',
                  createdAt: DateTime(2026, 11, 23, 12, 0),
                  read: false,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Подарок'), findsOneWidget);
      expect(find.byType(Gift3dIcon), findsOneWidget);
    });
  });
}
