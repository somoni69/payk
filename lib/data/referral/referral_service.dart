import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/loyalty_api.dart';
import '../models/models.dart';

/// Проверка и нормализация реферального кода (совпадает с бэкендом `loyalty_referral_link._CODE`).
final _referralCodePattern = RegExp(r'^[A-Z0-9][A-Z0-9-]{2,15}$');

String? normalizeReferralCode(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim().toUpperCase();
  if (trimmed.isEmpty || trimmed.length > 16) return null;
  return _referralCodePattern.hasMatch(trimmed) ? trimmed : null;
}

/// Извлекает код приглашения из Universal/App Link (`/r/AZ-4821`) или query-параметра (`payk_ref` / `ref`).
String? parseReferralCodeFromUri(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  for (var i = 0; i < segments.length - 1; i++) {
    if (segments[i].toLowerCase() == 'r') {
      final code = normalizeReferralCode(Uri.decodeComponent(segments[i + 1]));
      if (code != null) return code;
    }
  }
  final queryCode = uri.queryParameters['payk_ref'] ?? uri.queryParameters['ref'];
  return normalizeReferralCode(queryCode);
}

/// Контекст приглашения, собранный перед отправкой `POST /register`.
class ReferralContext {
  const ReferralContext({
    required this.match,
    this.linkCode,
    this.installReferrer,
    this.device,
  });

  static const empty = ReferralContext(match: ReferralMatch.notFound);

  final ReferralMatch match;
  final String? linkCode;
  final String? installReferrer;
  final ReferralDeviceInfo? device;
}

/// Сервис автопривязки реферала (0074):
/// 1. Читает метку установки Google Play (`Install Referrer`) на Android.
/// 2. Ловит Universal Links (iOS) и App Links (Android) вида `/r/<КОД>` при запуске и в фоне.
/// 3. Собирает характеристики устройства для вероятностного совпадения на iOS и Android.
/// 4. Запрашивает `POST /p/{slug}/referral/match` перед экраном регистрации и хранит данные до отправки `register`.
class ReferralService {
  ReferralService({
    MethodChannel? channel,
    this.readInstallReferrer,
    this.readInitialLink,
    this.readDeviceInfo,
  }) : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'app.payk.payk/referral';

  static const _pendingCodeKey = 'payk_pending_ref_code';
  static const _installReferrerKey = 'payk_install_referrer';
  static const _installReferrerCheckedKey = 'payk_install_referrer_checked';

  final MethodChannel _channel;
  final Future<String?> Function()? readInstallReferrer;
  final Future<String?> Function()? readInitialLink;
  final Future<ReferralDeviceInfo?> Function()? readDeviceInfo;

  final ValueNotifier<String?> _pendingCode = ValueNotifier<String?>(null);
  String? _installReferrer;
  Future<void>? _initFuture;
  var _handlerBound = false;

  ValueListenable<String?> get pendingCodeListenable => _pendingCode;
  String? get pendingCode => _pendingCode.value;
  String? get installReferrer => _installReferrer;

  /// Инициализация при старте приложения: читает кэш, подписывается на входящие ссылки и
  /// один раз запрашивает Google Play Install Referrer. Безопасна на web и в тестах.
  Future<void> initialize() {
    return _initFuture ??= _runInit();
  }

  Future<void> _runInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCode = normalizeReferralCode(prefs.getString(_pendingCodeKey));
      if (cachedCode != null && _pendingCode.value == null) {
        _pendingCode.value = cachedCode;
      }
      final cachedRef = prefs.getString(_installReferrerKey)?.trim();
      if (cachedRef != null && cachedRef.isNotEmpty) {
        _installReferrer = cachedRef;
      }

      if (!kIsWeb && !_handlerBound) {
        _handlerBound = true;
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'onLink' && call.arguments is String) {
            await captureLinkString(call.arguments as String);
          }
        });
      }

      final initialLink = await _invokeInitialLink();
      if (initialLink != null && initialLink.isNotEmpty) {
        await captureLinkString(initialLink);
      }

      final checked = prefs.getBool(_installReferrerCheckedKey) ?? false;
      if (!checked && _installReferrer == null) {
        final raw = await _invokeInstallReferrer();
        if (raw != null) {
          final cleaned = raw.trim();
          if (cleaned.isNotEmpty) {
            final clipped = cleaned.length > 512 ? cleaned.substring(0, 512) : cleaned;
            _installReferrer = clipped;
            await prefs.setString(_installReferrerKey, clipped);
          }
          await prefs.setBool(_installReferrerCheckedKey, true);
        }
      }
    } catch (_) {
      // На платформах без нативного канала и в тестах работаем без ошибок.
    }
  }

  /// Сохраняет код из входящей ссылки (например `https://payk-loyalty.vercel.app/r/AZ-4821` или `/r/AZ-4821`).
  Future<String?> captureLinkString(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    return captureLinkUri(uri);
  }

  Future<String?> captureLinkUri(Uri uri) async {
    final code = parseReferralCodeFromUri(uri);
    if (code == null) return null;
    await captureCode(code);
    return code;
  }

  Future<void> captureCode(String rawCode) async {
    final code = normalizeReferralCode(rawCode);
    if (code == null) return;
    _pendingCode.value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingCodeKey, code);
    } catch (_) {}
  }

  Future<ReferralDeviceInfo?> collectDeviceInfo() async {
    final reader = readDeviceInfo;
    if (reader != null) {
      try {
        return await reader();
      } catch (_) {
        return null;
      }
    }
    if (kIsWeb) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      if (raw == null || raw.isEmpty) return null;
      return ReferralDeviceInfo(
        platform: raw['platform'] as String?,
        osVersion: raw['os_version'] as String?,
        model: raw['model'] as String?,
        language: raw['language'] as String?,
        screen: raw['screen'] as String?,
        timezone: raw['timezone'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Спрашивает сервер, кто пригласил нового пользователя до заполнения анкеты.
  Future<ReferralContext> matchBeforeRegister(LoyaltyApi api) async {
    await initialize();
    final device = await collectDeviceInfo();
    final code = _pendingCode.value;
    final referrer = _installReferrer;
    try {
      final match = await api.matchReferral(
        code: code,
        installReferrer: referrer,
        device: device,
      );
      return ReferralContext(
        match: match,
        linkCode: code,
        installReferrer: referrer,
        device: device,
      );
    } catch (_) {
      return ReferralContext(
        match: ReferralMatch.notFound,
        linkCode: code,
        installReferrer: referrer,
        device: device,
      );
    }
  }

  /// Сбрасывает сохранённые данные приглашения после успешной регистрации.
  Future<void> clearPending() async {
    _pendingCode.value = null;
    _installReferrer = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingCodeKey);
      await prefs.remove(_installReferrerKey);
    } catch (_) {}
  }

  Future<String?> _invokeInitialLink() async {
    final reader = readInitialLink;
    if (reader != null) {
      try {
        return await reader();
      } catch (_) {
        return null;
      }
    }
    if (kIsWeb) return null;
    try {
      return await _channel.invokeMethod<String>('getInitialLink');
    } catch (_) {
      return null;
    }
  }

  Future<String?> _invokeInstallReferrer() async {
    final reader = readInstallReferrer;
    if (reader != null) {
      try {
        return await reader();
      } catch (_) {
        return null;
      }
    }
    if (kIsWeb) return null;
    try {
      return await _channel.invokeMethod<String>('getInstallReferrer');
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    if (_handlerBound) {
      _channel.setMethodCallHandler(null);
      _handlerBound = false;
    }
    _pendingCode.dispose();
  }
}
