import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/response_utils.dart';

void main() {
  group('friendlyError', () {
    test('network / CORS / socket errors become a connection message', () {
      expect(friendlyError('ClientException: XMLHttpRequest error., uri=...'),
          'Network error — please check your connection and try again.');
      expect(friendlyError(Exception('SocketException: Failed host lookup')),
          'Network error — please check your connection and try again.');
    });

    test('401 becomes a session-expired message', () {
      expect(friendlyError('Exception: ❌ Unauthorized - Token missing or expired'),
          'Your session has expired. Please log in again.');
    });

    test('server 5xx becomes a try-later message', () {
      expect(friendlyError('Exception: ❌ Error 500: boom'),
          'Server error — please try again in a moment.');
    });

    test('strips the Exception/glyph prefix from other messages', () {
      expect(friendlyError('Exception: ❌ Something specific'),
          'Something specific');
    });

    test('blank / unknown falls back to a generic message', () {
      expect(friendlyError(''), 'Something went wrong. Please try again.');
    });
  });
}
