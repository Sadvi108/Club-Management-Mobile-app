import 'package:dclix_app/screens/user_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:dclix_app/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'search opens an instructor feature and its full screenshot offline',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const UserGuideScreen()));
    await tester.tap(find.text('All features'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Instructor settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instructor settings and branch'));
    await tester.pumpAndSettle();
    expect(find.text('Instructor settings and branch'), findsOneWidget);
    await tester.ensureVisible(find.text('View full screen • Example data'));
    await tester.tap(find.text('View full screen • Example data'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Close screen preview'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('View full screen • Example data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contents handles a search with no results on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const UserGuideScreen()));
    await tester.tap(find.text('All features'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'no-such-feature');
    await tester.pumpAndSettle();
    expect(
        find.text('No matching features. Try another search.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
