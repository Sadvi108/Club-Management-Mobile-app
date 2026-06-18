import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/screens/instructor_reports/report_spec.dart';
import 'package:dclix_app/screens/instructor_reports/student_list_fetch.dart';

void main() {
  group('Receipt report payment-mode filter', () {
    final spec = kReportSpecs['receipt']!;

    test('extracts the mode from the real paymentMethod field', () {
      // Live data shape: "Cash - Monthly fee for August-2024".
      expect(spec.rowStatus!({'paymentMethod': 'Cash - Monthly fee for August-2024'}),
          'Cash');
      expect(spec.rowStatus!({'paymentMethod': 'Ibg - Monthly fee for July-2024'}),
          'Ibg');
      expect(spec.rowStatus!({'paymentMethod': 'Contra - Monthly fee for Nov-2025'}),
          'Contra');
    });

    test('falls back to the whole value when there is no separator', () {
      expect(spec.rowStatus!({'paymentMethod': 'Cash'}), 'Cash');
    });
  });

  group('New Student report wiring', () {
    test('is registered and titled (not the raw schedule endpoint)', () {
      final spec = kReportSpecs['new-student'];
      expect(spec, isNotNull);
      expect(spec!.title, 'New Student');
      // Must reuse the real student aggregator, not Reports/StudentDetails
      // (which returns instructor schedule rows).
      expect(identical(spec.fetch, fetchInstructorStudentList), isTrue);
    });
  });
}
