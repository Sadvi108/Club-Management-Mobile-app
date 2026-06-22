import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/receipt_pdf.dart';

void main() {
  group('ReceiptPdf.amountInWords', () {
    test('whole ringgit (matches official receipt wording)', () {
      expect(ReceiptPdf.amountInWords(100), 'RINGGIT MALAYSIA ONE HUNDRED ONLY');
      expect(ReceiptPdf.amountInWords(75), 'RINGGIT MALAYSIA SEVENTY FIVE ONLY');
    });

    test('hundreds use AND before the remainder', () {
      expect(ReceiptPdf.amountInWords(150),
          'RINGGIT MALAYSIA ONE HUNDRED AND FIFTY ONLY');
      expect(ReceiptPdf.amountInWords(1250),
          'RINGGIT MALAYSIA ONE THOUSAND TWO HUNDRED AND FIFTY ONLY');
    });

    test('cents become SEN', () {
      expect(ReceiptPdf.amountInWords(100.50),
          'RINGGIT MALAYSIA ONE HUNDRED AND FIFTY SEN ONLY');
    });
  });

  group('ReceiptPdf.invoiceTypeFor', () {
    test('derives the type from the description', () {
      expect(ReceiptPdf.invoiceTypeFor('Monthly fee for November-2025'), 'Monthly');
      expect(ReceiptPdf.invoiceTypeFor('Registration fee for year 2024'),
          'Registration');
      expect(ReceiptPdf.invoiceTypeFor('Grading fee'), 'Grading');
      expect(ReceiptPdf.invoiceTypeFor('Annual renewal'), 'Annual');
    });
  });
}
