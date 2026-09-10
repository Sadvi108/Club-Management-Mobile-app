import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/user_session.dart';

void main() {
  group('UserSession.tokenFromUpdateResponse', () {
    test('extracts the raw token string from a {status,data} envelope', () {
      final resp = {'status': 200, 'meta': {'code': 200}, 'data': 'jwt.abc.xyz'};
      expect(UserSession.tokenFromUpdateResponse(resp), 'jwt.abc.xyz');
    });

    test('accepts a bare token string', () {
      expect(UserSession.tokenFromUpdateResponse('jwt.raw'), 'jwt.raw');
    });

    test('accepts a nested {data:{accessToken}} shape', () {
      final resp = {'data': {'accessToken': 'jwt.nested'}};
      expect(UserSession.tokenFromUpdateResponse(resp), 'jwt.nested');
    });

    test('returns null for an error envelope / empty / non-token', () {
      expect(UserSession.tokenFromUpdateResponse({'status': 400, 'data': null}), isNull);
      expect(UserSession.tokenFromUpdateResponse({'data': ''}), isNull);
      expect(UserSession.tokenFromUpdateResponse(null), isNull);
      expect(UserSession.tokenFromUpdateResponse(42), isNull);
    });
  });
}
