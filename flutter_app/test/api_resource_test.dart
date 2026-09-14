import 'dart:async';
import 'package:dclix_app/widgets/use_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deferred report stays idle until requested, then completes', () async {
    var calls = 0;
    final response = Completer<List<String>>();
    final resource = ApiResource(() {
      calls++;
      return response.future;
    }, autoRun: false);
    addTearDown(resource.dispose);
    expect(resource.loading, isFalse);
    expect(calls, 0);
    final loading = resource.reload();
    expect(resource.loading, isTrue);
    expect(calls, 1);
    response.complete(['Sample student']);
    await loading;
    expect(resource.loading, isFalse);
    expect(resource.data, ['Sample student']);
  });
}
