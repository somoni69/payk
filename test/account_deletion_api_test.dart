import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payk/data/api/api_client.dart';
import 'package:payk/data/api/api_exception.dart';
import 'package:payk/data/api/loyalty_api.dart';
import 'package:payk/data/session/session_controller.dart';

class _DeletionApi extends Fake implements LoyaltyApi {
  _DeletionApi({this.fail = false});
  final bool fail;
  @override
  Future<void> deleteAccount() async {
    if (fail) throw ApiException(500, 'Deletion failed');
  }
}

class _Session extends SessionController {
  bool loggedOut = false;
  @override
  SessionState build() => const SessionState(ready: true, accessToken: 'access');
  @override
  Future<void> logout() async { loggedOut = true; }
}

void main() {
  LoyaltyApi apiWith(http.Client client) => LoyaltyApi(ApiClient(
        readTokens: () => const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
        writeTokens: (access, refresh) {},
        onExpired: () {},
        httpClient: client,
      ));

  test('account deletion sends an authenticated DELETE request', () async {
    final api = apiWith(MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, endsWith('/loyalty-app/me'));
      expect(request.headers['Authorization'], 'Bearer access');
      return http.Response('{}', 200);
    }));
    await api.deleteAccount();
  });

  test('account deletion reports server failure', () async {
    final api = apiWith(MockClient((_) async => http.Response('{"detail":"Deletion failed"}', 500)));
    await expectLater(api.deleteAccount(), throwsA(isA<ApiException>()));
  });

  test('session stays signed in when server deletion fails', () async {
    final session = _Session();
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => session),
      loyaltyApiProvider.overrideWithValue(_DeletionApi(fail: true)),
    ]);
    addTearDown(container.dispose);
    container.read(sessionProvider);
    await expectLater(session.deleteAccount(), throwsA(isA<ApiException>()));
    expect(session.loggedOut, isFalse);
  });

  test('session logs out after server deletion succeeds', () async {
    final session = _Session();
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => session),
      loyaltyApiProvider.overrideWithValue(_DeletionApi()),
    ]);
    addTearDown(container.dispose);
    container.read(sessionProvider);
    await session.deleteAccount();
    expect(session.loggedOut, isTrue);
  });
}
