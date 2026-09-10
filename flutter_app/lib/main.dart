import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'router/app_router.dart';
import 'services/user_session.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<UserSession>.value(value: UserSession.instance),
      ],
      child: const DClixApp(),
    ),
  );
}

class DClixApp extends StatelessWidget {
  const DClixApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'D-Clix',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.mode,
      routerConfig: appRouter,
      scaffoldMessengerKey: UserSession.scaffoldMessengerKey,
      // Allow drag-to-scroll from every pointer (touch, mouse, trackpad,
      // stylus). Keeps scrolling smooth on phones and makes the web/desktop
      // preview behave like a real device instead of needing a wheel.
      scrollBehavior: const _AppScrollBehavior(),
      // Clamp the OS text scale to a range the layouts are designed for.
      // Below 0.85 text becomes unreadable; above ~1.3 fixed-height cards
      // overflow. This single guard keeps every screen responsive to a
      // user's accessibility font setting without per-screen rework.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.30,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Enables drag scrolling from all pointer kinds (the Material default omits
/// mouse + trackpad, which makes web/desktop scrolling feel broken).
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
