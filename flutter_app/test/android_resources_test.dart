// Android resources referenced from XML must actually exist.
//
// network_security_config.xml points at @raw/uat_apimacuat. If that resource is missing,
// the build fails with "resource raw/uat_apimacuat not found" — which is the GOOD case.
// The bad case is subtler: the file was ignored by a blanket `*.pem` rule in .gitignore, so
// it existed on the developer's disk and the local APK built and verified fine, while a
// clean checkout could not build at all.
//
// This catches a rename or typo locally. Git tracking itself is caught by CI, which builds
// from a fresh checkout — that is why the workflow is the authority, not this test.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final configFile =
      File('android/app/src/main/res/xml/network_security_config.xml');

  test('the network security config exists', () {
    expect(configFile.existsSync(), isTrue);
  });

  test('every @raw resource it references exists on disk', () {
    final xml = configFile.readAsStringSync();
    final refs = RegExp(r'@raw/([A-Za-z0-9_]+)')
        .allMatches(xml)
        .map((m) => m.group(1)!)
        .toSet();
    expect(refs, isNotEmpty, reason: 'no @raw reference found — did the config change?');

    final rawDir = Directory('android/app/src/main/res/raw');
    final present = rawDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.split('.').first)
        .toSet();

    final missing = refs.where((r) => !present.contains(r)).toList();
    expect(missing, isEmpty,
        reason: 'referenced but not in res/raw: $missing (present: $present)');
  });

  test('the UAT certificate is a certificate, not a private key', () {
    // It is committed deliberately, against a blanket *.pem ignore. That is only
    // defensible because it is a server's PUBLIC certificate — the same bytes the host
    // sends every client. A private key slipping in here would be a serious leak.
    final pem = File('android/app/src/main/res/raw/uat_apimacuat.pem');
    expect(pem.existsSync(), isTrue);
    final text = pem.readAsStringSync();
    expect(text, contains('BEGIN CERTIFICATE'));
    expect(text, isNot(contains('PRIVATE KEY')));
  });
}
