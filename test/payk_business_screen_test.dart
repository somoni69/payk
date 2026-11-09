import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/app/router.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/api_config.dart';
import 'package:payk/data/api/api_exception.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/auth/splash_screen.dart';
import 'package:payk/features/showcase/payk_business_screen.dart';

class _Locale extends LocaleController {
  _Locale(this.value);

  final String value;

  @override
  String build() => value;
}

class _Api extends Fake implements LoyaltyApi {
  _Api(this.feed);

  ShowcaseFeed feed;
  Object? failure;
  int? cardId;
  String? company;
  String leadStatus = 'sent';

  @override
  Future<ShowcaseFeed> showcase() async {
    final error = failure;
    if (error != null) throw error;
    return feed;
  }

  @override
  Future<ShowcaseLeadResult> showcaseLead(int? cardId, String company) async {
    this.cardId = cardId;
    this.company = company;
    return ShowcaseLeadResult(leadStatus);
  }
}

ShowcaseCard _card({int id = 3, String art = 'receipt'}) {
  return ShowcaseCard(
    id: id,
    titleTj: 'Касса ва анбор',
    titleRu: 'Касса и склад',
    textTj: 'Ҳамааш аз телефон',
    textRu: 'Всё видно с телефона',
    art: art,
  );
}

ShowcaseFeed _feed({List<ShowcaseCard>? cards, bool sent = false}) {
  return ShowcaseFeed(
    cards: cards ?? [_card()],
    leadSentToday: sent,
    contact: const ShowcaseContact(
      name: 'Фарзод Сомони',
      phone: '992900112233',
    ),
  );
}

