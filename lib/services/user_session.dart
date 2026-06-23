import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'api_service.dart';
import 'response_utils.dart';

class UserSession extends ChangeNotifier {
  static final UserSession instance = UserSession._();
  UserSession._();

  /// App-wide messenger key used by [UserSession] to surface toast / SnackBar
  /// alerts (e.g. new notifications) without needing a BuildContext.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Map<String, dynamic>? authData;
  Map<String, dynamic>? myInfo;
  Map<String, dynamic>? homeStats;
  List<dynamic>? clubStats;
  List<dynamic>? notifications;
  Map<String, dynamic>? studentAddtnlInfo;
  /// Outstanding invoices for the instructor's branch — loaded from
  /// `/Outstanding/Fetch`. Used to compute live `dueAmount` and
  /// `invoiceCount` since `/Reports/HomePageStats` doesn't include them
  /// for instructor accounts.
  List<dynamic>? outstandingList;

  /// `/Reports/GradingSchedule` — the student's grading/exam rows. Source
  /// for Current Grade, Next Grading Date and Grading Payment Status on the
  /// home "Your info" card.
  List<dynamic>? gradingSchedule;

  /// `/ClassBooking/NextBookings` — upcoming sessions for the student.
  List<dynamic>? nextBookings;
  /// `/ClassBooking/GetBookings` — full booking history.
  List<dynamic>? allBookings;

  /// Cached `/Listing/MySiblings` rows ({id, value, text}).
  List<dynamic>? siblings;

  /// Active student filter for guardian accounts. `/Outstanding/Fetch`,
  /// `/Reports/Receipts`, `/Reports/Attendance` etc. return rows for ALL
  /// children under a parent login; selecting a sibling narrows every
  /// list to that child by matching the row's `studentName` / `name`.
  /// `null` = show the aggregate (all children).
  ///
  /// This is a client-side filter: `/Account/ChangeStudent` is not usable
  /// (returns 400 for guardian credentials), so switching is done by
  /// scoping the already-loaded multi-student data instead of re-auth.
  String? activeStudentName;
  Object? activeStudentId;

  /// Payment lock — when a payment is in progress, a 2-minute window
  /// blocks starting any other payment. Pure client-side guard.
  DateTime? paymentLockUntil;

  bool get paymentLocked =>
      paymentLockUntil != null && DateTime.now().isBefore(paymentLockUntil!);

  /// Seconds remaining on the payment lock (0 when not locked).
  int get paymentLockSeconds {
    if (paymentLockUntil == null) return 0;
    final s = paymentLockUntil!.difference(DateTime.now()).inSeconds;
    return s > 0 ? s : 0;
  }

  void startPaymentLock([Duration d = const Duration(minutes: 2)]) {
    paymentLockUntil = DateTime.now().add(d);
    notifyListeners();
  }

  void clearPaymentLock() {
    paymentLockUntil = null;
    notifyListeners();
  }

  /// Set (or clear, with null) the active student filter. Pure client-side,
  /// no network — instantly re-scopes every list via [notifyListeners].
  void setActiveStudent({String? name, Object? id}) {
    activeStudentName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : null;
    activeStudentId = id;
    notifyListeners();
  }

  /// Last raw response from /Outstanding/Fetch (kept for in-app debugging).
  dynamic outstandingRaw;
  /// Error message if the last /Outstanding/Fetch call threw.
  String? outstandingError;
  /// Last raw response from /Reports/HomePageStats (kept for in-app debugging).
  dynamic homeStatsRaw;
  String? homeStatsError;
  int unreadNotifications = 0;
  bool loading = false;
  String? error;

  // -------- Notification polling --------
  /// Live polling interval (seconds). Default 30s — light on the API but
  /// makes new notifications feel "real-time".
  static const Duration notificationPollInterval = Duration(seconds: 30);
  Timer? _notifTimer;
  int _previousUnread = 0;
  bool _pollingPaused = false;

  /// Latest store version returned by /Listing/StoreVersion. Compared against
  /// [currentAppVersion] to decide whether to show the "new version" banner.
  String? latestStoreVersion;
  bool storeVersionDismissed = false;
  static const String currentAppVersion = '1.1.2';

  bool get hasNewerVersion {
    final latest = latestStoreVersion;
    if (latest == null || latest.isEmpty) return false;
    if (storeVersionDismissed) return false;
    return _compareVersion(latest, currentAppVersion) > 0;
  }

  void dismissStoreVersionBanner() {
    storeVersionDismissed = true;
    notifyListeners();
  }

