import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/utils/qr_content.dart';

void main() {
  group('QrContent builders', () {
    test('trainingCenter pads to 8 digits', () {
      expect(QrContent.trainingCenter(1636), 'TC-00001636');
      expect(QrContent.trainingCenter(1), 'TC-00000001');
    });

    test('student pads to 8 digits', () {
      expect(QrContent.student(22410), 'ST-00022410');
    });

    test('ids longer than 8 digits are not truncated', () {
      expect(QrContent.student(123456789), 'ST-123456789');
    });

    test('studentFromRaw accepts int-like values', () {
      expect(QrContent.studentFromRaw(22410), 'ST-00022410');
      expect(QrContent.studentFromRaw('22410'), 'ST-00022410');
      expect(QrContent.studentFromRaw(' 47507 '), 'ST-00047507');
    });

    test('studentFromRaw rejects junk', () {
      expect(QrContent.studentFromRaw(null), isNull);
      expect(QrContent.studentFromRaw(''), isNull);
      expect(QrContent.studentFromRaw('ABC'), isNull);
      expect(QrContent.studentFromRaw('0'), isNull);
      expect(QrContent.studentFromRaw(-5), isNull);
    });
  });

  group('QrContent.parse', () {
    test('round-trips training center codes', () {
      final p = QrContent.parse('TC-00001636');
      expect(p, isNotNull);
      expect(p!.type, QrType.trainingCenter);
      expect(p.id, 1636);
      expect(p.code, 'TC-00001636');
    });

    test('round-trips student codes', () {
      final p = QrContent.parse('ST-00022410');
      expect(p, isNotNull);
      expect(p!.type, QrType.student);
      expect(p.id, 22410);
      expect(p.code, 'ST-00022410');
    });

    test('trims surrounding whitespace', () {
      expect(QrContent.parse(' TC-00001636 \n'), isNotNull);
    });

    test('rejects non-attendance strings', () {
      expect(QrContent.parse(null), isNull);
      expect(QrContent.parse(''), isNull);
      expect(QrContent.parse('TC-'), isNull);
      expect(QrContent.parse('tc-00001636'), isNull); // case-sensitive
      expect(QrContent.parse('TC-12AB'), isNull);
      expect(QrContent.parse('XX-00000001'), isNull);
      expect(QrContent.parse('https://example.com'), isNull);
      expect(QrContent.parse('ST-0'), isNull); // zero id
    });

    test('labels are human readable', () {
      expect(QrContent.parse('TC-00001636')!.label, 'Training Center #1636');
      expect(QrContent.parse('ST-00022410')!.label, 'Student #22410');
    });
  });
}
