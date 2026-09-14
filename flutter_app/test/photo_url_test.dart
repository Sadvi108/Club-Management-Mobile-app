// Profile photo URL resolution.
//
// This is the bug that shipped: the API returns photo paths relative far more often than
// absolute, the getter required "http", and every relative path fell through to the club
// logo. On a real phone that reads as "my photo upload failed" — and it looked fine on
// localhost, where the served path happened to resolve.
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/user_session.dart';

void main() {
  const base = 'http://apimac.zyncbook.com';
  String r(String raw) => UserSession.resolvePhotoUrl(raw, base: base);

  test('an absolute URL is left alone', () {
    expect(r('https://cdn.example.com/a.jpg'), 'https://cdn.example.com/a.jpg');
    expect(r('http://apimac.zyncbook.com/x.png'),
        'http://apimac.zyncbook.com/x.png');
  });

  test('a rooted server path is prefixed with the API host', () {
    expect(r('/Uploads/DP/123.jpg'), '$base/Uploads/DP/123.jpg');
  });

  test('a path with no leading slash still gets exactly one', () {
    expect(r('Uploads/DP/123.jpg'), '$base/Uploads/DP/123.jpg');
  });

  test('Windows separators from the server are normalised', () {
    // The backend is ASP.NET on Windows and sometimes hands back a filesystem-style path.
    expect(r(r'Uploads\DP\123.jpg'), '$base/Uploads/DP/123.jpg');
    expect(r(r'\Uploads\DP\123.jpg'), '$base/Uploads/DP/123.jpg');
  });

  test('a data URI is already renderable and must not be prefixed', () {
    const uri = 'data:image/png;base64,iVBORw0KGgo=';
    expect(r(uri), uri);
  });

  test('empty and whitespace mean no photo, not a broken URL', () {
    expect(r(''), '');
    expect(r('   '), '');
  });

  test('surrounding whitespace does not produce a 404 URL', () {
    expect(r('  /Uploads/DP/1.jpg  '), '$base/Uploads/DP/1.jpg');
  });

  group('studentPhoto', () {
    test('a relative myInfo path is rendered, not swapped for the club logo',
        () {
      final s = UserSession.instance;
      s.myInfo = {
        'photo': '/Uploads/DP/77.jpg',
        'clubPic': 'http://cdn/club.png'
      };
      s.studentAddtnlInfo = null;
      expect(s.studentPhoto, endsWith('/Uploads/DP/77.jpg'));
      expect(s.studentPhoto, isNot(contains('club.png')));
    });

    test('with no student photo the UI can show initials, not the club logo',
        () {
      final s = UserSession.instance;
      s.myInfo = {'clubPic': '/Uploads/Club/1.png'};
      s.studentAddtnlInfo = null;
      s.authData = null;
      expect(s.studentPhoto, isEmpty);
    });

    test('an empty photo field is skipped rather than returned as a blank URL',
        () {
      final s = UserSession.instance;
      s.myInfo = {'photo': '', 'profilePic': '/Uploads/DP/9.jpg'};
      s.studentAddtnlInfo = null;
      expect(s.studentPhoto, endsWith('/Uploads/DP/9.jpg'));
    });
  });
}