  static int _compareVersion(String a, String b) {
    final ap = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bp = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < ap.length || i < bp.length; i++) {
      final av = i < ap.length ? ap[i] : 0;
      final bv = i < bp.length ? bp[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  List<dynamic> get myOffers =>
      (homeStats?['myoffers'] as List?) ?? const <dynamic>[];
  List<dynamic> get myNews =>
      (homeStats?['mynews'] as List?) ?? const <dynamic>[];

  bool get isLoggedIn => authData != null && (authData!['accessToken'] ?? '').toString().isNotEmpty;

  /// Active student/instructor name. Resolution order:
  ///   1. `/Profile/MyInfo` (refreshes after ChangeStudent)
  ///   2. `/Account/Authenticate` payload
  ///   3. Fuzzy match — any string field whose lowercased key contains
  ///      "name" but does NOT look like a club / centre / instructor /
  ///      parent / sibling / login name.
  String get displayName {
    // A picked sibling overrides the token's bound student name.
    if (activeStudentName != null && activeStudentName!.isNotEmpty) {
      return activeStudentName!;
    }
    final pick = _pick([myInfo, authData],
        ['name', 'fullName', 'studentName', 'displayName',
         'Name', 'FullName', 'StudentName', 'userName', 'firstName',
         'fname', 'first_name', 'givenName']);
    if (pick.isNotEmpty) return pick;
    // Fuzzy: any key with "name" in it that isn't a different entity.
    const skip = ['clubname', 'centername', 'centrename',
                  'instructorname', 'parentname', 'siblingname',
                  'username', 'companyname', 'organizationname',
                  'logoname', 'modulename', 'classname', 'tcname',
                  'tcentername', 'scentername', 'examcentername'];
    for (final src in [myInfo, authData]) {
      if (src == null) continue;
      for (final entry in src.entries) {
        final key = entry.key.toString();
        final lower = key.toLowerCase();
        if (!lower.contains('name')) continue;
        if (skip.any(lower.contains)) continue;
        final v = entry.value;
        if (v is String && v.trim().isNotEmpty) {
          debugPrint('🔎 displayName fuzzy-matched from "$key": ${v.trim()}');
          return v.trim();
        }
      }
    }
    return '';
  }

  String get registrationNo => _pick([myInfo, authData],
      ['registrationNo', 'registrationNumber', 'regNo', 'code',
       'RegistrationNo', 'studentCode']);

  String get currentGrade => _pick([myInfo, authData],
      ['currentGrade', 'belt', 'grade', 'CurrentGrade']);

  /// Student code / membership number — distinct from registrationNo.
  String get studentCode => _pick([myInfo, authData], [
        'studentCode', 'studentcode', 'studentNo', 'studentNumber',
        'memberCode', 'memberNo', 'StudentCode',
      ]);

  /// Most relevant grading row: the soonest upcoming exam, else the latest.
  /// Scoped to the active student for guardian accounts.
  Map<String, dynamic>? get _gradingRow {
    final rows = scopedRows(gradingSchedule)
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (rows.isEmpty) return null;
    DateTime? dateOf(Map<String, dynamic> r) {
      for (final k in const [
        'nextGradingDate', 'nextGradeDate', 'examDate', 'gradingDate',
        'nextExamDate', 'date',
      ]) {
        final v = r[k];
        if (v == null) continue;
        final d = DateTime.tryParse(v.toString());
        if (d != null) return d;
      }
      return null;
    }

    final now = DateTime.now();
    final upcoming = rows
        .where((r) {
          final d = dateOf(r);
          return d != null && !d.isBefore(DateTime(now.year, now.month, now.day));
        })
        .toList()
      ..sort((a, b) => (dateOf(a) ?? now).compareTo(dateOf(b) ?? now));
    if (upcoming.isNotEmpty) return upcoming.first;
    rows.sort((a, b) => (dateOf(b) ?? DateTime(1970))
        .compareTo(dateOf(a) ?? DateTime(1970)));
    return rows.first;
  }

  /// Next grading/exam date (yyyy-MM-dd or full label). Checks myInfo first
  /// (some deployments return it inline), then the grading schedule.
  ///
  /// Only an UPCOMING date is returned. When the student's most relevant
  /// grading row is in the past, this returns empty so the home card falls
  /// through to [lastGradingDate] instead of labelling a past exam "Next".
  String get nextGradingDate {
    const keys = [
      'nextGradingDate', 'nextGradeDate', 'nextExamDate', 'examDate',
      'gradingDate',
    ];
    final inline = _pick([myInfo, studentAddtnlInfo], keys);
    final raw = inline.isNotEmpty ? inline : _pickFrom(_gradingRow, keys);
    if (raw.isEmpty) return '';
    // Drop dates that have already passed — they belong on the "Last Grading
    // Date" row, not "Next".
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final now = DateTime.now();
      if (parsed.isBefore(DateTime(now.year, now.month, now.day))) return '';
    }
    // Keep an explicit time window if the API provides one
    // (e.g. "2026-07-18 @ 14:00-16:00"); otherwise trim to the date.
    if (raw.contains('@') || raw.length <= 10) return raw;
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  /// Most recent past grading date — shown when there's no upcoming exam so
  /// the student still sees their grading history date.
  String get lastGradingDate {
    const keys = ['lastGradingDate', 'lastGradeDate', 'lastExamDate'];
    final inline = _pick([myInfo, studentAddtnlInfo], keys);
    String raw = inline;
    if (raw.isEmpty) {
      // Latest examDate among this student's grading rows.
      final rows = scopedRows(gradingSchedule).whereType<Map>().toList();
      DateTime? best;
      String bestRaw = '';
      for (final r in rows) {
        for (final k in const ['examDate', 'gradingDate', 'date']) {
          final v = r[k];
          if (v == null) continue;
          final d = DateTime.tryParse(v.toString());
          if (d != null && (best == null || d.isAfter(best))) {
            best = d;
            bestRaw = v.toString();
          }
        }
      }
      raw = bestRaw;
    }
    if (raw.isEmpty) return '';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  /// Grading payment status (e.g. "Paid").
  String get gradingPaymentStatus {
    const keys = [
      'gradingPaymentStatus', 'gradePaymentStatus', 'examPaymentStatus',
      'paymentStatus', 'payStatus',
    ];
    final inline = _pick([myInfo, studentAddtnlInfo], keys);
    return inline.isNotEmpty ? inline : _pickFrom(_gradingRow, keys);
  }

  /// First non-empty string value in [src] for any of [keys].
  static String _pickFrom(Map<String, dynamic>? src, List<String> keys) {
    if (src == null) return '';
    for (final k in keys) {
      final v = src[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  String get instructorName => _pick([myInfo],
      ['instructorName', 'trainer', 'sensei', 'coachName', 'InstructorName']);

  String get trainingTime => _pick([myInfo],
      ['trainingTme', 'trainingTime', 'tTime', 'TrainingTime', 'classTime']);

  String get tCenterName => _pick([myInfo],
      ['tCenterName', 'trainingCenter', 'trainingCentre',
       'TCenterName', 'tcName', 'centerName']);

  String get clubName => _pick([authData, myInfo],
      ['clubName', 'club', 'ClubName', 'organizationName']);

  String get clubPic => _pick([authData, myInfo],
      ['clubPic', 'clubLogo', 'logo', 'logoUrl', 'ClubPic']);

  String get phone => _pick([myInfo, authData],
      ['handPhone', 'mobile', 'phone', 'HandPhone', 'mobileNo', 'contactNo']);

  String get email => _pick([myInfo, authData],
      ['email', 'emailAddress', 'Email', 'mail']);

  /// First integer value found in `authData` (or `myInfo` as fallback) for
  /// any of the candidate keys. Returns 0 when nothing matches.
  int _intFromAuth(List<String> keys) {
    for (final src in [authData, myInfo]) {
      if (src == null) continue;
      for (final k in keys) {
        final v = src[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final n = int.tryParse(v.trim());
          if (n != null) return n;
        }
      }
    }
    return 0;
  }

  String _strFromAuth(List<String> keys) {
    for (final src in [authData, myInfo]) {
      if (src == null) continue;
      for (final k in keys) {
        final v = src[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
      }
    }
    return '';
  }

  /// Try each `source` map (skipping nulls) for each key in order. Returns
  /// the first non-empty string value found, or an empty string.
  static String _pick(List<Map<String, dynamic>?> sources, List<String> keys) {
    for (final src in sources) {
      if (src == null) continue;
      for (final k in keys) {
        final v = src[k];
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
    }
    return '';
  }

  /// Student's actual profile picture. Checks multiple myInfo / studentAddtnlInfo
  /// fields before falling back to the club logo (clubPic).
  String get studentPhoto {
    const photoKeys = ['photo', 'profilePic', 'pic', 'image', 'avatar', 'photoUrl', 'studentPhoto'];
    for (final k in photoKeys) {
      final v = (myInfo?[k] ?? studentAddtnlInfo?[k] ?? '').toString();
      if (v.isNotEmpty && v.startsWith('http')) return v;
    }
    return clubPic;
  }

  /// Locally-cached profile photo (base64), keyed by student id. The API
  /// exposes no read-back for an uploaded ProfilePic, so the picked image
  /// is cached on-device and shown until the server provides a real URL.
  String localPhotoB64 = '';

  String get _photoPrefKey {
    final id = (myInfo?['id'] ?? authData?['id'] ?? registrationNo).toString();
    return 'studentPhoto_$id';
  }

  Future<void> loadLocalPhoto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      localPhotoB64 = prefs.getString(_photoPrefKey) ?? '';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLocalPhoto(String b64) async {
    localPhotoB64 = b64;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (b64.isEmpty) {
        await prefs.remove(_photoPrefKey);
      } else {
        await prefs.setString(_photoPrefKey, b64);
      }
    } catch (_) {}
  }

  /// Attendance percentage from profile data, or empty string when unavailable.
  String get attendancePercentage {
    for (final k in ['attendancePercentage', 'attendance', 'attendancePct']) {
      final v = myInfo?[k] ?? studentAddtnlInfo?[k];
      if (v != null) return v.toString();
    }
    return '';
  }

  /// Outstanding rows scoped to [activeStudentName] when a sibling is
  /// selected, otherwise the full multi-student list.
  List<dynamic> get outstandingForCurrentStudent =>
      filterByActiveStudent(outstandingList);

  /// Narrow a report list to the logged-in student.
  ///
  /// Some report endpoints (`/Reports/Receipts`, `/Reports/GradingSchedule`,
  /// `/Reports/PaymentSlips`) return the WHOLE branch even for a student
  /// token, so without this a student would see other students' receipts /
  /// grading. Match by `icNo` (== authData.icNo) or `name` (== displayName).
  ///
  /// Instructors are meant to see everyone, so this is a no-op for them.
  List<dynamic> scopeToSelf(List<dynamic>? rows) {
    final list = rows ?? const [];
    if (list.isEmpty || isInstructor) return list;
    final myIc =
        (authData?['icNo'] ?? myInfo?['icNo'] ?? '').toString().trim().toUpperCase();
    final myName = displayName.trim().toUpperCase();
    if (myIc.isEmpty && myName.isEmpty) return list;
    bool mine(dynamic r) {
      if (r is! Map) return false;
      final ic = (r['icNo'] ?? '').toString().trim().toUpperCase();
      final nm = (r['name'] ?? r['studentName'] ?? r['receiverName'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      return (myIc.isNotEmpty && ic == myIc) ||
          (myName.isNotEmpty && nm == myName);
    }

    final scoped = list.where(mine).toList();
    if (scoped.isNotEmpty) return scoped;
    // None matched. If the list holds multiple distinct people the endpoint
    // returned the whole branch and none are ours → show nothing (never leak
    // another student). If it's a single subject, the server already scoped
    // to us (the icNo/name key just differs) → keep it.
    final subjects = <String>{};
    for (final r in list) {
      if (r is Map) {
        subjects.add((r['icNo'] ?? r['name'] ?? r['studentName'] ?? '')
            .toString()
            .toUpperCase());
      }
    }
    return subjects.length > 1 ? const <dynamic>[] : list;
  }

  /// Scope a per-student report list: a picked guardian child wins, else
  /// narrow to the logged-in student.
  List<dynamic> scopedRows(List<dynamic>? rows) {
    if (activeStudentName != null && activeStudentName!.isNotEmpty) {
      return filterByActiveStudent(rows);
    }
    return scopeToSelf(rows);
  }

  /// Narrow any multi-student row list to [activeStudentName]. Matches the
  /// row's `studentName` or `name` field (case-insensitive). When no active
  /// student is set, or no row matches, returns the list unchanged.
  List<dynamic> filterByActiveStudent(List<dynamic>? rows) {
    final list = rows ?? const [];
    final target = activeStudentName;
    if (target == null || list.isEmpty) return list;
    final t = target.toUpperCase();
    final scoped = list.where((r) {
      if (r is! Map) return false;
      final n = (r['studentName'] ?? r['name'] ?? r['receiverName'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      return n == t;
    }).toList();
    return scoped.isNotEmpty ? scoped : list;
  }

  /// Total amount due — the "FEES DUE / total due amt" badge.
  ///
  /// Role matters:
  ///  - STUDENT/parent: `/Outstanding/Fetch` returns the user's own (and
  ///    siblings') invoices, so the summed rows are the true personal due.
  ///    `/Reports/HomePageStats` can lag/return 0, so the live row sum
  ///    wins; HomePageStats is only a fallback.
  ///  - INSTRUCTOR: `/Outstanding/Fetch` returns ALL branch students'
  ///    invoices (wrong for a personal badge), so the server-precomputed
  ///    `HomePageStats.dueAmount` (instructor's own) wins.
  num get dueAmount {
    num sumOutstanding() {
      num total = 0;
      for (final row in outstandingForCurrentStudent) {
        if (row is Map) total += _readAmount(row);
      }
      return total;
    }

    final hps = _deepReadAmount(homeStats);
    final hpsRaw = _deepReadAmount(homeStatsRaw);
    if (isInstructor) {
      if (hps != 0) return hps;
      if (hpsRaw != 0) return hpsRaw;
      return 0;
    }
    // Student: live outstanding rows are authoritative.
    final s = sumOutstanding();
    if (s != 0) return s;
    if (hps != 0) return hps;
    if (hpsRaw != 0) return hpsRaw;
    final n3 = _deepReadAmount(outstandingRaw);
    if (n3 != 0) return n3;
    return 0;
  }

  /// Recursively walk any response (Map/List), returning the first
  /// non-zero amount produced by [_readAmount].
  static num _deepReadAmount(dynamic v) {
    if (v is Map) {
      final n = _readAmount(v);
      if (n != 0) return n;
      for (final inner in v.values) {
        final m = _deepReadAmount(inner);
        if (m != 0) return m;
      }
    } else if (v is List) {
      for (final item in v) {
        final m = _deepReadAmount(item);
        if (m != 0) return m;
      }
    }
    return 0;
  }

  /// Recursively walk any response (Map/List), returning the first
  /// non-zero count produced by [_readCount].
  static int _deepReadCount(dynamic v) {
    if (v is Map) {
      final n = _readCount(v);
      if (n != 0) return n;
      for (final inner in v.values) {
        final m = _deepReadCount(inner);
        if (m != 0) return m;
      }
    } else if (v is List) {
      for (final item in v) {
        final m = _deepReadCount(item);
        if (m != 0) return m;
      }
    }
    return 0;
  }

  /// Number of unpaid invoices — must mirror [dueAmount]'s source.
  ///  - INSTRUCTOR: HomePageStats.invoiceCount (own, not branch-aggregated).
  ///  - STUDENT: live outstanding row count is authoritative; HomePageStats
  ///    is only a fallback (it can lag/return 0).
  int get invoiceCount {
    final hps = _deepReadCount(homeStats);
    final hpsRaw = _deepReadCount(homeStatsRaw);
    if (isInstructor) {
      if (hps != 0) return hps;
      if (hpsRaw != 0) return hpsRaw;
      return 0;
    }
    final list = outstandingForCurrentStudent;
    if (list.isNotEmpty) return list.length;
    if (hps != 0) return hps;
    if (hpsRaw != 0) return hpsRaw;
    final n3 = _deepReadCount(outstandingRaw);
    if (n3 != 0) return n3;
    return 0;
  }

  /// Extract an integer count from any map by trying exact keys then a
  /// fuzzy lowercased substring match.
  static int _readCount(Map? m) {
    if (m == null) return 0;
    const exactKeys = [
      'invoiceCount', 'pendingInvoice', 'dueInvoice', 'invoices',
      'pendingCount', 'unpaidInvoices', 'invoiceQty', 'invQty',
      'numInvoices', 'totalInvoices', 'outstandingCount'
    ];
    for (final k in exactKeys) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    for (final entry in m.entries) {
      final key = entry.key.toString().toLowerCase();
      // any key that says "invoice" or "outstanding" and points at a number
      if (key.contains('invoice') || key.contains('outstanding')) {
        final v = entry.value;
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final n = int.tryParse(v.trim());
          if (n != null) return n;
        }
      }
    }
    return 0;
  }

  /// Earliest due date across the outstanding list (yyyy-MM-dd or first
  /// usable date string). Empty when nothing is loaded.
  String get earliestDueDate {
    final list = outstandingForCurrentStudent;
    if (list.isEmpty) return '';
    String? earliest;
    for (final row in list) {
      if (row is! Map) continue;
      for (final k in ['dueDate', 'due_date', 'invoiceDate', 'date',
                        'paymentDue', 'expiryDate']) {
        final v = row[k];
        if (v == null) continue;
        final s = v.toString();
        if (s.isEmpty) continue;
        if (earliest == null || s.compareTo(earliest) < 0) {
          earliest = s;
        }
        break;
      }
    }
    return earliest ?? '';
  }

  /// Bookings whose date matches today. Reads from `nextBookings` first
  /// (typically upcoming), then falls back to `allBookings`.
  List<Map<String, dynamic>> get todayBookings {
    final src = (nextBookings != null && nextBookings!.isNotEmpty)
        ? nextBookings
        : allBookings;
    if (src == null || src.isEmpty) return const [];
    final now = DateTime.now();
    final out = <Map<String, dynamic>>[];
    for (final row in src) {
      if (row is! Map) continue;
      final d = _bookingDate(row);
      if (d == null) continue;
      if (_isSameDay(now, d)) {
        out.add(Map<String, dynamic>.from(row));
      }
    }
    return out;
  }

  static DateTime? _bookingDate(Map row) {
    for (final k in ['date', 'bookingDate', 'startTime', 'classDate',
                      'sessionDate', 'time', 'sessionTime']) {
      final v = row[k];
      if (v == null) continue;
      if (v is DateTime) return v;
      final s = v.toString();
      if (s.isEmpty) continue;
      final parsed = DateTime.tryParse(s);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Extract a numeric amount from an outstanding-list row, trying:
  ///   1. exact keys we've seen in different swag responses
  ///   2. case-insensitive substring match for "amount" / "due" / "balance"
  ///   3. number parsing that strips currency symbols + commas
  static num _readAmount(Map row) {
    const exactKeys = [
      'dueAmount', 'dueAmt', 'amount', 'amountDue', 'outstandingAmount',
      'outstandingAmt', 'balance', 'totalAmount', 'totalDue', 'value',
      'invoiceAmount', 'amtDue'
    ];
    for (final k in exactKeys) {
      final n = _toNum(row[k]);
      if (n != null) return n;
    }
    // Fuzzy: any key whose lowercased name mentions money concepts.
    for (final entry in row.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.contains('amount') ||
          key.contains('amt') ||
          key.contains('balance') ||
          (key.contains('due') && !key.contains('date'))) {
        final n = _toNum(entry.value);
        if (n != null) return n;
      }
    }
    return 0;
  }

  static num? _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String && v.isNotEmpty) {
      // Strip "RM", "$", commas, spaces, any non-numeric except - and .
      final cleaned = v.replaceAll(RegExp(r'[^\d.\-]'), '');
      if (cleaned.isEmpty) return null;
      return num.tryParse(cleaned);
    }
    return null;
  }

  /// Recursively dig through a response object looking for the first List
  /// of records (so we tolerate `{data: [...]}`, `{data: {invoices: [...]}}`,
  /// `{records: [...]}`, etc.). When no List is found but the Map's values
  /// are themselves Maps (looks like an "indexed-by-id" collection), the
  /// values are returned as a synthetic list.
  static List<dynamic>? findList(dynamic resp) {
    if (resp == null) return null;
    if (resp is List) return resp;
    if (resp is Map) {
      // Common wrapper keys first.
      for (final k in const [
        'data', 'invoices', 'records', 'outstanding', 'list',
        'items', 'rows', 'results', 'value', 'siblings', 'children'
      ]) {
        if (resp.containsKey(k)) {
          final inner = findList(resp[k]);
          if (inner != null) return inner;
        }
      }
      // Scan every value once.
      for (final v in resp.values) {
        if (v is List) return v;
        if (v is Map) {
          final inner = findList(v);
          if (inner != null) return inner;
        }
      }
      // Last resort: if every value in this Map is itself a Map, treat
      // them as an indexed collection (e.g. {"1": {...}, "2": {...}}).
      if (resp.isNotEmpty && resp.values.every((v) => v is Map)) {
        return resp.values.toList();
      }
    }
    return null;
  }

  /// Backwards-compatible alias.
  static List<dynamic>? _findList(dynamic resp) => findList(resp);

  /// Public hook so external screens can ask listeners to rebuild
  /// after they've mutated session fields directly. (`notifyListeners`
  /// is protected on [ChangeNotifier], so we expose this thin wrapper.)
  void touch() => notifyListeners();

  /// True when the authenticated user is an instructor.
  ///
  /// Verified against the live API: student/parent accounts authenticate as
  /// `userType == 3`; instructors authenticate as `userType == 0` (the server
  /// rejects `2` at login with HTTP 400). `UserType` enum is {0, 2, 3}, so any
  /// logged-in non-student is an instructor. The `2` branch is kept defensively
  /// even though it never reaches the client today.
  bool get isInstructor {
    final raw = authData?['userType'];
    final ut = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    if (ut == null) return false; // logged out / unknown
    return ut != 3;               // 3 = student/parent; 0 (and 2) = instructor
  }

  /// Numeric student id to act on for per-student actions (e.g. prepay).
  /// A picked guardian child wins; otherwise the logged-in account's id.
  /// Returns null when neither is available.
  int? get currentStudentId {
    final active = activeStudentId;
    if (active != null) {
      if (active is int) return active;
      final n = int.tryParse(active.toString());
      if (n != null) return n;
    }
    final raw = authData?['id'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  /// Rows surfaced by `Profile/MyClubStats` — each entry is
  /// `{id: <count>, value: <orderIndex>, text: <label>}`.
  List<Map<String, dynamic>> get clubStatsRows =>
      clubStats?.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() ??
          const [];

  String get clubDisplayName {
    final list = authData?['clubList'];
    if (list is List && list.isNotEmpty && list.first is Map) {
      final t = (list.first as Map)['text']?.toString();
      if (t != null && t.isNotEmpty) return t;
    }
    return clubName;
  }

  // ---------------------------------------------------------------------------
  // Session persistence (survives app kill / cold start)
  // ---------------------------------------------------------------------------
  static const _kAuthKey = 'cm_auth_data_v1';

  /// Save the current [authData] to disk so the next cold start can
  /// restore the session without forcing a re-login.
  Future<void> _persistAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (authData == null) {
        await prefs.remove(_kAuthKey);
      } else {
        await prefs.setString(_kAuthKey, jsonEncode(authData));
      }
    } catch (e) {
      debugPrint('persistAuth failed: $e');
    }
  }

  /// Attempt to restore a saved session on app startup.
  ///
  /// Returns true when a stored token was found and the session was
  /// rehydrated (token re-applied + [_loadAll] run). The token may still
  /// be server-side expired — callers should treat a subsequent 401 as a
  /// signal to route back to /login.
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kAuthKey);
      if (raw == null || raw.isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final data = Map<String, dynamic>.from(decoded);
      final token = (data['accessToken'] ?? '').toString();
      if (token.isEmpty) return false;

      ApiService.setToken(token);
      authData = data;
      loading = true;
      notifyListeners();
      await _loadAll();
      // If the token was rejected, _loadAll surfaces errors but authData
      // stays set — guard with a lightweight validity check.
      if (myInfo == null && homeStatsError != null &&
          homeStatsError!.contains('401')) {
        await _clearPersistedAuth();
        authData = null;
        ApiService.clearToken();
        return false;
      }
      _previousUnread = unreadNotifications;
      startNotificationPolling();
      _checkStoreVersion();
      _registerPushToken();
      return true;
    } catch (e) {
      debugPrint('restoreSession failed: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _clearPersistedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAuthKey);
    } catch (_) {}
  }

  Future<bool> login({
    required String username,
    required String password,
    required int userType,
    int accessMethod = 0,
    String deviceType = 'mobile',
    String? clubCode,
    int? branchId,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'username': username,
        'password': password,
        'userType': userType,
        'accessMethod': accessMethod,
        'deviceType': deviceType,
      };
      if (clubCode != null && clubCode.isNotEmpty) {
        body['clubCode'] = clubCode;
      }
      if (branchId != null && branchId != 0) {
        body['branchId'] = branchId;
      }
      final resp = await ApiService.post('/Account/Authenticate', body);
      // A wrong password / unknown account comes back as HTTP 200 with an
      // error envelope (e.g. {status: 404, meta: {error: "Account not
      // found..."}}). Surface that real message instead of a generic one.
      final apiErr = apiEnvelopeError(resp);
      if (apiErr != null) {
        error = apiErr;
        return false;
      }
      if (resp is! Map || resp['data'] is! Map) {
        error = 'Unexpected response from the server. Please try again.';
        return false;
      }
      final data = Map<String, dynamic>.from(resp['data'] as Map);
      final token = data['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('No access token returned');
      }
      ApiService.setToken(token);
      authData = data;
      // Instructor auth payload omits clubCode/clubList; keep the code the
      // user entered at login so Switch Branch (and ChangeClub) can resolve it.
      if (clubCode != null && clubCode.isNotEmpty) {
        authData!['clubCode'] = clubCode;
      }
      debugPrint('🔐 AuthData keys: ${data.keys.toList()}');
      await _persistAuth();
      await _loadAll();
      _previousUnread = unreadNotifications;
      startNotificationPolling();
      // Boot-time post-login extras (best-effort, never throw).
      _checkStoreVersion();
      _registerPushToken();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAll() async {
    final futures = <Future>[
      _safeGet('/Profile/MyInfo').then((d) {
        if (d is Map) {
          myInfo = Map<String, dynamic>.from(d);
          debugPrint('👤 MyInfo keys: ${myInfo!.keys.toList()}');
        } else {
          debugPrint('👤 MyInfo response was not a Map (was ${d?.runtimeType})');
        }
      }),
      _loadHomeStats(),
      _safeGet('/Profile/MyClubStats').then((d) {
        if (d is List) clubStats = d;
      }),
      _safeGet('/Profile/MyUnreadNotificationCount').then((d) {
        if (d is int) unreadNotifications = d;
        if (d is num) unreadNotifications = d.toInt();
      }),
      _safeGet('/Profile/MyNotifications').then((d) {
        if (d is List) notifications = d;
      }),
    ];
    // StudentAddtnlInfo is student-only — skip for instructor accounts.
    if (!isInstructor) {
      futures.add(_safeGet('/Profile/StudentAddtnlInfo').then((d) {
        if (d is Map) studentAddtnlInfo = Map<String, dynamic>.from(d);
      }));
    }
    // /Outstanding/Fetch returns unpaid invoices — branch-wide for
    // instructors, personal for students. We load it for everyone so the
    // dueAmount/invoiceCount getters have a reliable live source even if
    // /Reports/HomePageStats omits those fields.
    futures.add(_loadOutstanding());
    // Class-booking endpoints — power student schedule + home Today's Class.
    if (!isInstructor) {
      futures.add(_safeGet('/ClassBooking/NextBookings').then((d) {
        if (d is List) {
          nextBookings = d;
        } else if (d != null) {
          nextBookings = findList(d);
        }
        debugPrint('📅 NextBookings: ${nextBookings?.length ?? 0} rows');
      }));
      futures.add(_safeGet('/ClassBooking/GetBookings').then((d) {
        if (d is List) {
          allBookings = d;
        } else if (d != null) {
          allBookings = findList(d);
        }
        debugPrint('📅 AllBookings: ${allBookings?.length ?? 0} rows');
      }));
      // Grading schedule powers Current Grade / Next Grading Date / Grading
      // Payment Status on the home "Your info" card.
      futures.add(() async {
        try {
          final d = await Api.reportsGradingSchedule();
          gradingSchedule = (d is List) ? d : findList(d);
          debugPrint('🥋 GradingSchedule: ${gradingSchedule?.length ?? 0} rows'
              '${gradingSchedule != null && gradingSchedule!.isNotEmpty && gradingSchedule!.first is Map ? " keys=${(gradingSchedule!.first as Map).keys.toList()}" : ""}');
        } catch (e) {
          debugPrint('🥋 GradingSchedule failed: $e');
        }
      }());
    }
    await Future.wait(futures);
    // Restore any locally-cached profile photo (keyed by the now-loaded
    // student id). Server has no photo read-back endpoint.
    await loadLocalPhoto();
  }

  /// Pull /Reports/HomePageStats and keep both the parsed map AND the raw
  /// response. Some deployments wrap the payload twice (`{data: {data: {...}}}`)
  /// so we recursively descend until we find the actual stats object.
  Future<void> _loadHomeStats() async {
    homeStatsError = null;
    homeStatsRaw = null;
    try {
      final resp = await ApiService.get('/Reports/HomePageStats');
      homeStatsRaw = resp;
      Map<String, dynamic>? best;
      void walk(dynamic v) {
        if (v is! Map) return;
        // Heuristic: a map is "stats-like" if it contains any of the
        // common keys we care about.
        final keys = v.keys.map((k) => k.toString().toLowerCase()).toSet();
        const interesting = {
          'dueamount', 'duamount', 'dueamt', 'totaldue', 'totalamount',
          'outstandingamount', 'invoicecount', 'invoices',
          'pendinginvoice', 'mynews', 'myoffers', 'newsfeed'
        };
        if (keys.any(interesting.contains)) {
          best = Map<String, dynamic>.from(v);
        }
        for (final inner in v.values) {
          walk(inner);
        }
      }
      walk(resp);
      homeStats = best ?? (resp is Map ? Map<String, dynamic>.from(resp) : null);
      debugPrint('🏠 HomeStats: keys=${homeStats?.keys.toList()}');
    } catch (e) {
      homeStatsError = e.toString();
      debugPrint('🏠 HomeStats failed: $e');
    }
  }

  /// Pulls /Outstanding/Fetch with a few candidate request bodies so we
  /// tolerate APIs that require explicit (even if empty) filter fields.
  /// Stops at the first call that returns a non-empty list.
  Future<void> _loadOutstanding() async {
    outstandingError = null;
    outstandingRaw = null;
    // Per swag.json the body is `OutstandingFetchViewModel` with fields:
    //   studentId, studentName, icNo, startDate, endDate,
    //   eCenterId, tCenterId, sCenterId, transactionType.
    // Server appears to require the shape even when fields are zero/empty,
    // so we send a fully-populated body keyed off the auth payload.
    final sid = _intFromAuth([
      'studentId', 'StudentId', 'id', 'Id', 'userId', 'UserId'
    ]);
    final icNo = _strFromAuth(['icNo', 'IcNo', 'nric', 'identityNo']);
    final now = DateTime.now();
    // Wide date window: 2 years back → 2 years forward.
    final start = DateTime(now.year - 2, 1, 1).toIso8601String();
    final end   = DateTime(now.year + 2, 12, 31).toIso8601String();
    final fullBody = <String, dynamic>{
      'studentId': sid,
      'studentName': '',
      'icNo': icNo,
      'startDate': start,
      'endDate': end,
      'eCenterId': 0,
      'tCenterId': 0,
      'sCenterId': 0,
      'transactionType': '',
    };
    final candidateBodies = <Map<String, dynamic>>[
      fullBody,
      // Same shape but studentId=0 (server-uses-token fallback).
      {...fullBody, 'studentId': 0},
      // Last-ditch empty (legacy spec).
      const <String, dynamic>{},
    ];
    for (final body in candidateBodies) {
      try {
        final resp = await ApiService.post('/Outstanding/Fetch', body);
        outstandingRaw = resp;
        final list = _findList(resp);
        if (list != null) {
          outstandingList = list;
          debugPrint('💰 Outstanding: ${list.length} records, '
              'sum=${dueAmount.toStringAsFixed(2)}, '
              'body=$body');
          if (list.isNotEmpty) return; // good, stop trying
        } else {
          debugPrint('💰 Outstanding: no list in response (type=${resp.runtimeType}, body=$body)');
        }
      } catch (e) {
        outstandingError = e.toString();
        debugPrint('💰 Outstanding failed (body=$body): $e');
      }
    }
  }

  Future<void> _checkStoreVersion() async {
    try {
      final resp = await ApiService.get('/Listing/StoreVersion/android');
      String? v;
      if (resp is String) {
        v = resp;
      } else if (resp is Map) {
        v = (resp['version'] ?? resp['data'] ?? resp['storeVersion'])?.toString();
      }
      if (v != null && v.isNotEmpty) {
        latestStoreVersion = v;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('StoreVersion failed: $e');
    }
  }

  /// Register the device push token with the backend.
  ///
  /// FCM is not wired yet, so there is no real device token to send. We
  /// deliberately do NOT post a placeholder/stub token (that would write
  /// junk into the server's notification routing table). Re-enable this
  /// once a genuine FCM/APNs token is available.
  Future<void> _registerPushToken() async {
    return;
  }

  // ---------------------------------------------------------------------------
  // Real-time notification polling
  // ---------------------------------------------------------------------------

  /// Start the periodic poll. Safe to call multiple times.
  void startNotificationPolling() {
    _notifTimer?.cancel();
    _previousUnread = unreadNotifications;
    _notifTimer = Timer.periodic(notificationPollInterval, (_) => _pollNotifications());
    debugPrint('🔔 Notification polling started (every ${notificationPollInterval.inSeconds}s)');
  }

  void stopNotificationPolling() {
    _notifTimer?.cancel();
    _notifTimer = null;
  }

  /// Temporarily skip a poll cycle (used while a switch/refresh is in flight).
  void pauseNotificationPolling() => _pollingPaused = true;
  void resumeNotificationPolling() => _pollingPaused = false;

  Future<void> _pollNotifications() async {
    if (!isLoggedIn || _pollingPaused) return;
    try {
      final countResp = await ApiService.get('/Profile/MyUnreadNotificationCount');
      final c = (countResp is Map && countResp.containsKey('data'))
          ? countResp['data']
          : countResp;
      int newCount = unreadNotifications;
      if (c is int) newCount = c;
      if (c is num) newCount = c.toInt();

      // No change → nothing to do.
      if (newCount == _previousUnread) return;

      // Pull the latest list so the bell sheet & toast have content.
      Map<String, dynamic>? newest;
      try {
        final listResp = await ApiService.get('/Profile/MyNotifications');
        final list = (listResp is Map && listResp.containsKey('data'))
            ? listResp['data']
            : listResp;
        if (list is List) {
          notifications = list;
          if (newCount > _previousUnread && list.isNotEmpty && list.first is Map) {
            newest = Map<String, dynamic>.from(list.first as Map);
          }
        }
      } catch (e) {
        debugPrint('Poll list failed: $e');
      }

      unreadNotifications = newCount;
      _previousUnread = newCount;
      notifyListeners();

      if (newest != null) _showNotificationToast(newest);
    } catch (e) {
      debugPrint('Notification poll failed: $e');
    }
  }

  void _showNotificationToast(Map<String, dynamic> n) {
    final title = (n['text'] ?? n['title'] ?? n['name'] ?? 'New notification').toString();
    final body = (n['value'] ?? n['description'] ?? '')
        .toString()
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      content: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFFB923C),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.notifications_active, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              if (body.isNotEmpty)
                Text(body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xCCFFFFFF), fontSize: 11)),
            ],
          ),
        ),
      ]),
    ));
  }

