import '../api/api_client.dart';
import '../api/json_parse.dart';

class Member {
  const Member({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.referralCode,
    this.birthYear,
    this.birthDate,
    this.country,
    this.email,
    this.gender,
    this.avatarUrl,
    this.messages = false,
    this.coinRounding = true,
    this.purchaseNotify = true,
    this.telegram = false,
    this.shoeSize,
    this.pantsSize,
    this.topSize,
    this.dobBonus,
    this.birthDateLocked = false,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final int? birthYear;
  final String? birthDate;
  final String? country;

  /// «Танга из кешбэка»: сервер зовёт это auto_round.
  final bool coinRounding;

  /// Сообщение после каждой покупки и возврата.
  final bool purchaseNotify;
  final String referralCode;
  final String? email;

  /// `m` — мужской, `f` — женский.
  final String? gender;
  final String? avatarUrl;
  final bool messages;
  final bool telegram;

  /// Размер обуви, брюк и верха. Пусто — клиент ещё не указал.
  final String? shoeSize;
  final String? pantsSize;
  final String? topSize;

  /// Сколько дадут за первую указанную дату. Пусто — дата уже есть или бонус уже выдан.
  final double? dobBonus;

  /// Дату меняет только магазин.
  final bool birthDateLocked;

  bool get isSizesComplete {
    bool filled(String? value) => value != null && value.trim().isNotEmpty;
    return filled(shoeSize) && filled(pantsSize) && filled(topSize);
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      firstName: asString(json['first_name']),
      lastName: asString(json['last_name']),
      phone: asString(json['phone']),
      birthYear: asIntOrNull(json['birth_year']),
      birthDate: asStringOrNull(json['birth_date']),
      country: asStringOrNull(json['country']),
      referralCode: asString(json['referral_code']),
      email: asStringOrNull(json['email']),
      gender: _memberGender(asStringOrNull(json['gender'])),
      avatarUrl: asStringOrNull(json['avatar_url']),
      messages: json['messages'] == true,
      coinRounding: json.containsKey('auto_round')
          ? json['auto_round'] == true
          : json['coin_rounding'] != false,
      purchaseNotify:
          !json.containsKey('purchase_notify') ||
          json['purchase_notify'] == true,
      telegram: json['telegram'] == true,
      shoeSize: asStringOrNull(json['shoe_size']),
      pantsSize: asStringOrNull(json['pants_size']),
      topSize: asStringOrNull(json['top_size']),
      dobBonus: asMoneyOrNull(json['dob_bonus']),
      birthDateLocked:
          json['birth_date_locked'] == true ||
          (asStringOrNull(json['birth_date']) ?? '').isNotEmpty,
    );
  }
}

String? _memberGender(String? raw) {
  if (raw == 'm' || raw == 'f') return raw;
  return null;
}

class Rate {
  const Rate({required this.earn, required this.burnCap});

  final double earn;
  final double burnCap;

  factory Rate.fromJson(Object? json) {
    if (json is! Map) return const Rate(earn: 0, burnCap: 0);
    final map = asMap(json);
    return Rate(earn: asMoney(map['earn']), burnCap: asMoney(map['burn_cap']));
  }
}

class ProgramRates {
  const ProgramRates({required this.supermarket, required this.clothes});

  final Rate supermarket;
  final Rate clothes;

  factory ProgramRates.fromJson(Object? json) {
    final map = json is Map ? asMap(json) : const <String, dynamic>{};
    return ProgramRates(
      supermarket: Rate.fromJson(map['SM']),
      clothes: Rate.fromJson(map['CL']),
    );
  }
}

class KeepInfo {
  const KeepInfo({required this.gap, required this.perDay, required this.kept});

  final double gap;
  final double perDay;
  final bool kept;

  factory KeepInfo.fromJson(Map<String, dynamic> json) {
    return KeepInfo(
      gap: asMoney(json['gap']),
      perDay: asMoney(json['per_day']),
      kept: json['kept'] == true,
    );
  }
}

class UpInfo {
  const UpInfo({
    required this.level,
    required this.threshold,
    required this.gap,
    required this.perDay,
    required this.rates,
  });

