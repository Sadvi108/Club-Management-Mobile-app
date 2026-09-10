import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Local receipt-PDF generation, laid out to match the club's official
/// server receipt: a single document per `receiptNo` with columns
/// `# | Student Name | Invoice Type | Description | Amount`, an amount-in-words
/// line, the total, and the payment mode at the foot.
///
/// The server endpoint `/Utilities/ReceiptAsPDF` returns a blank template for
/// the ids the app can supply, so the document is rendered client-side from the
/// `/Reports/Receipts` rows (number, date, payer, amount, paymentMethod).
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

  /// Format a date as `dd-MM-yyyy` (matches the official receipt).
  static String _dateDMY(String raw) {
    if (raw.isEmpty) return '';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year}';
  }

  /// Split a combined "Mode - Description" payment method into its two parts.
  /// Falls back to the whole string as the description when there is no
  /// separator.
  static List<String> _modeAndDesc(String method) {
    final idx = method.indexOf(' - ');
    if (idx < 0) return ['', method];
    return [method.substring(0, idx).trim(), method.substring(idx + 3).trim()];
  }

  /// All line items that belong to the same receipt as [row] — every row
  /// sharing its receiptNo, across all payers. A server receiptNo can cover a
  /// batch payment for several students, and the official receipt is the whole
  /// document, so it must NOT be scoped to one payer. When no receiptNo is
  /// present, just the single row.
  static List<Map> rowsForReceipt(Map row, List<dynamic> allRows) {
    final no = _pick(row, ['receiptNo', 'receiptNumber']);
    if (no.isEmpty) return [row];
    return allRows
        .whereType<Map>()
        .where((r) => _pick(r, ['receiptNo', 'receiptNumber']) == no)
        .toList();
  }

  // ── Amount → words (Malaysian ringgit) ────────────────────────────────────
  static const _ones = [
    '', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE',
    'TEN', 'ELEVEN', 'TWELVE', 'THIRTEEN', 'FOURTEEN', 'FIFTEEN', 'SIXTEEN',
    'SEVENTEEN', 'EIGHTEEN', 'NINETEEN',
  ];
  static const _tens = [
    '', '', 'TWENTY', 'THIRTY', 'FORTY', 'FIFTY', 'SIXTY', 'SEVENTY', 'EIGHTY',
    'NINETY',
  ];

  static String _under1000(int n) {
    final b = StringBuffer();
    if (n >= 100) {
      b.write(_ones[n ~/ 100]);
      b.write(' HUNDRED');
      n %= 100;
      if (n > 0) b.write(' AND ');
    }
    if (n >= 20) {
      b.write(_tens[n ~/ 10]);
      n %= 10;
      if (n > 0) b.write(' ');
    }
    if (n > 0 && n < 20) b.write(_ones[n]);
    return b.toString();
  }

  static String _wordsFor(int n) {
    if (n == 0) return 'ZERO';
    final parts = <String>[];
    final million = n ~/ 1000000;
    n %= 1000000;
    final thousand = n ~/ 1000;
    n %= 1000;
    if (million > 0) parts.add('${_under1000(million)} MILLION');
    if (thousand > 0) parts.add('${_under1000(thousand)} THOUSAND');
    if (n > 0) parts.add(_under1000(n));
    return parts.join(' ');
  }

  /// "RINGGIT MALAYSIA ONE HUNDRED AND FIFTY SEN ONLY" — the official wording.
  static String amountInWords(num amount) {
    final ringgit = amount.floor();
    final sen = ((amount - ringgit) * 100).round();
    final buf = StringBuffer('RINGGIT MALAYSIA ');
    buf.write(_wordsFor(ringgit));
    if (sen > 0) {
      buf.write(' AND ');
      buf.write(_wordsFor(sen));
      buf.write(' SEN');
    }
    buf.write(' ONLY');
    return buf.toString();
  }

  /// Invoice "type" column — the server receipt shows e.g. "Monthly". Derive it
  /// from the line description since `/Reports/Receipts` doesn't return a type.
  static String invoiceTypeFor(String description) {
    final d = description.toLowerCase();
    if (d.contains('monthly')) return 'Monthly';
    if (d.contains('registration')) return 'Registration';
    if (d.contains('grading')) return 'Grading';
    if (d.contains('annual')) return 'Annual';
    if (d.contains('tournament')) return 'Tournament';
    if (d.contains('uniform') || d.contains('material') || d.contains('belt')) {
      return 'Material';
    }
    final first = description.trim().split(RegExp(r'\s+')).first;
    if (first.isEmpty) return '';
    return first[0].toUpperCase() + first.substring(1).toLowerCase();
  }

  /// Best-effort download of the club logo (PNG/JPG) for the header. Returns
  /// null on any failure so the receipt still renders without it.
  static Future<Uint8List?> _fetchLogo(String? url) async {
    if (url == null || url.isEmpty || !url.startsWith('http')) return null;
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200 && r.bodyBytes.length > 8) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  /// Build the receipt PDF bytes for a group of line [rows] (all sharing one
  /// receiptNo). [clubName] is shown as the issuer header; [logoUrl] (e.g. the
  /// club logo) is embedded top-left when reachable.
  static Future<Uint8List> build(List<Map> rows,
      {String clubName = '', String? logoUrl}) async {
    final doc = pw.Document();
    final logoBytes = await _fetchLogo(logoUrl);
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    final first = rows.isNotEmpty ? rows.first : const {};
    final receiptNo = _pick(first, ['receiptNo', 'receiptNumber'], '-');
    final receiptDate =
        _dateDMY(_pick(first, ['receiptDate', 'date', 'paymentDate']));
    final payer = _pick(first, ['name', 'studentName'], '-');
    // Mode is per-receipt (shown once at the foot), e.g. "Contra"/"Cash".
    final mode = _modeAndDesc(_pick(first, ['paymentMethod', 'description'], ''))[0];

    double total = 0;
    final lineRows = <pw.TableRow>[];
    lineRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
        children: [
          _cell('#', bold: true),
          _cell('Student Name', bold: true),
          _cell('Invoice Type', bold: true),
          _cell('Description', bold: true),
          _cell('Amount (RM)', bold: true, align: pw.TextAlign.right),
        ],
      ),
    );
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final amt = _amount(r['receiptAmount'] ?? r['amount'] ?? r['value']);
      total += amt;
      final md = _modeAndDesc(_pick(r, ['paymentMethod', 'description'], ''));
      final desc = md[1].isEmpty ? '-' : md[1];
      final student = _pick(r, ['name', 'studentName'], payer);
      final type = _pick(r, ['transactionType', 'invoiceType'],
          invoiceTypeFor(desc));
      lineRows.add(pw.TableRow(children: [
        _cell('${i + 1}'),
        _cell(student),
        _cell(type),
        _cell(desc),
        _cell(amt.toStringAsFixed(2), align: pw.TextAlign.right),
      ]));
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header: left = title + logo + club name; right = receipt
            // no / date / paid-by (matches the official receipt layout).
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('OFFICIAL RECEIPT',
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (logo != null) ...[
                            pw.Container(
                                width: 36, height: 36, child: pw.Image(logo)),
                            pw.SizedBox(width: 8),
                          ],
                          if (clubName.isNotEmpty)
                            pw.Expanded(
                              child: pw.Text(clubName,
                                  style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Receipt No.',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
                  pw.Text(receiptNo,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Receipt Date',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
                  pw.Text(receiptDate,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 4),
                  pw.Text('Paid By',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
                  pw.Text(payer,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ]),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(1.4),
                3: pw.FlexColumnWidth(3),
                4: pw.FixedColumnWidth(70),
              },
              children: lineRows,
            ),
            pw.SizedBox(height: 12),
            // Amount in words (left) + total (right).
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(amountInWords(total),
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(width: 12),
                pw.Text(total.toStringAsFixed(2),
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            if (mode.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Payment Mode :  $mode',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
            pw.SizedBox(height: 24),
            pw.Text(
                '(THIS IS A COMPUTER GENERATED DOCUMENT. NO SIGNATURE IS REQUIRED.)',
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
