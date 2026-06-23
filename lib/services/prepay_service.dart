import 'api.dart';
import 'response_utils.dart';

/// Injectable term-payment fetcher (so tests don't hit the network).
typedef TermFetch = Future<dynamic> Function(Map<String, dynamic> body);

/// One priced future month.
class PrepayMonth {
  final int month; // 1..12
  final int year;
  final String label; // e.g. "June-2026"
  final String description;
  final num amount;
  final Map<String, dynamic> raw;
  const PrepayMonth({
    required this.month,
    required this.year,
    required this.label,
    required this.description,
    required this.amount,
    required this.raw,
  });
}

/// Result of pricing a set of months.
class PrepayQuote {
  final List<PrepayMonth> months;
  const PrepayQuote(this.months);
  num get total => months.fold<num>(0, (s, m) => s + m.amount);
}

/// One payable invoice (existing or future-term) for the prepay screen.
class PrepayInvoice {
  final int studentId;
  final String studentName;
  final String invoiceNo; // invoiceId ("0" = not yet invoiced / future term)
  final String invoiceType; // transactionType, e.g. "Monthly"
  final String period; // e.g. "August-2026"
  final num discount;
  final num amount; // dueAmount
  final int month; // 1..12
  final Map<String, dynamic> raw;
  const PrepayInvoice({
    required this.studentId,
    required this.studentName,
    required this.invoiceNo,
    required this.invoiceType,
    required this.period,
    required this.discount,
    required this.amount,
    required this.month,
    required this.raw,
  });
}

/// The collected bill across the selected students + months.
class PrepayBill {
  final List<PrepayInvoice> invoices;
  const PrepayBill(this.invoices);
  int get count => invoices.length;
  num get total => invoices.fold<num>(0, (s, i) => s + i.amount);
}

class PrepayService {
  /// Gather the payable invoices for every (student, month) combination — the
  /// term-payment endpoint returns at most one invoice per call (existing
  /// invoice with a real number, or a future-term row with invoiceNo "0"), so
  /// we loop. Empty / errored calls are skipped.
  static Future<PrepayBill> gatherInvoices({
    required List<int> studentIds,
    required int year,
    required List<int> months,
    TermFetch? fetch,
  }) async {
    final fn = fetch ?? (b) => Api.outstandingFetchTermPayments(b);
    final out = <PrepayInvoice>[];
    for (final sid in studentIds) {
      for (final m in months) {
        try {
          final resp = await fn({
            'studentIds': [sid],
            'year': year,
            'months': [m],
          });
          if (apiEnvelopeError(resp) != null) continue;
          for (final row in findRecordList(resp).whereType<Map>()) {
            final r = Map<String, dynamic>.from(row);
            final no = pickField(r, ['invoiceId', 'invoiceNo']);
            out.add(PrepayInvoice(
              studentId: (r['studentId'] is num)
                  ? (r['studentId'] as num).toInt()
                  : sid,
              studentName: pickField(r, ['studentName', 'name']),
              invoiceNo: no.isEmpty ? '0' : no,
              invoiceType: pickField(r, ['transactionType', 'invoiceType']),
              period: pickField(r, ['period', 'invoiceDescription']),
              discount: pickAmount(r, ['discountAmount', 'discount']),
              amount: pickAmount(r, ['dueAmount', 'invoiceAmount', 'amount']),
              month: m,
              raw: r,
            ));
          }
        } catch (_) {
          // skip this (student, month); keep gathering the rest
        }
      }
    }
    return PrepayBill(out);
  }

  /// Price [months] for [studentId]/[year]. Calls the term-payment endpoint
  /// once per month (the API only honors one month per request). Months that
  /// return no row (not prepayable) are skipped.
  static Future<PrepayQuote> priceMonths({
    required int studentId,
    required int year,
    required List<int> months,
    TermFetch? fetch,
  }) async {
    final fn = fetch ?? (b) => Api.outstandingFetchTermPayments(b);
    final out = <PrepayMonth>[];
    for (final m in months) {
      try {
        final resp = await fn({
          'studentIds': [studentId],
          'year': year,
          'months': [m],
        });
        if (apiEnvelopeError(resp) != null) continue;
        final rows = findRecordList(resp).whereType<Map>().toList();
        if (rows.isEmpty) continue;
        final row = Map<String, dynamic>.from(rows.first);
        out.add(PrepayMonth(
          month: m,
          year: year,
          label: pickField(row, ['period', 'invoiceDescription']),
          description: pickField(row, ['invoiceDescription', 'period']),
          amount: pickAmount(row, ['dueAmount', 'invoiceAmount', 'amount']),
          raw: row,
        ));
      } catch (_) {
        // skip a month that errored; keep pricing the rest
      }
    }
    return PrepayQuote(out);
  }
}