  final int level;
  final double threshold;
  final double gap;
  final double perDay;
  final ProgramRates rates;

  factory UpInfo.fromJson(Map<String, dynamic> json) {
    return UpInfo(
      level: asInt(json['status']),
      threshold: asMoney(json['threshold']),
      gap: asMoney(json['gap']),
      perDay: asMoney(json['per_day']),
      rates: ProgramRates.fromJson(json['rates']),
    );
  }
}

class Wallet {
  const Wallet({
    required this.status,
    required this.balance,
    required this.onHold,
    required this.debt,
    required this.spendMonth,
    required this.spendSupermarket,
    required this.spendClothes,
    required this.daysLeft,
    required this.keep,
    required this.up,
    required this.nextMonthStatus,
    required this.rates,
    required this.todaySupermarket,
    required this.todayClothes,
  });

  final int status;
  final double balance;
  final double onHold;
  final double debt;
  final double spendMonth;
  final double spendSupermarket;
  final double spendClothes;
  final int daysLeft;
  final KeepInfo? keep;
  final UpInfo? up;
  final int nextMonthStatus;
  final ProgramRates rates;
  final double todaySupermarket;
  final double todayClothes;
}

class Account {
  const Account({
    required this.member,
    required this.wallet,
    required this.store,
    required this.programEnabled,
    this.tierCount = 5,
    this.messagesUnread = 0,
    this.coupon,
  });

  final Member member;
  final Wallet wallet;
  final String store;
  final bool programEnabled;
  final int tierCount;
  final int messagesUnread;
  final BirthdayCoupon? coupon;

  factory Account.fromJson(Map<String, dynamic> json) {
    final program = json['program'] is Map
        ? asMap(json['program'])
        : const <String, dynamic>{};
    final today = json['today'] is Map
        ? asMap(json['today'])
        : const <String, dynamic>{};
    final keep = json['keep'];
    final up = json['up'];
    final thresholds = json['thresholds'];
    return Account(
      member: Member.fromJson(asMap(json['member'])),
      store: asString(program['store']),
      programEnabled: program['enabled'] == true,
      tierCount: thresholds is List && thresholds.isNotEmpty
          ? thresholds.length + 1
          : 5,
      messagesUnread: asInt(json['messages_unread']),
      coupon: json['coupon'] is Map
          ? BirthdayCoupon.fromJson(asMap(json['coupon']))
          : null,
      wallet: Wallet(
        status: asInt(json['status']),
        balance: asMoney(json['balance']),
        onHold: asMoney(json['on_hold']),
        debt: asMoney(json['debt']),
        spendMonth: asMoney(json['spend_month']),
        spendSupermarket: asMoney(json['spend_sm']),
        spendClothes: asMoney(json['spend_cl']),
        daysLeft: asInt(json['days_left']),
        keep: keep is Map ? KeepInfo.fromJson(asMap(keep)) : null,
        up: up is Map ? UpInfo.fromJson(asMap(up)) : null,
        nextMonthStatus: asInt(json['next_month_status']),
        rates: ProgramRates.fromJson(json['rates']),
        todaySupermarket: asMoney(today['SM']),
        todayClothes: asMoney(today['CL']),
      ),
    );
  }
}

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.billAmount,
    this.mode,
    this.format,
    this.note,
    this.billExtId,
  });

  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final DateTime createdAt;
  final double? billAmount;
  final String? mode;
  final String? format;
  final String? note;
  final String? billExtId;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final bill = json['bill'] is Map ? asMap(json['bill']) : null;
    return HistoryEntry(
      id: asInt(json['id']),
      type: asString(json['type']),
      amount: asMoney(json['amount']),
      balanceAfter: asMoney(json['balance_after']),
      createdAt: asDate(json['created_at']),
      billAmount: bill == null ? null : asMoneyOrNull(bill['amount']),
      mode: bill == null ? null : asStringOrNull(bill['mode']),
      format:
          asStringOrNull(json['format']) ??
          (bill == null ? null : asStringOrNull(bill['format'])),
      note: asStringOrNull(json['note']),
      billExtId: bill == null ? null : asStringOrNull(bill['ext_id']),
    );
  }
}

