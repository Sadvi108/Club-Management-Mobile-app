import 'notification_prefs.dart';

/// Deciding which new notifications become OS alerts.
///
/// Kept separate from the platform code so the rules can be tested. Two bugs lived here in
/// the React Native version and both destroyed alerts silently:
///
///  1. The volume cap ran BEFORE the category filter. If the three newest rows happened to
///     be in a muted category, every older row the member did want was skipped — and the
///     high-water mark still advanced past it, so it never alerted at all. Muting fees must
///     not silence class notices.
///  2. Quiet hours advanced the mark too, which DELETED the alerts instead of deferring
///     them. "Silence overnight" must mean "tell me in the morning".

/// How many individual alerts one poll may raise before collapsing into a summary.
const kMaxAlertsPerPoll = 3;

class AlertPlan {
  /// Rows to raise, oldest first so the newest ends up on top of the tray.
  final List<Map<String, dynamic>> show;

  /// How many wanted rows the volume cap dropped (summarised instead).
  final int capped;

  /// True when quiet hours held alerts back — the caller must NOT advance the mark.
  final bool deferred;

  /// The mark to persist, or null to leave it untouched.
  final int? newLastSeen;

  const AlertPlan({
    required this.show,
    required this.capped,
    required this.deferred,
    required this.newLastSeen,
  });
}

int? _idOf(dynamic row) {
  if (row is! Map) return null;
  final v = row['id'];
  final n = v is int ? v : int.tryParse('$v');
  return n;
}

/// Work out what to alert about, given the server rows and the last id already alerted.
///
/// [lastSeen] null means a first run: seed the mark WITHOUT alerting, so a member who just
/// signed in is not buried under their whole backlog.
AlertPlan planAlerts({
  required List<dynamic> rows,
  required int? lastSeen,
  required NotifPrefs prefs,
  DateTime? now,
}) {
  final ids = rows.map(_idOf).whereType<int>().toList();
  // reduce, not fold with spread: the row count is server-controlled and spreading a large
  // list as arguments overflows.
  final maxId = ids.isEmpty ? null : ids.reduce((a, b) => b > a ? b : a);

  if (lastSeen == null) {
    return AlertPlan(show: const [], capped: 0, deferred: false, newLastSeen: maxId);
  }

  final fresh = rows
      .whereType<Map>()
      .where((r) {
        final id = _idOf(r);
        return id != null && id > lastSeen;
      })
      .map((r) => Map<String, dynamic>.from(r))
      .toList()
    ..sort((a, b) => (_idOf(a) ?? 0).compareTo(_idOf(b) ?? 0));

  // Category filter FIRST, then the cap (bug 1).
  final wanted = fresh.where((r) {
    final c = categorise(
      notificationType: (r['notificationType'] ?? '').toString(),
      subject: (r['text'] ?? '').toString(),
      body: (r['value'] ?? '').toString(),
    );
    return isAllowed(prefs, c);
  }).toList();

  // Quiet hours DEFER, they do not delete (bug 2).
  if (wanted.isNotEmpty && inQuietHours(prefs, now)) {
    return const AlertPlan(show: [], capped: 0, deferred: true, newLastSeen: null);
  }

  final show = wanted.length <= kMaxAlertsPerPoll
      ? wanted
      : wanted.sublist(wanted.length - kMaxAlertsPerPoll);

  return AlertPlan(
    show: show,
    capped: wanted.length - show.length,
    deferred: false,
    newLastSeen: (maxId != null && maxId > lastSeen) ? maxId : lastSeen,
  );
}

/// Category for one server row.
NotifCategory categoryOf(Map row) => categorise(
      notificationType: (row['notificationType'] ?? '').toString(),
      subject: (row['text'] ?? '').toString(),
      body: (row['value'] ?? '').toString(),
    );

/// Title shown in the tray — the row's short subject, or a safe default.
String titleOf(Map row) {
  final t = (row['text'] ?? '').toString().trim();
  return t.isEmpty ? 'Club notification' : t;
}

/// Body shown in the tray, with any stray markup from the admin panel stripped.
String bodyOf(Map row) => (row['value'] ?? '')
    .toString()
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .trim();
