import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which bucket a club notification belongs to, so a member can mute one kind and keep
/// the rest.
enum NotifCategory { payments, classes, general }

extension NotifCategoryX on NotifCategory {
  String get key => name;
  String get label => switch (this) {
        NotifCategory.payments => 'Fees & payments',
        NotifCategory.classes => 'Classes & training',
        NotifCategory.general => 'Club announcements',
      };
  String get hint => switch (this) {
        NotifCategory.payments => 'Invoices, receipts, dues reminders',
        NotifCategory.classes => 'Bookings, timetable, attendance, grading',
        NotifCategory.general => 'Events, offers, help desk replies',
      };
}

/// Device-level alert preferences.
///
/// Deliberately NOT per-user: these describe how this handset should behave, so switching
/// student or sibling must not reset them.
class NotifPrefs {
  /// App-side master switch, independent of the OS permission.
  final bool enabled;
  final bool sound;
  final bool vibrate;
  final Map<NotifCategory, bool> categories;
  final bool quietEnabled;
  final int quietStartHour;
  final int quietEndHour;

  const NotifPrefs({
    this.enabled = true,
    this.sound = true,
    this.vibrate = true,
    this.categories = const {
      NotifCategory.payments: true,
      NotifCategory.classes: true,
      NotifCategory.general: true,
    },
    this.quietEnabled = false,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
  });

  static const defaults = NotifPrefs();

  NotifPrefs copyWith({
    bool? enabled,
    bool? sound,
    bool? vibrate,
    Map<NotifCategory, bool>? categories,
    bool? quietEnabled,
    int? quietStartHour,
    int? quietEndHour,
  }) =>
      NotifPrefs(
        enabled: enabled ?? this.enabled,
        sound: sound ?? this.sound,
        vibrate: vibrate ?? this.vibrate,
        categories: categories ?? this.categories,
        quietEnabled: quietEnabled ?? this.quietEnabled,
        quietStartHour: quietStartHour ?? this.quietStartHour,
        quietEndHour: quietEndHour ?? this.quietEndHour,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'sound': sound,
        'vibrate': vibrate,
        'categories': {for (final e in categories.entries) e.key.key: e.value},
        'quietHours': {
          'enabled': quietEnabled,
          'startHour': quietStartHour,
          'endHour': quietEndHour,
        },
      };

  /// Tolerant of anything: a corrupt blob falls back to defaults rather than stranding the
  /// member with no alerts at all.
  factory NotifPrefs.fromJson(dynamic raw) {
    if (raw is! Map) return defaults;
    bool b(dynamic v, bool d) => v is bool ? v : d;
    int hour(dynamic v, int d) => (v is int && v >= 0 && v <= 23) ? v : d;

    final cats = raw['categories'];
    final qh = raw['quietHours'];
    return NotifPrefs(
      enabled: b(raw['enabled'], true),
      sound: b(raw['sound'], true),
      vibrate: b(raw['vibrate'], true),
      categories: {
        for (final c in NotifCategory.values)
          c: b(cats is Map ? cats[c.key] : null, true),
      },
      quietEnabled: b(qh is Map ? qh['enabled'] : null, false),
      quietStartHour: hour(qh is Map ? qh['startHour'] : null, 22),
      quietEndHour: hour(qh is Map ? qh['endHour'] : null, 7),
    );
  }
}

/// True when [at] falls inside the configured quiet window.
///
/// Handles the normal overnight case (22:00 -> 07:00) where start > end and the range wraps
/// midnight. start == end is an EMPTY window, never a 24-hour mute.
bool inQuietHours(NotifPrefs p, [DateTime? at]) {
  if (!p.quietEnabled) return false;
  if (p.quietStartHour == p.quietEndHour) return false;
  final h = (at ?? DateTime.now()).hour;
  return p.quietStartHour < p.quietEndHour
      ? h >= p.quietStartHour && h < p.quietEndHour
      : h >= p.quietStartHour || h < p.quietEndHour;
}

/// Master switch + category only, ignoring the clock.
///
/// This is "the member WANTS this kind of alert", as distinct from "now is a good time".
/// The poller needs them apart: a muted category is discarded for good, while a
/// quiet-hours suppression must merely be deferred.
bool isAllowed(NotifPrefs p, NotifCategory c) =>
    p.enabled && (p.categories[c] ?? true);

/// Should an alert in [c] be raised right now?
bool shouldAlert(NotifPrefs p, NotifCategory c, [DateTime? at]) =>
    isAllowed(p, c) && !inQuietHours(p, at);

// Probed against prod (student test account, 15 rows): `notificationType` is ALWAYS the
// empty string, `text` is a short subject from a fixed set ("Reminder", "Class Activity",
// "ClassReplacement"), and the only real content is `value` — written in MALAY ("Sila
// jelaskan yuran tertunggak RM85.00 anda secepat mungkin"). So the BODY has to be part of
// the match, and matching English alone would file every live fee reminder under "general".
final _paymentWords = RegExp(
    r'(fee|payment|invoice|receipt|due|outstanding|bill|paid|refund|reimburse|purchase|arrear'
    r'|yuran|tertunggak|bayar|pembayaran|resit|invois|hutang|caj|denda|rm\s*\d)',
    caseSensitive: false);
final _classWords = RegExp(
    r'(class|training|book|attend|schedul|timetable|grad|belt|exam|tournament|competit|replacement'
    r'|kelas|latihan|jadual|kehadiran|peperiksaan|ujian|pertandingan|gred|tali ?pinggang)',
    caseSensitive: false);

/// Map a notification onto a category.
///
/// Falls back to `general` — an unrecognised notification must still alert, never silently
/// vanish. Payments is tested first: a fee reminder about a class is still a fee reminder.
NotifCategory categorise({String? notificationType, String? subject, String? body}) {
  final s = '${notificationType ?? ''} ${subject ?? ''} ${body ?? ''}';
  if (_paymentWords.hasMatch(s)) return NotifCategory.payments;
  if (_classWords.hasMatch(s)) return NotifCategory.classes;
  return NotifCategory.general;
}

/// Persistence + change notification for [NotifPrefs].
class NotifPrefsStore {
  static const _key = 'dclix.notif.prefs.v1';
  static NotifPrefs? _cache;
  static final List<void Function(NotifPrefs)> _listeners = [];

  /// Last value read, without awaiting. Null until [load] has run once.
  static NotifPrefs? peek() => _cache;

  static Future<NotifPrefs> load() async {
    if (_cache != null) return _cache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      _cache = raw == null || raw.isEmpty
          ? NotifPrefs.defaults
          : NotifPrefs.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('NotifPrefs load failed: $e');
      _cache = NotifPrefs.defaults;
    }
    return _cache!;
  }

  static Future<NotifPrefs> save(NotifPrefs next) async {
    _cache = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(next.toJson()));
    } catch (e) {
      // Keep the in-memory value so the session still honours the change.
      debugPrint('NotifPrefs save failed: $e');
    }
    for (final l in List.of(_listeners)) {
      l(next);
    }
    return next;
  }

  static void Function() subscribe(void Function(NotifPrefs) fn) {
    _listeners.add(fn);
    return () => _listeners.remove(fn);
  }

  @visibleForTesting
  static void resetForTest() {
    _cache = null;
    _listeners.clear();
  }
}
