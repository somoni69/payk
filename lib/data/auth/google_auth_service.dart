import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_config.dart';

/// Обёртка над нативным Google Sign-In (`google_sign_in` v7).
///
/// По правилу App Store 4.8 (docs/loyalty-app-api-2026-11-26-google.md, п. 6)
/// кнопка Google на iOS скрыта, пока на сервере не добавлен «Вход через Apple».
class GoogleAuthService {
  GoogleAuthService({
    String? serverClientId,
    this.platformOverride,
  }) : _serverClientId = (serverClientId ?? ApiConfig.googleServerClientId)
           .trim();

  final String _serverClientId;
  final TargetPlatform? platformOverride;
  Future<void>? _initFuture;

  TargetPlatform get _platform => platformOverride ?? defaultTargetPlatform;

  /// Доступен ли вход/привязка Google на этом устройстве.
  bool get isAvailable {
    if (kIsWeb) return false;
    // На iPhone кнопку Google не включаем, пока на сервере нет «Входа через Apple» (App Store 4.8).
    if (_platform != TargetPlatform.android) return false;
    return _serverClientId.isNotEmpty;
  }

  Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
    );
  }

  /// Запускает нативный выбор Google-аккаунта и возвращает свежий `id_token`.
  /// Возвращает `null`, если пользователь отменил выбор аккаунта.
  Future<String?> requestIdToken() async {
    if (!isAvailable) return null;
    await _ensureInitialized();
    // Сбрасываем локальную сессию SDK, чтобы пользователь мог выбрать аккаунт и получить свежий id_token (<10 мин).
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['openid', 'email', 'profile'],
      );
      final token = account.authentication.idToken?.trim();
      if (token == null || token.isEmpty) {
        throw StateError('Google did not return id_token');
      }
      return token;
    } on GoogleSignInException catch (error) {
      debugPrint(
        'GoogleSignInException(${error.code}): ${error.description} ${error.details}',
      );
      if (isSilentUserCancel(error)) {
        return null;
      }
      rethrow;
    }
  }

  /// Play Services часто оборачивает ошибку конфигурации SHA-1/OAuth
  /// (`[16] Account reauth failed`, `28444`) в `GetCredentialCancellationException`.
  /// Настоящую отмену пользователем игнорируем, а сбой конфигурации показываем.
  @visibleForTesting
  static bool isSilentUserCancel(GoogleSignInException error) {
    if (error.code != GoogleSignInExceptionCode.canceled &&
        error.code != GoogleSignInExceptionCode.interrupted) {
      return false;
    }
    final desc = (error.description ?? '').toLowerCase();
    if (desc.contains('reauth') ||
        desc.contains('[16]') ||
        desc.contains('28444') ||
        desc.contains('developer') ||
        desc.contains('configuration')) {
      return false;
    }
    return true;
  }

  Future<void> signOut() async {
    if (_initFuture == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
