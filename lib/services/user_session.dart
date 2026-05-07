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
  int unreadNotifications = 0;
  bool loading = false;
  String? error;

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

  num get dueAmount => (homeStats?['dueAmount'] as num?) ?? 0;
  int get invoiceCount => (homeStats?['invoiceCount'] as int?) ?? 0;

  Future<bool> login({
    required String username,
    required String password,
    required int userType,
    int accessMethod = 0,
    String deviceType = 'mobile',
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final resp = await ApiService.post('/Account/Authenticate', {
        'username': username,
        'password': password,
        'userType': userType,
        'accessMethod': accessMethod,
        'deviceType': deviceType,
      });
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
    await Future.wait([
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
      _safeGet('/Profile/StudentAddtnlInfo').then((d) {
        if (d is Map) studentAddtnlInfo = Map<String, dynamic>.from(d);
      }),
    ]);
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
    unreadNotifications = 0;
    ApiService.clearToken();
    notifyListeners();
  }
}
