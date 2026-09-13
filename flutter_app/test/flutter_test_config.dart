import 'dart:async';
import 'package:dclix_app/services/live_refresh.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Ordinary render tests do not advance a live clock. Dedicated live_refresh_test
  // cases enable polling and verify it with the fake clock, then dispose the screen.
  LiveRefresh.enabled = false;
  await testMain();
}
