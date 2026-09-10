import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/prepay_service.dart';

void main() {
  // Fake term-payment endpoint keyed by (studentId, month).
  Future<dynamic> fake(Map<String, dynamic> body) async {
    final sid = (body['studentIds'] as List).first;
    final m = (body['months'] as List).first;
    if (sid == 100 && m == 8) {
      return {
        'status': 200,
        'data': [
          {
            'invoiceId': 1442011,
            'studentId': 100,
            'studentName': 'ARSYAD',
            'transactionType': 'Monthly',
            'period': 'August-2026',
            'discountAmount': 0.0,
            'dueAmount': 70.0,
          }
        ],
      };
    }
    if (sid == 200 && m == 8) {
      return {
        'status': 200,
        'data': [
          {
            'invoiceId': 0,
            'studentId': 200,
            'studentName': 'TTT',
            'transactionType': 'Monthly',
            'period': 'August-2026',
            'discountAmount': 5.0,
            'dueAmount': 50.0,
          }
        ],
      };
    }
    return {'status': 200, 'data': []};
  }

  test('gatherInvoices collects one invoice per (student, month), with detail', () async {
    final bill = await PrepayService.gatherInvoices(
      studentIds: [100, 200],
      year: 2026,
      months: [8, 9],
      fetch: fake,
    );
    expect(bill.count, 2);
    expect(bill.total, 120.0);
    final a = bill.invoices.firstWhere((i) => i.studentId == 100);
    expect(a.invoiceNo, '1442011');
    expect(a.invoiceType, 'Monthly');
    expect(a.period, 'August-2026');
    expect(a.studentName, 'ARSYAD');
    expect(a.amount, 70.0);
    final t = bill.invoices.firstWhere((i) => i.studentId == 200);
    expect(t.invoiceNo, '0');
    expect(t.discount, 5.0);
  });

  test('empty months/students yield an empty bill', () async {
    final bill = await PrepayService.gatherInvoices(
      studentIds: [999],
      year: 2026,
      months: [1, 2],
      fetch: (_) async => {'status': 200, 'data': []},
    );
    expect(bill.count, 0);
    expect(bill.total, 0);
  });
}
