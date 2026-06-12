import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/attendance_outcome.dart';

void main() {
  group('AttendanceOutcome.parse', () {
    test('status 0 → success (live server shape)', () {
      final o = AttendanceOutcome.parse({
        'status': 200,
        'meta': {'code': 200},
        'data': {
          'status': 0,
          'message': 'Attendance updated successfully',
          'attendance': [],
          'tTimeSession': [],
        },
      });
      expect(o.success, isTrue);
      expect(o.needsClassTime, isFalse);
      expect(o.message, 'Attendance updated successfully');
    });

    test('status 1 + sessions → needsClassTime (live server shape)', () {
      final o = AttendanceOutcome.parse({
        'status': 200,
        'data': {
          'status': 1,
          'message': 'Select your training class time',
          'tTimeSession': [
            {'id': 2583, 'text': 'Friday (15:00 16:00 )'},
            {'id': 2584, 'text': 'Saturday (10:00 11:00 )'},
          ],
        },
      });
      expect(o.success, isFalse);
      expect(o.needsClassTime, isTrue);
      expect(o.sessions.length, 2);
      expect(o.sessions.first.id, 2583);
      expect(o.sessions.first.text, contains('Friday'));
    });

    test('status -1 → rejection with message (live server shape)', () {
      final o = AttendanceOutcome.parse({
        'data': {
          'status': -1,
          'message': 'Invalid QR Code',
          'attendance': [],
          'tTimeSession': [],
        },
      });
      expect(o.success, isFalse);
      expect(o.needsClassTime, isFalse);
      expect(o.message, 'Invalid QR Code');
    });

    test('status 1 without sessions is NOT needsClassTime', () {
      final o = AttendanceOutcome.parse({
        'data': {'status': 1, 'message': 'Select your training class time'},
      });
      expect(o.needsClassTime, isFalse);
      expect(o.success, isFalse);
    });

    test('missing/unknown data shape → assumed success', () {
      expect(AttendanceOutcome.parse(null).success, isTrue);
      expect(AttendanceOutcome.parse({'status': 200}).success, isTrue);
      expect(AttendanceOutcome.parse('ok').success, isTrue);
    });

    test('malformed session rows are skipped', () {
      final o = AttendanceOutcome.parse({
        'data': {
          'status': 1,
          'tTimeSession': [
            {'id': 'not-a-number', 'text': 'bad'},
            'junk',
            {'id': 7, 'text': 'Monday'},
          ],
        },
      });
      expect(o.sessions.length, 1);
      expect(o.sessions.single.id, 7);
    });
  });
}
