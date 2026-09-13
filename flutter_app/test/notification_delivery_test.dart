import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dclix_app/services/notification_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const mark = 'dclix.notif.lastSeen.v1.90001';
  var allowed = true, failShow = false;
  final shown = <int>[];
  Map<String, dynamic> row(int id) =>
      {'id': id, 'text': 'Fictional test update', 'value': 'Sample body'};
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    NotificationService.resetForTest();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    allowed = true;
    failShow = false;
    shown.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'getNotificationAppLaunchDetails':
          return {'notificationLaunchedApp': false};
        case 'areNotificationsEnabled':
          return allowed;
        case 'show':
          if (failShow) throw PlatformException(code: 'delivery_failed');
          shown.add((call.arguments as Map)['id'] as int);
          return null;
        default:
          return null;
      }
    });
  });
  tearDown(() {
    NotificationService.resetForTest();
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
  test('empty first inbox seeds the mark so the first arrival alerts',
      () async {
    await NotificationService.alertForNew(userId: 90001, rows: []);
    expect((await SharedPreferences.getInstance()).getInt(mark), 0);
    await NotificationService.alertForNew(userId: 90001, rows: [row(1)]);
    expect(shown, [1]);
    expect((await SharedPreferences.getInstance()).getInt(mark), 1);
    await NotificationService.alertForNew(userId: 90001, rows: [row(1)]);
    expect(shown, [1]);
  });
  test('denied OS permission and failed delivery do not swallow messages',
      () async {
    await NotificationService.alertForNew(userId: 90001, rows: []);
    allowed = false;
    await NotificationService.alertForNew(userId: 90001, rows: [row(1)]);
    expect(shown, isEmpty);
    expect((await SharedPreferences.getInstance()).getInt(mark), 0);
    allowed = true;
    failShow = true;
    await NotificationService.alertForNew(userId: 90001, rows: [row(1)]);
    expect((await SharedPreferences.getInstance()).getInt(mark), 0);
    failShow = false;
    await NotificationService.alertForNew(userId: 90001, rows: [row(1)]);
    expect(shown, [1]);
    expect((await SharedPreferences.getInstance()).getInt(mark), 1);
  });
}
