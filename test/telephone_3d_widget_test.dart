import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/i18n/locale_controller.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/core/widgets/telephone_3d_icon.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/friends/friends_screen.dart';
import 'package:payk/features/profile/phone_change_screen.dart';
import 'package:payk/features/profile/profile_screen.dart';
import 'package:payk/features/showcase/lead_sheet.dart';

class _TestLocale extends LocaleController {
  _TestLocale(this.value);
  final String value;

  @override
  String build() => value;
}

Finder _findTelephoneAsset() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == Telephone3dIcon.assetPath,
  );
}

const _account = Account(
  member: Member(
    firstName: 'Фарзод',
    lastName: 'Сомони',
    phone: '+992900000000',
    referralCode: 'SO-4654',
    messages: true,
    telegram: false,
  ),
  wallet: Wallet(
    status: 1,
    balance: 500,
    onHold: 0,
    debt: 0,
    spendMonth: 100,
    spendSupermarket: 60,
    spendClothes: 40,
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
  store: 'MSX Алмоси',
  programEnabled: true,
);

void main() {
  Widget wrap(Widget child, {FriendsInfo? friends}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith(() => _TestLocale('ru')),
        meProvider.overrideWith((ref) => _account),
        if (friends != null) friendsProvider.overrideWith((ref) => friends),
      ],
      child: MaterialApp(theme: PaykTheme.light, home: child),
    );
  }

  testWidgets('ProfileDetailsScreen renders 3D telephone icon next to user phone', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ProfileDetailsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('+992 90 000 00 00'), findsOneWidget);
    expect(find.byType(Telephone3dIcon), findsOneWidget);
    expect(_findTelephoneAsset(), findsOneWidget);
  });

  testWidgets('Store contact sheet uses 3D telephone icon for phone call tile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(const ProfileScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Связь с магазином'));
    await tester.pumpAndSettle();

    expect(find.text('Звонок в магазин'), findsOneWidget);
    expect(find.byIcon(Icons.phone_in_talk_rounded), findsNothing);
    expect(_findTelephoneAsset(), findsOneWidget);
  });

  testWidgets('PhoneChangeScreen renders 3D telephone icon on current number card', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const PhoneChangeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('+992 90 000 00 00'), findsOneWidget);
    expect(find.byType(Telephone3dIcon), findsOneWidget);
    expect(_findTelephoneAsset(), findsOneWidget);
  });

  testWidgets('PaykLeadSheet uses 3D telephone icon in contact card', (tester) async {
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: PaykLeadSheet(
            cardId: 1,
            contact: const ShowcaseContact(name: 'Фарзод Сомони', phone: '992900112233'),
            onSent: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+992 90 011 22 33'), findsOneWidget);
    expect(find.byIcon(Icons.phone_rounded), findsNothing);
    expect(_findTelephoneAsset(), findsOneWidget);
  });

  testWidgets('FriendsScreen renders 3D telephone icon next to invitee phone', (
    tester,
  ) async {
    final friends = FriendsInfo(
      code: 'SO-4654',
      levels: const [0.01, 0.005],
      months: 12,
      countL1: 1,
      countL2: 0,
      total: 15,
      month: 5,
      invitees: [
        Invitee(
          phone: '+992 90 123 45 67',
          firstName: 'Алишер',
          level: 2,
          earned: 15,
          activeUntil: DateTime(2027, 1, 1),
        ),
      ],
    );

    await tester.pumpWidget(wrap(const FriendsScreen(), friends: friends));
    await tester.pumpAndSettle();

    expect(find.text('+992 90 123 45 67'), findsOneWidget);
    expect(find.byType(Telephone3dIcon), findsOneWidget);
    expect(_findTelephoneAsset(), findsOneWidget);
  });
}
