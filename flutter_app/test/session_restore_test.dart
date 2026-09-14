import 'dart:convert';
import 'package:dclix_app/config/app_version.dart';
import 'package:dclix_app/services/api_service.dart';
import 'package:dclix_app/services/secure_store.dart';
import 'package:dclix_app/services/user_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final session = UserSession.instance;
  late http.Client originalClient;
  var requests = 0;
  setUp(() async {
    originalClient = ApiService.client;
    requests = 0;
    session.authData = null;
    session.myInfo = null;
    SharedPreferences.setMockInitialValues({
      UserSession.sessionKey: jsonEncode({'id': 1, 'userType': 3}),
    });
    await SecureStore.delete(UserSession.sessionBuildKey);
    await SecureStore.write(UserSession.tokenKey, 'test-token');
    ApiService.client = MockClient((request) async {
      requests++;
      return http.Response('{"status":401}', 401);
    });
  });
  tearDown(() async {
    session.stopNotificationPolling();
    session.authData = null;
    ApiService.clearToken();
    ApiService.client = originalClient;
    await SecureStore.delete(UserSession.tokenKey);
    await SecureStore.delete(UserSession.sessionBuildKey);
  });

  test('restored backup without a build stamp requires sign-in', () async {
    expect(await session.restoreSession(), isFalse);
    expect(requests, 0);
    expect(session.isLoggedIn, isFalse);
    expect(await SecureStore.read(UserSession.tokenKey), isNull);
    expect(
        (await SharedPreferences.getInstance())
            .containsKey(UserSession.sessionKey),
        isFalse);
  });

  test('an app update does not automatically sign in the previous account',
      () async {
    await SecureStore.write(UserSession.sessionBuildKey, '${kAppBuild - 1}');
    expect(await session.restoreSession(), isFalse);
    expect(requests, 0);
    expect(session.isLoggedIn, isFalse);
    expect(await SecureStore.read(UserSession.tokenKey), isNull);
  });

  test('an expired token on this build cannot route home', () async {
    await SecureStore.write(UserSession.sessionBuildKey, '$kAppBuild');
    expect(await session.restoreSession(), isFalse);
    expect(requests, 1,
        reason: 'validate the token before loading dashboard reports');
    expect(session.isLoggedIn, isFalse);
    expect(await SecureStore.read(UserSession.tokenKey), isNull);
  });

  test('an unavailable profile endpoint does not authenticate cached data',
      () async {
    await SecureStore.write(UserSession.sessionBuildKey, '$kAppBuild');
    ApiService.client =
        MockClient((_) async => http.Response('Unavailable', 503));
    expect(await session.restoreSession(), isFalse);
    expect(session.isLoggedIn, isFalse);
    expect(await SecureStore.read(UserSession.tokenKey), 'test-token',
        reason: 'a temporary outage must not revoke the persisted token');
  });
}
