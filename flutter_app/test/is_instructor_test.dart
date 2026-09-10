import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/user_session.dart';

void main() {
  group('UserSession.isInstructor', () {
    final session = UserSession.instance;

    tearDown(() => session.authData = null);

    test('userType 0 (live instructor) → true', () {
      session.authData = {'userType': 0};
      expect(session.isInstructor, isTrue);
    });

    test('userType 2 (legacy instructor) → true', () {
      session.authData = {'userType': 2};
      expect(session.isInstructor, isTrue);
    });

    test('userType 3 (student / parent) → false', () {
      session.authData = {'userType': 3};
      expect(session.isInstructor, isFalse);
    });

    test('no authData (logged out) → false', () {
      session.authData = null;
      expect(session.isInstructor, isFalse);
    });

    test('logged in but userType key absent → false', () {
      session.authData = {'someOtherKey': 1};
      expect(session.isInstructor, isFalse);
    });

    test('userType as numeric string is tolerated', () {
      session.authData = {'userType': '0'};
      expect(session.isInstructor, isTrue);
    });
  });
}
