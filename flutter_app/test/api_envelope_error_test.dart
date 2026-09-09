import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/response_utils.dart';

void main() {
  group('apiEnvelopeError', () {
    test('HTTP-200-wrapped failure returns the server message', () {
      final resp = {
        'status': 404,
        'meta': {'code': 404, 'error': 'Account not found, contact your club administrator'},
      };
      expect(apiEnvelopeError(resp),
          'Account not found, contact your club administrator');
    });

    test('400 envelope with meta.error returns it', () {
      final resp = {
        'status': 400,
        'meta': {'code': 0, 'error': 'Object reference not set to an instance of an object.'},
      };
      expect(apiEnvelopeError(resp),
          'Object reference not set to an instance of an object.');
    });

    test('successful auth envelope returns null', () {
      final resp = {
        'status': 200,
        'meta': {'code': 200},
        'data': {'accessToken': 'abc', 'userType': 3},
      };
      expect(apiEnvelopeError(resp), isNull);
    });

    test('bare success map without status returns null', () {
      final resp = {
        'data': {'accessToken': 'abc'},
      };
      expect(apiEnvelopeError(resp), isNull);
    });

    test('non-map response returns null', () {
      expect(apiEnvelopeError('oops'), isNull);
      expect(apiEnvelopeError(null), isNull);
    });

    test('failure status without a message falls back to a generic string', () {
      final resp = {'status': 500, 'meta': {'code': 500}};
      expect(apiEnvelopeError(resp), 'Request failed (status 500).');
    });
  });
}
