import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/app/payk_app.dart';
import 'package:payk/app/router.dart';
import 'package:payk/core/notifications/push_notification_service.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';

class _FakePushNotificationService extends Fake
    implements PushNotificationService {
  void Function(String route)? onTap;
  Future<void> Function(String token)? onToken;
  VoidCallback? onForeground;
  String? _token;

  @override
  String? get fcmToken => _token;

  @override
  Future<void> initialize({
    void Function(String route)? onNotificationTap,
    Future<void> Function(String token)? onTokenUpdate,
    VoidCallback? onForegroundMessage,
  }) async {
    onTap = onNotificationTap;
    onToken = onTokenUpdate;
    onForeground = onForegroundMessage;
    // Эмулируем cold-start клик по пушу, пришедший ещё во время /splash.
    onTap?.call('/notifications');
    _token = 'android-fcm-token-123';
    await onToken?.call(_token!);
  }
}

class _FakeLoyaltyApi extends Fake implements LoyaltyApi {
  final List<Map<String, dynamic>> patches = [];
  int messagesCalls = 0;
  int meCalls = 0;

  @override
  Future<Account> me() async {
    meCalls++;
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

  @override
  Future<List<LoyaltyMessageItem>> messages({int? beforeId}) async {
    messagesCalls++;
    return const [];
  }

  @override
  Future<int> markMessagesRead({int? upToId}) async => 0;

  @override
  Future<void> updateMe(Map<String, dynamic> patch) async {
    patches.add(patch);
  }

  @override
  Future<PendingSnapshot> pending() async => const PendingSnapshot();

  @override
  Future<SizeOffersResponse> sizeOffers({bool markRead = true}) async =>
      SizeOffersResponse(items: const [], serverNow: DateTime.now());
}

class _LoggedSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(
    ready: true,
    onboardingSeen: true,
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );
}

void main() {
  testWidgets(
    'cold-start push tap during splash opens /notifications after splash and updates fcm_token',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakePush = _FakePushNotificationService();
      final fakeApi = _FakeLoyaltyApi();

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(_LoggedSessionController.new),
          pushNotificationServiceProvider.overrideWithValue(fakePush),
          loyaltyApiProvider.overrideWithValue(fakeApi),
          friendsProvider.overrideWith(
            (ref) => const FriendsInfo(
              code: 'SO-4654',
              link: null,
              levels: [0.01],
              months: 12,
              countL1: 0,
              countL2: 0,
              total: 0,
              month: 0,
              invitees: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PaykApp(),
        ),
      );

      // Первый кадр: сплэш ещё идёт, токен уже отправлен на /me, но навигация отложена.
      await tester.pump();
      expect(
        fakeApi.patches,
        contains(equals({'fcm_token': 'android-fcm-token-123'})),
      );
      expect(
        container.read(routerProvider).state.matchedLocation,
        equals('/splash'),
      );

      // Сплэш завершается (1680ms) -> сначала /home, затем отложенный /notifications.
      await tester.pump(const Duration(milliseconds: 1750));
      await tester.pumpAndSettle();

      expect(
        container.read(routerProvider).state.matchedLocation,
        equals('/notifications'),
      );

      // Кнопка «Назад» возвращает на /home (route был запушен поверх /home).
      final beforeMessages = fakeApi.messagesCalls;
      final beforeMe = fakeApi.meCalls;

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.matchedLocation,
        equals('/home'),
      );

      // Foreground-пуш на /home сразу обновляет профиль (счётчик непрочитанных),
      // а при открытом экране уведомлений — сразу подгружает свежие сообщения.
      fakePush.onForeground?.call();
      await tester.pumpAndSettle();
      expect(fakeApi.meCalls, greaterThan(beforeMe));

      fakePush.onTap?.call('/notifications');
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).state.matchedLocation,
        equals('/notifications'),
      );
      expect(fakeApi.messagesCalls, greaterThan(beforeMessages));

      final whileOpenMessages = fakeApi.messagesCalls;
      fakePush.onForeground?.call();
      await tester.pumpAndSettle();
      expect(fakeApi.messagesCalls, greaterThan(whileOpenMessages));
    },
  );
}
