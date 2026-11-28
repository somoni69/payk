import '../../core/formats.dart';
import '../api/api_client.dart';
import '../api/json_parse.dart';

export 'receipt_models.dart';

/// Выбор клиента на экране кода для кассы 1С: копить, потратить немного (кэшбэк сохраняется)
/// или потратить максимум.
enum SpendPref {
  earn('earn'),
  keep('keep'),
  max('max');

  const SpendPref(this.apiValue);
  final String apiValue;
}

SpendPref? parseSpendPref(String? raw) {
  return switch (raw) {
    'earn' => SpendPref.earn,
    'keep' => SpendPref.keep,
    'max' => SpendPref.max,
    _ => null,
  };
}

/// Выбор списания и купона на экране кода, передаваемый в `POST /me/code`.
class CodeChoice {
  const CodeChoice({required this.spend, required this.coupon});

  final SpendPref spend;
  final bool coupon;

  CodeChoice copyWith({SpendPref? spend, bool? coupon}) => CodeChoice(
    spend: spend ?? this.spend,
    coupon: coupon ?? this.coupon,
  );

  String get key => '${spend.apiValue}:${coupon ? 1 : 0}';

  @override
  bool operator ==(Object other) =>
      other is CodeChoice && other.spend == spend && other.coupon == coupon;

  @override
  int get hashCode => Object.hash(spend, coupon);
}

