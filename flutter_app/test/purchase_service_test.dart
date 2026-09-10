// Purchase basket maths and catalogue parsing.
//
// These numbers end up on a customer's bill through a payment gateway that echoes whatever
// it is sent, so the arithmetic is worth pinning down.
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/purchase_service.dart';

const _gi = PurchaseProduct(productId: 1, name: 'Gi', category: 'Uniform', price: 120.0);
const _belt = PurchaseProduct(productId: 2, name: 'Belt', category: 'Uniform', price: 33.33);

void main() {
  group('parseProducts', () {
    test('reads the envelope and the server casing', () {
      final rows = parseProducts({
        'status': true,
        'data': [
          {'productId': 7, 'name': 'Gi', 'category': 'Uniform', 'price': 120},
          {'ProductId': 8, 'Name': 'Belt', 'Price': '33.50'},
        ]
      });
      expect(rows, hasLength(2));
      expect(rows[0].name, 'Gi');
      expect(rows[0].price, 120.0);
      expect(rows[1].productId, 8);
      expect(rows[1].price, 33.5, reason: 'a price sent as a string still has to bill');
    });

    test('rows with no product id are dropped, not shown as unbuyable tiles', () {
      final rows = parseProducts({
        'data': [
          {'name': 'Ghost'},
          {'productId': 0, 'name': 'Zero'},
          {'productId': 3, 'name': 'Real'},
        ]
      });
      expect(rows.map((r) => r.name), ['Real']);
    });

    test('a non-list payload yields an empty catalogue rather than throwing', () {
      expect(parseProducts(null), isEmpty);
      expect(parseProducts({'data': null}), isEmpty);
      expect(parseProducts({'data': 'nope'}), isEmpty);
    });
  });

  group('buildPurchaseLine', () {
    test('the server owns both ids', () {
      final line = buildPurchaseLine(_gi, 2);
      expect(line.id, 0);
      expect(line.purchaseRequestId, 0);
      expect(line.productId, 1);
      expect(line.qty, 2);
      expect(line.totalAmount, 240.0);
    });

    test('totals are rounded to sen', () {
      // 3 * 33.33 is 99.98999999999999 in binary floating point. Sent raw, that is what
      // the gateway bills and what prints on the receipt.
      final line = buildPurchaseLine(_belt, 3);
      expect(line.totalAmount, 99.99);
    });

    test('a negative quantity cannot bill a negative total', () {
      final line = buildPurchaseLine(_gi, -5);
      expect(line.qty, 0);
      expect(line.totalAmount, 0.0);
    });

    test('the wire field names are the server\'s: qty and price', () {
      final json = buildPurchaseLine(_gi, 2).toJson();
      expect(json.keys, containsAll(['qty', 'price', 'productId', 'totalAmount']));
      expect(json.containsKey('quantity'), isFalse);
      expect(json.containsKey('amount'), isFalse);
    });
  });

  group('basket', () {
    const catalogue = [_gi, _belt];

    test('only selected lines are sent', () {
      final lines = basketLines({1: 2, 2: 0}, catalogue);
      expect(lines, hasLength(1));
      expect(lines.single.productId, 1);
    });

    test('an empty basket sends nothing and totals zero', () {
      expect(basketLines({}, catalogue), isEmpty);
      expect(basketTotal({}, catalogue), 0.0);
      expect(basketTotal({1: 0}, catalogue), 0.0);
    });

    test('the total is rounded once, at the end', () {
      expect(basketTotal({1: 1, 2: 3}, catalogue), 219.99);
    });

    test('a quantity for an unknown product is ignored', () {
      // The catalogue can change between load and tap; a stale id must not bill.
      expect(basketTotal({999: 4}, catalogue), 0.0);
      expect(basketLines({999: 4}, catalogue), isEmpty);
    });
  });

  group('PurchaseRow', () {
    test('picks whichever column the report actually used', () {
      final r = PurchaseRow.fromJson({
        'productName': 'Sparring gloves',
        'invoiceDate': '2026-03-14T00:00:00',
        'paymentStatus': 'Paid',
        'totalAmount': 88.5,
      });
      expect(r.title, 'Sparring gloves');
      expect(r.status, 'Paid');
      expect(r.date?.year, 2026);
      expect(r.amount, 88.5);
    });

    test('a row with nothing usable still renders as a purchase', () {
      final r = PurchaseRow.fromJson({});
      expect(r.title, 'Purchase');
      expect(r.date, isNull);
      expect(r.amount, isNull);
    });

    test('an amount arriving as "RM 88.50" is still a number', () {
      expect(PurchaseRow.fromJson({'amount': 'RM 88.50'}).amount, 88.5);
    });

    test('an empty string is not treated as a value', () {
      final r = PurchaseRow.fromJson({'itemName': '', 'productName': 'Real name'});
      expect(r.title, 'Real name');
    });
  });
}
