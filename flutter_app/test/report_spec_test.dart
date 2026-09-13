import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/screens/instructor_reports/report_spec.dart';

void main() {
  group('Receipt report body — server-side payment-mode filter', () {
    // /Reports/Receipts filters by mode via `reportType`, but the server only
    // accepts 'Cash' or 'FPX' — any other value returns zero rows. So only
    // pass reportType for those two; otherwise omit it (show all).
    test('Cash → reportType=Cash', () {
      final b = receiptReportBody(ReportQuery(status: 'Cash'));
      expect(b['reportType'], 'Cash');
    });

    test('FPX → reportType=FPX', () {
      final b = receiptReportBody(ReportQuery(status: 'FPX'));
      expect(b['reportType'], 'FPX');
    });

    test('an unsupported mode does NOT send reportType', () {
      final b = receiptReportBody(ReportQuery(status: 'Ibg'));
      expect(b.containsKey('reportType'), isFalse);
    });

    test('no status → no reportType', () {
      final b = receiptReportBody(ReportQuery());
      expect(b.containsKey('reportType'), isFalse);
    });

    test('receipt spec offers only the server-supported modes', () {
      expect(kReportSpecs['receipt']!.statusOptions, ['Cash', 'FPX']);
    });
  });

  test('New Student does not masquerade as the enrolled student report', () {
    expect(kReportSpecs.containsKey('new-student'), isFalse);
  });
}
