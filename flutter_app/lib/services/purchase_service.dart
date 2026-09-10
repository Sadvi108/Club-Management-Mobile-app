import 'api.dart';
import 'boost_payment.dart';
import 'response_utils.dart';

/// Buying gear from the academy catalogue.
///
/// There is NO "create purchase request" route in the mobile API. A purchase is raised by
/// PAYING for it: the lines ride in `purchaseItems` on `/Bcpg/PayInvoices`, and the server
/// creates the request as a side effect of the payment landing. That is why this file has
/// no `submit()` — see [BoostPayment.start].
class PurchaseProduct {
  final int productId;
  final String name;
  final String category;
  final String code;
  final double price;
  final bool isRegistration;

  const PurchaseProduct({
    required this.productId,
    required this.name,
    this.category = '',
    this.code = '',
    this.price = 0,
    this.isRegistration = false,
  });

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}'.trim()) ?? 0;
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}'.trim()) ?? 0;
  }

  static String _str(dynamic v) => v == null ? '' : '$v'.trim();

  /// Tolerant of the server's casing drift; a row with no usable id is rejected by
  /// [parseProducts] rather than rendered as an unbuyable tile.
  static PurchaseProduct? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = _int(m['productId'] ?? m['ProductId'] ?? m['id']);
    if (id <= 0) return null;
    return PurchaseProduct(
      productId: id,
      name: _str(m['name'] ?? m['Name'] ?? m['productName']),
      category: _str(m['category'] ?? m['Category'] ?? m['categoryName']),
      code: _str(m['code'] ?? m['Code']),
      price: _num(m['price'] ?? m['Price']),
      isRegistration: m['isRegistration'] == true,
    );
  }
}

List<PurchaseProduct> parseProducts(dynamic res) {
  final data = unwrapData(res);
  if (data is! List) return const [];
  return data
      .map(PurchaseProduct.fromJson)
      .whereType<PurchaseProduct>()
      .toList(growable: false);
}

/// Build one `PurchaseRequestLineViewModel`.
///
/// `id` and `purchaseRequestId` are 0 because the SERVER creates both. `qty` is truncated
/// and floored at zero: a negative line would bill a negative total, and the gateway does
/// not reject it.
PurchaseItem buildPurchaseLine(PurchaseProduct product, int qty) {
  final n = qty < 0 ? 0 : qty;
  final price = product.price;
  return PurchaseItem(
    productId: product.productId,
    qty: n,
    price: price,
    unitTax: 0,
    totalTax: 0,
    // Rounded to sen. Floating point makes 3 × 33.33 into 99.98999999999999, and the
    // gateway echoes whatever it is sent straight onto the customer's bill.
    totalAmount: double.parse((price * n).toStringAsFixed(2)),
  );
}

/// Total for a basket, in ringgit.
double basketTotal(Map<int, int> quantities, List<PurchaseProduct> catalogue) {
  var sum = 0.0;
  for (final p in catalogue) {
    final n = quantities[p.productId] ?? 0;
    if (n > 0) sum += p.price * n;
  }
  return double.parse(sum.toStringAsFixed(2));
}

/// The lines to send, newest-selection order irrelevant — the server keys on productId.
List<PurchaseItem> basketLines(
    Map<int, int> quantities, List<PurchaseProduct> catalogue) {
  final out = <PurchaseItem>[];
  for (final p in catalogue) {
    final n = quantities[p.productId] ?? 0;
    if (n > 0) out.add(buildPurchaseLine(p, n));
  }
  return out;
}

class PurchaseService {
  static Future<List<PurchaseProduct>> fetchProducts() async =>
      parseProducts(await Api.purchaseRequestFetchProducts());

  /// Past purchase requests. `/Reports/PurchaseRequests` is scoped to the caller's token.
  static Future<List<Map<String, dynamic>>> fetchRequests() async {
    final data = unwrapData(await Api.reportsPurchaseRequests());
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList(growable: false);
  }

  /// Row count, used as the before/after baseline that proves a payment created a request.
  static Future<int> countRequests() async => (await fetchRequests()).length;
}

/// One purchase row, flattened out of whatever column names the report returns.
class PurchaseRow {
  final String title;
  final String status;
  final DateTime? date;
  final double? amount;

  const PurchaseRow({
    required this.title,
    this.status = '',
    this.date,
    this.amount,
  });

  static dynamic _first(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && '$v'.trim().isNotEmpty) return v;
    }
    return null;
  }

  factory PurchaseRow.fromJson(Map<String, dynamic> m) {
    final rawDate = _first(m, ['requestDate', 'date', 'invoiceDate', 'createdDate']);
    final rawAmt = _first(m, ['amount', 'totalAmount', 'dueAmount', 'price']);
    return PurchaseRow(
      title: '${_first(m, [
            'itemName',
            'productName',
            'name',
            'description',
            'invoiceDescription'
          ]) ?? 'Purchase'}',
      status: '${_first(m, ['status', 'paymentStatus', 'requestStatus']) ?? ''}',
      date: rawDate == null ? null : DateTime.tryParse('$rawDate'),
      amount: rawAmt == null
          ? null
          : (rawAmt is num
              ? rawAmt.toDouble()
              : double.tryParse('$rawAmt'.replaceAll(RegExp(r'[^0-9.\-]'), ''))),
    );
  }
}
