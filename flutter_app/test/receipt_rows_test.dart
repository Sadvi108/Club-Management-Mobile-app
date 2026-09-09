import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/receipt_pdf.dart';

void main() {
  group('ReceiptPdf.rowsForReceipt — full official receipt', () {
    final allRows = <Map>[
      {'receiptNo': 10000304, 'icNo': 'AUNTY1', 'name': 'ROY', 'receiptAmount': 75},
      {'receiptNo': 10000304, 'icNo': 'MUHDSYAFIQRaig', 'name': 'MUHD SYAFIQ', 'receiptAmount': 50},
      {'receiptNo': 10000304, 'icNo': 'AUNTY1', 'name': 'ROY', 'receiptAmount': 75},
      {'receiptNo': 10000339, 'icNo': 'AUNTY1', 'name': 'ROY', 'receiptAmount': 50},
    ];

    test('groups every line under the same receiptNo across all payers', () {
      final tapped = allRows.first; // a ROY row
      final group = ReceiptPdf.rowsForReceipt(tapped, allRows);
      // All three rows with receiptNo 10000304 — including the other
      // student's line — must be present (full official receipt).
      expect(group.length, 3);
      expect(
        group.map((r) => r['name']).toSet(),
        {'ROY', 'MUHD SYAFIQ'},
      );
    });

    test('excludes rows from a different receiptNo', () {
      final group = ReceiptPdf.rowsForReceipt(allRows.first, allRows);
      expect(group.any((r) => r['receiptNo'] == 10000339), isFalse);
    });

    test('no receiptNo → just the single tapped row', () {
      final row = {'icNo': 'AUNTY1', 'receiptAmount': 75};
      final group = ReceiptPdf.rowsForReceipt(row, allRows);
      expect(group, [row]);
    });
  });
}
