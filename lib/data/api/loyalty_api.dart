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

  Future<void> updateMe(Map<String, dynamic> patch) async {
    await _client.send('/me', method: 'PATCH', body: patch);
  }

  /// Размеры обуви, брюк и верха. null снимает значение.
  Future<void> updateSizes({
    String? shoe,
    String? pants,
    String? top,
  }) async {
    await _client.send(
      '/me/sizes',
      method: 'PATCH',
      body: {
        'shoe_size': shoe,
        'pants_size': pants,
        'top_size': top,
      },
    );
  }

  Future<List<SizeOffer>> sizeOffers() async {
    final json = asMap(await _client.send('/me/size-offers'));
    final raw = json['items'];
    if (raw is! List) return const [];
    return [for (final item in raw) SizeOffer.fromJson(asMap(item))];
  }

  Future<SizeOffer> claimSizeOffer(int id) async {
    final json = await _client.send('/me/size-offers/$id/claim', method: 'POST');
    return SizeOffer.fromJson(asMap(json));
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

  Future<PendingCheck> choose(int id, Map<String, dynamic> body) async {
    final json = await _client.send(
      '/me/pending/$id',
      method: 'POST',
      body: body,
    );
    return PendingCheck.fromJson(asMap(json));
  }

  Future<List<HistoryEntry>> history() async {
    final json = await _client.send('/me/history');
    if (json is! List) throw ApiException(0, 'Неожиданный ответ сервера');
    return [for (final item in json) HistoryEntry.fromJson(asMap(item))];
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
