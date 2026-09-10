// The version shown in the app must match the version that ships.
//
// profile_screen hardcoded "v1.0.0" while pubspec said 1.1.5 — a member reporting "I'm on
// 1.0.0" then sends you looking at the wrong build.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/config/app_version.dart';

void main() {
  test('kAppVersion and kAppBuild match pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true)
        .firstMatch(pubspec);
    expect(m, isNotNull, reason: 'could not find a version: x.y.z+n line in pubspec.yaml');
    expect(kAppVersion, m!.group(1), reason: 'app_version.dart drifted from pubspec');
    expect(kAppBuild, int.parse(m.group(2)!),
        reason: 'app_version.dart build number drifted from pubspec');
  });

  test('the build number stays above the Expo app it replaces', () {
    // Both ship as com.dclix.clubapp. Android refuses to install a lower versionCode, so
    // dropping below the Expo release (2.11.1+17) would fail to update existing installs.
    expect(kAppBuild, greaterThan(17));
  });
}