class Invitee {
  const Invitee({
    required this.phone,
    required this.firstName,
    required this.level,
    required this.earned,
    required this.activeUntil,
  });

  final String phone;
  final String firstName;
  final int level;
  final double earned;
  final DateTime activeUntil;

  factory Invitee.fromJson(Map<String, dynamic> json) {
    return Invitee(
      phone: asString(json['phone']),
      firstName: asString(json['first_name']),
      level: asInt(json['level']),
      earned: asMoney(json['earned']),
      activeUntil: asDate(json['active_until']),
    );
  }
}

class FriendsInfo {
  const FriendsInfo({
    required this.code,
    required this.levels,
    required this.months,
    required this.countL1,
    required this.countL2,
    required this.total,
    required this.month,
    required this.invitees,
    this.link,
  });

  final String code;
  final String? link;
  final List<double> levels;
  final int months;
  final int countL1;
  final int countL2;
  final double total;
  final double month;
  final List<Invitee> invitees;

  double get level1 => levels.isEmpty ? 0 : levels.first;
  double get level2 => levels.length < 2 ? 0 : levels[1];

  factory FriendsInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['invitees'];
    return FriendsInfo(
      code: asString(json['code']),
      link: asStringOrNull(json['link']),
      levels: asDoubleList(json['levels']),
      months: asInt(json['months']),
      countL1: asInt(json['count_l1']),
      countL2: asInt(json['count_l2']),
      total: asMoney(json['total']),
      month: asMoney(json['month']),
      invitees: raw is List
          ? [for (final item in raw) Invitee.fromJson(asMap(item))]
          : const [],
    );
  }
}

class PendingCoupon {
  const PendingCoupon({
    required this.id,
    required this.offer,
    required this.minBill,
    required this.usable,
    required this.applied,
    required this.amount,
  });

  final int id;
  final double offer;
  final double minBill;
  final bool usable;
  final bool applied;
  final double amount;

  factory PendingCoupon.fromJson(Map<String, dynamic> json) {
    return PendingCoupon(
      id: asInt(json['id']),
      offer: asMoney(json['offer']),
      minBill: asMoney(json['min_bill']),
      usable: json['usable'] == true,
      applied: json['applied'] == true,
      amount: asMoney(json['amount']),
    );
  }
}

class BirthdayCoupon {
  const BirthdayCoupon({
    required this.amount,
    required this.minBillSm,
    required this.minBillCl,
    required this.validTo,
  });

  final double amount;
  final double minBillSm;
  final double minBillCl;
  final String validTo;

  factory BirthdayCoupon.fromJson(Map<String, dynamic> json) {
    return BirthdayCoupon(
      amount: asMoney(json['amount']),
      minBillSm: asMoney(json['min_bill_sm']),
      minBillCl: asMoney(json['min_bill_cl']),
      validTo: asString(json['valid_to']),
    );
  }
}

class PendingCheck {
  const PendingCheck({
    required this.id,
    required this.format,
    required this.mode,
    required this.v,
    required this.clientConfirmed,
    this.state = 'pending',
    this.billExtId,
    this.amount,
    this.x0,
    this.x,
    this.y,
    this.a,
    this.aStar,
    this.cap,
    this.r = 0,
    this.why,
    this.b = 0,
    this.coin10 = false,
    this.coin10Available = false,
    this.coinDeclined = false,
    this.coinSuggested = false,
    this.cardAmount = 0,
    this.toPay,
    this.cashToPay,
    this.store,
    this.expiresAt,
    this.serverNow,
    this.balance,
    this.debt,
    this.burnMin = 0.5,
    this.eligible,
    this.excludedAmount,
    this.isWholesale = false,
    this.source,
    this.status,
    this.amountBeforeCoupon,
    this.coupon,
  });

  final int id;
  final String state;
  final String format;
  final String? billExtId;
  final double? amount;
  final int? status;
  final double? x0;
  final double? x;
  final double? y;
  final double? a;
  final double? aStar;
  final double? cap;
  final String mode;

  /// Выбранное списание.
  final double v;

