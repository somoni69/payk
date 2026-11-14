import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    if (access is! String || refresh is! String || access.isEmpty || refresh.isEmpty) {
      throw ApiException(0, 'Неожиданный ответ сервера');
    }
    return TokenPair(accessToken: access, refreshToken: refresh);
  }
}

class ApiClient {
  ApiClient({
    required this.readTokens,
    required this.writeTokens,
    required this.onExpired,
    this.readLocale = _russian,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  static String _russian() => 'ru';

  final TokenPair? Function() readTokens;
  final void Function(String accessToken, String refreshToken) writeTokens;
  final void Function() onExpired;
  final String Function() readLocale;
  final http.Client _http;
  Future<void>? _refreshing;

  Future<http.Response> _sendWithAuthRetry(
    Future<http.Response> Function(String? token) dispatch, {
    required bool auth,
  }) async {
    String? sentToken = auth ? readTokens()?.accessToken : null;
    http.Response response;
    try {
      response = await dispatch(sentToken);
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(0, 'Нет связи с сервером');
    }

    if (response.statusCode == 401 && auth) {
      final current = readTokens()?.accessToken;
      var retry = false;
      if (current != null && current.isNotEmpty && current != sentToken) {
        retry = true;
      } else {
        try {
          await _refresh();
          retry = true;
        } on ApiException catch (error) {
          if (error.status == 401) onExpired();
          rethrow;
        }
      }
      if (retry) {
        sentToken = readTokens()?.accessToken;
        try {
          response = await dispatch(sentToken);
        } catch (_) {
          throw ApiException(0, 'Нет связи с сервером');
        }
      }
      if (response.statusCode == 401) {
        onExpired();
        throw ApiException(401, _detail(response) ?? 'Сессия истекла — войдите снова');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _detail(response) ?? _fallback(response.statusCode));
    }
    return response;
  }

  Future<Object?> send(
    String path, {
    String method = 'GET',
    Object? body,
    bool auth = true,
  }) async {
    final response = await _sendWithAuthRetry((sentToken) {
      final headers = <String, String>{
        'Accept': 'application/json',
        'X-Locale': readLocale(),
      };
      if (body != null) headers['Content-Type'] = 'application/json';
      if (sentToken != null && sentToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $sentToken';
      }
      final uri = Uri.parse('${ApiConfig.base}$path');
      final encoded = body == null ? null : jsonEncode(body);
      final Future<http.Response> req;
      switch (method) {
        case 'POST':
          req = _http.post(uri, headers: headers, body: encoded);
        case 'PATCH':
          req = _http.patch(uri, headers: headers, body: encoded);
        case 'DELETE':
          req = _http.delete(uri, headers: headers, body: encoded);
        default:
          req = _http.get(uri, headers: headers);
      }
      return req.timeout(const Duration(seconds: 20));
    }, auth: auth);

    if (response.statusCode == 204 || response.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ApiException(response.statusCode, 'Сервер ответил некорректно');
    }
  }

  Future<Object?> upload(String path, String filePath, {String field = 'file'}) async {
    Future<http.Response> dispatch() async {
      final request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.base}$path'));
      request.headers['Accept'] = 'application/json';
      request.headers['X-Locale'] = readLocale();
      final token = readTokens()?.accessToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath(field, filePath));
      final streamed = await _http.send(request).timeout(const Duration(seconds: 30));
      return http.Response.fromStream(streamed);
    }

    http.Response response;
    try {
      response = await dispatch();
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(0, 'Нет связи с сервером');
    }
    if (response.statusCode == 401) {
      await _refresh();
      response = await dispatch();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, _detail(response) ?? _fallback(response.statusCode));
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// Скачивает бинарный файл (например, чек в PDF или PNG) с автообновлением токена.
  Future<Uint8List> downloadBytes(String path, {bool auth = true}) async {
    final response = await _sendWithAuthRetry((sentToken) {
      final headers = <String, String>{
        'X-Locale': readLocale(),
      };
      if (sentToken != null && sentToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $sentToken';
      }
      final uri = Uri.parse('${ApiConfig.base}$path');
      return _http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
    }, auth: auth);
    return response.bodyBytes;
  }

  Future<void> _refresh() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final future = _refreshOnce();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshOnce() async {
    final refresh = readTokens()?.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      throw ApiException(401, 'Сессия истекла — войдите снова');
    }
    final uri = Uri.parse('${ApiConfig.base}/refresh');
    http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Locale': readLocale(),
            },
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException(0, 'Нет связи с сервером');
    }
    if (response.statusCode >= 500) {
      throw ApiException(0, 'Сервер недоступен');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(401, 'Сессия истекла — войдите снова');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map) throw ApiException(0, 'Неожиданный ответ сервера');
    final pair = TokenPair.fromJson(json.map((key, value) => MapEntry(key.toString(), value)));
    writeTokens(pair.accessToken, pair.refreshToken);
  }

  String? _detail(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map) return null;
      final detail = json['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          return (first['msg'] as String).replaceFirst(RegExp(r'^Value error, '), '');
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _fallback(int status) {
    if (status == 401) return 'Сессия истекла — войдите снова';
    if (status == 429) return 'Слишком много запросов — попробуйте позже';
    if (status >= 500) return 'Сервер недоступен';
    return 'Не удалось выполнить запрос';
  }

  void close() => _http.close();
}
