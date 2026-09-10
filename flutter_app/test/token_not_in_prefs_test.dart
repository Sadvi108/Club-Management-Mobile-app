// The bearer token must never be written to SharedPreferences.
//
// The session used to be persisted whole — token included — as a JSON blob in prefs, which
// is plaintext on disk (readable from an ADB backup, or by another app on a rooted device).
// The token now goes to the OS keystore and the prefs blob is written without it. These
// tests pin that rule so it cannot quietly regress.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/user_session.dart';
import 'package:dclix_app/services/secure_store.dart';

const _jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1bmlxdWVfbmFtZSI6IlRFU1QifQ.c2lnbmF0dXJl';

void main() {
  // Initialise the binding so the secure-storage platform channel fails cleanly
  // (unavailable in unit tests) instead of throwing binding errors into the output.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('splitAuthForStorage', () {
    test('pulls the token out and leaves the rest of the profile intact', () {
      final (token, safe) = UserSession.splitAuthForStorage({
        'accessToken': _jwt,
        'id': 35842,
        'name': 'TEST MEMBER',
        'clubId': 68,
      });

      expect(token, _jwt);
      expect(safe.containsKey('accessToken'), isFalse,
          reason: 'the token must not survive into the prefs blob');
      expect(safe['id'], 35842);
      expect(safe['name'], 'TEST MEMBER');
      expect(safe['clubId'], 68);
    });

    test('the serialised prefs blob contains no JWT', () {
      final (_, safe) = UserSession.splitAuthForStorage({
        'accessToken': _jwt,
        'name': 'TEST MEMBER',
      });
      final encoded = jsonEncode(safe);

      expect(encoded.contains(_jwt), isFalse);
      expect(RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.').hasMatch(encoded), isFalse,
          reason: 'no JWT-shaped string may appear anywhere in the blob');
      expect(encoded.contains('accessToken'), isFalse);
    });

    test('does not mutate the caller\'s map', () {
      final original = {'accessToken': _jwt, 'name': 'TEST MEMBER'};
      UserSession.splitAuthForStorage(original);
      expect(original['accessToken'], _jwt,
          reason: 'the in-memory session still needs its token');
    });

    test('a session with no token yields an empty token, not a crash', () {
      final (token, safe) = UserSession.splitAuthForStorage({'name': 'NO TOKEN'});
      expect(token, isEmpty);
      expect(safe['name'], 'NO TOKEN');
    });
  });

  group('SecureStore', () {
    // Platform channels are unavailable in unit tests, so these exercise the in-memory
    // fallback — which is exactly the path that keeps auth working when the Android
    // keystore throws.
    test('round-trips a value and deletes it', () async {
      await SecureStore.write('k', _jwt);
      expect(await SecureStore.read('k'), _jwt);
      await SecureStore.delete('k');
      expect(await SecureStore.read('k'), isNull);
    });

    test('reading an unknown key returns null', () async {
      expect(await SecureStore.read('never-written'), isNull);
    });
  });
}
