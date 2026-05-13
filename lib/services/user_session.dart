import 'dart:async';

import 'package:flutter/material.dart';
import 'api_service.dart';

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
  static const String currentAppVersion = '1.0.0';

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

  String get displayName =>
      (myInfo?['name'] ?? authData?['name'] ?? '').toString();

  String get registrationNo =>
      (myInfo?['registrationNo'] ?? authData?['code'] ?? '').toString();

  String get currentGrade =>
      (myInfo?['currentGrade'] ?? authData?['currentGrade'] ?? '').toString();

  String get instructorName => (myInfo?['instructorName'] ?? '').toString();
  String get trainingTime => (myInfo?['trainingTme'] ?? '').toString();
  String get tCenterName => (myInfo?['tCenterName'] ?? '').toString();
  String get clubName => (authData?['clubName'] ?? '').toString();
  String get clubPic => (authData?['clubPic'] ?? '').toString();
  String get phone => (authData?['handPhone'] ?? '').toString();
  String get email =>
      (myInfo?['email'] ?? authData?['email'] ?? '').toString();

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

  /// Attendance percentage from profile data, or empty string when unavailable.
  String get attendancePercentage {
    for (final k in ['attendancePercentage', 'attendance', 'attendancePct']) {
      final v = myInfo?[k] ?? studentAddtnlInfo?[k];
      if (v != null) return v.toString();
    }
    return '';
  }

  /// Total amount due. Prefers the live sum of [outstandingList] when
  /// it's available (works for both instructors and students). Falls back
  /// to `homeStats` keys when no list was loaded.
  num get dueAmount {
    final list = outstandingList;
    if (list != null && list.isNotEmpty) {
      num total = 0;
      for (final row in list) {
        if (row is Map) total += _readAmount(row);
      }
      // If the sum produced something non-zero, return it. Otherwise fall
      // through to homeStats — the row fields might not match any of our
      // amount key heuristics.
      if (total != 0) return total;
    }
    final m = homeStats;
    if (m == null) return 0;
    for (final k in [
      'dueAmount', 'dueAmt', 'totalDue', 'totalAmount', 'outstandingAmount'
    ]) {
      final v = m[k];
      final n = _toNum(v);
      if (n != null) return n;
    }
    return 0;
  }

  /// Number of unpaid invoices. Prefers `outstandingList.length`, falls
  /// back to `homeStats` keys.
  int get invoiceCount {
    final list = outstandingList;
    if (list != null) return list.length;
    final m = homeStats;
    if (m == null) return 0;
    for (final k in [
      'invoiceCount', 'pendingInvoice', 'dueInvoice', 'invoices', 'pendingCount'
    ]) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return 0;
  }

  /// Earliest due date across the outstanding list (yyyy-MM-dd or first
  /// usable date string). Empty when nothing is loaded.
  String get earliestDueDate {
    final list = outstandingList;
    if (list == null || list.isEmpty) return '';
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
  /// `{records: [...]}`, etc.).
  static List<dynamic>? _findList(dynamic resp) {
    if (resp == null) return null;
    if (resp is List) return resp;
    if (resp is Map) {
      // Common wrapper keys first.
      for (final k in const [
        'data', 'invoices', 'records', 'outstanding', 'list',
        'items', 'rows', 'results', 'value'
      ]) {
        if (resp.containsKey(k)) {
          final inner = _findList(resp[k]);
          if (inner != null) return inner;
        }
      }
      // Otherwise scan every value once.
      for (final v in resp.values) {
        if (v is List) return v;
        if (v is Map) {
          final inner = _findList(v);
          if (inner != null) return inner;
        }
      }
    }
    return null;
  }

  /// True when the authenticated user is an instructor.
  /// The Authenticate response sets `userType == 2` for instructors.
  bool get isInstructor => ((authData?['userType'] as num?)?.toInt() ?? 0) == 2;

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
      if (resp is! Map || resp['data'] is! Map) {
        throw Exception('Invalid login response');
      }
      final data = Map<String, dynamic>.from(resp['data'] as Map);
      final token = data['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('No access token returned');
      }
      ApiService.setToken(token);
      authData = data;
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
        if (d is Map) myInfo = Map<String, dynamic>.from(d);
      }),
      _safeGet('/Reports/HomePageStats').then((d) {
        if (d is Map) homeStats = Map<String, dynamic>.from(d);
      }),
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
    futures.add(_safePostRaw('/Outstanding/Fetch').then((d) {
      final list = _findList(d);
      if (list != null) {
        outstandingList = list;
        debugPrint('💰 Outstanding loaded: ${list.length} records, '
            'sum=${dueAmount.toStringAsFixed(2)}');
      } else {
        debugPrint('💰 Outstanding: no list found in response shape: '
            '${d.runtimeType}');
      }
    }));
    await Future.wait(futures);
  }

  /// POST helper that returns the raw response (without auto-unwrapping
  /// `data`). [_findList] is more flexible about response shapes.
  Future<dynamic> _safePostRaw(String endpoint,
      [Map<String, dynamic> body = const {}]) async {
    try {
      return await ApiService.post(endpoint, body);
    } catch (e) {
      debugPrint('Failed POST $endpoint: $e');
      return null;
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

  Future<void> _registerPushToken() async {
    try {
      final branchId = authData?['branchId'] ?? authData?['branchID'] ?? 0;
      // FCM not wired — send a stub so the endpoint is exercised.
      await ApiService.post('/Profile/UpdateToken/$branchId', <String, dynamic>{
        'token': 'flutter-stub-token',
        'deviceType': 'android',
      });
    } catch (e) {
      debugPrint('UpdateToken failed: $e');
    }
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

  /// Switch the active student profile in-place. Calls
  /// `POST /Account/ChangeStudent`, swaps the bearer token via
  /// [ApiService.setToken], then re-runs [_loadAll] so every screen
  /// re-renders with the new student's data.
  Future<bool> switchStudent(Object studentId) async {
    if (!isLoggedIn) return false;
    pauseNotificationPolling();
    loading = true;
    notifyListeners();
    try {
      final oldToken = (authData?['accessToken'] ?? '').toString();
      final resp = await ApiService.post('/Account/ChangeStudent', {
        'studentId': studentId,
        'accessToken': oldToken,
      });
      Map<String, dynamic>? newData;
      if (resp is Map && resp['data'] is Map) {
        newData = Map<String, dynamic>.from(resp['data'] as Map);
      } else if (resp is Map) {
        newData = Map<String, dynamic>.from(resp);
      }
      if (newData == null) throw Exception('ChangeStudent returned no data');

      final newToken = (newData['accessToken'] ?? oldToken).toString();
      if (newToken.isNotEmpty) ApiService.setToken(newToken);
      authData = newData;

      // Clear stale per-student data before re-fetching.
      myInfo = null;
      homeStats = null;
      clubStats = null;
      notifications = null;
      studentAddtnlInfo = null;
      outstandingList = null;

      await _loadAll();
      _previousUnread = unreadNotifications;
      return true;
    } catch (e) {
      error = e.toString();
      debugPrint('switchStudent failed: $e');
      return false;
    } finally {
      loading = false;
      resumeNotificationPolling();
      notifyListeners();
    }
  }

  /// Switch the active branch / club (works for both student & instructor).
  /// Calls `POST /Account/ChangeClub`, swaps the bearer token, refreshes data.
  Future<bool> switchBranch(Object branchId, {String? clubCode}) async {
    if (!isLoggedIn) return false;
    pauseNotificationPolling();
    loading = true;
    notifyListeners();
    try {
      final oldToken = (authData?['accessToken'] ?? '').toString();
      final body = <String, dynamic>{
        'branchId': branchId,
        'accessToken': oldToken,
      };
      if (clubCode != null && clubCode.isNotEmpty) body['clubCode'] = clubCode;
      final resp = await ApiService.post('/Account/ChangeClub', body);
      Map<String, dynamic>? newData;
      if (resp is Map && resp['data'] is Map) {
        newData = Map<String, dynamic>.from(resp['data'] as Map);
      } else if (resp is Map) {
        newData = Map<String, dynamic>.from(resp);
      }
      if (newData == null) throw Exception('ChangeClub returned no data');

      final newToken = (newData['accessToken'] ?? oldToken).toString();
      if (newToken.isNotEmpty) ApiService.setToken(newToken);
      authData = newData;

      myInfo = null;
      homeStats = null;
      clubStats = null;
      notifications = null;
      studentAddtnlInfo = null;
      outstandingList = null;

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
    authData = null;
    myInfo = null;
    homeStats = null;
    clubStats = null;
    notifications = null;
    studentAddtnlInfo = null;
    outstandingList = null;
    unreadNotifications = 0;
    _previousUnread = 0;
    ApiService.clearToken();
    notifyListeners();
  }
}
