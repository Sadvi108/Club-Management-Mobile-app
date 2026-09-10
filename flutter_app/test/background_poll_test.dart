// Background notification polling.
//
// The callback runs in a HEADLESS ISOLATE on a member's phone: no widgets, no providers,
// no UserSession in memory, and nothing you can attach a debugger to. If it silently does
// nothing, the symptom is "I stopped getting fee reminders" weeks later. So the parts that
// can be tested here — the storage contract it depends on — are.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dclix_app/services/background_poll.dart';
import 'package:dclix_app/services/user_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the isolate reads the SAME storage keys the app writes', () {
    // A duplicated literal that drifted would stop every closed-app alert with no error.
    expect(UserSession.sessionKey, 'cm_auth_data_v1');
    expect(UserSession.tokenKey, 'cm_auth_token_v1');
  });

  test('the task name and unique name are stable', () {
    // WorkManager keys the registration on these; changing one orphans the old job.
    expect(BackgroundPoll.taskName, 'dclix-notification-poll');
  });

  test('the interval is not below what Android will honour', () {
    // Asking for less than 15 minutes is silently rounded up, so asking for it is a lie
    // about how often alerts arrive.
    expect(BackgroundPoll.interval.inMinutes, greaterThanOrEqualTo(15));
  });

  group('runOnce', () {
    test('a signed-out device does no work and does not ask to retry', () async {
      SharedPreferences.setMockInitialValues({});
      // No token in the keystore (SecureStore falls back to in-memory in a test).
      expect(await BackgroundPoll.runOnce(), isTrue,
          reason: 'nothing to do is success, not a failure worth retrying');
    });

    test('a session with no usable id does not retry forever', () async {
      SharedPreferences.setMockInitialValues({
        UserSession.sessionKey: '{"authData":{"name":"Alex Tan"}}',
      });
      expect(await BackgroundPoll.runOnce(), isTrue);
    });

    test('a corrupt session blob is survivable', () async {
      SharedPreferences.setMockInitialValues({UserSession.sessionKey: 'not json'});
      expect(await BackgroundPoll.runOnce(), isTrue);
    });
  });
}
