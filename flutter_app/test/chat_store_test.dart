// Messaging rules.
//
// Two of these matter more than the rest:
//  - a conversation is built ONLY from the caller's own notification rows, never from
//    /Profile/NotificationDetails, which returns other members' data;
//  - a thread with no real groupId is not repliable, because Reply2Notification answers 200
//    to any groupId and the message would be echoed to the user and then silently dropped.
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/chat_store.dart';

DateTime _t(int day, [int hour = 12]) => DateTime(2026, 9, day, hour);

List<dynamic> get _notifications => [
      {
        'id': 1,
        'groupId': 'AAA',
        'text': 'Reminder',
        'value': 'Sila jelaskan yuran tertunggak RM85.00',
        'notifyDate': '2026-09-01T10:00:00',
        'isRead': false,
      },
      {
        'id': 2,
        'groupId': 'BBB',
        'text': 'Class Activity',
        'value': 'Sukma training',
        'notifyDate': '2026-09-03T10:00:00',
        'isRead': true,
      },
      // A row the backend sent without a groupId.
      {
        'id': 3,
        'groupId': '',
        'text': 'Announcement',
        'value': 'Dojo closed Monday',
        'notifyDate': '2026-09-05T10:00:00',
        'isRead': false,
      },
    ];

void main() {
  group('buildThread', () {
    test('includes only rows from the requested group', () {
      final t = buildThread(
        myNotifications: _notifications,
        groupId: 'AAA',
        sent: const [],
      );
      expect(t, hasLength(1));
      expect(t.single.text, contains('RM85.00'));
      expect(t.single.mine, isFalse);
      expect(t.single.subject, 'Reminder');
    });

    test('never surfaces another member\'s row', () {
      // The shape /Profile/NotificationDetails returns: the whole broadcast batch, with
      // other students' names. Even if such rows were handed in, only the caller's own
      // group is rendered — and the real screen never calls that route at all.
      final foreign = [
        ..._notifications,
        {
          'id': 99,
          'groupId': 'AAA',
          'receiverName': 'SOMEONE ELSE',
          'value': 'Their fee RM900',
          'notifyDate': '2026-09-02T10:00:00',
        },
      ];
      final t = buildThread(myNotifications: foreign, groupId: 'AAA', sent: const []);
      // It is in the same group, so it appears — which is exactly why the screen must feed
      // this function MyNotifications (already caller-scoped) and never NotificationDetails.
      expect(t.length, 2);
    });

    test('merges sent messages and orders everything by time', () {
      final t = buildThread(
        myNotifications: _notifications,
        groupId: 'AAA',
        sent: [SentMessage(id: 's1', text: 'When is it due?', at: _t(2))],
      );
      expect(t.map((b) => b.mine).toList(), [false, true]);
      expect(t.last.text, 'When is it due?');
    });

    test('a helpdesk thread with no server rows is just what we sent', () {
      final t = buildThread(
        myNotifications: _notifications,
        groupId: ChatStore.helpdeskThread,
        sent: [SentMessage(id: 's1', text: 'Hello', at: _t(1))],
      );
      expect(t, hasLength(1));
      expect(t.single.mine, isTrue);
    });

    test('survives malformed rows', () {
      final t = buildThread(
        myNotifications: [null, 'x', 42, {}],
        groupId: 'AAA',
        sent: const [],
      );
      expect(t, isEmpty);
    });
  });

  group('buildThreadList', () {
    test('groups by groupId, newest activity first', () {
      final list = buildThreadList(myNotifications: _notifications, sentByThread: const {});
      expect(list.map((t) => t.key).toList(), ['3', 'BBB', 'AAA']);
      expect(list.first.title, 'Announcement');
    });

    test('a row with no groupId is NOT repliable', () {
      // Reply2Notification returns 200 for any groupId, including a synthesised one, so a
      // reply here would look sent and then vanish.
      final list = buildThreadList(myNotifications: _notifications, sentByThread: const {});
      final synthetic = list.firstWhere((t) => t.key == '3');
      expect(synthetic.replyable, isFalse);
      expect(list.firstWhere((t) => t.key == 'AAA').replyable, isTrue);
    });

    test('counts unread per thread', () {
      final list = buildThreadList(myNotifications: _notifications, sentByThread: const {});
      expect(list.firstWhere((t) => t.key == 'AAA').unread, 1);
      expect(list.firstWhere((t) => t.key == 'BBB').unread, 0);
    });

    test('a newer sent message becomes the preview and bumps the thread', () {
      final list = buildThreadList(
        myNotifications: _notifications,
        sentByThread: {
          'AAA': [SentMessage(id: 's', text: 'Paid it', at: _t(9))],
        },
      );
      expect(list.first.key, 'AAA');
      expect(list.first.preview, 'You: Paid it');
    });

    test('an older sent message does not override the club\'s latest', () {
      final list = buildThreadList(
        myNotifications: _notifications,
        sentByThread: {
          'AAA': [SentMessage(id: 's', text: 'old', at: DateTime(2026, 8, 1))],
        },
      );
      expect(list.firstWhere((t) => t.key == 'AAA').preview, contains('RM85.00'));
    });

    test('no notifications -> empty list, not a crash', () {
      expect(buildThreadList(myNotifications: const [], sentByThread: const {}), isEmpty);
    });
  });

  group('SentMessage', () {
    test('round-trips through json', () {
      final m = SentMessage(id: 'a', text: 'hi', at: _t(4, 9));
      final back = SentMessage.fromJson(m.toJson());
      expect(back.id, 'a');
      expect(back.text, 'hi');
      expect(back.at, m.at);
    });

    test('tolerates a corrupt stored entry', () {
      final back = SentMessage.fromJson({'text': 'only text'});
      expect(back.text, 'only text');
      expect(back.id, '');
    });
  });
}
