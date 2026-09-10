import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/api.dart';

void main() {
  group('Api.termPaymentQuery', () {
    test('serializes repeated studentIds/months and scalar year', () {
      final q = Api.termPaymentQuery([46679], 2026, [6, 7]);
      expect(q, 'studentIds=46679&year=2026&months=6&months=7');
    });

    test('handles multiple students', () {
      final q = Api.termPaymentQuery([1, 2], 2026, [1]);
      expect(q, 'studentIds=1&studentIds=2&year=2026&months=1');
    });
  });
}
