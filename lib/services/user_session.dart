import 'package:flutter/foundation.dart';
import 'api_service.dart';

class UserSession extends ChangeNotifier {
  static final UserSession instance = UserSession._();
  UserSession._();

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

  /// Total amount due. For instructors this is the SUM of every unpaid
  /// invoice across the branch (loaded from `/Outstanding/Fetch`). For
  /// students it's the personal `dueAmount` from `/Reports/HomePageStats`.
  num get dueAmount {
    // Instructors → real-time sum from the outstanding list
    if (isInstructor && outstandingList != null) {
      num total = 0;
      for (final row in outstandingList!) {
        if (row is Map) {
          for (final k in ['dueAmount', 'amount', 'dueAmt', 'outstandingAmount',
                            'balance', 'amountDue', 'totalAmount', 'value']) {
            final v = row[k];
            if (v is num) { total += v; break; }
            if (v is String) {
              final n = num.tryParse(v.replaceAll(',', ''));
              if (n != null) { total += n; break; }
            }
          }
        }
      }
      return total;
    }
    // Students → homeStats keys
    final m = homeStats;
    if (m == null) return 0;
    for (final k in ['dueAmount', 'dueAmt', 'totalDue', 'totalAmount', 'outstandingAmount']) {
      final v = m[k];
      if (v is num) return v;
    }
    return 0;
  }

  /// Number of unpaid invoices. Instructors → outstanding list length.
  /// Students → homeStats keys.
  int get invoiceCount {
    if (isInstructor && outstandingList != null) {
      return outstandingList!.length;
    }
    final m = homeStats;
    if (m == null) return 0;
    for (final k in ['invoiceCount', 'pendingInvoice', 'dueInvoice', 'invoices', 'pendingCount']) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return 0;
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
    // Outstanding/Fetch is the real source of unpaid invoices for
    // instructors. /Reports/HomePageStats does NOT include dueAmount /
    // invoiceCount for instructor accounts, so compute them from this list.
    if (isInstructor) {
      futures.add(_safePost('/Outstanding/Fetch').then((d) {
        if (d is List) outstandingList = d;
      }));
    }
    await Future.wait(futures);
  }

  Future<dynamic> _safePost(String endpoint,
      [Map<String, dynamic> body = const {}]) async {
    try {
      final resp = await ApiService.post(endpoint, body);
      if (resp is Map && resp.containsKey('data')) return resp['data'];
      return resp;
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
    authData = null;
    myInfo = null;
    homeStats = null;
    clubStats = null;
    notifications = null;
    studentAddtnlInfo = null;
    outstandingList = null;
    unreadNotifications = 0;
    ApiService.clearToken();
    notifyListeners();
  }
}
