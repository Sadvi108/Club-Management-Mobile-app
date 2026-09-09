// Smoke tests for app foundations. Kept dependency-free of the live
// router/network so they run green in CI.
//
// Note: AppTheme.light()/dark() are NOT built here — GoogleFonts fires an
// async font download on theme construction, and the flutter_test
// HttpClient answers every request with HTTP 400, which surfaces as an
// unhandled async exception after the test completes. The theme tokens
// (palette, radii) are exercised instead; the full theme is covered by
// running the real app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dclix_app/theme/app_theme.dart';

void main() {
  test('Color palettes are complete and distinct', () {
    expect(AppColors.light.isDark, isFalse);
    expect(AppColors.dark.isDark, isTrue);
    expect(AppColors.light.background, isNot(AppColors.dark.background));
    expect(AppColors.light.gradient.length, 3);
    expect(AppColors.dark.gradient.length, 3);
  });

  test('Design tokens are sane', () {
    expect(Radii.sm, lessThan(Radii.xxl));
    expect(Gaps.xs, lessThan(Gaps.xxxl));
    expect(Shadows.card(AppColors.light), isNotEmpty);
    expect(Shadows.card(AppColors.dark), isNotEmpty);
  });

  testWidgets('A themed scaffold renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: AppColors.light.primary,
        ),
        home: const Scaffold(body: Center(child: Text('D-Clix'))),
      ),
    );
    expect(find.text('D-Clix'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