class Member {
  const Member({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.referralCode,
    this.referralLink,
    this.id,
    this.birthYear,
    this.birthDate,
    this.country,
    this.email,
    this.gender,
    this.avatarUrl,
    this.messages = false,
    this.coinRounding = true,
    this.purchaseNotify = true,
    this.spendPref = SpendPref.earn,
    this.couponPref = true,
    this.telegram = false,
    this.google,
    this.shoeSize,
    this.pantsSize,
    this.topSize,
    this.dobBonus,
    this.birthDateLocked = false,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final int? id;
  final int? birthYear;
  final String? birthDate;
  final String? country;

  /// «Танга из кешбэка»: сервер зовёт это auto_round.
  final bool coinRounding;

  /// Сообщение после каждой покупки и возврата.
  final bool purchaseNotify;

  /// Последний выбор списания на экране кода для кассы 1С.
  final SpendPref spendPref;

  /// Применять ли купон ко дню рождения на экране кода.
  final bool couponPref;
  final String referralCode;

  /// Ссылка-приглашение участника (`https://…/r/<код>`), 26.11.2026.
  final String? referralLink;
  final String? email;

  /// `m` — мужской, `f` — женский.
  final String? gender;
  final String? avatarUrl;
  final bool messages;
  final bool telegram;

  /// Привязанный аккаунт Google (`{email}`) или `null`.
  final GoogleLink? google;

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
      id: asIntOrNull(json['id']),
      firstName: asString(json['first_name']),
      lastName: asString(json['last_name']),
      phone: asString(json['phone']),
      birthYear: asIntOrNull(json['birth_year']),
      birthDate: asStringOrNull(json['birth_date']),
      country: asStringOrNull(json['country']),
      referralCode: asString(json['referral_code']),
      referralLink: asStringOrNull(json['referral_link']),
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
      spendPref:
          parseSpendPref(asStringOrNull(json['spend_pref'])) ?? SpendPref.earn,
      couponPref:
          !json.containsKey('coupon_pref') || json['coupon_pref'] == true,
      telegram: json['telegram'] == true,
      google: json['google'] is Map
          ? GoogleLink.fromJson(asMap(json['google']))
          : null,
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
  const ProgramRates({
    required this.supermarket,
    required this.clothes,
    this.restaurant,
  });

  final Rate supermarket;
  final Rate clothes;
  final Rate? restaurant;

  Rate byFormat(String format) {
    return switch (format) {
      'SM' => supermarket,
      'CL' => clothes,
      'RS' => restaurant ?? const Rate(earn: 0, burnCap: 0),
      _ => supermarket,
    };
  }

  Rate? rateFor(String format) {
    return switch (format) {
      'SM' => supermarket,
      'CL' => clothes,
      'RS' => restaurant,
      _ => null,
    };
  }

  factory ProgramRates.fromJson(Object? json) {
    final map = json is Map ? asMap(json) : const <String, dynamic>{};
    return ProgramRates(
      supermarket: Rate.fromJson(map['SM']),
      clothes: Rate.fromJson(map['CL']),
      restaurant: map['RS'] is Map ? Rate.fromJson(map['RS']) : null,
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

/// Кошелёк одного магазина: кэшбэк «Супермаркета» тратится только в «Супермаркете»,
/// «Либос» — только в «Либос».
class StoreWallet {
  const StoreWallet({
    required this.balance,
    this.reserved = 0,
    required this.onHold,
    required this.debt,
  });

  static const empty = StoreWallet(balance: 0, reserved: 0, onHold: 0, debt: 0);

  final double balance;
  final double reserved;
  final double onHold;
  final double debt;

  factory StoreWallet.fromJson(Object? json) {
    final map = json is Map ? asMap(json) : const <String, dynamic>{};
    return StoreWallet(
      balance: asMoney(map['balance']),
      reserved: asMoney(map['reserved']),
      onHold: asMoney(map['on_hold']),
      debt: asMoney(map['debt']),
    );
  }
}

class StoreWallets {
  const StoreWallets({
    required this.sm,
    required this.cl,
    this.rs = StoreWallet.empty,
  });

  static const formats = ['SM', 'CL', 'RS'];

  final StoreWallet sm;
  final StoreWallet cl;
  final StoreWallet rs;

  StoreWallet byFormat(String format) => switch (format) {
    'CL' => cl,
    'RS' => rs,
    _ => sm,
  };

  factory StoreWallets.fromJson(Map<String, dynamic> json) {
    return StoreWallets(
      sm: StoreWallet.fromJson(json['SM']),
      cl: StoreWallet.fromJson(json['CL']),
      rs: StoreWallet.fromJson(json['RS']),
    );
  }
}

class Wallet {
  const Wallet({
    required this.status,
    required this.balance,
    this.reserved = 0,
    required this.onHold,
    required this.debt,
    this.wallets,
    required this.spendMonth,
    required this.spendSupermarket,
    required this.spendClothes,
    this.spendRestaurant = 0,
    required this.daysLeft,
    required this.keep,
    required this.up,
    required this.nextMonthStatus,
    required this.rates,
    required this.todaySupermarket,
    required this.todayClothes,
    this.todayRestaurant = 0,
  });

  final int status;
  final double balance;

  /// Отложено для покупки, которую сейчас проводит касса 1С.
  final double reserved;
  final double onHold;
  final double debt;

  /// Раздельные кошельки SM/CL/RS (если сервер их вернул).
  final StoreWallets? wallets;

  /// Кошельки по магазинам: для старого сервера без `wallets` весь баланс — в SM.
  StoreWallets get storeWallets =>
      wallets ??
      StoreWallets(
        sm: StoreWallet(
          balance: balance,
          reserved: reserved,
          onHold: onHold,
          debt: debt,
        ),
        cl: StoreWallet.empty,
        rs: StoreWallet.empty,
      );

  final double spendMonth;
  final double spendSupermarket;
  final double spendClothes;
  final double spendRestaurant;
  final int daysLeft;
  final KeepInfo? keep;
  final UpInfo? up;
  final int nextMonthStatus;
  final ProgramRates rates;
  final double todaySupermarket;
  final double todayClothes;
  final double todayRestaurant;

  double spendByFormat(String format) => switch (format) {
    'SM' => spendSupermarket,
    'CL' => spendClothes,
    'RS' => spendRestaurant,
    _ => 0,
  };
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
    this.burnKeepsCashback = false,
    this.formats,
  });

  final Member member;
  final Wallet wallet;
  final String store;
  final bool programEnabled;
  final int tierCount;
  final int messagesUnread;
  final BirthdayCoupon? coupon;

  /// Кешбэк с оплаты деньгами при любом списании (24.11.2026): на экране кода два варианта вместо трёх.
  final bool burnKeepsCashback;

  /// Форматы активных касс магазина (порядок SM, CL, RS); `null` — старый сервер.
  final List<String>? formats;

  /// Форматы для отображения отделов, ставок, купона и фильтра чеков.
  List<String> get activeFormats => resolveActiveFormats(
    formats,
    hasRestaurant: wallet.rates.restaurant != null,
  );

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
      burnKeepsCashback: json['burn_keeps_cashback'] == true,
      formats: parseFormatsField(json['formats']),
      wallet: Wallet(
        status: asInt(json['status']),
        balance: asMoney(json['balance']),
        reserved: asMoney(json['reserved']),
        onHold: asMoney(json['on_hold']),
        debt: asMoney(json['debt']),
        wallets: json['wallets'] is Map
            ? StoreWallets.fromJson(asMap(json['wallets']))
            : null,
        spendMonth: asMoney(json['spend_month']),
        spendSupermarket: asMoney(json['spend_sm']),
        spendClothes: asMoney(json['spend_cl']),
        spendRestaurant: asMoney(json['spend_rs']),
        daysLeft: asInt(json['days_left']),
        keep: keep is Map ? KeepInfo.fromJson(asMap(keep)) : null,
        up: up is Map ? UpInfo.fromJson(asMap(up)) : null,
        nextMonthStatus: asInt(json['next_month_status']),
        rates: ProgramRates.fromJson(json['rates']),
        todaySupermarket: asMoney(today['SM']),
        todayClothes: asMoney(today['CL']),
        todayRestaurant: asMoney(today['RS']),
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
    this.expiresAt,
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
  final DateTime? expiresAt;

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
      expiresAt: json['expires_at'] == null ? null : asDate(json['expires_at']),
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
    this.firstBonus = 0,
    this.firstBonusMin = 0,
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

  /// Разовый бонус за первую покупку приглашённого друга (0 — выключен) и минимальный чек.
  final double firstBonus;
  final double firstBonusMin;

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
      firstBonus: asMoney(json['first_bonus']),
      firstBonusMin: asMoney(json['first_bonus_min']),
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
    this.minBillRs,
    required this.validTo,
    this.status = 'issued',
  });

  final double amount;
  final double minBillSm;
  final double minBillCl;
  final double? minBillRs;
  final String validTo;
  final String status;

  /// Минимальный чек купона в формате; `null` — сервер не прислал значение.
  double? minBillFor(String format) {
    return switch (format) {
      'SM' => minBillSm,
      'CL' => minBillCl,
      'RS' => minBillRs,
      _ => null,
    };
  }

  factory BirthdayCoupon.fromJson(Map<String, dynamic> json) {
    final status = asString(json['status']);
    return BirthdayCoupon(
      amount: asMoney(json['amount']),
      minBillSm: asMoney(json['min_bill_sm']),
      minBillCl: asMoney(json['min_bill_cl']),
      minBillRs: asMoneyOrNull(json['min_bill_rs']),
      validTo: asString(json['valid_to']),
      status: status.isEmpty ? 'issued' : status,
    );
  }
}

/// Минимальный чек купона ко дню рождения в формате; `null` — сервер не прислал значение.
double? couponMinBill(BirthdayCoupon coupon, String format) =>
    coupon.minBillFor(format);

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
    this.roundBurn,
    this.roundCash,
    this.roundSuggested = false,
    this.cardAmount = 0,
    this.toPay,
    this.cashToPay,
    this.store,
    this.expiresAt,
    this.serverNow,
    this.balance,
    this.debt,
    this.wallet,
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

  /// «Без сдачи» (ТЗ 24.11.2026, п. 1): списать roundBurn — доплата деньгами roundCash.
  final double? roundBurn;
  final double? roundCash;
  final bool roundSuggested;
  final double cardAmount;
  final double? toPay;
  final double? cashToPay;
  final bool clientConfirmed;
  final String? store;
  final DateTime? expiresAt;
  final DateTime? serverNow;
  final double? balance;
  final double? debt;
  final String? wallet;
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
      roundBurn: asMoneyOrNull(json['round_burn']),
      roundCash: asMoneyOrNull(json['round_cash']),
      roundSuggested: json['round_suggested'] == true,
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
      wallet: asStringOrNull(json['wallet']),
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
  const CashierCode({
    required this.qr,
    required this.code,
    required this.ttl,
    this.issuedAt,
    this.spendPref,
    this.useCoupon,
  });

  final String qr;
  final String code;
  final int ttl;
  final DateTime? issuedAt;
  final SpendPref? spendPref;
  final bool? useCoupon;

  factory CashierCode.fromJson(Map<String, dynamic> json) {
    return CashierCode(
      qr: asString(json['qr']),
      code: asString(json['code']),
      ttl: asInt(json['ttl']),
      issuedAt: json['issued_at'] == null ? null : asDate(json['issued_at']),
      spendPref: parseSpendPref(asStringOrNull(json['spend_pref'])),
      useCoupon: json['use_coupon'] is bool ? json['use_coupon'] as bool : null,
    );
  }
}

double? _positiveBonus(Object? raw) {
  final value = asMoneyOrNull(raw);
  if (value == null || value <= 0) return null;
  return value;
}

class ProgramInfo {
  const ProgramInfo({
    required this.title,
    required this.store,
    required this.enabled,
    required this.countries,
    required this.birthYearMin,
    required this.birthYearMax,
    this.welcomeBonus,
  });

