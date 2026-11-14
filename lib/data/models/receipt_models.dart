import '../api/json_parse.dart';

class ReceiptsHeader {
  const ReceiptsHeader({
    required this.month,
    required this.spendMonth,
    required this.bills,
    required this.earned,
    required this.spent,
    this.toNext,
  });

  final String month;
  final double spendMonth;
  final int bills;
  final double earned;
  final double spent;
  final double? toNext;

  factory ReceiptsHeader.fromJson(Map<String, dynamic> json) {
    return ReceiptsHeader(
      month: asString(json['month']),
      spendMonth: asMoney(json['spend_month']),
      bills: asInt(json['bills']),
      earned: asMoney(json['earned']),
      spent: asMoney(json['spent']),
      toNext: asMoneyOrNull(json['to_next']),
    );
  }
}

class ReceiptMonth {
  const ReceiptMonth({
    required this.month,
    required this.bills,
    required this.amount,
    required this.earned,
    required this.spent,
  });

  final String month;
  final int bills;
  final double amount;
  final double earned;
  final double spent;

  factory ReceiptMonth.fromJson(Map<String, dynamic> json) {
    return ReceiptMonth(
      month: asString(json['month']),
      bills: asInt(json['bills']),
      amount: asMoney(json['amount']),
      earned: asMoney(json['earned']),
      spent: asMoney(json['spent']),
    );
  }
}

class ReceiptRow {
  const ReceiptRow({
    required this.id,
    required this.ts,
    required this.number,
    required this.amount,
    required this.earn,
    required this.burn,
    required this.round,
    required this.coupon,
    required this.state,
    required this.itemsStatus,
    this.store,
    this.format,
    this.terminal,
    this.mode,
  });

  final int id;
  final DateTime ts;
  final String? store;
  final String? format;
  final String? terminal;
  final String number;
  final double amount;
  final double earn;
  final double burn;
  final double round;
  final double coupon;
  final String? mode;
  final String state;
  final String itemsStatus;

  bool get isReturned => state == 'returned';
  bool get isPartiallyReturned => state == 'partially_returned';

  factory ReceiptRow.fromJson(Map<String, dynamic> json) {
    return ReceiptRow(
      id: asInt(json['id']),
      ts: asDate(json['ts']),
      store: asStringOrNull(json['store']),
      format: asStringOrNull(json['format']),
      terminal: asStringOrNull(json['terminal']),
      number: asString(json['number']),
      amount: asMoney(json['amount']),
      earn: asMoney(json['earn']),
      burn: asMoney(json['burn']),
      round: asMoney(json['round']),
      coupon: asMoney(json['coupon']),
      mode: asStringOrNull(json['mode']),
      state: asString(json['state']),
      itemsStatus: asString(json['items_status']),
    );
  }
}

class ReceiptsPage {
  const ReceiptsPage({
    required this.header,
    required this.months,
    required this.items,
    this.nextBeforeId,
  });

  final ReceiptsHeader? header;
  final List<ReceiptMonth> months;
  final List<ReceiptRow> items;
  final int? nextBeforeId;

  factory ReceiptsPage.fromJson(Map<String, dynamic> json) {
    final rawHeader = json['header'];
    final rawMonths = json['months'];
    final rawItems = json['items'];
    return ReceiptsPage(
      header: rawHeader is Map ? ReceiptsHeader.fromJson(asMap(rawHeader)) : null,
      months: rawMonths is List
          ? [for (final item in rawMonths) ReceiptMonth.fromJson(asMap(item))]
          : const [],
      items: rawItems is List
          ? [for (final item in rawItems) ReceiptRow.fromJson(asMap(item))]
          : const [],
      nextBeforeId: asIntOrNull(json['next_before_id']),
    );
  }
}

class ReceiptLine {
  const ReceiptLine({
    required this.lineNo,
    required this.name,
    required this.qty,
    required this.price,
    required this.amount,
    required this.returnedQty,
    required this.returnedAmount,
    required this.state,
    required this.estimated,
    required this.returned,
    this.group,
    this.unit,
  });