Widget _screen(_Api api, {String locale = 'ru'}) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith(() => _Locale(locale)),
      loyaltyApiProvider.overrideWithValue(api),
    ],
    child: MaterialApp(
      theme: PaykTheme.light,
      home: const PaykBusinessScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('showcase feed keeps both languages and the image address', () {
    final feed = ShowcaseFeed.fromJson({
      'cards': [
        {
          'id': 7,
          'title_tj': 'Тоҷикӣ',
          'title_ru': 'Русский',
          'text_tj': 'матн',
          'text_ru': 'текст',
          'image_url': '/loyalty-app/showcase/img/sc_abc.jpg',
          'image_w': 800,
          'image_h': 400,
          'art': 'gem',
        },
      ],
      'lead_sent_today': true,
      'contact': {'name': 'Фарзод', 'phone': '992900112233'},
    });

    expect(feed.leadSentToday, isTrue);
    expect(feed.cards.single.titleFor('ru'), 'Русский');
    expect(feed.cards.single.titleFor('tj'), 'Тоҷикӣ');
    expect(feed.cards.single.aspectRatio, 2);
    expect(feed.contact.phone, '992900112233');
    expect(
      ApiConfig.url(feed.cards.single.imageUrl!),
      '${ApiConfig.root}/loyalty-app/showcase/img/sc_abc.jpg',
    );
    expect(
      ApiConfig.url('https://cdn.example/a.jpg'),
      'https://cdn.example/a.jpg',
    );
    expect(ShowcaseCard.fromJson({'id': 1, 'art': ''}).art, 'sparkles');
  });

  testWidgets(
    'shows the owner card and sends a lead with an optional company',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _Api(_feed());
      await _settle(tester, _screen(api));

      expect(find.text('PAYK для бизнеса'), findsWidgets);
      expect(find.text('Касса и склад'), findsOneWidget);
      expect(find.text('Всё видно с телефона'), findsOneWidget);
      expect(find.text('Хочу PAYK'), findsOneWidget);
      expect(find.text('Это приложение работает на PAYK'), findsOneWidget);

      await tester.tap(find.text('Хочу PAYK'));
      await tester.pumpAndSettle();

      expect(find.text('Заявка на PAYK'), findsOneWidget);
      expect(find.text('Фарзод Сомони'), findsOneWidget);
      expect(find.text('+992 90 011 22 33'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('lead-company')),
        '  магазин Нур  ',
      );
      await tester.tap(find.byKey(const Key('lead-send')));
      await tester.pumpAndSettle();

      expect(api.cardId, 3);
      expect(api.company, 'магазин Нур');
      expect(find.text('Заявка отправлена!'), findsOneWidget);
      expect(find.textContaining('+992 90 011 22 33'), findsWidgets);

      await tester.tap(find.byKey(const Key('lead-ok')));
      await tester.pumpAndSettle();
      expect(find.text('Заявка отправлена'), findsOneWidget);
      expect(find.text('Хочу PAYK'), findsNothing);
    },
  );

  testWidgets('a lead that already exists today says so', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _Api(_feed())..leadStatus = 'already';
    await _settle(tester, _screen(api));
    await tester.tap(find.text('Хочу PAYK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lead-send')));
    await tester.pumpAndSettle();

    expect(find.text('Заявка уже есть'), findsOneWidget);
    expect(api.company, isEmpty);
  });

  testWidgets('without cards the fallback story still offers PAYK', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _Api(_feed(cards: const []));
    await _settle(tester, _screen(api, locale: 'tj'));

    expect(find.text('PAYK барои тиҷорат'), findsWidgets);
    expect(find.byKey(const Key('showcase-fallback')), findsOneWidget);
    expect(find.text('PAYK — тиҷорати шумо дар телефон'), findsOneWidget);
    expect(find.text('PAYK мехоҳам'), findsOneWidget);

    await tester.tap(find.text('PAYK мехоҳам'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lead-send')));
    await tester.pumpAndSettle();
    expect(api.cardId, isNull);
    expect(find.text('Дархост фиристода шуд!'), findsOneWidget);
  });

  testWidgets('a sent lead replaces the button with a quiet badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _settle(tester, _screen(_Api(_feed(sent: true))));
    expect(find.text('Заявка отправлена'), findsOneWidget);
    expect(find.text('Хочу PAYK'), findsNothing);
  });

  testWidgets('a failed load can be retried', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _Api(_feed())
      ..failure = ApiException(0, 'Нет связи с сервером');
    await _settle(tester, _screen(api));
    expect(find.text('Нет связи с сервером'), findsOneWidget);

    api.failure = null;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Касса и склад'), findsOneWidget);
  });

  testWidgets('the center tab opens PAYK for business', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _Api(_feed());
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _LoggedIn()),
        splashFinishedProvider.overrideWith(() => _SplashDone()),
        meProvider.overrideWith((ref) => _account),
        historyProvider.overrideWith((ref) => const []),
        friendsProvider.overrideWith((ref) => _friends),
        loyaltyApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: container.read(routerProvider)),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(routerProvider).state.matchedLocation, '/home');
    await tester.tap(find.bySemanticsLabel('PAYK для бизнеса'));
    await tester.pumpAndSettle();

    expect(container.read(routerProvider).state.matchedLocation, '/payk');
    expect(find.text('Касса и склад'), findsOneWidget);
    expect(find.text('Хочу PAYK'), findsOneWidget);
  });
}

class _LoggedIn extends SessionController {
  @override
  SessionState build() => const SessionState(
    ready: true,
    onboardingSeen: true,
    accessToken: 'access',
    refreshToken: 'refresh',
  );
}

class _SplashDone extends SplashGate {
  @override
  bool build() => true;
}

const _account = Account(
  member: Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    referralCode: 'FARZOD',
  ),
  wallet: Wallet(
    status: 1,
    balance: 250,
    onHold: 0,
    debt: 0,
    spendMonth: 120,
    spendSupermarket: 70,
    spendClothes: 50,
    daysLeft: 20,
    keep: null,
    up: null,
    nextMonthStatus: 1,
    rates: ProgramRates(
      supermarket: Rate(earn: 0.03, burnCap: 0.5),
      clothes: Rate(earn: 0.05, burnCap: 0.5),
    ),
    todaySupermarket: 0,
    todayClothes: 0,
  ),
  store: 'Payk Store',
  programEnabled: true,
);

const _friends = FriendsInfo(
  code: 'FARZOD',
  levels: [0.05, 0.02],
  months: 6,
  countL1: 0,
  countL2: 0,
  total: 0,
  month: 0,
  invitees: [],
);