  /// Танга.
  final double r;
  final String? why;
  final double b;
  final bool coin10;
  final bool coin10Available;
  final bool coinDeclined;
  final bool coinSuggested;
  final double cardAmount;
  final double? toPay;
  final double? cashToPay;
  final bool clientConfirmed;
  final String? store;
  final DateTime? expiresAt;
  final DateTime? serverNow;
  final double? balance;
  final double? debt;
  final double burnMin;
  final double? eligible;
  final double? excludedAmount;
  final bool isWholesale;
  final String? source;
  final double? amountBeforeCoupon;
  final PendingCoupon? coupon;

  double get burnAmount => v;
  double? get earn => x;
  double? get maxBurn => y;

  factory PendingCheck.fromJson(Map<String, dynamic> json) {
    final burn = json.containsKey('v')
        ? asMoney(json['v'])
        : asMoney(json['burn_amount']);
    final star = asMoneyOrNull(json['a_star']) ?? asMoneyOrNull(json['a']);
    return PendingCheck(
      id: asInt(json['id']),
      state: asString(json['state']).isEmpty
          ? 'pending'
          : asString(json['state']),
      format: asString(json['format']),
      billExtId: asStringOrNull(json['bill_ext_id']),
      amount: asMoneyOrNull(json['amount']),
      status: asIntOrNull(json['status']),
      x0: asMoneyOrNull(json['x0']),
      x: asMoneyOrNull(json['x']),
      y: asMoneyOrNull(json['y']),
      a: asMoneyOrNull(json['a']),
      aStar: star,
      cap: asMoneyOrNull(json['cap']),
      mode: asString(json['mode']).isEmpty ? 'earn' : asString(json['mode']),
      v: burn,
      r: asMoney(json['r'] ?? json['round']),
      why: asStringOrNull(json['why']),
      b: asMoney(json['b']),
      coin10: json['coin10'] == true || json['to_ten'] == true,
      coin10Available: json['coin10_available'] == true,
      coinDeclined: json['coin_declined'] == true,
      coinSuggested: json['coin_suggested'] == true,
      cardAmount: asMoney(json['card_amount']),
      toPay: asMoneyOrNull(json['to_pay']),
      cashToPay:
          asMoneyOrNull(json['cash_to_pay']) ?? asMoneyOrNull(json['to_pay']),
      clientConfirmed: json['client_confirmed'] == true,
      store: asStringOrNull(json['store']),
      expiresAt: json['expires_at'] == null ? null : asDate(json['expires_at']),
      serverNow: json['server_now'] == null ? null : asDate(json['server_now']),
      balance: asMoneyOrNull(json['balance']),
      debt: asMoneyOrNull(json['debt']),
      burnMin: json['burn_min'] == null ? 0.5 : asMoney(json['burn_min']),
      eligible: asMoneyOrNull(json['eligible']),
      excludedAmount: asMoneyOrNull(json['excluded_amount']),
      isWholesale: json['is_wholesale'] == true,
      source: asStringOrNull(json['source']),
      amountBeforeCoupon: asMoneyOrNull(json['amount_before_coupon']),
      coupon: json['coupon'] is Map
          ? PendingCoupon.fromJson(asMap(json['coupon']))
          : null,
    );
  }
}

class QuoteResult {
  const QuoteResult({this.preview, this.message});

  final PendingCheck? preview;
  final String? message;

  factory QuoteResult.fromJson(Map<String, dynamic> json) {
    final preview = json['preview'];
    return QuoteResult(
      preview: preview is Map ? PendingCheck.fromJson(asMap(preview)) : null,
      message: asStringOrNull(json['message']),
    );
  }
}

class PhoneChangeStart {
  const PhoneChangeStart({
    required this.phone,
    required this.oldPhone,
    required this.resendIn,
    required this.ttl,
    this.debugOld,
    this.debugNew,
  });

  final String phone;
  final String oldPhone;
  final int resendIn;
  final int ttl;
  final String? debugOld;
  final String? debugNew;

