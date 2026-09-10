import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Auto Pay.
///
/// WHAT THIS IS NOT: a direct debit or a card-on-file mandate. Club.Api exposes 73 routes
/// (probed on UAT 2026-09-10) and NONE of them create, hold or execute a recurring payment
/// authority — no mandate, no schedule, no standing instruction, no stored card. There is
/// no server that could charge a member on a timer even if the app asked it to.
///
/// WHAT THIS IS: a monthly reminder plus one-tap advance payment, built entirely on routes
/// that exist. On the chosen day the app raises a local notification; tapping it opens the
/// term-payment flow with the months already selected, and the member confirms. The money
/// only ever moves because a person tapped Pay.
///
/// The screen says this in plain words. Calling it "automatic" when a member still has to
/// tap would have them stop watching their fees and fall into arrears — the exact failure
/// the Expo shell avoided by disclosing itself as a preview.
class AutoPayPrefs {
  final bool enabled;

  /// Day of the month to remind on. Capped at 28 so the reminder cannot fall into a month
  /// that has no such day — a "31st" reminder would silently skip February, April, June,
  /// September and November.
  final int dayOfMonth;

  /// How many months ahead to pre-settle in one go (1-6).
  final int monthsAhead;

  /// Accounts to pay for. Empty means "the signed-in student only".
  final List<int> payeeIds;

  /// Epoch millis of the last reminder the app actually raised. Null until the first one.
  final int? lastRemindedMs;

  const AutoPayPrefs({
    this.enabled = false,
    this.dayOfMonth = 1,
    this.monthsAhead = 1,
    this.payeeIds = const [],
    this.lastRemindedMs,
  });

  static const defaults = AutoPayPrefs();

  static int _clampDay(dynamic v) {
    final n = v is int ? v : int.tryParse('${v ?? ''}') ?? 1;
    if (n < 1) return 1;
    if (n > 28) return 28;
    return n;
  }

  static int _clampMonths(dynamic v) {
    final n = v is int ? v : int.tryParse('${v ?? ''}') ?? 1;
    if (n < 1) return 1;
    if (n > 6) return 6;
    return n;
  }

  AutoPayPrefs copyWith({
    bool? enabled,
    int? dayOfMonth,
    int? monthsAhead,
    List<int>? payeeIds,
    int? lastRemindedMs,
  }) =>
      AutoPayPrefs(
        enabled: enabled ?? this.enabled,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        monthsAhead: monthsAhead ?? this.monthsAhead,
        payeeIds: payeeIds ?? this.payeeIds,
        lastRemindedMs: lastRemindedMs ?? this.lastRemindedMs,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'dayOfMonth': dayOfMonth,
        'monthsAhead': monthsAhead,
        'payeeIds': payeeIds,
        'lastRemindedMs': lastRemindedMs,
      };

  /// Tolerant of a corrupt or partial blob: a bad value falls back to the default rather
  /// than throwing, because a parse failure here must not leave the member with no
  /// reminder AND no way to see why.
  factory AutoPayPrefs.fromJson(dynamic raw) {
    if (raw is! Map) return defaults;
    final ids = <int>[];
    final list = raw['payeeIds'];
    if (list is List) {
      for (final v in list) {
        final n = v is int ? v : int.tryParse('${v ?? ''}');
        if (n != null && n > 0) ids.add(n);
      }
    }
    return AutoPayPrefs(
      enabled: raw['enabled'] == true,
      dayOfMonth: _clampDay(raw['dayOfMonth']),
      monthsAhead: _clampMonths(raw['monthsAhead']),
      payeeIds: ids,
      lastRemindedMs:
          raw['lastRemindedMs'] is int ? raw['lastRemindedMs'] as int : null,
    );
  }
}

/// The hour reminders fire at. Morning, so the member has the day to act on it.
const int kAutoPayHour = 9;

/// Next time the reminder should fire, strictly AFTER [now].
///
/// Returns the chosen day at [kAutoPayHour]:00 local, this month if that moment is still
/// in the future, otherwise next month.
DateTime nextReminder(AutoPayPrefs p, DateTime now) {
  final day = p.dayOfMonth < 1 ? 1 : (p.dayOfMonth > 28 ? 28 : p.dayOfMonth);
  final thisMonth = DateTime(now.year, now.month, day, kAutoPayHour);
  if (thisMonth.isAfter(now)) return thisMonth;
  // Let DateTime roll December into January rather than doing the arithmetic by hand.
  return DateTime(now.year, now.month + 1, day, kAutoPayHour);
}

/// One (year, month) the member wants to settle in advance.
class TermMonth {
  final int year;
  final int month;
  const TermMonth(this.year, this.month);

  @override
  bool operator ==(Object other) =>
      other is TermMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}

/// The months an Auto Pay run should settle, starting with the month AFTER [now].
///
/// The current month is excluded on purpose: it is normally already invoiced and shows up
/// under Fees Due, so including it here would double up with the ordinary payment screen.
List<TermMonth> monthsToSettle(AutoPayPrefs p, DateTime now) {
  final out = <TermMonth>[];
  for (var i = 1; i <= p.monthsAhead; i++) {
    final d = DateTime(now.year, now.month + i, 1);
    out.add(TermMonth(d.year, d.month));
  }
  return out;
}

/// Whether a reminder is due — used on app resume to catch a scheduled alert the OS
/// dropped (a rebooted phone, a force-stopped app, battery optimisation).
///
/// True when the scheduled moment has passed and no reminder was raised since it.
bool reminderOverdue(AutoPayPrefs p, DateTime now) {
  if (!p.enabled) return false;
  final day = p.dayOfMonth < 1 ? 1 : (p.dayOfMonth > 28 ? 28 : p.dayOfMonth);
  final due = DateTime(now.year, now.month, day, kAutoPayHour);
  if (!now.isAfter(due)) return false;
  final last = p.lastRemindedMs;
  if (last == null) return true;
  return DateTime.fromMillisecondsSinceEpoch(last).isBefore(due);
}

class AutoPayStore {
  static const _key = 'dclix.autopay.v1';

  static Future<AutoPayPrefs> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return AutoPayPrefs.defaults;
      return AutoPayPrefs.fromJson(jsonDecode(raw));
    } catch (_) {
      return AutoPayPrefs.defaults;
    }
  }

  static Future<void> save(AutoPayPrefs p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(p.toJson()));
    } catch (_) {
      // Nothing useful to do: the screen already reflects the change in memory, and the
      // next load falls back to defaults rather than to a half-written record.
    }
  }
}