  final int lineNo;
  final String name;
  final String? group;
  final double qty;
  final String? unit;
  final double price;
  final double amount;
  final double returnedQty;
  final double returnedAmount;
  final String state;
  final bool estimated;
  final bool returned;

  bool get isFullReturned => state == 'full' || returned;
  bool get isPartialReturned => state == 'partial' && !estimated;

  factory ReceiptLine.fromJson(Map<String, dynamic> json) {
    return ReceiptLine(
      lineNo: asInt(json['line_no']),
      name: asString(json['name']),
      group: asStringOrNull(json['group']),
      qty: asMoney(json['qty']),
      unit: asStringOrNull(json['unit']),
      price: asMoney(json['price']),
      amount: asMoney(json['amount']),
      returnedQty: asMoney(json['returned_qty']),
      returnedAmount: asMoney(json['returned_amount']),
      state: asString(json['state']),
      estimated: json['estimated'] == true,
      returned: json['returned'] == true,
    );
  }
}

class ReceiptReturnLine {
  const ReceiptReturnLine({
    required this.lineNo,
    required this.name,
    required this.qty,
    required this.price,
    required this.amount,
    required this.estimated,
    this.unit,
  });

  final int lineNo;
  final String name;
  final double qty;
  final String? unit;
  final double price;
  final double amount;
  final bool estimated;

  factory ReceiptReturnLine.fromJson(Map<String, dynamic> json) {
    return ReceiptReturnLine(
      lineNo: asInt(json['line_no']),
      name: asString(json['name']),
      qty: asMoney(json['qty']),
      unit: asStringOrNull(json['unit']),
      price: asMoney(json['price']),
      amount: asMoney(json['amount']),
      estimated: json['estimated'] == true,
    );
  }
}

class ReceiptReturn {
  const ReceiptReturn({
    required this.ts,
    required this.amount,
    required this.reversedEarn,
    required this.refundedBurn,
    required this.refundedRound,
    required this.linesState,
    required this.lines,
  });

  final DateTime ts;
  final double amount;
  final double reversedEarn;
  final double refundedBurn;
  final double refundedRound;
  final String linesState;
  final List<ReceiptReturnLine> lines;

  factory ReceiptReturn.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return ReceiptReturn(
      ts: asDate(json['ts']),
      amount: asMoney(json['amount']),
      reversedEarn: asMoney(json['reversed_earn']),
      refundedBurn: asMoney(json['refunded_burn']),
      refundedRound: asMoney(json['refunded_round']),
      linesState: asString(json['lines_state']),
      lines: rawLines is List
          ? [for (final item in rawLines) ReceiptReturnLine.fromJson(asMap(item))]
          : const [],
    );
  }
}

class ReceiptClaim {
  const ReceiptClaim({
    required this.id,
    required this.kind,
    required this.status,
    this.text,
    this.decision,
    this.answer,
    this.createdAt,
    this.dueAt,
    this.answeredAt,
  });

  final int id;
  final String kind;
  final String? text;
  final String status;
  final String? decision;
  final String? answer;
  final DateTime? createdAt;
  final DateTime? dueAt;
  final DateTime? answeredAt;

  bool get isOpen => status == 'open';

  factory ReceiptClaim.fromJson(Map<String, dynamic> json) {
    DateTime? dateOrNull(Object? v) {
      if (v is! String || v.isEmpty) return null;
      return DateTime.tryParse(v)?.toLocal();
    }

    return ReceiptClaim(
      id: asInt(json['id']),
      kind: asString(json['kind']),
      text: asStringOrNull(json['text']),
      status: asString(json['status']),
      decision: asStringOrNull(json['decision']),
      answer: asStringOrNull(json['answer']),
      createdAt: dateOrNull(json['created_at']),
      dueAt: dateOrNull(json['due_at']),
      answeredAt: dateOrNull(json['answered_at']),
    );
  }
}

class ReceiptRate {
  const ReceiptRate({required this.pct, required this.status});

  final double pct;
  final int status;