  factory PhoneChangeStart.fromJson(Map<String, dynamic> json) {
    return PhoneChangeStart(
      phone: asString(json['phone']),
      oldPhone: asString(json['old_phone']),
      resendIn: asInt(json['resend_in']),
      ttl: asInt(json['ttl']),
      debugOld: asStringOrNull(json['debug_old']),
      debugNew: asStringOrNull(json['debug_new']),
    );
  }
}

class ClosedBill {
  const ClosedBill({
    required this.id,
    required this.state,
    this.mode,
    this.earn,
    this.burn,
    this.round,
    this.amount,
    this.coupon,
  });

  final int id;
  final String state;
  final String? mode;
  final double? earn;
  final double? burn;
  final double? round;
  final double? amount;
  final double? coupon;

  factory ClosedBill.fromJson(Map<String, dynamic> json) {
    final bill = json['bill'] is Map ? asMap(json['bill']) : null;
    return ClosedBill(
      id: asInt(json['id']),
      state: asString(json['state']),
      mode: bill == null ? null : asStringOrNull(bill['mode']),
      earn: bill == null ? null : asMoneyOrNull(bill['earn']),
      burn: bill == null ? null : asMoneyOrNull(bill['burn']),
      round: bill == null ? null : asMoneyOrNull(bill['round']),
      amount: bill == null ? null : asMoneyOrNull(bill['amount']),
      coupon: bill == null ? null : asMoneyOrNull(bill['coupon']),
    );
  }
}

class PendingSnapshot {
  const PendingSnapshot({this.pending, this.lastClosed});

  final PendingCheck? pending;
  final ClosedBill? lastClosed;

  factory PendingSnapshot.fromJson(Map<String, dynamic> json) {
    final pending = json['pending'];
    final closed = json['last_closed'];
    return PendingSnapshot(
      pending: pending is Map ? PendingCheck.fromJson(asMap(pending)) : null,
      lastClosed: closed is Map ? ClosedBill.fromJson(asMap(closed)) : null,
    );
  }
}

class CashierCode {
  const CashierCode({required this.qr, required this.code, required this.ttl});

  final String qr;
  final String code;
  final int ttl;

  factory CashierCode.fromJson(Map<String, dynamic> json) {
    return CashierCode(
      qr: asString(json['qr']),
      code: asString(json['code']),
      ttl: asInt(json['ttl']),
    );
  }
}

class ProgramInfo {
  const ProgramInfo({
    required this.title,
    required this.store,
    required this.enabled,
    required this.countries,
    required this.birthYearMin,
    required this.birthYearMax,
  });

  final String title;
  final String store;
  final bool enabled;
  final List<String> countries;
  final int birthYearMin;
  final int birthYearMax;

  factory ProgramInfo.fromJson(Map<String, dynamic> json) {
    final countries = json['countries'];
    return ProgramInfo(
      title: asString(json['title']),
      store: asString(json['store']),
      enabled: json['enabled'] == true,
      countries: countries is List
          ? [for (final item in countries) asString(item)]
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
      birthYearMin: asInt(json['birth_year_min']),
      birthYearMax: asInt(json['birth_year_max']),
    );
  }
}

class TierRule {
  const TierRule({required this.level, required this.rates});

  final int level;
  final ProgramRates rates;

  factory TierRule.fromJson(Map<String, dynamic> json) {
    return TierRule(
      level: asInt(json['status']),
      rates: ProgramRates.fromJson(json['rates']),
    );
  }
}

class RulesInfo {
  const RulesInfo({
    required this.thresholds,
    required this.statuses,
    required this.referralLevels,
    required this.months,
    this.burnMin = 0,
    this.stackAbs = 0,
  });

  final List<double> thresholds;
  final List<TierRule> statuses;
  final List<double> referralLevels;
  final int months;
  final double burnMin;
  final double stackAbs;

  double get level1 => referralLevels.isEmpty ? 0 : referralLevels.first;
  double get level2 => referralLevels.length < 2 ? 0 : referralLevels[1];

