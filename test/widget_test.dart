// Smoke tests for app foundations. Kept dependency-free of the live
// router/network so they run green in CI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:club_management_app/theme/app_theme.dart';

void main() {
  test('Light and dark themes build', () {
    expect(AppTheme.light(), isA<ThemeData>());
    expect(AppTheme.dark(), isA<ThemeData>());
  });

  testWidgets('A themed scaffold renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: Text('D-Clix'))),
      ),
    );
    expect(find.text('D-Clix'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