  final String title;
  final String store;
  final bool enabled;
  final List<String> countries;
  final int birthYearMin;
  final int birthYearMax;

  /// Подарок за регистрацию (смн), `null` — подарок выключен.
  final double? welcomeBonus;

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
      welcomeBonus: _positiveBonus(json['welcome_bonus']),
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

class BirthdayRules {
  const BirthdayRules({
    required this.coupon,
    required this.minBillX,
    required this.windowBefore,
    required this.windowAfter,
  });

  final List<double> coupon;
  final Map<String, double> minBillX;
  final int windowBefore;
  final int windowAfter;

  factory BirthdayRules.fromJson(Map<String, dynamic> json) {
    final rawMinX = json['min_bill_x'];
    final minX = <String, double>{};
    if (rawMinX is Map) {
      for (final entry in rawMinX.entries) {
        final key = parseFormat(entry.key.toString());
        if (key != null && entry.value != null) {
          minX[key] = asMoney(entry.value);
        }
      }
    }
    return BirthdayRules(
      coupon: asDoubleList(json['coupon']),
      minBillX: minX,
      windowBefore: asInt(json['window_before']),
      windowAfter: asInt(json['window_after']),
    );
  }
}

class RulesInfo {
  const RulesInfo({
    required this.thresholds,
    required this.statuses,
    required this.referralLevels,
    required this.months,
    this.firstBonus = 0,
    this.firstBonusMin = 0,
    this.burnMin = 0,
    this.stackAbs = 0,
    this.welcomeBonus,
    this.burnKeepsCashback = false,
    this.formats,
    this.birthday,
  });