  factory ReceiptRate.fromJson(Map<String, dynamic> json) {
    return ReceiptRate(
      pct: asMoney(json['pct']),
      status: asInt(json['status']),
    );
  }
}

class ReceiptView {
  const ReceiptView({
    required this.id,
    required this.ts,
    required this.number,
    required this.lines,
    required this.itemsStatus,
    required this.amountBeforeCoupon,
    required this.coupon,
    required this.amount,
    required this.burn,
    required this.round,
    required this.b,
    required this.cashPay,
    required this.cardPay,
    required this.earn,
    required this.returns,
    required this.state,
    this.store,
    this.format,
    this.terminal,
    this.mode,
    this.rate,
    this.balanceAfter,
    this.spendContribution,
    this.spendAfter,
    this.claim,
  });

  final int id;
  final DateTime ts;
  final String? store;
  final String? format;
  final String? terminal;
  final String number;
  final List<ReceiptLine> lines;
  final String itemsStatus;
  final double amountBeforeCoupon;
  final double coupon;
  final double amount;
  final double burn;
  final double round;
  final double b;
  final String? mode;
  final double cashPay;
  final double cardPay;
  final double earn;
  final ReceiptRate? rate;
  final double? balanceAfter;
  final double? spendContribution;
  final double? spendAfter;
  final List<ReceiptReturn> returns;
  final String state;
  final ReceiptClaim? claim;

  factory ReceiptView.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final rawReturns = json['returns'];
    final rawPay = json['pay'] is Map ? asMap(json['pay']) : const <String, dynamic>{};
    final rawRate = json['rate'];
    final rawClaim = json['claim'];

    return ReceiptView(
      id: asInt(json['id']),
      ts: asDate(json['ts']),
      store: asStringOrNull(json['store']),
      format: asStringOrNull(json['format']),
      terminal: asStringOrNull(json['terminal']),
      number: asString(json['number']),
      lines: rawLines is List
          ? [for (final item in rawLines) ReceiptLine.fromJson(asMap(item))]
          : const [],
      itemsStatus: asString(json['items_status']),
      amountBeforeCoupon: asMoney(json['amount_before_coupon']),
      coupon: asMoney(json['coupon']),
      amount: asMoney(json['amount']),
      burn: asMoney(json['burn']),
      round: asMoney(json['round']),
      b: asMoney(json['b']),
      mode: asStringOrNull(json['mode']),
      cashPay: asMoney(rawPay['cash']),
      cardPay: asMoney(rawPay['card']),
      earn: asMoney(json['earn']),
      rate: rawRate is Map ? ReceiptRate.fromJson(asMap(rawRate)) : null,
      balanceAfter: asMoneyOrNull(json['balance_after']),
      spendContribution: asMoneyOrNull(json['spend_contribution']),
      spendAfter: asMoneyOrNull(json['spend_after']),
      returns: rawReturns is List
          ? [for (final item in rawReturns) ReceiptReturn.fromJson(asMap(item))]
          : const [],
      state: asString(json['state']),
      claim: rawClaim is Map ? ReceiptClaim.fromJson(asMap(rawClaim)) : null,
    );
  }
}

class ReceiptsQuery {
  const ReceiptsQuery({
    this.search = '',
    this.dFrom = '',
    this.dTo = '',
    this.fmt = '',
  });

  final String search;
  final String dFrom;
  final String dTo;
  final String fmt;

  int get filterCount {
    var count = 0;
    if (dFrom.isNotEmpty) count++;
    if (dTo.isNotEmpty) count++;
    if (fmt.isNotEmpty) count++;
    return count;
  }

  bool get isFiltered => search.trim().isNotEmpty || filterCount > 0;

  ReceiptsQuery copyWith({
    String? search,
    String? dFrom,
    String? dTo,
    String? fmt,
  }) {
    return ReceiptsQuery(
      search: search ?? this.search,
      dFrom: dFrom ?? this.dFrom,
      dTo: dTo ?? this.dTo,
      fmt: fmt ?? this.fmt,
    );
  }
}
