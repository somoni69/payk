import 'package:flutter_test/flutter_test.dart';
import 'package:payk/data/models/models.dart';

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
}