  factory RulesInfo.fromJson(Map<String, dynamic> json) {
    final statuses = json['statuses'];
    final referral = json['referral'] is Map
        ? asMap(json['referral'])
        : const <String, dynamic>{};
    return RulesInfo(
      thresholds: asDoubleList(json['thresholds']),
      statuses: statuses is List
          ? [for (final item in statuses) TierRule.fromJson(asMap(item))]
          : const [],
      referralLevels: asDoubleList(referral['levels']),
      months: asInt(referral['months']),
      burnMin: asMoney(json['burn_min']),
      stackAbs: asMoney(json['stack_abs']),
    );
  }
}

class OtpChallenge {
  const OtpChallenge({required this.phone});

  final String phone;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) {
    return OtpChallenge(phone: asString(json['phone']));
  }
}

class VerifyResult {
  const VerifyResult.login(this.tokens)
    : registrationToken = null,
      phone = null;

  const VerifyResult.register({
    required this.registrationToken,
    required this.phone,
  }) : tokens = null;

  final TokenPair? tokens;
  final String? registrationToken;
  final String? phone;

  bool get needsRegistration => tokens == null;
}

class RegisterInput {
  const RegisterInput({
    required this.registrationToken,
    required this.firstName,
    required this.lastName,
    required this.birthYear,
    required this.country,
    required this.consentPd,
    required this.consentMessages,
    this.email,
    this.referralCode,
    this.birthDate,
  });

  final String registrationToken;
  final String firstName;
  final String lastName;
  final int birthYear;
  final String country;
  final bool consentPd;
  final bool consentMessages;
  final String? email;
  final String? referralCode;
  final String? birthDate;

  Map<String, dynamic> toJson() {
    return {
      'registration_token': registrationToken,
      'first_name': firstName,
      'last_name': lastName,
      'birth_year': birthYear,
      if (birthDate != null) 'birth_date': birthDate,
      'country': country,
      'email': (email == null || email!.isEmpty) ? null : email,
      'referral_code': (referralCode == null || referralCode!.isEmpty)
          ? null
          : referralCode,
      'consent_pd': consentPd,
      'consent_messages': consentMessages,
      'locale': 'ru',
    };
  }
}

class LoyaltyMessageItem {
  const LoyaltyMessageItem({
    required this.id,
    required this.kind,
    required this.text,
    required this.createdAt,
    required this.read,
  });

  final int id;
  final String kind;
  final String text;
  final DateTime createdAt;
  final bool read;

  factory LoyaltyMessageItem.fromJson(Map<String, dynamic> json) {
    return LoyaltyMessageItem(
      id: asInt(json['id']),
      kind: asString(json['kind']),
      text: asString(json['text']),
      createdAt: asDate(json['created_at']),
      read: json['read'] == true,
    );
  }
}

class TelegramLinks {
  const TelegramLinks({
    required this.bot,
    required this.appLink,
    required this.webLink,
    required this.token,
    required this.linked,
  });

  final String bot;
  final String appLink;
  final String webLink;
  final String token;
  final bool linked;

  factory TelegramLinks.fromJson(Map<String, dynamic> json) {
    return TelegramLinks(
      bot: asString(json['bot']),
      appLink: asString(json['app_link']),
      webLink: asString(json['web_link']),
      token: asString(json['token']),
      linked: json['linked'] == true,
    );
  }
}

class ShowcaseContact {
  const ShowcaseContact({required this.name, required this.phone});

  final String name;
  final String phone;

  factory ShowcaseContact.fromJson(Map<String, dynamic> json) {
    return ShowcaseContact(
      name: asString(json['name']),
      phone: asString(json['phone']),
    );
  }
}

/// Карточка рекламы PAYK: тексты на обоих языках, картинка владельца или 3D-иллюстрация.
class ShowcaseCard {
  const ShowcaseCard({
    required this.id,
    required this.titleTj,
    required this.titleRu,
    required this.textTj,
    required this.textRu,
    this.imageUrl,
    this.imageW,
    this.imageH,
    required this.art,
  });

  final int id;
  final String titleTj;
  final String titleRu;
  final String textTj;
  final String textRu;
  final String? imageUrl;
  final int? imageW;
  final int? imageH;
  final String art;

  String titleFor(String locale) => locale == 'ru' ? titleRu : titleTj;

  String textFor(String locale) => locale == 'ru' ? textRu : textTj;

