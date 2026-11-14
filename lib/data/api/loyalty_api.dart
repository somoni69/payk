import 'dart:typed_data';

import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'json_parse.dart';
import '../models/models.dart';

class LoyaltyApi {
  LoyaltyApi(this._client);

  final ApiClient _client;

  String get _slug => Uri.encodeComponent(ApiConfig.program);

  Future<ProgramInfo> program() async {
    final json = await _client.send('/p/$_slug', auth: false);
    return ProgramInfo.fromJson(asMap(json));
  }

  Future<OtpChallenge> requestOtp(String phone) async {
    final json = await _client.send(
      '/p/$_slug/otp',
      method: 'POST',
      auth: false,
      body: {'phone': phone, 'locale': 'ru'},
    );
    return OtpChallenge.fromJson(asMap(json));
  }

  Future<VerifyResult> verify(String phone, String code) async {
    final json = asMap(
      await _client.send(
        '/p/$_slug/verify',
        method: 'POST',
        auth: false,
        body: {'phone': phone, 'code': code},
      ),
    );
    if (json['status'] == 'register') {
      final token = asString(json['registration_token']);
      if (token.isEmpty) throw ApiException(0, 'Неожиданный ответ сервера');
      return VerifyResult.register(
        registrationToken: token,
        phone: asStringOrNull(json['phone']),
      );
    }
    return VerifyResult.login(TokenPair.fromJson(json));
  }

  Future<TokenPair> register(RegisterInput input) async {
    if (!input.consentPd) {
      throw ApiException(422, 'Нужно согласие на обработку данных');
    }
    final json = await _client.send(
      '/p/$_slug/register',
      method: 'POST',
      auth: false,
      body: input.toJson(),
    );
    return TokenPair.fromJson(asMap(json));
  }

  Future<RulesInfo> rules() async {
    final json = await _client.send('/p/$_slug/rules', auth: false);
    return RulesInfo.fromJson(asMap(json));
  }

  Future<Account> me() async {
    final json = await _client.send('/me');
    return Account.fromJson(asMap(json));
  }

  Future<void> deleteAccount() async {
    await _client.send('/me', method: 'DELETE');
  }

  Future<void> logout() async {
    await _client.send('/logout', method: 'POST');
  }

  Future<void> updateMe(Map<String, dynamic> patch) async {
    await _client.send('/me', method: 'PATCH', body: patch);
  }

  /// Размеры обуви, брюк и верха. null снимает значение.
  Future<void> updateSizes({String? shoe, String? pants, String? top}) async {
    await updateSizesPatch({'shoe_size': shoe, 'pants_size': pants, 'top_size': top});
  }

  /// Отправляет только изменённые поля размеров (ключ с null снимает значение).
  Future<void> updateSizesPatch(Map<String, String?> patch) async {
    if (patch.isEmpty) return;
    await _client.send('/me/sizes', method: 'PATCH', body: patch);
  }

  Future<SizeOffersResponse> sizeOffers({bool markRead = true}) async {
    final suffix = markRead ? '' : '?mark_read=false';
    final json = asMap(await _client.send('/me/size-offers$suffix'));
    return SizeOffersResponse.fromJson(json, fetchedAt: DateTime.now());
  }

  Future<SizeOffer> claimSizeOffer(int id) async {
    final json = await _client.send(
      '/me/size-offers/$id/claim',
      method: 'POST',
    );
    return SizeOffer.fromJson(asMap(json), fetchedAt: DateTime.now());
  }

  Future<void> uploadAvatar(String filePath) async {
    await _client.upload('/me/avatar', filePath);
  }

  Future<CashierCode> code() async {
    final json = await _client.send('/me/code', method: 'POST');
    final parsed = CashierCode.fromJson(asMap(json));
    if (parsed.code.isEmpty || parsed.qr.isEmpty) {
      throw ApiException(0, 'Сервер не выдал код');
    }
    return parsed;
  }

  Future<PendingSnapshot> pending() async {
    final json = await _client.send('/me/pending');
    return PendingSnapshot.fromJson(asMap(json));
  }

  Future<PendingCheck> choose(
    int id, {
    required double burn,
    required bool coin10,
    required bool noCoin,
    bool coupon = false,
  }) async {
    final json = await _client.send(
      '/me/pending/$id',
      method: 'POST',
      body: {
        'burn_amount': burn.toStringAsFixed(2),
        'coin10': coin10,
        'no_coin': noCoin,
        'coupon': coupon,
      },
    );
    return PendingCheck.fromJson(asMap(json));
  }

