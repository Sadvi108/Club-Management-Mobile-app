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

class PrepayService {
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
