import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'response_utils.dart';
import 'secure_store.dart';
import 'user_session.dart';

/// Background notification polling.
///
/// Ports the Expo app's expo-background-task job. Android runs it through WorkManager
/// at a minimum requested interval of 15 minutes. Execution is OS-controlled and can be
/// delayed; force-stopped apps do not receive this work. This is a fallback for eventual
/// local alerts, not a guarantee of immediate delivery while the app is closed.
///
/// The callback runs in a HEADLESS ISOLATE: no widgets, no providers, and UserSession's
/// in-memory state does not exist. Everything it needs — the token and the member id — is
/// read back from storage by hand.
class BackgroundPoll {
  static const taskName = 'dclix-notification-poll';
  static const _uniqueName = 'dclix-notification-poll-periodic';

  /// Android's minimum for a periodic WorkManager job. Asking for less is silently
  /// rounded up, so ask for what we will actually get.
  static const interval = Duration(minutes: 15);

  static Future<void> register() async {
    if (kIsWeb) return; // no WorkManager in a browser
    try {
      await Workmanager()
          .initialize(backgroundCallbackDispatcher, isInDebugMode: false);
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        taskName,
        frequency: interval,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.linear,
      );
    } catch (e) {
      // A device that refuses to schedule (aggressive OEM battery management, or a
      // platform with no WorkManager) must not stop the app from starting. Foreground
      // polling still works; the member just loses closed-app alerts.
      debugPrint('background poll registration failed: $e');
    }
  }

  static Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
    } catch (_) {}
  }

  /// The work itself. Returns false only when it is worth retrying.
  ///
  /// Kept separate from the dispatcher so it can be reasoned about (and called) without a
  /// WorkManager around it.
  static Future<bool> runOnce() async {
    try {
      final token = await SecureStore.read(UserSession.tokenKey);
      if (token == null || token.isEmpty)
        return true; // signed out: nothing to do

      final userId = await _restoreUserId();
      if (userId == null) return true;

      ApiService.setToken(token);
      final res = await Api.profileMyNotifications();
      final rows = findRecordList(res);
      if (await SecureStore.read(UserSession.tokenKey) != token) return true;

      // Same selection logic the foreground poll uses — categories, quiet hours, the
      // volume cap and both silent-loss fixes all come along for free.
      await NotificationService.alertForNew(userId: userId, rows: rows);
      return true;
    } catch (e) {
      debugPrint('background poll failed: $e');
      return false; // let WorkManager back off and retry
    }
  }

  /// The signed-in member's id, from whatever the app last persisted.
  static Future<int?> _restoreUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(UserSession.sessionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      // The id lives under authData for a normal session; tolerate a flat shape too.
      for (final candidate in [decoded['authData'], decoded]) {
        if (candidate is Map) {
          final v =
              candidate['id'] ?? candidate['userId'] ?? candidate['studentId'];
          final id = v is int ? v : int.tryParse('${v ?? ''}');
          if (id != null && id > 0) return id;
        }
      }
    } catch (e) {
      debugPrint('background poll could not restore the session: $e');
    }
    return null;
  }
}

/// WorkManager entry point.
///
/// MUST be a top-level function annotated with @pragma('vm:entry-point'): the headless
/// launch looks it up by symbol, and tree-shaking would otherwise remove it from a release
/// build — silently, with the job then doing nothing.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != BackgroundPoll.taskName) return true;
    return BackgroundPoll.runOnce();
  });
}
