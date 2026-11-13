import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  @override
  SessionState build() => const SessionState(ready: true, accessToken: 'access');
}

void main() {
  LoyaltyApi apiWith(http.Client client) => LoyaltyApi(ApiClient(
        readTokens: () => const TokenPair(accessToken: 'access', refreshToken: 'refresh'),
        writeTokens: (access, refresh) {},
        onExpired: () {},
        httpClient: client,
      ));

  test('logout sends an authenticated POST before the session is dropped', () async {
    final api = apiWith(MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/loyalty-app/logout'));
      expect(request.headers['Authorization'], 'Bearer access');
      return http.Response('{"ok":true}', 200);
    }));
    await api.logout();
  });

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
    SharedPreferences.setMockInitialValues({});
    final session = _Session();
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => session),
      loyaltyApiProvider.overrideWithValue(_DeletionApi(fail: true)),
    ]);
    addTearDown(container.dispose);
    container.read(sessionProvider);
    await expectLater(session.deleteAccount(), throwsA(isA<ApiException>()));
    expect(session.state.loggedIn, isTrue);
  });

  test('session logs out after server deletion succeeds', () async {
    SharedPreferences.setMockInitialValues({});
    final session = _Session();
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => session),
      loyaltyApiProvider.overrideWithValue(_DeletionApi()),
    ]);
    addTearDown(container.dispose);
    container.read(sessionProvider);
    await session.deleteAccount();
    expect(session.state.loggedIn, isFalse);
  });
}