  // ---------------------------------------------------------------------------
  // Real-time student / branch switching
  // ---------------------------------------------------------------------------

  /// Switch the active student.
  ///
  /// `/Account/ChangeStudent` is unusable here — it returns `400 Bad
  /// Request` for guardian credentials regardless of body shape, so a
  /// server-side re-scope isn't possible. Instead the guardian login
  /// already pulls every child's rows (Outstanding / Receipts /
  /// Attendance / Grading all carry a `studentName`), so switching is a
  /// pure client-side filter: set [activeStudentName] and every list
  /// getter re-scopes instantly. Pass `name: null` to show all children.
  ///
  /// Always succeeds (no network), returns true so existing callers and
  /// their success UI keep working.
  Future<bool> switchStudent(Object studentId, {String? studentName}) async {
    setActiveStudent(name: studentName, id: studentId);
    return true;
  }

  /// Clear the student filter — show the aggregate across all children.
  void showAllStudents() => setActiveStudent(name: null, id: null);

  /// Extract the new bearer token from a `/Profile/UpdateToken` response.
  /// The endpoint returns the JWT as the raw `data` string (verified live),
  /// but tolerate a bare string or a nested `{data: {accessToken}}` shape too.
  static String? tokenFromUpdateResponse(dynamic resp) {
    if (resp is String) return resp.isEmpty ? null : resp;
    if (resp is Map) {
      final d = resp['data'];
      if (d is String && d.isNotEmpty) return d;
      if (d is Map && d['accessToken'] is String) {
        final t = d['accessToken'] as String;
        return t.isEmpty ? null : t;
      }
    }
    return null;
  }

