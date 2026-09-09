import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_diff.dart';
import 'notification_prefs.dart';

/// OS notifications for club messages.
///
/// The backend has NO push-token endpoint (confirmed against the live Swagger: 73 routes,
/// none of them device registration), so server-initiated FCM/APNs is impossible. The app
/// polls and raises LOCAL notifications instead, which the OS renders exactly like a remote
/// push — tray entry, heads-up banner and sound included.
///
/// Sound, per platform:
///   Android 8+  the CHANNEL owns the sound and vibration; content-level settings are
///               ignored. A channel's sound is FROZEN at creation, so loudness is baked
///               into the channel id and we switch channels rather than mutate one.
///   iOS         the notification names the bundled dclix_alert.wav.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Bundled by Android as res/raw/dclix_alert.wav and by iOS from the app bundle.
  static const _soundName = 'dclix_alert';

  static const _lastSeenKey = 'dclix.notif.lastSeen.v1';

  /// Tapping a notification should open the conversation list.
  static void Function(String? payload)? onTap;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
    _ready = true;
  }

  /// Ask for the OS permission. Android 13+ needs POST_NOTIFICATIONS at runtime.
  static Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
    } catch (e) {
      debugPrint('notification permission request failed: $e');
    }
    return false;
  }

  static Future<bool> hasPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.areNotificationsEnabled() ?? false;
    } catch (_) {}
    return true; // iOS/desktop: assume granted unless the OS says otherwise
  }

  // ── Channels ───────────────────────────────────────────────────────────────
  // Loudness is part of the id because Android freezes a channel's sound and vibration at
  // creation and ignores every later edit. Channels are created lazily, so a member who
  // never opens the settings screen sees three channels rather than nine.
  static final _created = <String>{};

  static String _channelId(NotifCategory c, String loudness) =>
      'dclix-${c.key}-$loudness-v1';

  static String _loudnessFor(NotifPrefs p) =>
      p.sound ? 'alert' : (p.vibrate ? 'vibrate' : 'quiet');

  static Future<AndroidNotificationDetails> _android(
      NotifCategory c, NotifPrefs p) async {
    final loudness = _loudnessFor(p);
    final id = _channelId(c, loudness);
    final suffix = switch (loudness) {
      'vibrate' => ' (vibrate only)',
      'quiet' => ' (silent)',
      _ => '',
    };

    if (!_created.contains(id)) {
      try {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(AndroidNotificationChannel(
          id,
          '${c.label}$suffix',
          groupId: 'dclix-notifications',
          // MAX is what earns a heads-up banner over whatever the member is doing.
          importance: loudness == 'quiet' ? Importance.defaultImportance : Importance.max,
          playSound: loudness == 'alert',
          sound: loudness == 'alert'
              ? const RawResourceAndroidNotificationSound(_soundName)
              : null,
          enableVibration: loudness != 'quiet',
          enableLights: true,
          ledColor: const Color(0xFFF97316),
        ));
        _created.add(id);
      } catch (e) {
        // Posting to a channel that failed to create would be silently dropped by Android,
        // so fall through and let the plugin use its default channel instead.
        debugPrint('channel create failed: $e');
      }
    }

    return AndroidNotificationDetails(
      id,
      '${c.label}$suffix',
      channelShowBadge: true,
      importance: loudness == 'quiet' ? Importance.defaultImportance : Importance.max,
      priority: loudness == 'quiet' ? Priority.defaultPriority : Priority.high,
      playSound: loudness == 'alert',
      sound: loudness == 'alert'
          ? const RawResourceAndroidNotificationSound(_soundName)
          : null,
      enableVibration: loudness != 'quiet',
      styleInformation: const BigTextStyleInformation(''),
    );
  }

  /// Raise one notification. Returns false when preferences or permission suppressed it.
  static Future<bool> present({
    required String title,
    required String body,
    NotifCategory category = NotifCategory.general,
    int? id,
    bool force = false,
  }) async {
    await init();
    final p = await NotifPrefsStore.load();

    if (!p.enabled) return false;
    if (!force && !shouldAlert(p, category)) return false;

    try {
      final details = NotificationDetails(
        android: await _android(category, p),
        iOS: DarwinNotificationDetails(
          presentSound: p.sound,
          sound: p.sound ? '$_soundName.wav' : null,
        ),
      );
      await _plugin.show(
        id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: 'chat',
      );
      return true;
    } catch (e) {
      debugPrint('present notification failed: $e');
      return false;
    }
  }

  /// Fire a sample so the member can hear exactly what an incoming alert does.
  static Future<bool> sendTestAlert() => present(
        title: 'D-CLIX test notification',
        body: 'This is how your alerts will look and sound.',
        force: true,
      );

  // ── Poll → alert ───────────────────────────────────────────────────────────

  static Future<int?> _lastSeen(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt('$_lastSeenKey.$userId');
      return v;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _setLastSeen(int userId, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_lastSeenKey.$userId', value);
    } catch (_) {}
  }

  /// Raise alerts for anything newer than the high-water mark for [userId].
  ///
  /// Selection is [planAlerts], which is unit-tested; this only does the I/O.
  static Future<void> alertForNew({
    required int userId,
    required List<dynamic> rows,
  }) async {
    if (rows.isEmpty) return;
    final prefs = await NotifPrefsStore.load();
    final plan = planAlerts(
      rows: rows,
      lastSeen: await _lastSeen(userId),
      prefs: prefs,
    );

    var presented = 0;
    for (final row in plan.show) {
      final ok = await present(
        title: titleOf(row),
        body: bodyOf(row),
        category: categoryOf(row),
        id: (row['id'] is int) ? row['id'] as int : null,
      );
      if (ok) presented++;
    }

    // Summarise only what the volume cap dropped, and only if something got through.
    // Counting rows a muted category already filtered would leak the very alerts the
    // member turned off.
    if (plan.capped > 0 && presented > 0) {
      await present(
        title: 'Club notifications',
        body: '${plan.capped} more new notification${plan.capped > 1 ? 's' : ''}',
      );
    }

    // Quiet hours hold the mark back so the batch alerts once the window ends.
    if (!plan.deferred && plan.newLastSeen != null) {
      await _setLastSeen(userId, plan.newLastSeen!);
    }
  }

  static Future<void> clearAll() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
