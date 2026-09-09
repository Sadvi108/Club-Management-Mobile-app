import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/user_session.dart';

void main() {
  group('UserSession.currentStudentId', () {
    final s = UserSession.instance;
    tearDown(() {
      s.authData = null;
      s.setActiveStudent(name: null, id: null);
    });

    test('returns authData id when no sibling is active', () {
      s.authData = {'id': 22410};
      expect(s.currentStudentId, 22410);
    });

    test('active guardian child wins over authData id', () {
      s.authData = {'id': 22410};
      s.setActiveStudent(name: 'KID', id: 46679);
      expect(s.currentStudentId, 46679);
    });

    test('numeric-string id is parsed', () {
      s.authData = {'id': '2347'};
      expect(s.currentStudentId, 2347);
    });

    test('null when nothing is available', () {
      s.authData = null;
      expect(s.currentStudentId, isNull);
    });
  });
}
