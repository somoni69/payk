import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/profile/connect_screen.dart';
import 'package:payk/features/profile/profile_screen.dart';

class _TestLocaleController extends LocaleController {
  _TestLocaleController(this.initial);
  final String initial;
  @override
  String build() => initial;
}

class _FakeLoyaltyApi extends Fake implements LoyaltyApi {
  @override
  Future<TelegramLinks> telegram() async {
    return const TelegramLinks(
      linked: false,
      bot: 'PaykBot',
      appLink: 'tg://resolve?domain=PaykBot&start=test',
      webLink: 'https://t.me/PaykBot?start=test',
      token: 'tok_test',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockMember = Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    referralCode: 'SO-4654',
    messages: true,
    telegram: false,
  );

  const mockAccount = Account(
    member: mockMember,
    wallet: Wallet(
      status: 1,
      balance: 750,
      onHold: 0,
      debt: 0,
      spendMonth: 0,
      spendSupermarket: 0,
      spendClothes: 0,
      daysLeft: 26,
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

  Widget createWidget({String locale = 'tj'}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => _TestLocaleController(locale)),
        meProvider.overrideWith((ref) => mockAccount),
        loyaltyApiProvider.overrideWithValue(_FakeLoyaltyApi()),
      ],
      child: MaterialApp(
        theme: PaykTheme.light,
        home: const ProfileScreen(),
      ),
    );
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      return null;
    });
  });

  group('Profile Screen Mockup Widgets (Tajik UI)', () {
    testWidgets('Renders all requested widgets matching design screenshot and loyalty-app', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(locale: 'tj'));
      await tester.pumpAndSettle();

      // 1. Верхний виджет профиля пользователя
      expect(find.text('Фарзод Сомони'), findsOneWidget);
      expect(find.text('Профил'), findsOneWidget);
      expect(find.text('ФС'), findsOneWidget);

      // 2. Карточка «Тарзҳои воридшавӣ» и «Дидан»
      expect(find.text('Тарзҳои воридшавӣ'), findsOneWidget);
      expect(find.text('Дидан'), findsOneWidget);

      // Иконки SMS и Telegram (SMS бейдж + пункт Паёмҳо в меню)
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      // Галочка зеленая на SMS и плюс на Telegram (потому что telegram: false)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // 3. Баннер «Статусҳои ПАЙК» (первый слайд скроллящейся карусели)
      expect(find.text('Статусҳои ПАЙК'), findsOneWidget);
      expect(find.text('Бештар харид кунед — кэшбэк то 20%'), findsOneWidget);

      // Проверяем скролл ко второму слайду («Клуби дӯстон»)
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Клуби дӯстон'), findsOneWidget);
      expect(find.text('Аз ҳар хариди дӯстони даъваткарда 1%'), findsOneWidget);

      // 4. 8 пунктов меню
      expect(find.text('Мағозаи ман'), findsOneWidget);
      expect(find.text('MSX Алмоси'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);

      expect(find.text('Паёмҳо'), findsOneWidget);

      expect(find.text('Харидҳои ман'), findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);

      expect(find.text('Статусҳо ва қоидаҳо'), findsOneWidget);
      expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);

      expect(find.text('Таърихи амалиётҳо'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);

      expect(find.text('Алоқа бо мағоза'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);

      expect(find.text('Дар бораи барнома'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      expect(find.text('Танзимот'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // 5. Нижняя плитка уведомлений (Switch)
      expect(find.text('Кэшбэк ва статусро аз даст надиҳед — огоҳиномаҳоро фаъол кунед'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Tapping on top profile user card navigates to ProfileDetailsScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(locale: 'tj'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Фарзод Сомони'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileDetailsScreen), findsOneWidget);
    });

    testWidgets('Tapping on Танзимот navigates to SettingsScreen with language and notifications', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(locale: 'tj'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Танзимот'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Забон'), findsOneWidget);
      expect(find.text('Огоҳиномаҳо'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
      expect(find.text('Баромадан'), findsNothing);
      expect(find.text('Выйти'), findsNothing);
    });

    testWidgets('Tapping on Дидан navigates to ConnectScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(locale: 'tj'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Дидан'));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectScreen), findsOneWidget);
      expect(find.text('Тарзҳои воридшавӣ'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
      expect(find.textContaining('SMS'), findsOneWidget);
    });

    testWidgets('Tapping on Мағозаи ман opens store dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(locale: 'tj'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Мағозаи ман'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Мағозаи асосии шумо дар экосистемаи ПАЙК'), findsOneWidget);
      expect(find.text('Фаҳмо'), findsOneWidget);
    });

    testWidgets('Tapping on Алоқа бо мағоза opens contact modal', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(locale: 'tj'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Алоқа бо мағоза'));
      await tester.pumpAndSettle();

      expect(find.text('Алоқа бо мағоза'), findsNWidgets(2)); // Menu item + modal header
      expect(find.text('WhatsApp · MSX Алмоси'), findsOneWidget);
      expect(find.textContaining('+992 55 551 82 20'), findsNWidgets(2));
    });
  });
}
