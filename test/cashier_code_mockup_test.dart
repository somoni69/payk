import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/code/client_code_screen.dart';

class _TestLocaleController extends LocaleController {
  _TestLocaleController(this.initial);
  final String initial;
  @override
  String build() => initial;
}

class FakeLoyaltyApi extends Fake implements LoyaltyApi {
  FakeLoyaltyApi({
    required this.cashierCode,
    this.pendingSnapshot = const PendingSnapshot(),
  });

  CashierCode cashierCode;
  PendingSnapshot pendingSnapshot;
  int codeCallCount = 0;

  @override
  Future<CashierCode> code() async {
    codeCallCount++;
    return cashierCode;
  }

  @override
  Future<PendingSnapshot> pending() async {
    return pendingSnapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLoyaltyApi fakeApi;

  setUp(() {
    fakeApi = FakeLoyaltyApi(
      cashierCode: const CashierCode(
        qr: 'payk://code/42447996',
        code: '42447996',
        ttl: 40,
      ),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      return null;
    });
  });

  Widget createWidget({String locale = 'tj'}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => _TestLocaleController(locale)),
        loyaltyApiProvider.overrideWithValue(fakeApi),
      ],
      child: MaterialApp(
        theme: PaykTheme.light,
        home: const ClientCodeScreen(),
      ),
    );
  }

  group('Cashier Code Screen Mockup (Matching Design & loyalty-app)', () {
    testWidgets('Renders all requested widgets matching design screenshot in Tajik', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(locale: 'tj'));
      await tester.pumpAndSettle();

      // 1. Header: «Рамз барои касса»
      expect(find.text('Рамз барои касса'), findsOneWidget);

      // 2. Метка над кодом: «Рамз барои ворид кардан»
      expect(find.text('Рамз барои ворид кардан'), findsOneWidget);

      // 3. Форматированные 8 цифр: «4244 7996»
      expect(find.text('4244 7996'), findsOneWidget);

      // 4. Плашка обратного отсчета
      expect(find.textContaining('Рамз баъд аз'), findsOneWidget);
      expect(find.textContaining('сония нав мешавад'), findsOneWidget);

      // Кнопка обновления с иконкой
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      // 5. Нижняя карточка с 3D-корзиной и подсказкой кассиру
      expect(find.text('Ба кассир нишон диҳед'), findsOneWidget);
      expect(
        find.text('Кассир QR-ро скан мекунад ё 8 рақамро ворид мекунад'),
        findsOneWidget,
      );
      expect(
        find.text('Ҳар рамз як бор ва 40 сония амал мекунад'),
        findsOneWidget,
      );

      // 3D Cart Image asset
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/3d/cart.webp',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Renders correctly in Russian locale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(locale: 'ru'));
      await tester.pumpAndSettle();

      // Header RU
      expect(find.text('Код для кассы'), findsOneWidget);
      expect(find.text('Код для ввода'), findsOneWidget);
      expect(find.text('4244 7996'), findsOneWidget);

      // Таймер RU
      expect(find.textContaining('Код обновится через'), findsOneWidget);

      // Подсказка RU
      expect(find.text('Покажите кассиру'), findsOneWidget);
      expect(
        find.text('Кассир сканирует QR или вводит 8 цифр'),
        findsOneWidget,
      );
      expect(
        find.text('Каждый код одноразовый и действует 40 сек'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping refresh button calls api.code() again', (tester) async {
      await tester.pumpWidget(createWidget(locale: 'tj'));
      await tester.pumpAndSettle();

      expect(fakeApi.codeCallCount, 1);

      // Нажимаем на кнопку обновления
      final refreshBtn = find.byIcon(Icons.refresh_rounded);
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pump();

      expect(fakeApi.codeCallCount, 2);
    });
  });
}