  double get aspectRatio {
    final w = imageW;
    final h = imageH;
    if (w == null || h == null || w <= 0 || h <= 0) return 2;
    return w / h;
  }

  factory ShowcaseCard.fromJson(Map<String, dynamic> json) {
    final art = asString(json['art']);
    return ShowcaseCard(
      id: asInt(json['id']),
      titleTj: asString(json['title_tj']),
      titleRu: asString(json['title_ru']),
      textTj: asString(json['text_tj']),
      textRu: asString(json['text_ru']),
      imageUrl: asStringOrNull(json['image_url']),
      imageW: _positiveInt(json['image_w']),
      imageH: _positiveInt(json['image_h']),
      art: art.isEmpty ? 'sparkles' : art,
    );
  }
}

class ShowcaseFeed {
  const ShowcaseFeed({
    required this.cards,
    required this.leadSentToday,
    required this.contact,
  });

  final List<ShowcaseCard> cards;
  final bool leadSentToday;
  final ShowcaseContact contact;

  ShowcaseFeed copyWith({bool? leadSentToday}) {
    return ShowcaseFeed(
      cards: cards,
      leadSentToday: leadSentToday ?? this.leadSentToday,
      contact: contact,
    );
  }

  factory ShowcaseFeed.fromJson(Map<String, dynamic> json) {
    final raw = json['cards'];
    final contact = json['contact'];
    return ShowcaseFeed(
      cards: raw is List
          ? [for (final item in raw) ShowcaseCard.fromJson(asMap(item))]
          : const [],
      leadSentToday: json['lead_sent_today'] == true,
      contact: contact is Map
          ? ShowcaseContact.fromJson(asMap(contact))
          : const ShowcaseContact(name: '', phone: ''),
    );
  }
}

class ShowcaseLeadResult {
  const ShowcaseLeadResult(this.status);

  final String status;

  bool get sent => status == 'sent';

  bool get already => status == 'already';

  factory ShowcaseLeadResult.fromJson(Map<String, dynamic> json) {
    return ShowcaseLeadResult(asString(json['status']));
  }
}

/// Персональное предложение по размеру: остаток со сроком или новая партия.
class SizeOffer {
  SizeOffer({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.size,
    this.imageUrl,
    this.originalPrice,
    this.discountPrice,
    this.expiresAt,
    this.serverNow,
    this.promoCode,
    this.claimed = false,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  final int id;
  final String type;
  final String category;
  final String title;
  final String description;
  final String size;
  final String? imageUrl;
  final double? originalPrice;
  final double? discountPrice;
  final DateTime? expiresAt;

  /// Часы сервера в момент ответа. Обратный отсчёт считаем от них.
  final DateTime? serverNow;
  final String? promoCode;
  final bool claimed;
  final DateTime fetchedAt;

  bool get flash => type == 'FLASH_SALE';

  Duration remainingAt(DateTime now) {
    final deadline = expiresAt;
    if (deadline == null) return Duration.zero;
    final base = serverNow ?? fetchedAt;
    final left = deadline.difference(base.add(now.difference(fetchedAt)));
    if (left.isNegative) return Duration.zero;
    return left;
  }

  factory SizeOffer.fromJson(Map<String, dynamic> json) {
    return SizeOffer(
      id: asInt(json['id']),
      type: asString(json['type']),
      category: asString(json['category']),
      title: asString(json['title']),
      description: asString(json['description']),
      size: asString(json['size']),
      imageUrl: asStringOrNull(json['image_url']),
      originalPrice: asMoneyOrNull(json['original_price']),
      discountPrice: asMoneyOrNull(json['discount_price']),
      expiresAt: _dateOrNull(json['expires_at']),
      serverNow: _dateOrNull(json['server_now']),
      promoCode: asStringOrNull(json['promo_code']),
      claimed: json['claimed'] == true,
    );
  }
}

/// `47:59:12` — часы не сбрасываются после суток, срок акции доходит до двух дней.
String formatOfferCountdown(Duration value) {
  final seconds = value.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(rest)}';
}

DateTime? _dateOrNull(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.parse(value).toLocal();
}

int? _positiveInt(Object? value) {
  final parsed = asIntOrNull(value);
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}
