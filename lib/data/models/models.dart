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
    this.messages = false,
    this.coinRounding = true,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final int? birthYear;
  final String? birthDate;
  final String? country;
  final bool coinRounding;
  final String referralCode;
  final String? email;
  final bool messages;

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
      messages: json['messages'] == true,
      coinRounding: json['coin_rounding'] != false,
    );
  }
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
  });

  final Member member;
  final Wallet wallet;
  final String store;
  final bool programEnabled;
  final int tierCount;

  factory Account.fromJson(Map<String, dynamic> json) {
    final program = json['program'] is Map ? asMap(json['program']) : const <String, dynamic>{};
    final today = json['today'] is Map ? asMap(json['today']) : const <String, dynamic>{};
    final keep = json['keep'];
    final up = json['up'];
    final thresholds = json['thresholds'];
    return Account(
      member: Member.fromJson(asMap(json['member'])),
      store: asString(program['store']),
      programEnabled: program['enabled'] == true,
      tierCount: thresholds is List && thresholds.isNotEmpty ? thresholds.length + 1 : 5,
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
      format: asStringOrNull(json['format']) ?? (bill == null ? null : asStringOrNull(bill['format'])),
      note: asStringOrNull(json['note']),
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
      invitees: raw is List ? [for (final item in raw) Invitee.fromJson(asMap(item))] : const [],
    );
  }
}

class PendingCheck {
  const PendingCheck({
    required this.id,
    required this.format,
    required this.mode,
    required this.burnAmount,
    required this.clientConfirmed,
    this.amount,
    this.earn,
    this.maxBurn,
    this.toPay,
    this.store,
    this.expiresAt,
    this.threshold,
    this.cap,
    this.earnRate,
    this.resultEarn,
    this.roundAmount,
    this.coin = true,
    this.toTen = false,
    this.balance,
    this.debt,
  });

  final int id;
  final String format;
  final String mode;
  final double burnAmount;
  final bool clientConfirmed;
  final double? amount;
  final double? earn;
  final double? maxBurn;
  final double? toPay;
  final String? store;
  final DateTime? expiresAt;
  final double? threshold;
  final double? cap;
  final double? earnRate;
  final double? resultEarn;
  final double? roundAmount;
  final bool coin;
  final bool toTen;
  final double? balance;
  final double? debt;

  factory PendingCheck.fromJson(Map<String, dynamic> json) {
    return PendingCheck(
      id: asInt(json['id']),
      format: asString(json['format']),
      mode: asString(json['mode']).isEmpty ? 'earn' : asString(json['mode']),
      burnAmount: asMoney(json['burn_amount']),
      clientConfirmed: json['client_confirmed'] == true,
      amount: asMoneyOrNull(json['amount']),
      earn: asMoneyOrNull(json['x']),
      maxBurn: asMoneyOrNull(json['y']),
      toPay: asMoneyOrNull(json['to_pay']),
      store: asStringOrNull(json['store']),
      expiresAt: json['expires_at'] == null ? null : asDate(json['expires_at']),
      threshold: asMoneyOrNull(json['a']),
      cap: asMoneyOrNull(json['cap']),
      earnRate: asMoneyOrNull(json['earn_rate']),
      resultEarn: asMoneyOrNull(json['earn']),
      roundAmount: asMoneyOrNull(json['round']),
      coin: json['coin'] != false,
      toTen: json['to_ten'] == true,
      balance: asMoneyOrNull(json['balance']),
      debt: asMoneyOrNull(json['debt']),
    );
  }
}

class ClosedBill {
  const ClosedBill({required this.id, required this.state, this.mode, this.earn, this.burn, this.amount});

  final int id;
  final String state;
  final String? mode;
  final double? earn;
  final double? burn;
  final double? amount;

  factory ClosedBill.fromJson(Map<String, dynamic> json) {
    final bill = json['bill'] is Map ? asMap(json['bill']) : null;
    return ClosedBill(
      id: asInt(json['id']),
      state: asString(json['state']),
      mode: bill == null ? null : asStringOrNull(bill['mode']),
      earn: bill == null ? null : asMoneyOrNull(bill['earn']),
      burn: bill == null ? null : asMoneyOrNull(bill['burn']),
      amount: bill == null ? null : asMoneyOrNull(bill['amount']),
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
      countries: countries is List ? [for (final item in countries) asString(item)].where((item) => item.isNotEmpty).toList() : const [],
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
    return TierRule(level: asInt(json['status']), rates: ProgramRates.fromJson(json['rates']));
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
    final referral = json['referral'] is Map ? asMap(json['referral']) : const <String, dynamic>{};
    return RulesInfo(
      thresholds: asDoubleList(json['thresholds']),
      statuses: statuses is List ? [for (final item in statuses) TierRule.fromJson(asMap(item))] : const [],
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
  const VerifyResult.login(this.tokens) : registrationToken = null, phone = null;

  const VerifyResult.register({required this.registrationToken, required this.phone}) : tokens = null;

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
      'referral_code': (referralCode == null || referralCode!.isEmpty) ? null : referralCode,
      'consent_pd': consentPd,
      'consent_messages': consentMessages,
      'locale': 'ru',
    };
  }
}
