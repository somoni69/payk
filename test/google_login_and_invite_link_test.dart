import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/api_client.dart';
import 'package:payk/data/api/api_config.dart';
import 'package:payk/data/api/api_exception.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/auth_screens.dart';
import 'package:payk/features/friends/friends_screen.dart';
import 'package:payk/features/profile/connect_screen.dart';
import 'package:payk/features/profile/profile_screen.dart';

http.Response _jsonResponse(Object body, {int status = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

class _TestLocale extends LocaleController {
  _TestLocale(this.initial);
  final String initial;

  @override
  String build() => initial;
}

class _FakeGoogleAuthService extends GoogleAuthService {
  _FakeGoogleAuthService({
    required this.available,
    this.tokenToReturn,
  }) : super(
         serverClientId: available ? 'test-web-client-id' : '',
         platformOverride: TargetPlatform.android,
       );

  final bool available;
  final String? tokenToReturn;
  int requestCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<String?> requestIdToken() async {
    requestCalls++;
    return tokenToReturn;
  }
}

class _SeededSession extends SessionController {
  _SeededSession(this._initial);
  final SessionState _initial;

  @override
  SessionState build() => _initial;
}

class _FakeGoogleLoyaltyApi extends LoyaltyApi {
  _FakeGoogleLoyaltyApi()
    : super(
        ApiClient(
          readTokens: () => const TokenPair(
            accessToken: 'acc',
            refreshToken: 'ref',
          ),
          writeTokens: (_, _) {},
          onExpired: () {},
        ),
      );

  GoogleLoginResult? googleLoginResult;
  ApiException? googleLoginError;
  VerifyResult? verifyResult;
  final List<ApiException?> verifyQueueErrors = [];
  final List<String?> seenGoogleTickets = [];

  GoogleLinkStart? linkGoogleResult;
  OtpChallenge? linkCodeResult;
  GoogleLink? linkConfirmResult;
  bool unlinkedGoogle = false;
  int linkCodeCalls = 0;
  String? lastLinkConfirmCode;

  @override
  Future<GoogleLoginResult> googleLogin(String idToken) async {
    if (googleLoginError != null) throw googleLoginError!;
    return googleLoginResult!;
  }

  @override
  Future<VerifyResult> verify(
    String phone,
    String code, {
    String? googleTicket,
  }) async {
    seenGoogleTickets.add(googleTicket);
    if (verifyQueueErrors.isNotEmpty) {
      final err = verifyQueueErrors.removeAt(0);
      if (err != null) throw err;
    }
    return verifyResult!;
  }

  @override
  Future<TelegramLinks> telegram() async {
    return const TelegramLinks(
      bot: '@payk_bot',
      appLink: '',
      webLink: '',
      token: 'tok123',
      linked: false,
    );
  }

  @override
  Future<GoogleLinkStart> linkGoogle(String idToken) async {
    return linkGoogleResult!;
  }

  @override
  Future<OtpChallenge> googleLinkCode(String googleTicket) async {
    linkCodeCalls++;
    return linkCodeResult ??
        const OtpChallenge(
          phone: '+992900000000',
          resendIn: 60,
          ttl: 300,
          debugCode: '654321',
        );
  }

  @override
  Future<GoogleLink?> googleLinkConfirm(String googleTicket, String code) async {
    lastLinkConfirmCode = code;
    return linkConfirmResult ?? const GoogleLink(email: 'ali@gmail.com');
  }

  @override
  Future<void> unlinkGoogle() async {
    unlinkedGoogle = true;
  }

  @override
  Future<ReferralMatch> matchReferral({
    String? code,
    String? click,
    String? installReferrer,
    ReferralDeviceInfo? device,
  }) async {
    return const ReferralMatch(found: false);
  }
}

Account _sampleAccount({GoogleLink? google, String? referralLink}) {
  return Account(
    member: Member(
      firstName: 'Али',
      lastName: 'Рахимов',
      phone: '+992900000000',
      referralCode: 'SO-4654',
      referralLink: referralLink,
      google: google,
      messages: true,
    ),
    wallet: const Wallet(
      status: 1,
      balance: 100,
      onHold: 0,
      debt: 0,
      spendMonth: 0,
      spendSupermarket: 0,
      spendClothes: 0,
      daysLeft: 20,
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
    store: 'Алмоси',
    programEnabled: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Commit 93183a4: Invite link helpers & models', () {
    test('ApiConfig.referralLink prefers serverLink and falls back to /r/CODE', () {
      expect(
        ApiConfig.referralLink(
          code: 'so-4654',
          serverLink: 'https://payk.tj/r/SO-4654',
        ),
        'https://payk.tj/r/SO-4654',
      );
      expect(
        ApiConfig.referralLink(code: ' so-4654 ', serverLink: null),
        'https://payk-loyalty.vercel.app/r/SO-4654',
      );
      expect(
        ApiConfig.referralLink(code: 'SO-4654', serverLink: '   '),
        'https://payk-loyalty.vercel.app/r/SO-4654',
      );
    });

    test('ApiConfig.inviteLinkParts strips https:// and splits before /r/', () {
      final parts = ApiConfig.inviteLinkParts(
        'https://payk-loyalty.vercel.app/r/SO-4654',
      );
      expect(parts.host, 'payk-loyalty.vercel.app');
      expect(parts.path, '/r/SO-4654');

      final noPath = ApiConfig.inviteLinkParts('http://payk.tj');
      expect(noPath.host, 'payk.tj');
      expect(noPath.path, '');
    });

    test('Member.fromJson parses referral_link and google email', () {
      final member = Member.fromJson({
        'first_name': 'Фарзод',
        'last_name': 'Сомони',
        'phone': '+992900000000',
        'referral_code': 'SO-4654',
        'referral_link': 'https://payk-loyalty.vercel.app/r/SO-4654',
        'google': {'email': 'farzod@gmail.com'},
      });
      expect(member.referralLink, 'https://payk-loyalty.vercel.app/r/SO-4654');
      expect(member.google?.email, 'farzod@gmail.com');

      final noGoogle = Member.fromJson({
        'first_name': 'Фарзод',
        'last_name': 'Сомони',
        'phone': '+992900000000',
        'referral_code': 'SO-4654',
        'google': null,
      });
      expect(noGoogle.google, isNull);
      expect(noGoogle.referralLink, isNull);
    });
  });

  group('Commit 47b7710: GoogleAuthService platform gating (App Store 4.8)', () {
    test('disabled on iOS even with serverClientId, enabled on Android with clientId', () {
      final ios = GoogleAuthService(
        serverClientId: '123456.apps.googleusercontent.com',
        platformOverride: TargetPlatform.iOS,
      );
      expect(ios.isAvailable, isFalse);

      final androidNoClient = GoogleAuthService(
        serverClientId: '',
        platformOverride: TargetPlatform.android,
      );
      expect(androidNoClient.isAvailable, isFalse);

      final androidReady = GoogleAuthService(
        serverClientId: '123456.apps.googleusercontent.com',
        platformOverride: TargetPlatform.android,
      );
      expect(androidReady.isAvailable, isTrue);
    });
  });

  group('Commit 47b7710: LoyaltyApi Google endpoints', () {
    test('googleLogin handles login and phone responses, verify passes google_ticket', () async {
      final requests = <({String method, String path, Map<String, dynamic>? body})>[];
      final mockHttp = MockClient((req) async {
        final body = req.body.isEmpty
            ? null
            : jsonDecode(req.body) as Map<String, dynamic>;
        requests.add((method: req.method, path: req.url.path, body: body));
        if (req.url.path.endsWith('/google') && body?['id_token'] == 'tok-known') {
          return _jsonResponse({
            'status': 'login',
            'access_token': 'acc-1',
            'refresh_token': 'ref-1',
          });
        }
        if (req.url.path.endsWith('/google') && body?['id_token'] == 'tok-new') {
          return _jsonResponse({
            'status': 'phone',
            'google_ticket': 'gt-123',
            'email': 'ali@gmail.com',
            'first_name': 'Али',
            'last_name': 'Рахимов',
          });
        }
        if (req.url.path.endsWith('/verify')) {
          return _jsonResponse({
            'status': 'register',
            'registration_token': 'reg-999',
            'phone': '+992901234567',
          });
        }
        if (req.url.path.endsWith('/me/google') && req.method == 'POST') {
          return _jsonResponse({
            'status': 'confirm',
            'google_ticket': 'gt-link',
            'email': 'ali@gmail.com',
            'phone': '+992901234567',
          });
        }
        if (req.url.path.endsWith('/me/google/code')) {
          return _jsonResponse({
            'sent': true,
            'phone': '+992901234567',
            'resend_in': 60,
            'ttl': 300,
            'debug_code': '112233',
          });
        }
        if (req.url.path.endsWith('/me/google/confirm')) {
          return _jsonResponse({
            'linked': true,
            'google': {'email': 'ali@gmail.com'},
          });
        }
        if (req.url.path.endsWith('/me/google') && req.method == 'DELETE') {
          return _jsonResponse({'linked': false});
        }
        return _jsonResponse({'detail': 'not found'}, status: 404);
      });

      final api = LoyaltyApi(
        ApiClient(
          httpClient: mockHttp,
          readTokens: () => const TokenPair(accessToken: 'a', refreshToken: 'r'),
          writeTokens: (_, _) {},
          onExpired: () {},
        ),
      );

      final direct = await api.googleLogin('tok-known');
      expect(direct.needsPhone, isFalse);
      expect(direct.tokens?.accessToken, 'acc-1');

      final pending = await api.googleLogin('tok-new');
      expect(pending.needsPhone, isTrue);
      expect(pending.pending?.ticket, 'gt-123');
      expect(pending.pending?.email, 'ali@gmail.com');
      expect(pending.pending?.firstName, 'Али');
      expect(pending.pending?.lastName, 'Рахимов');

      final verified = await api.verify(
        '+992901234567',
        '123456',
        googleTicket: 'gt-123',
      );
      expect(verified.needsRegistration, isTrue);
      expect(requests.last.body?['google_ticket'], 'gt-123');

      final linkStart = await api.linkGoogle('tok-link');
      expect(linkStart.needsConfirm, isTrue);
      expect(linkStart.ticket, 'gt-link');

      final challenge = await api.googleLinkCode('gt-link');
      expect(challenge.resendIn, 60);
      expect(challenge.debugCode, '112233');

      final confirmed = await api.googleLinkConfirm('gt-link', '112233');
      expect(confirmed?.email, 'ali@gmail.com');

      await api.unlinkGoogle();
      expect(requests.last.method, 'DELETE');
      expect(requests.last.path, endsWith('/me/google'));
    });
  });

  group('Commit 93183a4: FriendsScreen invite link & fallback code', () {
    testWidgets('shows invite link without https://, copies full URL, and fallback code copies raw code', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            meProvider.overrideWith((ref) => _sampleAccount()),
            friendsProvider.overrideWith(
              (ref) => const FriendsInfo(
                code: 'SO-4654',
                link: 'https://payk-loyalty.vercel.app/r/SO-4654',
                levels: [0.01, 0.005],
                months: 12,
                countL1: 0,
                countL2: 0,
                total: 0,
                month: 0,
                invitees: [],
              ),
            ),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const FriendsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ваша ссылка-приглашение'), findsOneWidget);
      expect(find.byKey(const ValueKey('referral-link')), findsOneWidget);
      expect(find.text('payk-loyalty.vercel.app'), findsOneWidget);
      expect(find.text('/r/SO-4654'), findsOneWidget);
      expect(find.textContaining('https://'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('referral-link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(copied.last, 'https://payk-loyalty.vercel.app/r/SO-4654');
      expect(find.text('Ссылка скопирована'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('referral-code')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(copied.last, 'SO-4654');
      expect(find.text('Скопировано'), findsOneWidget);
    });
  });

  group('Commit 47b7710: Google Sign-In UI flows', () {
    testWidgets('PhoneScreen shows Google button, handles phone confirmation & cancel', (
      tester,
    ) async {
      final fakeApi = _FakeGoogleLoyaltyApi()
        ..googleLoginResult = const GoogleLoginResult.phone(
          GooglePending(
            ticket: 'gt-1',
            email: 'ali@gmail.com',
            firstName: 'Али',
            lastName: 'Рахимов',
          ),
        );
      final fakeGoogle = _FakeGoogleAuthService(
        available: true,
        tokenToReturn: 'id-token-123',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            loyaltyApiProvider.overrideWithValue(fakeApi),
            googleAuthServiceProvider.overrideWithValue(fakeGoogle),
            programProvider.overrideWith(
              (ref) => const ProgramInfo(
                title: 'Алмоси',
                store: 'Алмоси',
                enabled: true,
                countries: ['TJ'],
                birthYearMin: 1940,
                birthYearMax: 2015,
              ),
            ),
            sessionProvider.overrideWith(
              () => _SeededSession(const SessionState(ready: true)),
            ),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const PhoneScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('google-continue-btn')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('google-continue-btn')));
      await tester.pumpAndSettle();

      expect(fakeGoogle.requestCalls, 1);
      expect(find.byKey(const ValueKey('google-pending')), findsOneWidget);
      expect(find.text('Подтвердите номер'), findsOneWidget);
      expect(find.text('Google: ali@gmail.com'), findsOneWidget);
      expect(find.byKey(const ValueKey('google-continue-btn')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('google-pending-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('google-pending')), findsNothing);
      expect(find.byKey(const ValueKey('google-continue-btn')), findsOneWidget);
    });

    testWidgets('PhoneScreen hides Google button on 503 from server', (
      tester,
    ) async {
      final fakeApi = _FakeGoogleLoyaltyApi()
        ..googleLoginError = ApiException(503, 'Вход через Google отключён');
      final fakeGoogle = _FakeGoogleAuthService(
        available: true,
        tokenToReturn: 'id-token-123',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            loyaltyApiProvider.overrideWithValue(fakeApi),
            googleAuthServiceProvider.overrideWithValue(fakeGoogle),
            programProvider.overrideWith(
              (ref) => const ProgramInfo(
                title: 'Алмоси',
                store: 'Алмоси',
                enabled: true,
                countries: ['TJ'],
                birthYearMin: 1940,
                birthYearMax: 2015,
              ),
            ),
            sessionProvider.overrideWith(
              () => _SeededSession(const SessionState(ready: true)),
            ),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const PhoneScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('google-continue-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('google-continue-btn')), findsNothing);
    });

    testWidgets('OtpScreen shows pending Google and drops google_ticket on 409 so same code succeeds', (
      tester,
    ) async {
      final fakeApi = _FakeGoogleLoyaltyApi()
        ..verifyQueueErrors.add(
          ApiException(409, 'Этот Google уже привязан к другому номеру'),
        )
        ..verifyResult = VerifyResult.login(
          const TokenPair(accessToken: 'acc-ok', refreshToken: 'ref-ok'),
        );

      final router = GoRouter(
        initialLocation: '/auth/code',
        routes: [
          GoRoute(
            path: '/auth/code',
            builder: (context, state) => const OtpScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(body: Text('HOME_OK')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            loyaltyApiProvider.overrideWithValue(fakeApi),
            sessionProvider.overrideWith(
              () => _SeededSession(
                const SessionState(
                  ready: true,
                  pendingPhone: '+992901234567',
                  pendingGoogle: GooglePending(
                    ticket: 'gt-conflict',
                    email: 'ali@gmail.com',
                    firstName: 'Али',
                    lastName: 'Рахимов',
                  ),
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: PaykTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('google-pending-code')), findsOneWidget);
      expect(find.text('Google: ali@gmail.com'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      expect(fakeApi.seenGoogleTickets, ['gt-conflict']);
      expect(find.byKey(const ValueKey('google-pending-code')), findsNothing);
      expect(
        find.text('Этот Google уже привязан к другому номеру'),
        findsOneWidget,
      );

      // Повторная отправка того же SMS-кода идёт уже без google_ticket.
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();

      expect(fakeApi.seenGoogleTickets, ['gt-conflict', null]);
      expect(find.text('HOME_OK'), findsOneWidget);
    });

    testWidgets('ProfileSetupScreen prefills name, lastName and locks email from pendingGoogle', (
      tester,
    ) async {
      final fakeApi = _FakeGoogleLoyaltyApi();
      final referral = ReferralService(
        readInstallReferrer: () async => null,
        readInitialLink: () async => null,
        readDeviceInfo: () async => null,
      );
      addTearDown(referral.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            loyaltyApiProvider.overrideWithValue(fakeApi),
            referralServiceProvider.overrideWithValue(referral),
            programProvider.overrideWith(
              (ref) => const ProgramInfo(
                title: 'Алмоси',
                store: 'Алмоси',
                enabled: true,
                countries: ['TJ'],
                birthYearMin: 1940,
                birthYearMax: 2015,
              ),
            ),
            sessionProvider.overrideWith(
              () => _SeededSession(
                const SessionState(
                  ready: true,
                  pendingPhone: '+992901234567',
                  registrationToken: 'reg-1',
                  pendingGoogle: GooglePending(
                    ticket: 'gt-reg',
                    email: 'ali@gmail.com',
                    firstName: 'Али',
                    lastName: 'Рахимов',
                  ),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const ProfileSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emailFinder = find.byKey(const ValueKey('register-email-google'));
      expect(emailFinder, findsOneWidget);
      final emailField = tester.widget<TextField>(emailFinder);
      expect(emailField.readOnly, isTrue);
      expect(emailField.controller?.text, 'ali@gmail.com');
      expect(find.text('Из Google — менять не нужно'), findsOneWidget);
      expect(find.text('Али'), findsOneWidget);
      expect(find.text('Рахимов'), findsOneWidget);
    });

    testWidgets('ConnectScreen links Google with SMS confirmation and supports unlink', (
      tester,
    ) async {
      final fakeApi = _FakeGoogleLoyaltyApi()
        ..linkGoogleResult = const GoogleLinkStart.confirm(
          ticket: 'gt-link-1',
          email: 'ali@gmail.com',
          phone: '+992900000000',
        );
      final fakeGoogle = _FakeGoogleAuthService(
        available: true,
        tokenToReturn: 'id-tok-link',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            loyaltyApiProvider.overrideWithValue(fakeApi),
            googleAuthServiceProvider.overrideWithValue(fakeGoogle),
            meProvider.overrideWith((ref) => _sampleAccount()),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const ConnectScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('connect-google')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('connect-google-link')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('connect-google-confirm')), findsOneWidget);
      expect(fakeApi.linkCodeCalls, 1);
      expect(find.text('654321'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('connect-google-code')),
        '654321',
      );
      await tester.pumpAndSettle();

      expect(fakeApi.lastLinkConfirmCode, '654321');
      expect(find.byKey(const ValueKey('connect-google-confirm')), findsNothing);
    });

    testWidgets('ConnectScreen shows linked Google email & unlink even when Google SDK is unavailable (iOS)', (
      tester,
    ) async {
      final fakeApi = _FakeGoogleLoyaltyApi();
      final iosGoogle = _FakeGoogleAuthService(available: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            loyaltyApiProvider.overrideWithValue(fakeApi),
            googleAuthServiceProvider.overrideWithValue(iosGoogle),
            meProvider.overrideWith(
              (ref) => _sampleAccount(
                google: const GoogleLink(email: 'ali@gmail.com'),
              ),
            ),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const ConnectScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('connect-google')), findsOneWidget);
      expect(find.text('Вход через Google: ali@gmail.com'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('connect-google-unlink')));
      await tester.pumpAndSettle();

      expect(fakeApi.unlinkedGoogle, isTrue);
    });

    testWidgets('ProfileScreen shows Google badge in login methods when available or linked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _TestLocale('ru')),
            googleAuthServiceProvider.overrideWithValue(
              _FakeGoogleAuthService(available: true),
            ),
            meProvider.overrideWith((ref) => _sampleAccount()),
            rafflesPreviewProvider.overrideWith((ref) async => null),
            sizeOffersPreviewProvider.overrideWith(
              (ref) async => const SizeOffersResponse(items: []),
            ),
          ],
          child: MaterialApp(
            theme: PaykTheme.light,
            home: const Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('method-google')), findsOneWidget);
    });
  });
}
