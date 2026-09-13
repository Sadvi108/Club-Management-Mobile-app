import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dclix_app/services/api_service.dart';
import 'package:dclix_app/services/live_refresh.dart';

class Probe extends StatefulWidget {
  final Future<void> Function() refresh;
  const Probe(this.refresh, {super.key});
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> with LiveRefreshMixin<Probe> {
  @override
  Future<void> refreshLiveData() => widget.refresh();
  @override
  Widget build(BuildContext context) => const Scaffold(body: TextField());
}

void main() {
  setUp(() => LiveRefresh.enabled = true);
  tearDown(() => LiveRefresh.enabled = false);

  testWidgets(
      'refreshes on interval, preserves drafts and pauses while backgrounded',
      (tester) async {
    var calls = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp(home: Probe(() async {
      calls++;
    })));
    await tester.enterText(find.byType(TextField), 'Keep my draft');
    await tester.pump(const Duration(seconds: 14));
    expect(calls, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    expect(find.text('Keep my draft'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'does not overlap requests and refreshes after returning to a route',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    var calls = 0;
    Completer<void>? pending;
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [LiveRefreshNavigatorObserver()],
        home: Probe(() {
          calls++;
          return (pending = Completer<void>()).future;
        })));
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 1);
    pending!.complete();
    await tester.pump();
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covered'))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 1);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls, 2);
    pending!.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('only a confirmed QR check-in refreshes attendance readers',
      (tester) async {
    final old = ApiService.client;
    addTearDown(() => ApiService.client = old);
    dynamic data = {
      'status': 1,
      'tTimeSession': [
        {'id': 7, 'text': 'Class'}
      ]
    };
    ApiService.client = MockClient((_) async =>
        http.Response(jsonEncode({'status': 200, 'data': data}), 200));
    var refreshes = 0;
    await tester.pumpWidget(MaterialApp(home: Probe(() async {
      refreshes++;
    })));
    await ApiService.post(
        '/Attendance/Add', {'qrContent': 'fictional', 'tTimeId': 0});
    await tester.pump();
    expect(refreshes, 0);
    data = {'status': -1, 'message': 'Rejected'};
    await ApiService.post('/Attendance/Add', {});
    await tester.pump();
    expect(refreshes, 0);
    data = {};
    await ApiService.post('/Attendance/Add', {});
    await tester.pump();
    expect(refreshes, 0);
    data = {'status': 0};
    await ApiService.post('/Attendance/Add', {});
    await tester.pump();
    expect(refreshes, 1);
    // Checkout URL creation must not be reported as settlement.
    await ApiService.post('/Bcpg/PayInvoices', {});
    await tester.pump();
    expect(refreshes, 1);
    await tester.pumpWidget(const SizedBox());
  });

  test('late response from a previous account is rejected', () async {
    final old = ApiService.client;
    final response = Completer<http.Response>();
    ApiService.client = MockClient((_) => response.future);
    addTearDown(() {
      ApiService.client = old;
      ApiService.clearToken();
    });
    ApiService.setToken('fictional-account-a');
    final request = ApiService.get('/Profile/MyInfo');
    final assertion = expectLater(request, throwsA(isA<ApiException>()));
    ApiService.setToken('fictional-account-b');
    response.complete(http.Response('{"data":{"name":"Old account"}}', 200));
    await assertion;
  });
}
