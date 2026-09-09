import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/prepay_service.dart';

void main() {
  Future<dynamic> fakeFetch(Map<String, dynamic> body) async {
    final m = (body['months'] as List).first;
    if (m == 6) {
      return {
        'status': 200,
        'data': [
          {
            'invoiceId': 0,
            'period': 'June-2026',
            'invoiceDescription': 'Monthly fee for June-2026',
            'dueAmount': 50.0,
            'monthlyFeeId': 1181,
          }
        ],
      };
    }
    return {'status': 200, 'data': []};
  }

  test('prices each month, skips empty, sums total', () async {
    final quote = await PrepayService.priceMonths(
      studentId: 46679,
      year: 2026,
      months: [6, 9],
      fetch: fakeFetch,
    );
    expect(quote.months.length, 1);
    expect(quote.months.first.month, 6);
    expect(quote.months.first.label, 'June-2026');
    expect(quote.months.first.amount, 50.0);
    expect(quote.total, 50.0);
  });

  test('empty result yields an empty quote', () async {
    final quote = await PrepayService.priceMonths(
      studentId: 1,
      year: 2026,
      months: [9],
      fetch: (_) async => {'status': 200, 'data': []},
    );
    expect(quote.months, isEmpty);
    expect(quote.total, 0);
  });
}