  final List<double> thresholds;
  final List<TierRule> statuses;
  final List<double> referralLevels;
  final int months;
  final double firstBonus;
  final double firstBonusMin;
  final double burnMin;
  final double stackAbs;

  /// Подарок за регистрацию (смн), `null` — выключен.
  final double? welcomeBonus;

  /// Кешбэк с оплаты деньгами при любом списании (24.11.2026).
  final bool burnKeepsCashback;

  /// Форматы активных касс магазина; `null` — старый сервер.
  final List<String>? formats;

  /// Купоны ко дню рождения; `null`, если программа их не даёт.
  final BirthdayRules? birthday;

  /// Форматы, по которым показываются ставки и минимальные чеки купона.
  List<String> get activeFormats => resolveActiveFormats(
    formats,
    hasRestaurant: statuses.any((s) => s.rates.restaurant != null),
  );

  /// Самый высокий кэшбэк по статусам в формате; без формата — по всем форматам магазина.
  double? maxEarn({String? format}) {
    if (statuses.isEmpty) return null;
    final targetFormats = format != null ? [format] : activeFormats;
    double? best;
    for (final tier in statuses) {
      for (final fmt in targetFormats) {
        final earn = tier.rates.rateFor(fmt)?.earn;
        if (earn != null && (best == null || earn > best)) {
          best = earn;
        }
      }
    }
    return best;
  }

