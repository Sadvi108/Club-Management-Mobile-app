// Standalone routes must provide a Material ancestor.
//
// AppHeader's back button is an AppIconButton, which is an InkWell, and InkWell asserts
// "No Material widget found" unless something above it provides Material. Scaffold does.
// A screen that returns a bare Container gets away with it ONLY while it is rendered inside
// the tab shell, which has its own Scaffold — a standalone route has nothing above it but
// the Navigator.
//
// Driven through the REAL router, not a hand-built wrapper, so this reflects what a member
// actually hits when they tap the tile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:dclix_app/screens/book_class_screen.dart';
import 'package:dclix_app/screens/chat_screen.dart';
import 'package:dclix_app/screens/notification_settings_screen.dart';
import 'package:dclix_app/services/user_session.dart';
import 'package:dclix_app/theme/theme_provider.dart';

/// Render [screen] the way go_router does for a standalone route: as a page inside a
/// Navigator, with no shell and no Scaffold of its own.
Future<List<String>> renderStandalone(WidgetTester tester, Widget screen) async {
  // Collect via FlutterError.onError, not takeException(): a build error is reported to
  // the error handler and swapped for an ErrorWidget, and takeException() returned null
  // while "No Material widget found" was printing to the console — a test that passed
  // over a screen that was visibly broken.
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  addTearDown(() => FlutterError.onError = previous);

  final router = GoRouter(
    initialLocation: '/x',
    routes: [GoRoute(path: '/x', builder: (_, __) => screen)],
  );
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<UserSession>.value(value: UserSession.instance),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return errors;
}

void main() {
  for (final entry in {
    '/book-class': const BookClassScreen(),
    '/chat': const ChatScreen(),
    '/notification-settings': const NotificationSettingsScreen(),
  }.entries) {
    testWidgets('${entry.key} renders without a Material assertion', (tester) async {
      final errors = await renderStandalone(tester, entry.value);
      expect(errors.join(' | '), isNot(contains('No Material widget found')),
          reason: '${entry.key} is a standalone route with no Scaffold, so InkWell '
              '(AppHeader back button) has no Material ancestor');
    });
  }
}
