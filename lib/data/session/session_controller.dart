import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/loyalty_api.dart';
import '../models/models.dart';
import '../../core/i18n/locale_controller.dart';

const _accessKey = 'payk.access';
const _refreshKey = 'payk.refresh';
const _onboardingKey = 'payk.onboarding';

class SessionState {
  const SessionState({
    this.accessToken,
    this.refreshToken,
    this.pendingPhone,
    this.registrationToken,
    this.onboardingSeen = false,
    this.ready = false,
  });

  final String? accessToken;
  final String? refreshToken;
  final String? pendingPhone;
  final String? registrationToken;
  final bool onboardingSeen;
  final bool ready;

  bool get loggedIn => accessToken != null && accessToken!.isNotEmpty;

  SessionState copyWith({
    String? accessToken,
    String? refreshToken,
    String? pendingPhone,
    String? registrationToken,
    bool? ready,
    bool? onboardingSeen,
    bool clearPhone = false,
    bool clearRegistration = false,
  }) {
    return SessionState(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      pendingPhone: clearPhone ? null : (pendingPhone ?? this.pendingPhone),
      registrationToken: clearRegistration ? null : (registrationToken ?? this.registrationToken),
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      ready: ready ?? this.ready,
    );
  }
}

class SessionController extends Notifier<SessionState> {
  var _restoreScheduled = false;

  @override
  SessionState build() {
    if (!_restoreScheduled) {
      _restoreScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ref.mounted) return;
        unawaited(_restore());
      });
    }
    return const SessionState();
  }

  LoyaltyApi get _api => ref.read(loyaltyApiProvider);

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final access = prefs.getString(_accessKey);
      final refresh = prefs.getString(_refreshKey);
      final seen = prefs.getBool(_onboardingKey) ?? false;
      if (!ref.mounted) return;
      state = SessionState(ready: true, accessToken: access, refreshToken: refresh, onboardingSeen: seen);
    } catch (_) {
      if (!ref.mounted) return;
      state = const SessionState(ready: true);
    }
  }

  Future<void> finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!ref.mounted) return;
    state = state.copyWith(onboardingSeen: true);
  }

  Future<void> requestCode(String phone) async {
    final challenge = await _api.requestOtp(phone);
    final normalized = challenge.phone.isEmpty ? phone : challenge.phone;
    state = state.copyWith(pendingPhone: normalized, clearRegistration: true);
  }

  Future<bool> confirmCode(String code) async {
    final phone = state.pendingPhone;
    if (phone == null || phone.isEmpty) {
      throw ApiException(401, 'Запросите код ещё раз');
    }
    final result = await _api.verify(phone, code);
    if (result.needsRegistration) {
      state = state.copyWith(registrationToken: result.registrationToken);
      return false;
    }
    final tokens = result.tokens;
    if (tokens == null) throw ApiException(0, 'Неожиданный ответ сервера');
    await _persistLogin(tokens.accessToken, tokens.refreshToken);
    return true;
  }

  Future<void> completeProfile(RegisterInput input) async {
    final token = state.registrationToken;
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Подтвердите номер ещё раз');
    }
    final tokens = await _api.register(input);
    await _persistLogin(tokens.accessToken, tokens.refreshToken);
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? email,
  }) async {
    await _api.updateMe({
      'first_name': firstName,
      'last_name': lastName,
      'email': (email == null || email.isEmpty) ? null : email,
    });
  }

  Future<void> setMessages(bool value) async {
    await _api.updateMe({'messages': value});
  }

  Future<void> setCoinRounding(bool value) async {
    await _api.updateMe({'coin_rounding': value});
  }

  void applyTokens(String accessToken, String refreshToken) {
    if (state.accessToken == accessToken && state.refreshToken == refreshToken) return;
    state = SessionState(ready: true, accessToken: accessToken, refreshToken: refreshToken);
    unawaited(_write(accessToken, refreshToken));
  }

  void expire() {
    if (!state.loggedIn) return;
    unawaited(logout());
  }

  Future<void> logout() async {
    state = const SessionState(ready: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  Future<void> _persistLogin(String accessToken, String refreshToken) async {
    state = SessionState(ready: true, accessToken: accessToken, refreshToken: refreshToken);
    await _write(accessToken, refreshToken);
  }

  Future<void> _write(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    readTokens: () {
      final session = ref.read(sessionProvider);
      final access = session.accessToken;
      final refresh = session.refreshToken;
      if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) return null;
      return TokenPair(accessToken: access, refreshToken: refresh);
    },
    writeTokens: (accessToken, refreshToken) {
      ref.read(sessionProvider.notifier).applyTokens(accessToken, refreshToken);
    },
    onExpired: () => ref.read(sessionProvider.notifier).expire(),
    readLocale: () => ref.read(localeProvider),
  );
  ref.onDispose(client.close);
  return client;
});

final loyaltyApiProvider = Provider<LoyaltyApi>((ref) => LoyaltyApi(ref.watch(apiClientProvider)));