  double get level1 => referralLevels.isEmpty ? 0 : referralLevels.first;
  double get level2 => referralLevels.length < 2 ? 0 : referralLevels[1];

  factory RulesInfo.fromJson(Map<String, dynamic> json) {
    final statuses = json['statuses'];
    final referral = json['referral'] is Map
        ? asMap(json['referral'])
        : const <String, dynamic>{};
    final rawBirthday = json['birthday'];
    return RulesInfo(
      thresholds: asDoubleList(json['thresholds']),
      statuses: statuses is List
          ? [for (final item in statuses) TierRule.fromJson(asMap(item))]
          : const [],
      referralLevels: asDoubleList(referral['levels']),
      months: asInt(referral['months']),
      firstBonus: asMoney(referral['first_bonus']),
      firstBonusMin: asMoney(referral['first_bonus_min']),
      burnMin: asMoney(json['burn_min']),
      stackAbs: asMoney(json['stack_abs']),
      welcomeBonus: _positiveBonus(json['welcome_bonus']),
      burnKeepsCashback: json['burn_keeps_cashback'] == true,
      formats: parseFormatsField(json['formats']),
      birthday: rawBirthday is Map
          ? BirthdayRules.fromJson(asMap(rawBirthday))
          : null,
    );
  }
}

class RegisterResult {
  const RegisterResult({required this.tokens, this.welcomeBonus});

  final TokenPair tokens;

  /// Сумма подарка, начисленного прямо сейчас; `null` — уже получал или выключен.
  final double? welcomeBonus;

  factory RegisterResult.fromJson(Map<String, dynamic> json) {
    return RegisterResult(
      tokens: TokenPair.fromJson(json),
      welcomeBonus: _positiveBonus(json['welcome_bonus']),
    );
  }
}

class OtpChallenge {
  const OtpChallenge({
    required this.phone,
    this.resendIn = 60,
    this.ttl = 300,
    this.debugCode,
  });

  final String phone;
  final int resendIn;
  final int ttl;
  final String? debugCode;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) {
    final resend = asInt(json['resend_in']);
    final ttl = asInt(json['ttl']);
    return OtpChallenge(
      phone: asString(json['phone']),
      resendIn: resend > 0 ? resend : 60,
      ttl: ttl > 0 ? ttl : 300,
      debugCode: asStringOrNull(json['debug_code']),
    );
  }
}

/// Привязанный аккаунт Google участника (`member.google`).
class GoogleLink {
  const GoogleLink({required this.email});

  final String email;

