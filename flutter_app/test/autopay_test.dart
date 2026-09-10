// Auto Pay scheduling. Dates are where reminder features quietly fail — a "31st" that
// skips February, a December that never rolls into January, a reminder that fires twice.
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/autopay.dart';

void main() {
  group('nextReminder', () {
    test('later this month when the day has not passed', () {
      const p = AutoPayPrefs(enabled: true, dayOfMonth: 15);
      final next = nextReminder(p, DateTime(2026, 3, 2, 8));
      expect(next, DateTime(2026, 3, 15, kAutoPayHour));
    });

    test('next month once the day has passed', () {
      const p = AutoPayPrefs(enabled: true, dayOfMonth: 15);
      final next = nextReminder(p, DateTime(2026, 3, 20));
      expect(next, DateTime(2026, 4, 15, kAutoPayHour));
    });

    test('December rolls into January of the next year', () {
      const p = AutoPayPrefs(enabled: true, dayOfMonth: 5);
      final next = nextReminder(p, DateTime(2026, 12, 20));
      expect(next, DateTime(2027, 1, 5, kAutoPayHour));
    });

    test('the same day but later in the day still moves to next month', () {
      const p = AutoPayPrefs(enabled: true, dayOfMonth: 10);
      // 10:00 is past the 09:00 slot.
      final next = nextReminder(p, DateTime(2026, 3, 10, 10));
      expect(next, DateTime(2026, 4, 10, kAutoPayHour));
    });

    test('the same day but earlier fires today', () {
      const p = AutoPayPrefs(enabled: true, dayOfMonth: 10);
      final next = nextReminder(p, DateTime(2026, 3, 10, 7));
      expect(next, DateTime(2026, 3, 10, kAutoPayHour));
    });

    test('a day past 28 is capped so February is never skipped', () {
      // The whole reason for the cap: a 31st reminder would have no valid date in Feb,
      // Apr, Jun, Sep or Nov, and the member would silently miss those months.
      final p = AutoPayPrefs.fromJson({'dayOfMonth': 31});
      expect(p.dayOfMonth, 28);
      expect(nextReminder(p, DateTime(2026, 2, 1)), DateTime(2026, 2, 28, kAutoPayHour));
    });

    test('a nonsense day falls back into range rather than crashing', () {
      expect(AutoPayPrefs.fromJson({'dayOfMonth': 0}).dayOfMonth, 1);
      expect(AutoPayPrefs.fromJson({'dayOfMonth': -5}).dayOfMonth, 1);
      expect(AutoPayPrefs.fromJson({'dayOfMonth': 'x'}).dayOfMonth, 1);
    });
  });

  group('monthsToSettle', () {
    test('starts at the month AFTER now, never the current one', () {
      // The current month is already invoiced and shows under Fees Due; including it
      // would have the member pay for it twice.
      const p = AutoPayPrefs(monthsAhead: 3);
      expect(monthsToSettle(p, DateTime(2026, 3, 15)),
          [const TermMonth(2026, 4), const TermMonth(2026, 5), const TermMonth(2026, 6)]);
    });

    test('crosses the year boundary correctly', () {
      const p = AutoPayPrefs(monthsAhead: 3);
      expect(monthsToSettle(p, DateTime(2026, 11, 2)),
          [const TermMonth(2026, 12), const TermMonth(2027, 1), const TermMonth(2027, 2)]);
    });

    test('one month ahead is a single month', () {
      const p = AutoPayPrefs(monthsAhead: 1);
      expect(monthsToSettle(p, DateTime(2026, 12, 1)), [const TermMonth(2027, 1)]);
    });

    test('monthsAhead is clamped to 1..6', () {
      expect(AutoPayPrefs.fromJson({'monthsAhead': 99}).monthsAhead, 6);
      expect(AutoPayPrefs.fromJson({'monthsAhead': 0}).monthsAhead, 1);
    });
  });

  group('reminderOverdue', () {
    test('disabled is never overdue', () {
      const p = AutoPayPrefs(enabled: false, dayOfMonth: 1);
      expect(reminderOverdue(p, DateTime(2026, 3, 28)), isFalse);
    });

    test('due and never reminded is overdue', () {
      // Catches the scheduled alert the OS dropped after a reboot or a force-stop.
      const p = AutoPayPrefs(enabled: true, dayOfMonth: 1);
      expect(reminderOverdue(p, DateTime(2026, 3, 5)), isTrue);
    });

    test('already reminded this month is not overdue again', () {
      final p = AutoPayPrefs(
        enabled: true,
        dayOfMonth: 1,
        lastRemindedMs: DateTime(2026, 3, 1, 9).millisecondsSinceEpoch,
      );
      expect(reminderOverdue(p, DateTime(2026, 3, 5)), isFalse);
    });

    test('last month\'s reminder does not satisfy this month', () {
      final p = AutoPayPrefs(
        enabled: true,
        dayOfMonth: 1,
        lastRemindedMs: DateTime(2026, 2, 1, 9).millisecondsSinceEpoch,
      );
      expect(reminderOverdue(p, DateTime(2026, 3, 5)), isTrue);
    });

    test('before the due moment it is not overdue', () {
      const p = AutoPayPrefs(enabled: true, dayOfMonth: 20);
      expect(reminderOverdue(p, DateTime(2026, 3, 19, 23)), isFalse);
    });
  });

  group('serialisation', () {
    test('round-trips', () {
      const p = AutoPayPrefs(
          enabled: true, dayOfMonth: 12, monthsAhead: 3, payeeIds: [7, 9]);
      final back = AutoPayPrefs.fromJson(p.toJson());
      expect(back.enabled, isTrue);
      expect(back.dayOfMonth, 12);
      expect(back.monthsAhead, 3);
      expect(back.payeeIds, [7, 9]);
    });

    test('a corrupt blob yields defaults, and defaults are OFF', () {
      // Defaulting to ON would start reminding a member who never asked for it.
      expect(AutoPayPrefs.fromJson('garbage').enabled, isFalse);
      expect(AutoPayPrefs.fromJson(null).enabled, isFalse);
      expect(AutoPayPrefs.defaults.enabled, isFalse);
    });

    test('junk payee ids are dropped rather than paying for account 0', () {
      final p = AutoPayPrefs.fromJson({
        'payeeIds': [5, 0, -2, 'x', null, 8]
      });
      expect(p.payeeIds, [5, 8]);
    });
  });
}