  /// Пробный расчёт выбора: ничего не сохраняет.
  Future<QuoteResult> quote(
    int id, {
    required double burn,
    required bool coin10,
    required bool noCoin,
    bool coupon = false,
  }) async {
    final json = await _client.send(
      '/me/pending/$id/quote',
      method: 'POST',
      body: {
        'burn_amount': burn.toStringAsFixed(2),
        'coin10': coin10,
        'no_coin': noCoin,
        'coupon': coupon,
      },
    );
    return QuoteResult.fromJson(asMap(json));
  }

  Future<List<HistoryEntry>> history({
    int? beforeId,
    String? category,
    String? query,
  }) async {
    final params = <String, String>{};
    if (beforeId != null) params['before_id'] = '$beforeId';
    if (category != null && category.isNotEmpty && category != 'all') {
      params['cat'] = category;
    }
    final text = query?.trim();
    if (text != null && text.isNotEmpty) params['q'] = text;
    final suffix = params.isEmpty
        ? ''
        : '?${params.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    final json = await _client.send('/me/history$suffix');
    if (json is! List) throw ApiException(0, 'Неожиданный ответ сервера');
    return [for (final item in json) HistoryEntry.fromJson(asMap(item))];
  }

  Future<ReceiptsPage> receipts({
    int? beforeId,
    String? dFrom,
    String? dTo,
    String? fmt,
    String? q,
  }) async {
    final params = <String, String>{};
    if (beforeId != null) params['before_id'] = '$beforeId';
    if (dFrom != null && dFrom.isNotEmpty) params['d_from'] = dFrom;
    if (dTo != null && dTo.isNotEmpty) params['d_to'] = dTo;
    if (fmt != null && fmt.isNotEmpty) params['fmt'] = fmt;
    final text = q?.trim();
    if (text != null && text.isNotEmpty) params['q'] = text;
    final suffix = params.isEmpty
        ? ''
        : '?${params.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    final json = asMap(await _client.send('/me/receipts$suffix'));
    return ReceiptsPage.fromJson(json);
  }

  Future<ReceiptView> receipt(int id) async {
    final json = asMap(await _client.send('/me/receipts/$id'));
    return ReceiptView.fromJson(json);
  }

  Future<ReceiptClaim> claimReceipt(
    int id, {
    required String kind,
    String text = '',
  }) async {
    final json = asMap(
      await _client.send(
        '/me/receipts/$id/claims',
        method: 'POST',
        body: {'kind': kind, 'text': text},
      ),
    );
    return ReceiptClaim.fromJson(json);
  }

  Future<Uint8List> receiptFile(int id, {required String kind}) {
    return _client.downloadBytes('/me/receipts/$id/file?kind=$kind');
  }

  Future<FriendsInfo> friends() async {
    final json = await _client.send('/me/friends');
    return FriendsInfo.fromJson(asMap(json));
  }

  Future<List<LoyaltyMessageItem>> messages({int? beforeId}) async {
    final query = beforeId != null ? '?before_id=$beforeId' : '';
    final json = asMap(await _client.send('/me/messages$query'));
    final raw = json['items'];
    if (raw is! List) return const [];
    return [for (final item in raw) LoyaltyMessageItem.fromJson(asMap(item))];
  }

  Future<int> markMessagesRead({int? upToId}) async {
    final json = asMap(
      await _client.send(
        '/me/messages/read',
        method: 'POST',
        body: {'up_to_id': upToId},
      ),
    );
    return asInt(json['unread']);
  }

  Future<TelegramLinks> telegram() async {
    final json = await _client.send('/me/telegram');
    return TelegramLinks.fromJson(asMap(json));
  }

  Future<void> unlinkTelegram() async {
    await _client.send('/me/telegram', method: 'DELETE');
  }

  Future<PhoneChangeStart> phoneStart(String phone) async {
    final json = asMap(
      await _client.send(
        '/me/phone/start',
        method: 'POST',
        body: {'phone': phone},
      ),
    );
    return PhoneChangeStart.fromJson(json);
  }

  Future<Member> phoneConfirm(
    String phone,
    String codeOld,
    String codeNew,
  ) async {
    final json = asMap(
      await _client.send(
        '/me/phone/confirm',
        method: 'POST',
        body: {'phone': phone, 'code_old': codeOld, 'code_new': codeNew},
      ),
    );
    return Member.fromJson(json);
  }

  Future<ShowcaseFeed> showcase() async {
    final json = await _client.send('/showcase');
    return ShowcaseFeed.fromJson(asMap(json));
  }

  /// «Хочу PAYK»: sent — заявка ушла; already — сегодня с этого номера заявка уже есть.
  Future<ShowcaseLeadResult> showcaseLead(int? cardId, String company) async {
    final trimmed = company.trim();
    final json = asMap(
      await _client.send(
        '/showcase/lead',
        method: 'POST',
        body: {'card_id': cardId, 'company': trimmed.isEmpty ? null : trimmed},
      ),
    );
    return ShowcaseLeadResult.fromJson(json);
  }
}