  factory GoogleLink.fromJson(Map<String, dynamic> json) {
    return GoogleLink(email: asString(json['email']));
  }
}

/// Ожидание одноразового подтверждения номера после «Продолжить с Google».
class GooglePending {
  const GooglePending({
    required this.ticket,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  final String ticket;
  final String email;
  final String firstName;
  final String lastName;
}

/// Ответ `POST /p/{slug}/google`: либо сразу вход, либо одноразовое подтверждение номера.
class GoogleLoginResult {
  const GoogleLoginResult.login(this.tokens) : pending = null;
  const GoogleLoginResult.phone(this.pending) : tokens = null;

  final TokenPair? tokens;
  final GooglePending? pending;

  bool get needsPhone => tokens == null;

  factory GoogleLoginResult.fromJson(Map<String, dynamic> json) {
    if (json['status'] == 'phone') {
      return GoogleLoginResult.phone(
        GooglePending(
          ticket: asString(json['google_ticket']),
          email: asString(json['email']),
          firstName: asString(json['first_name']),
          lastName: asString(json['last_name']),
        ),
      );
    }
    return GoogleLoginResult.login(TokenPair.fromJson(json));
  }
}

/// Ответ `POST /me/google`: уже привязан (`linked`) или требуется SMS-код (`confirm`).
class GoogleLinkStart {
  const GoogleLinkStart.linked(this.google)
    : ticket = null,
      email = null,
      phone = null;

  const GoogleLinkStart.confirm({
    required this.ticket,
    required this.email,
    required this.phone,
  }) : google = null;

  final GoogleLink? google;
  final String? ticket;
  final String? email;
  final String? phone;

  bool get needsConfirm => ticket != null && ticket!.isNotEmpty;

  factory GoogleLinkStart.fromJson(Map<String, dynamic> json) {
    if (json['status'] == 'confirm') {
      return GoogleLinkStart.confirm(
        ticket: asString(json['google_ticket']),
        email: asString(json['email']),
        phone: asString(json['phone']),
      );
    }
    final raw = json['google'];
    return GoogleLinkStart.linked(
      raw is Map ? GoogleLink.fromJson(asMap(raw)) : null,
    );
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

/// Характеристики устройства для автопривязки реферала (0074).
/// `model` отправляется только с Android; `screen` (`ШxВxDPR` в точках) — только с iOS.
class ReferralDeviceInfo {
  const ReferralDeviceInfo({
    this.platform,
    this.osVersion,
    this.model,
    this.language,
    this.screen,
    this.timezone,
  });

  final String? platform;
  final String? osVersion;
  final String? model;
  final String? language;
  final String? screen;
  final String? timezone;

  Map<String, dynamic> toJson() {
    return {
      if (platform != null && platform!.isNotEmpty) 'platform': platform,
      if (osVersion != null && osVersion!.isNotEmpty) 'os_version': osVersion,
      if (model != null && model!.isNotEmpty) 'model': model,
      if (language != null && language!.isNotEmpty) 'language': language,
      if (screen != null && screen!.isNotEmpty) 'screen': screen,
      if (timezone != null && timezone!.isNotEmpty) 'timezone': timezone,
    };
  }
}

/// Результат проверки пригласившего до регистрации (`POST /p/{slug}/referral/match`).
class ReferralMatch {
  const ReferralMatch({
    required this.found,
    this.code,
    this.firstName,
    this.source,
  });

  static const notFound = ReferralMatch(found: false);

  final bool found;
  final String? code;
  final String? firstName;

  /// `'install'` (Google Play), `'link'` (Universal/App Link) или `'match'` (сеть + телефон).
  final String? source;

  factory ReferralMatch.fromJson(Map<String, dynamic> json) {
    return ReferralMatch(
      found: json['found'] == true,
      code: asStringOrNull(json['code']),
      firstName: asStringOrNull(json['first_name']),
      source: asStringOrNull(json['source']),
    );
  }
}

/// Проверка вручную введённого кода приглашения (`GET /p/{slug}/referral/{code}`).
class ReferralCheck {
  const ReferralCheck({required this.valid, this.firstName});

  final bool valid;
  final String? firstName;

  factory ReferralCheck.fromJson(Map<String, dynamic> json) {
    return ReferralCheck(
      valid: json['valid'] == true,
      firstName: asStringOrNull(json['first_name']),
    );
  }
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
    this.referralDeclined = false,
    this.referralClick,
    this.installReferrer,
    this.device,
    this.birthDate,
    this.locale = 'ru',
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
  final bool referralDeclined;
  final String? referralClick;
  final String? installReferrer;
  final ReferralDeviceInfo? device;
  final String? birthDate;
  final String locale;

  Map<String, dynamic> toJson() {
    final deviceMap = device?.toJson();
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
      if (referralDeclined) 'referral_declined': true,
      if (referralClick != null && referralClick!.isNotEmpty)
        'referral_click': referralClick,
      if (installReferrer != null && installReferrer!.isNotEmpty)
        'install_referrer': installReferrer,
      if (deviceMap != null && deviceMap.isNotEmpty) 'device': deviceMap,
      'consent_pd': consentPd,
      'consent_messages': consentMessages,
      'locale': locale == 'tj' ? 'tj' : 'ru',
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
    this.billId,
  });

  final int id;
  final String kind;
  final String text;
  final DateTime createdAt;
  final bool read;

  /// Чек этого уведомления о покупке или возврате (`null` — чека нет или он вне истории).
  final int? billId;

  LoyaltyMessageItem copyWith({bool? read}) {
    return LoyaltyMessageItem(
      id: id,
      kind: kind,
      text: text,
      createdAt: createdAt,
      read: read ?? this.read,
      billId: billId,
    );
  }

  factory LoyaltyMessageItem.fromJson(Map<String, dynamic> json) {
    return LoyaltyMessageItem(
      id: asInt(json['id']),
      kind: asString(json['kind']),
      text: asString(json['text']),
      createdAt: asDate(json['created_at']),
      read: json['read'] == true,
      billId: asIntOrNull(json['bill_id']),
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
    this.currency = 'смн',
    this.validHours,
    this.expiresAt,
    this.serverNow,
    this.status = 'ACTIVE',
    this.promoCode,
    this.claimed = false,
    this.issued = false,
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
  final String currency;
  final int? validHours;
  final DateTime? expiresAt;

  /// Часы сервера в момент ответа. Обратный отсчёт считаем от них.
  final DateTime? serverNow;
  final String status;
  final String? promoCode;
  final bool claimed;

  /// Кассир уже выдал товар по коду — код и «Забрать» больше не показываем.
  final bool issued;
  final DateTime fetchedAt;

  bool get flash => type == 'FLASH_SALE';

  SizeOffer copyWith({
    String? status,
    String? promoCode,
    bool? claimed,
    bool? issued,
    DateTime? serverNow,
    DateTime? fetchedAt,
  }) {
    return SizeOffer(
      id: id,
      type: type,
      category: category,
      title: title,
      description: description,
      size: size,
      imageUrl: imageUrl,
      originalPrice: originalPrice,
      discountPrice: discountPrice,
      currency: currency,
      validHours: validHours,
      expiresAt: expiresAt,
      serverNow: serverNow ?? this.serverNow,
      status: status ?? this.status,
      promoCode: promoCode ?? this.promoCode,
      claimed: claimed ?? this.claimed,
      issued: issued ?? this.issued,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  Duration remainingAt(DateTime now) {
    final deadline = expiresAt;
    if (deadline == null) return Duration.zero;
    final base = serverNow ?? fetchedAt;
    final left = deadline.difference(base.add(now.difference(fetchedAt)));
    if (left.isNegative) return Duration.zero;
    return left;
  }

  factory SizeOffer.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackServerNow,
    DateTime? fetchedAt,
  }) {
    final currency = asString(json['currency']);
    final rawStatus = asString(json['status']);
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
      currency: currency.isEmpty ? 'смн' : currency,
      validHours: asIntOrNull(json['valid_hours']),
      expiresAt: _dateOrNull(json['expires_at']),
      serverNow: _dateOrNull(json['server_now']) ?? fallbackServerNow,
      status: rawStatus.isEmpty ? 'ACTIVE' : rawStatus,
      promoCode: asStringOrNull(json['promo_code']),
      claimed: json['claimed'] == true,
      issued: json['issued'] == true,
      fetchedAt: fetchedAt,
    );
  }
}

class SizeOffersResponse {
  const SizeOffersResponse({required this.items, this.serverNow});

  final List<SizeOffer> items;
  final DateTime? serverNow;

  factory SizeOffersResponse.fromJson(
    Map<String, dynamic> json, {
    DateTime? fetchedAt,
  }) {
    final serverNow = _dateOrNull(json['server_now']);
    final raw = json['items'];
    final items = raw is List
        ? [
            for (final item in raw)
              SizeOffer.fromJson(
                asMap(item),
                fallbackServerNow: serverNow,
                fetchedAt: fetchedAt,
              ),
          ]
        : const <SizeOffer>[];
    return SizeOffersResponse(items: items, serverNow: serverNow);
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

/// Чек, за который выдан промокод розыгрыша.
class RaffleBill {
  const RaffleBill({
    required this.id,
    required this.extId,
    required this.amount,
  });

  final int id;
  final String extId;
  final double amount;

  factory RaffleBill.fromJson(Map<String, dynamic> json) {
    return RaffleBill(
      id: asInt(json['id']),
      extId: asString(json['ext_id']),
      amount: asMoney(json['amount']),
    );
  }
}

/// Промокод клиента в розыгрыше: `active`, `cancelled` (возврат) или `won`.
class RaffleCode {
  const RaffleCode({
    required this.code,
    required this.state,
    this.place,
    this.cancelReason,
    this.createdAt,
    this.bill,
  });

  final String code;
  final String state;
  final int? place;
  final String? cancelReason;
  final DateTime? createdAt;
  final RaffleBill? bill;

  bool get isWon => state == 'won';
  bool get isCancelled => state == 'cancelled';
  bool get isActive => state == 'active';

  factory RaffleCode.fromJson(Map<String, dynamic> json) {
    final state = asString(json['state']);
    return RaffleCode(
      code: asString(json['code']),
      state: state.isEmpty ? 'active' : state,
      place: asIntOrNull(json['place']),
      cancelReason: asStringOrNull(json['cancel_reason']),
      createdAt: _dateOrNull(json['created_at']),
      bill: json['bill'] is Map ? RaffleBill.fromJson(asMap(json['bill'])) : null,
    );
  }
}

class RaffleWinner {
  const RaffleWinner({required this.code, required this.place});

  final String code;
  final int place;

  factory RaffleWinner.fromJson(Map<String, dynamic> json) {
    return RaffleWinner(
      code: asString(json['code']),
      place: asInt(json['place']),
    );
  }
}

/// Розыгрыш (ТЗ 24.11.2026, п. 3): за каждые полные `stepAmount` смн чека в период — промокод.
class RaffleInfo {
  const RaffleInfo({
    required this.id,
    required this.title,
    required this.prizes,
    required this.startsOn,
    required this.endsOn,
    required this.stepAmount,
    required this.winnersCount,
    required this.state,
    this.drawnAt,
    this.codes = const [],
    this.winners = const [],
  });

  final int id;
  final String title;
  final String prizes;
  final String startsOn;
  final String endsOn;
  final double stepAmount;
  final int winnersCount;
  final String state;
  final DateTime? drawnAt;
  final List<RaffleCode> codes;
  final List<RaffleWinner> winners;

  bool get isActive => state == 'active';
  bool get isDrawn => state == 'drawn';

  int get liveCodesCount => codes.where((c) => !c.isCancelled).length;

  factory RaffleInfo.fromJson(Map<String, dynamic> json) {
    final rawCodes = json['codes'];
    final rawWinners = json['winners'];
    final state = asString(json['state']);
    return RaffleInfo(
      id: asInt(json['id']),
      title: asString(json['title']),
      prizes: asString(json['prizes']),
      startsOn: asString(json['starts_on']),
      endsOn: asString(json['ends_on']),
      stepAmount: asMoney(json['step_amount']),
      winnersCount: asInt(json['winners_count']),
      state: state.isEmpty ? 'upcoming' : state,
      drawnAt: _dateOrNull(json['drawn_at']),
      codes: rawCodes is List
          ? [for (final item in rawCodes) RaffleCode.fromJson(asMap(item))]
          : const [],
      winners: rawWinners is List
          ? [for (final item in rawWinners) RaffleWinner.fromJson(asMap(item))]
          : const [],
    );
  }
}

class RafflesResponse {
  const RafflesResponse({
    this.current,
    this.raffles = const [],
    this.activeCodes = 0,
  });

  final RaffleInfo? current;
  final List<RaffleInfo> raffles;
  final int activeCodes;

  factory RafflesResponse.fromJson(Map<String, dynamic> json) {
    final rawCurrent = json['current'];
    final rawRaffles = json['raffles'];
    return RafflesResponse(
      current: rawCurrent is Map ? RaffleInfo.fromJson(asMap(rawCurrent)) : null,
      raffles: rawRaffles is List
          ? [for (final item in rawRaffles) RaffleInfo.fromJson(asMap(item))]
          : const [],
      activeCodes: asInt(json['active_codes']),
    );
  }
}
