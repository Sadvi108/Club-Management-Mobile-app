// The user guide is instructions a member acts on, so the content is worth asserting.
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/data/guide_content.dart';

void main() {
  test('all 11 pages survived the port', () {
    expect(kGuideSteps, hasLength(11));
    expect(kGuideSteps.map((s) => s.key).toSet(), hasLength(11),
        reason: 'duplicate keys would mean a page was overwritten');
  });

  test('every page has a title, an intro and numbered steps', () {
    for (final s in kGuideSteps) {
      expect(s.title.trim(), isNotEmpty, reason: '${s.key} has no title');
      expect(s.intro.trim(), isNotEmpty, reason: '${s.key} has no intro');
      expect(s.details, isNotEmpty, reason: '${s.key} has no steps');
      for (final d in s.details) {
        expect(d.title.trim(), isNotEmpty, reason: '${s.key} step ${d.n} has no title');
        expect(d.text.trim(), isNotEmpty, reason: '${s.key} step ${d.n} has no text');
      }
    }
  });

  test('step numbers run 1..n with no gaps or repeats', () {
    for (final s in kGuideSteps) {
      expect(s.details.map((d) => d.n).toList(),
          List.generate(s.details.length, (i) => i + 1),
          reason: '${s.key} is misnumbered');
    }
  });

  test('the guide does not promise Auto Pay', () {
    // Auto Pay is not built in this app: the Expo screen is a disclosed UI shell and
    // Club.Api has no recurring-payment routes. Telling a member their fees settle
    // automatically would have them stop paying.
    for (final s in kGuideSteps) {
      final blob = [
        s.intro,
        s.note,
        ...s.tips,
        ...s.details.map((d) => '${d.title} ${d.text}'),
      ].join(' ').toLowerCase();
      expect(blob, isNot(contains('auto pay')), reason: '${s.key} mentions Auto Pay');
      expect(blob, isNot(contains('automatically')),
          reason: '${s.key} implies payments happen on their own');
    }
  });

  test('the sign-in page comes first', () {
    // It is linked from the login screen, so a reader with no account starts there.
    expect(kGuideSteps.first.key, 'signin');
  });

  test('the pages that carry a warning still carry it', () {
    final withNotes = kGuideSteps.where((s) => s.note.trim().isNotEmpty).map((s) => s.key);
    expect(withNotes, containsAll(['checkin', 'payments', 'profile']));
  });
}
