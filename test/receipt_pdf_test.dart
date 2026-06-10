import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/receipt_pdf.dart';

void main() {
  final receiptRows = <Map<String, dynamic>>[
    {
      'id': 575162,
      'tcName': 'Kelab Golf Negara Subang RM80',
      'receiptNo': 10000304,
      'receiptDate': '2025-08-01T06:56:22',
      'receiptAmount': 75.0,
      'paymentMethod': 'Ibg - Monthly fee for August-2024',
      'icNo': 'AUNTY1',
      'name': 'ROY',
    },
    {
      'id': 555801,
      'tcName': 'Kelab Golf Negara Subang RM80',
      'receiptNo': 10000304,
      'receiptDate': '2025-08-01T06:56:22',
      'receiptAmount': 75.0,
      'paymentMethod': 'Ibg - Monthly fee for July-2024',
      'icNo': 'AUNTY1',
      'name': 'ROY',
    },
    // A different receipt for the same payer — must NOT be grouped in.
    {
      'id': 450971,
      'receiptNo': 10000301,
      'receiptDate': '2025-08-01T06:55:55',
      'receiptAmount': 100.0,
      'paymentMethod': 'Ibg - Uniform charges',
      'icNo': 'AUNTY1',
      'name': 'ROY',
    },
  ];

  test('rowsForReceipt groups by receiptNo and payer', () {
    final group = ReceiptPdf.rowsForReceipt(receiptRows.first, receiptRows);
    expect(group.length, 2);
    expect(
        group.every((r) => r['receiptNo'].toString() == '10000304'), isTrue);
  });

  test('build produces a non-empty %PDF document carrying the data', () async {
    final group = ReceiptPdf.rowsForReceipt(receiptRows.first, receiptRows);
    final bytes = await ReceiptPdf.build(group, clubName: 'RAIG TAEKWONDO');
    expect(bytes.length, greaterThan(1000));
    // %PDF magic header.
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });

  test('build tolerates a single row with no receiptNo', () async {
    final bytes = await ReceiptPdf.build([
      {'receiptAmount': 50, 'name': 'JANE', 'paymentMethod': 'Cash - Term fee'}
    ]);
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });
}
