import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk/core/size_offers_logic.dart';
import 'package:payk/core/theme/payk_theme.dart';
import 'package:payk/data/models/models.dart';
import 'package:payk/data/providers.dart';
import 'package:payk/features/sizes/size_offers_screen.dart';

void main() {
  test('sizes are complete only when shoe, pants and top are filled', () {
    const empty = Member(firstName: 'А', lastName: 'Б', phone: '+992900000000', referralCode: 'A');
    expect(empty.isSizesComplete, isFalse);

    const partial = Member(
      firstName: 'А',
      lastName: 'Б',
      phone: '+992900000000',
      referralCode: 'A',
      shoeSize: '40',
      pantsSize: '32',
    );
    expect(partial.isSizesComplete, isFalse);

    final parsed = Member.fromJson({
      'first_name': 'А',
      'last_name': 'Б',
      'phone': '+992900000000',
      'referral_code': 'A',
      'shoe_size': '40',
      'pants_size': 'L',
      'top_size': 'XL',
    });
    expect(parsed.shoeSize, '40');
    expect(parsed.pantsSize, 'L');
    expect(parsed.topSize, 'XL');
    expect(parsed.isSizesComplete, isTrue);
  });

  test('flash countdown follows the server clock, not a stale phone clock', () {
    final fetched = DateTime(2026, 11, 10, 12);
    final offer = SizeOffer(
      id: 7,
      type: 'FLASH_SALE',
      category: 'SHOE',
      title: 'Кроссовки',
      description: '',
      size: '40',
      expiresAt: DateTime(2026, 11, 12, 12),
      serverNow: DateTime(2026, 11, 10, 12),
      fetchedAt: fetched,
    );
    expect(offer.remainingAt(fetched), const Duration(hours: 48));
    expect(offer.remainingAt(fetched.add(const Duration(hours: 1, seconds: 5))), const Duration(hours: 46, minutes: 59, seconds: 55));
    expect(formatOfferCountdown(const Duration(hours: 47, minutes: 59, seconds: 12)), '47:59:12');
    expect(offer.flash, isTrue);
  });

  test('offer json keeps the claim code and prices', () {
    final offer = SizeOffer.fromJson({
      'id': 3,
      'type': 'NEW_ARRIVAL',
      'category': 'TOP',
      'title': 'Куртка',
      'description': 'Новая партия',
      'size': 'XL',
      'image_url': '/loyalty-app/size-offers/img/sz_abc.jpg',
      'original_price': null,
      'discount_price': null,
      'expires_at': null,
      'server_now': '2026-11-10T07:00:00Z',
      'promo_code': 'K7M2QP',
      'claimed': true,
    });
    expect(offer.claimed, isTrue);
    expect(offer.promoCode, 'K7M2QP');
    expect(offer.flash, isFalse);
    expect(offer.originalPrice, isNull);
    expect(offer.remainingAt(DateTime.now()), Duration.zero);
  });

  test('size_offers_logic handles toggle, custom sizes, patch diff, merge, and actions', () {
    expect(toggleSizeSelection('40', '40'), isNull);
    expect(toggleSizeSelection('40', '41'), '41');
    expect(
      rowsWithCurrentSize(shoeSizeRows, '47').expand((r) => r),
      contains('47'),
    );
    expect(
      buildSizesPatch(
        initialShoe: '40',
        initialPants: 'L',
        initialTop: null,
        draftShoe: '41',
        draftPants: 'L',
        draftTop: 'XL',
      ),
      {'shoe_size': '41', 'top_size': 'XL'},
    );
    expect(
      isSizesEmpty(
        const Member(
          firstName: 'A',
          lastName: 'B',
          phone: '1',
          referralCode: 'R',
        ),
      ),
      isTrue,
    );

    final fetched = DateTime(2026, 11, 12, 10);
    final activeFlash = SizeOffer(
      id: 10,
      type: 'FLASH_SALE',
      category: 'SHOE',
      title: 'Кроссовки',
      description: 'Описание',
      size: '42',
      originalPrice: 200,
      discountPrice: 150,
      status: 'ACTIVE',
      expiresAt: fetched.add(const Duration(hours: 25, minutes: 5)),
      serverNow: fetched,
      fetchedAt: fetched,
    );
    expect(discountPercent(activeFlash.originalPrice, activeFlash.discountPrice), 25);
    expect(liveOfferStatus(activeFlash, fetched), 'ACTIVE');
    expect(resolveOfferAction(activeFlash, 'ACTIVE'), OfferAction.claim);
    expect(
      formatOfferCountdownWithDays(const Duration(hours: 25, minutes: 5, seconds: 9), 'д'),
      '1\u00A0д 01:05:09',
    );
    expect(formatPromoCode('K7M2QP'), 'K7M 2QP');

    final issued = activeFlash.copyWith(claimed: true, promoCode: 'K7M2QP', issued: true);
    expect(resolveOfferAction(issued, 'ACTIVE'), OfferAction.issued);
    expect(showOfferOnHome(issued, 'ACTIVE'), isFalse);

    final merged = mergeSizeOffers(
      [activeFlash.copyWith(claimed: true, promoCode: 'K7M2QP')],
      [activeFlash],
    );
    expect(merged.single.claimed, isTrue);
    expect(merged.single.promoCode, 'K7M2QP');
  });

  testWidgets('SizeOffersScreen shows issued badge without promo code', (tester) async {
    final now = DateTime.now();
    final issuedOffer = SizeOffer(
      id: 5,
      type: 'FLASH_SALE',
      category: 'SHOE',
      title: 'Ботинки',
      description: 'Зимние',
      size: '42',
      originalPrice: 400,
      discountPrice: 300,
      status: 'ACTIVE',
      claimed: true,
      issued: true,
      promoCode: 'ABC123',
      expiresAt: now.add(const Duration(hours: 3)),
      serverNow: now,
      fetchedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sizeOffersFeedProvider.overrideWith(
            () => _FakeSizeOffersFeedNotifier(
              SizeOffersResponse(items: [issuedOffer], serverNow: now),
            ),
          ),
        ],
        child: MaterialApp(
          theme: PaykTheme.light,
          home: const SizeOffersScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ботинки'), findsOneWidget);
    expect(find.text('Получено'), findsWidgets);
    expect(find.textContaining('ABC'), findsNothing);
  });

  testWidgets('SizeOffersScreen empty state renders compact pill CTA button', (tester) async {
    final now = DateTime.now();
    const emptyAccount = Account(
      store: 'MSX',
      member: Member(
        id: 1,
        firstName: 'А',
        lastName: 'Б',
        phone: '+992900000000',
        referralCode: 'A',
      ),
      wallet: Wallet(
        status: 1,
        balance: 0,
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
          supermarket: Rate(earn: 0.03, burnCap: 0.5),
          clothes: Rate(earn: 0.05, burnCap: 0.5),
        ),
        todaySupermarket: 0,
        todayClothes: 0,
      ),
      programEnabled: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meProvider.overrideWith((ref) => emptyAccount),
          sizeOffersFeedProvider.overrideWith(
            () => _FakeSizeOffersFeedNotifier(
              SizeOffersResponse(items: const [], serverNow: now),
            ),
          ),
        ],
        child: MaterialApp(
          theme: PaykTheme.light,
          home: const SizeOffersScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Указать размеры'), findsOneWidget);
    final buttonFinder = find.ancestor(
      of: find.text('Указать размеры'),
      matching: find.byType(FilledButton),
    );
    expect(buttonFinder, findsOneWidget);
    final buttonSize = tester.getSize(buttonFinder);
    expect(buttonSize.width, greaterThanOrEqualTo(180));
    expect(buttonSize.width, lessThan(350));
  });
}

class _FakeSizeOffersFeedNotifier extends SizeOffersFeedNotifier {
  _FakeSizeOffersFeedNotifier(this._response);

  final SizeOffersResponse _response;

  @override
  Future<SizeOffersResponse> build() async => _response;
}
