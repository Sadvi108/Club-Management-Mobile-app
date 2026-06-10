import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Local receipt-PDF generation.
///
/// The server endpoint `/Utilities/ReceiptAsPDF/{clubId}/{paymentId}/{invoiceId}`
/// returns a blank template (only column headers, no rows) for the IDs the app
/// can supply — `/Reports/Receipts` exposes a per-line `id` and a `receiptNo`,
/// neither of which the PDF generator resolves to a payment, so every receipt
/// downloaded "empty". The receipt rows themselves already carry every value a
/// receipt needs (number, date, payer, amount, description), so we render the
/// document client-side instead of relying on the broken endpoint.
class ReceiptPdf {
  /// Pick the first non-empty value among [keys] in [m].
  static String _pick(Map m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return fallback;
  }

  /// Parse any numeric / "RM 50.00" style value into a double.
  static double _amount(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^\d.\-]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  /// Trim an ISO date string to `yyyy-MM-dd HH:mm` (or the date alone).
  static String _date(String raw) {
    if (raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${d.year}-${two(d.month)}-${two(d.day)}';
    if (d.hour == 0 && d.minute == 0 && d.second == 0) return date;
    return '$date ${two(d.hour)}:${two(d.minute)}';
  }

  /// Split a combined "Mode - Description" payment method into its two parts.
  /// Falls back to the whole string as the description when there is no
  /// separator.
  static List<String> _modeAndDesc(String method) {
    final idx = method.indexOf(' - ');
    if (idx < 0) return ['', method];
    return [method.substring(0, idx).trim(), method.substring(idx + 3).trim()];
  }

  /// All rows that belong to the same receipt as [row] (same receiptNo and
  /// payer). When no receiptNo is present, just the single row.
  static List<Map> rowsForReceipt(Map row, List<dynamic> allRows) {
    final no = _pick(row, ['receiptNo', 'receiptNumber']);
    final ic = _pick(row, ['icNo']);
    if (no.isEmpty) return [row];
    return allRows
        .whereType<Map>()
        .where((r) =>
            _pick(r, ['receiptNo', 'receiptNumber']) == no &&
            (ic.isEmpty || _pick(r, ['icNo']) == ic))
        .toList();
  }

  /// Build the receipt PDF bytes for a group of line [rows] (all sharing one
  /// receiptNo). [clubName] is shown as the issuer header.
  static Future<Uint8List> build(List<Map> rows, {String clubName = ''}) async {
    final doc = pw.Document();
    final first = rows.isNotEmpty ? rows.first : const {};
    final receiptNo = _pick(first, ['receiptNo', 'receiptNumber'], '-');
    final receiptDate = _date(_pick(first, ['receiptDate', 'date', 'paymentDate']));
    final payer = _pick(first, ['name', 'studentName'], '-');
    final icNo = _pick(first, ['icNo']);
    final centre = _pick(first, ['tcName', 'centerName', 'trainingCenter']);

    double total = 0;
    final lineRows = <pw.TableRow>[];
    lineRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
        children: [
          _cell('#', bold: true),
          _cell('Description', bold: true),
          _cell('Mode', bold: true),
          _cell('Amount (RM)', bold: true, align: pw.TextAlign.right),
        ],
      ),
    );
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final amt = _amount(r['receiptAmount'] ?? r['amount'] ?? r['value']);
      total += amt;
      final md = _modeAndDesc(_pick(r, ['paymentMethod', 'description'], ''));
      lineRows.add(pw.TableRow(children: [
        _cell('${i + 1}'),
        _cell(md[1].isEmpty ? '-' : md[1]),
        _cell(md[0]),
        _cell(amt.toStringAsFixed(2), align: pw.TextAlign.right),
      ]));
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('OFFICIAL RECEIPT',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  if (clubName.isNotEmpty)
                    pw.Text(clubName,
                        style: const pw.TextStyle(
                            fontSize: 11, color: PdfColors.grey700)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Receipt No. $receiptNo',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: $receiptDate',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey700)),
                ]),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text('Paid By', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text(icNo.isEmpty ? payer : '$payer  ($icNo)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (centre.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(centre, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(28),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(1.4),
                3: pw.FixedColumnWidth(80),
              },
              children: lineRows,
            ),
            pw.SizedBox(height: 10),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Text('Total:  ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text('RM ${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ]),
            pw.SizedBox(height: 28),
            pw.Text(
                'THIS IS A COMPUTER GENERATED DOCUMENT. NO SIGNATURE IS REQUIRED.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _cell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }
}
