import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/home/home_screen.dart';
import 'package:payk/features/home/loyalty_card.dart';

class _TestLocaleController extends LocaleController {
  _TestLocaleController(this.initial);
  final String initial;
  @override
  String build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockMember = Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    referralCode: 'SO-4654',
    messages: true,
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
      up: UpInfo(
        level: 2,
        threshold: 1800,
        gap: 1800,
        perDay: 70,
        rates: ProgramRates(
          supermarket: Rate(earn: 0.03, burnCap: 0.02),
          clothes: Rate(earn: 0.07, burnCap: 0.15),
        ),
      ),
      nextMonthStatus: 1,
      rates: ProgramRates(
        supermarket: Rate(earn: 0.02, burnCap: 0.01),
        clothes: Rate(earn: 0.05, burnCap: 0.10),
      ),
      todaySupermarket: 0,
      todayClothes: 0,
    ),
    store: 'Payk Flagship',
    programEnabled: true,
  );

  Widget wrapWithScope({String locale = 'tj'}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => _TestLocaleController(locale)),
        meProvider.overrideWith((ref) => mockAccount),
        friendsProvider.overrideWith(
          (ref) => const FriendsInfo(
            code: 'SO-4654',
            link: 'https://payk.app/r/SO-4654',
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
        home: const Scaffold(
          body: HomeScreen(),
        ),
      ),
    );
  }

  group('Home Screen New Mockup Widgets (Tajik UI)', () {
    testWidgets('Renders all 4 requested widgets matching design screenshot', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithScope(locale: 'tj'));
      await tester.pumpAndSettle();

      // 1. Карта статуса вместо блока «Статуси ман»
      expect(find.byType(LoyaltyCard), findsOneWidget);
      expect(find.byKey(const ValueKey('loyalty-face-1')), findsOneWidget);
      expect(find.text('Стандарт'), findsOneWidget);
      expect(find.text('Тавозун'), findsOneWidget);
      expect(find.textContaining('750,00'), findsOneWidget);
      expect(find.text('СОМОНИ ФАРЗОД'), findsOneWidget);
      expect(find.text('SO-4654'), findsOneWidget);
      expect(find.text('ПАЙК'), findsOneWidget);
      expect(find.text('Статуси ман'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // 2. Дӯстонро даъват кунед card
      expect(find.text('Дӯстонро даъват кунед ва аз харидҳои онҳо 1% гиред'), findsOneWidget);
      expect(find.text('SO - 4654'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);

      // 3. Огоҳиномаҳо switch tile
      expect(find.text('Кэшбэк ва статусро аз даст надиҳед — огоҳиномаҳоро фаъол кунед'), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);

      // 4. Мағозаҳо section
      expect(find.text('Мағозаҳо'), findsOneWidget);
      expect(find.text('Ҳама'), findsOneWidget);
      expect(find.text('СУПЕРМАРКЕТ'), findsOneWidget);
      expect(find.text('ЛИБОС'), findsOneWidget);
      expect(find.textContaining('кэшбэк 2%'), findsOneWidget);
      expect(find.textContaining('бо бонус то 1%'), findsOneWidget);
      expect(find.textContaining('кэшбэк 5%'), findsOneWidget);
      expect(find.textContaining('бо бонус то 10%'), findsOneWidget);
    });

    testWidgets('Tapping on referral code copies it to clipboard and shows snackbar', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(wrapWithScope(locale: 'tj'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SO - 4654'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Пайванд нусха шуд'), findsOneWidget);
    });
  });

  test('each status keeps its own card material', () {
    final faces = List<LoyaltyCardFace>.generate(5, (index) => loyaltyCardFace(index + 1));
    expect(faces.map((face) => face.colors.first).toSet(), hasLength(5));
    expect(faces[0].ink, Colors.white);
    expect(faces[1].ink, isNot(Colors.white));
    expect(faces[2].ink, isNot(Colors.white));
    expect(faces[3].ink, Colors.white);
    expect(faces[4].ink, Colors.white);
    expect(loyaltyTierLevel(4, tiers: 4), 5);
    expect(loyaltyTierLevel(1), 1);
  });

  testWidgets('changing status applies the matching card design', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final status = ValueNotifier<int>(1);
    addTearDown(status.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PaykTheme.light,
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: status,
            builder: (context, level, _) {
              return LoyaltyCard(
                member: mockMember,
                locale: 'ru',
                tiers: 5,
                wallet: Wallet(
                  status: level,
                  balance: 0,
                  onHold: 0,
                  debt: 0,
                  spendMonth: 0,
                  spendSupermarket: 0,
                  spendClothes: 0,
                  daysLeft: 26,
                  keep: null,
                  up: null,
                  nextMonthStatus: level,
                  rates: const ProgramRates(
                    supermarket: Rate(earn: 0.02, burnCap: 0.01),
                    clothes: Rate(earn: 0.05, burnCap: 0.10),
                  ),
                  todaySupermarket: 0,
                  todayClothes: 0,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Стандарт'), findsOneWidget);
    expect(find.text('Баланс'), findsOneWidget);
    final word = tester.widget<Text>(find.text('ПАЙК'));
    expect(word.style?.fontFamily, isNull);
    expect(word.style?.inherit, isFalse);
    expect(find.textContaining('0,00'), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty-face-1')), findsOneWidget);

    status.value = 2;
    await tester.pumpAndSettle();
    expect(find.text('Силвер'), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty-face-2')), findsOneWidget);
    expect(find.text('Стандарт'), findsNothing);

    status.value = 3;
    await tester.pumpAndSettle();
    expect(find.text('Голд'), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty-face-3')), findsOneWidget);

    status.value = 4;
    await tester.pumpAndSettle();
    expect(find.text('Платинум'), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty-face-4')), findsOneWidget);

    status.value = 5;
    await tester.pumpAndSettle();
    expect(find.text('Алмаз'), findsOneWidget);
    expect(find.byKey(const ValueKey('loyalty-face-5')), findsOneWidget);
    expect(find.text('SOMONI FARZOD'), findsNothing);
    expect(find.text('СОМОНИ ФАРЗОД'), findsOneWidget);
  });
}