  /// Switch the active branch (works for both student & instructor).
  ///
  /// Uses `POST /Profile/UpdateToken/{branchId}`, which returns a new bearer
  /// token bound to the chosen branch. (`/Account/ChangeClub` returns HTTP 400
  /// for instructor accounts — verified live — so it can't be used here.) The
  /// new token is applied, `authData` is updated with the branch + token, and
  /// every branch-scoped cache is reloaded.
  Future<bool> switchBranch(Object branchId, {String? clubCode}) async {
    if (!isLoggedIn) return false;
    pauseNotificationPolling();
    loading = true;
    notifyListeners();
    try {
      final resp = await Api.profileUpdateToken(branchId);
      final newToken = tokenFromUpdateResponse(resp);
      if (newToken == null || newToken.isEmpty) {
        throw Exception('UpdateToken returned no token');
      }
      ApiService.setToken(newToken);

      // UpdateToken returns only the token; carry the rest of authData forward
      // and patch in the new token + branch so the session/persistence reflect
      // the switch.
      authData ??= <String, dynamic>{};
      authData!['accessToken'] = newToken;
      authData!['branchId'] = branchId;
      if (clubCode != null && clubCode.isNotEmpty) {
        authData!['clubCode'] = clubCode;
      }
      await _persistAuth();

      myInfo = null;
      homeStats = null;
      clubStats = null;
      notifications = null;
      studentAddtnlInfo = null;
      outstandingList = null;
      gradingSchedule = null;

      await _loadAll();
      _previousUnread = unreadNotifications;
      return true;
    } catch (e) {
      error = e.toString();
      debugPrint('switchBranch failed: $e');
      return false;
    } finally {
      loading = false;
      resumeNotificationPolling();
      notifyListeners();
    }
  }

  Future<dynamic> _safeGet(String endpoint) async {
    try {
      final resp = await ApiService.get(endpoint);
      if (resp is Map && resp.containsKey('data')) return resp['data'];
      return resp;
    } catch (e) {
      debugPrint('Failed $endpoint: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    await _loadAll();
    loading = false;
    notifyListeners();
  }

  void logout() {
    stopNotificationPolling();
    _clearPersistedAuth();
    authData = null;
    myInfo = null;
    homeStats = null;
    clubStats = null;
    notifications = null;
    studentAddtnlInfo = null;
    outstandingList = null;
    outstandingRaw = null;
    outstandingError = null;
    homeStatsRaw = null;
    homeStatsError = null;
    nextBookings = null;
    allBookings = null;
    gradingSchedule = null;
    unreadNotifications = 0;
    _previousUnread = 0;
    ApiService.clearToken();
    notifyListeners();
  }
}
