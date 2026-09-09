// Opt-in smoke test against the LIVE Club.Api.
//
// Skipped unless credentials are supplied, so `flutter test` stays offline and green by
// default and no account is ever committed:
//
//   flutter test test/live_api_smoke_test.dart \
//     --dart-define=LIVE_USER=<id> --dart-define=LIVE_PASS=<password>
//
// Runs on the Dart VM rather than a browser, so it exercises the real API without the CORS
// wall that blocks Flutter web against this plain-HTTP backend.
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/api_service.dart';

const _user = String.fromEnvironment('LIVE_USER');
const _pass = String.fromEnvironment('LIVE_PASS');

void main() {
  final configured = _user.isNotEmpty && _pass.isNotEmpty;

  group('live Club.Api', () {
    late String token;

    test('authenticates and returns a bearer token', () async {
      final res = await ApiService.post('/Account/Authenticate', {
        'userType': 3,
        'username': _user,
        'password': _pass,
        'accessMethod': 0,
        'branchId': 0,
      });
      final data = (res is Map) ? res['data'] : null;
      expect(data, isA<Map>(), reason: 'expected a {status,meta,data} envelope');
      final t = (data as Map)['accessToken'];
      expect(t, isA<String>());
      expect((t as String).length, greaterThan(100), reason: 'JWT looks too short');
      token = t;
      ApiService.setToken(token);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('reads the signed-in profile', () async {
      final res = await ApiService.get('/Profile/MyInfo');
      final data = (res is Map) ? res['data'] : null;
      expect(data, isA<Map>());
      expect((data as Map)['name'], isA<String>());
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('reads notifications (list or empty, never an error envelope)', () async {
      final res = await ApiService.get('/Profile/MyNotifications');
      final data = (res is Map) ? res['data'] : null;
      expect(data, anyOf(isA<List>(), isNull));
    }, timeout: const Timeout(Duration(seconds: 60)));
  }, skip: configured ? false : 'set --dart-define=LIVE_USER/LIVE_PASS to run');
}
