// Alert rules. Ported from the React Native implementation together with the two
// silent-loss bugs found there, so they cannot reappear here.
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/notification_prefs.dart';
import 'package:dclix_app/services/notification_diff.dart';

DateTime _at(int hour) => DateTime(2026, 9, 3, hour, 30);

Map<String, dynamic> _fee(int id) => {
      'id': id,
      'notificationType': '',
      'text': 'Reminder',
      'value': 'Sila jelaskan yuran tertunggak RM$id.00 anda secepat mungkin',
    };
Map<String, dynamic> _cls(int id) => {
      'id': id,
      'notificationType': '',
      'text': 'Class Activity',
      'value': 'Sukma training',
    };

void main() {
  group('categorise', () {
    test('English fee wording -> payments', () {
      expect(categorise(subject: 'Invoice', body: 'Your April invoice is ready'),
          NotifCategory.payments);
      expect(categorise(body: 'Outstanding fees reminder'), NotifCategory.payments);
    });

    test('the LIVE Malay payloads -> payments', () {
      // On prod notificationType is always empty and the body is Malay. Keying off the
      // type, or matching English only, filed every real fee reminder under "general" —
      // so muting announcements silently killed fee alerts.
      expect(
          categorise(
              notificationType: '',
              subject: 'Reminder',
              body: 'Sila jelaskan yuran tertunggak RM85.00 anda secepat mungkin'),
          NotifCategory.payments);
    });

    test('class wording -> classes', () {
      expect(categorise(subject: 'Class Activity', body: 'Sukma training'),
          NotifCategory.classes);
      expect(categorise(subject: 'ClassReplacement', body: ''), NotifCategory.classes);
      expect(categorise(body: 'Belt grading on Sunday'), NotifCategory.classes);
      expect(categorise(body: 'Jadual kelas baharu'), NotifCategory.classes);
    });

    test('anything unrecognised still alerts, as general', () {
      expect(categorise(subject: 'Reminder', body: ''), NotifCategory.general);
      expect(categorise(), NotifCategory.general);
    });

    test('a fee notice about a class is still a fee notice', () {
      expect(categorise(subject: 'Reminder', body: 'Yuran kelas tertunggak'),
          NotifCategory.payments);
    });
  });

  group('quiet hours', () {
    const night = NotifPrefs(quietEnabled: true, quietStartHour: 22, quietEndHour: 7);
    const day = NotifPrefs(quietEnabled: true, quietStartHour: 9, quietEndHour: 17);

    test('an overnight window wraps midnight', () {
      expect(inQuietHours(night, _at(23)), isTrue);
      expect(inQuietHours(night, _at(2)), isTrue);
      expect(inQuietHours(night, _at(6)), isTrue);
      expect(inQuietHours(night, _at(7)), isFalse);
      expect(inQuietHours(night, _at(13)), isFalse);
      expect(inQuietHours(night, _at(21)), isFalse);
    });

    test('a same-day window does not wrap', () {
      expect(inQuietHours(day, _at(12)), isTrue);
      expect(inQuietHours(day, _at(20)), isFalse);
    });

    test('start == end is an empty window, never a 24h mute', () {
      const degenerate =
          NotifPrefs(quietEnabled: true, quietStartHour: 8, quietEndHour: 8);
      expect(inQuietHours(degenerate, _at(8)), isFalse);
    });

    test('disabled means never quiet', () {
      expect(inQuietHours(NotifPrefs.defaults, _at(3)), isFalse);
    });
  });

  group('shouldAlert / isAllowed', () {
    test('defaults alert', () {
      expect(shouldAlert(NotifPrefs.defaults, NotifCategory.payments, _at(12)), isTrue);
    });
    test('the master switch blocks everything', () {
      expect(shouldAlert(const NotifPrefs(enabled: false), NotifCategory.payments, _at(12)),
          isFalse);
    });
    test('a muted category blocks only itself', () {
      const p = NotifPrefs(categories: {
        NotifCategory.payments: false,
        NotifCategory.classes: true,
        NotifCategory.general: true,
      });
      expect(shouldAlert(p, NotifCategory.payments, _at(12)), isFalse);
      expect(shouldAlert(p, NotifCategory.classes, _at(12)), isTrue);
    });
    test('isAllowed ignores the clock; shouldAlert does not', () {
      const night = NotifPrefs(quietEnabled: true, quietStartHour: 22, quietEndHour: 7);
      expect(isAllowed(night, NotifCategory.general), isTrue);
      expect(shouldAlert(night, NotifCategory.general, _at(23)), isFalse);
    });
  });

  group('planAlerts — the two silent-loss bugs', () {
    const mutedFees = NotifPrefs(categories: {
      NotifCategory.payments: false,
      NotifCategory.classes: true,
      NotifCategory.general: true,
    });

    test('muting fees still alerts the older class rows', () {
      // BUG 1: capping before filtering took the 3 newest (all fees), found them muted,
      // alerted nothing, and still advanced the mark — losing both class rows for good.
      final plan = planAlerts(
        rows: [_cls(1), _cls(2), _fee(3), _fee(4), _fee(5)],
        lastSeen: 0,
        prefs: mutedFees,
        now: _at(12),
      );
      expect(plan.show.map((r) => r['id']).toList(), [1, 2]);
      expect(plan.newLastSeen, 5);
    });

    test('the cap keeps the newest wanted rows and summarises the rest', () {
      final plan = planAlerts(
        rows: [_cls(1), _cls(2), _cls(3), _cls(4), _cls(5)],
        lastSeen: 0,
        prefs: NotifPrefs.defaults,
        now: _at(12),
      );
      expect(plan.show.map((r) => r['id']).toList(), [3, 4, 5]);
      expect(plan.capped, 2);
    });

    test('a fully muted batch is discarded on purpose and the mark advances', () {
      final plan = planAlerts(
        rows: [_fee(7), _fee(8)],
        lastSeen: 0,
        prefs: mutedFees,
        now: _at(12),
      );
      expect(plan.show, isEmpty);
      expect(plan.deferred, isFalse);
      expect(plan.newLastSeen, 8);
    });

    test('quiet hours DEFER: nothing alerts and the mark is held', () {
      // BUG 2: advancing the mark here deleted the alerts instead of postponing them.
      const night = NotifPrefs(quietEnabled: true, quietStartHour: 22, quietEndHour: 7);
      final plan = planAlerts(
        rows: [_cls(1), _cls(2)],
        lastSeen: 0,
        prefs: night,
        now: _at(23),
      );
      expect(plan.show, isEmpty);
      expect(plan.deferred, isTrue);
      expect(plan.newLastSeen, isNull, reason: 'the mark must not move');
    });

    test('the same batch alerts once quiet hours end', () {
      const night = NotifPrefs(quietEnabled: true, quietStartHour: 22, quietEndHour: 7);
      final plan = planAlerts(
        rows: [_cls(1), _cls(2)],
        lastSeen: 0,
        prefs: night,
        now: _at(12),
      );
      expect(plan.show.map((r) => r['id']).toList(), [1, 2]);
      expect(plan.newLastSeen, 2);
    });

    test('quiet hours do not defer a batch that is entirely muted', () {
      const night = NotifPrefs(quietEnabled: true, quietStartHour: 22, quietEndHour: 7,
          categories: {
            NotifCategory.payments: false,
            NotifCategory.classes: true,
            NotifCategory.general: true,
          });
      final plan =
          planAlerts(rows: [_fee(9)], lastSeen: 0, prefs: night, now: _at(23));
      expect(plan.deferred, isFalse, reason: 'otherwise it is rescanned forever');
      expect(plan.newLastSeen, 9);
    });

    test('first run seeds the mark without alerting the backlog', () {
      final plan = planAlerts(
        rows: [_cls(1), _fee(2), _cls(3)],
        lastSeen: null,
        prefs: NotifPrefs.defaults,
        now: _at(12),
      );
      expect(plan.show, isEmpty);
      expect(plan.newLastSeen, 3);
    });

    test('a huge row list does not overflow', () {
      final many = List.generate(200000, (i) => _cls(i + 1));
      final plan = planAlerts(
        rows: many, lastSeen: 199997, prefs: NotifPrefs.defaults, now: _at(12));
      expect(plan.newLastSeen, 200000);
      expect(plan.show, hasLength(3));
    });

    test('malformed rows are ignored rather than crashing the poll', () {
      final plan = planAlerts(
        rows: [null, 'x', {}, {'id': 'abc'}, _cls(5)],
        lastSeen: 0,
        prefs: NotifPrefs.defaults,
        now: _at(12),
      );
      expect(plan.show.map((r) => r['id']).toList(), [5]);
    });
  });

  group('display helpers', () {
    test('title falls back when the subject is empty', () {
      expect(titleOf({'text': 'Reminder'}), 'Reminder');
      expect(titleOf({'text': ''}), 'Club notification');
    });
    test('body strips markup the admin panel sometimes sends', () {
      expect(bodyOf({'value': '<p>Fee&nbsp;due</p>'}), 'Fee due');
    });
  });

  group('NotifPrefs serialisation', () {
    test('round-trips', () {
      const p = NotifPrefs(sound: false, quietEnabled: true, quietStartHour: 21);
      final back = NotifPrefs.fromJson(p.toJson());
      expect(back.sound, isFalse);
      expect(back.quietEnabled, isTrue);
      expect(back.quietStartHour, 21);
    });
    test('out-of-range hours fall back to defaults', () {
      final back = NotifPrefs.fromJson({
        'quietHours': {'enabled': true, 'startHour': 99, 'endHour': -1}
      });
      expect(back.quietStartHour, 22);
      expect(back.quietEndHour, 7);
    });
    test('a corrupt blob yields defaults, not no-alerts', () {
      expect(NotifPrefs.fromJson('garbage').enabled, isTrue);
      expect(NotifPrefs.fromJson(null).sound, isTrue);
    });
  });
}
