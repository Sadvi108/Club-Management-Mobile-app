// Generates the user-guide screenshots.
//
//   flutter test tool/capture_guide_shots.dart --dart-define=CAPTURE=true
//
// It lives in tool/ and NOT in test/ on purpose: `flutter test` auto-discovers everything
// under test/, and the hang described below stalled the whole suite. Nothing here runs
// unless you invoke this file by path.
//
// KNOWN LIMITATION — the capture itself works and is fast, but the test harness does not
// terminate afterwards: the first shot is written correctly within seconds, then the run
// hangs and every later test reports "did not complete". Ruled out as causes: the
// notification method channel (mocked), the UserSession poll timer (cancelled in
// tearDown), an undisposed ui.Image, and a still-mounted widget tree. Cause not yet
// identified.
//
// Practical consequence: ONE shot per invocation, and the process needs killing after.
// Capture a specific screen with:
//
//   flutter test tool/capture_guide_shots.dart --dart-define=CAPTURE=true --plain-name offers
//
// The PNG lands before the hang, so the output is still correct — just not batchable.
//
// WHY A TEST AND NOT A DEVICE: a widget test renders the real screens deterministically at
// a fixed size, with no phone, no login and — critically — no real member's data. The Expo
// guide shipped screenshots containing a real name, phone number and member QR before that
// was caught. Everything here is obviously fictional and lives in this file, so a shot can
// never contain anyone's actual record.
//
// SCOPE — only screens that render fully from seeded state, for two reasons:
//   * API-driven screens (schedule, payments, chat) would capture their loading or empty
//     state, and a picture of an empty screen teaches a reader nothing.
//   * Screens that touch a PLUGIN at load — AutoPayScreen calls into
//     flutter_local_notifications — hang here even with the method channel mocked, and the
//     capture comes out as a spinner. Mocking the channel was not enough; whatever the
//     plugin awaits underneath never completes in the test binding. Not worth more time
//     for one picture, so Auto Pay stays text-only. If you revisit it, the symptom is a
//     ~10-minute hang per test and a 10KB PNG of a progress indicator.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dclix_app/screens/more_screen.dart';
import 'package:dclix_app/screens/offers_screen.dart';
import 'package:dclix_app/services/user_session.dart';

const _capture = bool.fromEnvironment('CAPTURE');

/// Fonts ship with the Flutter SDK. Without them every glyph renders as a filled box and
/// every Material icon as an empty square — fine for layout tests, useless for a picture.
const _sdkCache = r'C:\flutter\bin\cache';

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) throw StateError('font not found: $path');
  final loader = FontLoader(family)
    ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  await loader.load();
}

/// Entirely invented. No field here corresponds to a real member.
void _seedFixture() {
  final s = UserSession.instance;
  s.myInfo = {
    'name': 'Alex Tan',
    'registrationNo': 'DCX-0001',
    'currentGrade': 'Green Belt',
    'tCenterName': 'Sample Training Centre',
    'eCenterName': 'Sample Exam Centre',
    'instructorName': 'Sensei Sample',
    'handPhone': '000-0000000',
    'email': 'member@example.com',
    'clubName': 'D-CLIX Sample Academy',
  };
  s.homeStats = {
    'myoffers': [
      {
        'code': 'SAMPLE10',
        'title': 'Members save 10% on uniforms',
        'description': 'Show this screen at the counter. Sample offer.',
        'expiryDate': '2099-12-31T00:00:00',
      },
      {
        'code': 'SAMPLE20',
        'title': 'Bring a friend — free trial class',
        'description': 'Sample offer for illustration only.',
      },
    ],
  };
  s.studentAddtnlInfo = {'schoolname': 'Sample School', 'bloodtype': 'O+'};
}

Future<void> _shot(WidgetTester tester, String name, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    ChangeNotifierProvider<UserSession>.value(
      value: UserSession.instance,
      child: MaterialApp(
        // A plain theme on purpose. AppTheme.light() constructs GoogleFonts, which fires
        // an async font download that the test HttpClient answers with a 400 — and the
        // placeholder font comes back. context.appColors falls back to AppColors.light
        // when the extension is absent, so the palette is still the real one.
        theme: ThemeData(fontFamily: 'Roboto'),
        home: RepaintBoundary(key: key, child: screen),
      ),
    ),
  );
  // NOT pumpAndSettle: a screen showing a CircularProgressIndicator never settles — the
  // spinner animates forever — and each capture sat there until the 10-minute timeout.
  // Three fixed pumps is enough for initState futures to complete and lay out.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
  }

  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  // An undisposed ui.Image keeps native memory (and the binding) alive past the test.
  image.dispose();
  final out = File('assets/guide/$name.png');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('shot: ${out.path} (${out.lengthSync()} bytes)');

  // Unmount before the test ends: leaving the screen mounted leaves its listeners
  // attached to the UserSession singleton, which outlives the test.
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  // `testWidgets` takes a bool skip; `test` takes a String reason. Both are used below.
  const skipShots = !_capture;
  const skipReason =
      _capture ? null : 'pass --dart-define=CAPTURE=true to regenerate guide shots';

  setUpAll(() async {
    if (!_capture) return;
    await _loadFont('MaterialIcons',
        '$_sdkCache\\dart-sdk\\bin\\resources\\devtools\\assets\\fonts\\MaterialIcons-Regular.otf');
    await _loadFont(
        'Roboto', '$_sdkCache\\artifacts\\material_fonts\\roboto-regular.ttf');
    // AutoPayScreen and the notification prefs read SharedPreferences; without a mock the
    // platform channel throws and the screen stays on its spinner.
    SharedPreferences.setMockInitialValues({
      // Captured with the feature ON, so the shot shows the real settings rather than a
      // bare toggle. Values match the screen's own defaults.
      'dclix.autopay.v1':
          '{"enabled":true,"dayOfMonth":1,"monthsAhead":1,"payeeIds":[],"lastRemindedMs":null}',
    });

    // flutter_local_notifications has no platform side in a test, so every call hangs
    // unanswered — which is why the Auto Pay capture came out as a spinner, and why each
    // test then sat until teardown timed out. Answer the channel instead.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => switch (call.method) {
        'pendingNotificationRequests' => <Map<String, Object?>>[],
        'areNotificationsEnabled' => true,
        'requestNotificationsPermission' => true,
        'requestPermissions' => true,
        _ => null,
      },
    );
    _seedFixture();
  });

  // UserSession is a singleton that starts a periodic notification poll. A live Timer
  // keeps the test binding from ever finishing, so each capture wrote its PNG and then
  // hung until the harness gave up — the shot itself was never the slow part.
  tearDown(() => UserSession.instance.stopNotificationPolling());

  testWidgets('everything', (t) => _shot(t, 'more', const MoreScreen()), skip: skipShots);
  testWidgets('offers', (t) => _shot(t, 'offers', const OffersScreen()), skip: skipShots);

  test('no captured shot contains a real-looking identifier', () {
    // A cheap standing guard on the fixture. If someone later seeds this from a live
    // session, the names below stop matching and this fails.
    final s = UserSession.instance;
    if (s.myInfo == null) return;
    expect(s.myInfo!['name'], 'Alex Tan');
    expect('${s.myInfo!['handPhone']}', matches(RegExp(r'^0+-0+$')));
  }, skip: skipReason);
}
