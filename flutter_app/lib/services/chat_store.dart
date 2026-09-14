import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local echo for messages this member has sent to the club.
///
/// The backend delivers a reply to the club's admin panel but exposes NO endpoint to read
/// it back — probed live: after `Reply2Notification` and `Send2ClubHelpDesk` both return
/// 200, the sent text appears in neither `MyNotifications` nor anywhere else. Without a
/// local copy the user's own messages would vanish the moment the screen closed, making the
/// conversation look one-sided and unsent.
///
/// Incoming messages always come from the server; only outgoing ones live here.
class ChatStore {
  /// Pseudo-thread for a brand-new conversation (Send2ClubHelpDesk), which has no groupId.
  static const helpdeskThread = 'helpdesk';

  static String _key(int userId) => 'dclix.chat.sent.v1.$userId';

  static Future<Map<String, List<SentMessage>>> _readAll(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(
            k.toString(),
            (v as List? ?? [])
                .whereType<Map>()
                .map(SentMessage.fromJson)
                .toList(),
          ));
    } catch (e) {
      // A corrupt blob must not cost the user their ability to message the club.
      debugPrint('ChatStore read failed: $e');
      return {};
    }
  }

  static Future<void> _writeAll(
      int userId, Map<String, List<SentMessage>> all) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(userId),
        jsonEncode(
            all.map((k, v) => MapEntry(k, v.map((m) => m.toJson()).toList()))),
      );
    } catch (e) {
      debugPrint('ChatStore write failed: $e');
    }
  }

  /// Messages sent in one thread, oldest first.
  static Future<List<SentMessage>> sent(int userId, String threadKey) async =>
      (await _readAll(userId))[threadKey] ?? const [];

  /// Every thread this member has sent something in — the help desk shows up here even
  /// before the club has replied.
  static Future<Map<String, List<SentMessage>>> threads(int userId) =>
      _readAll(userId);

  /// Record a message that the server accepted.
  ///
  /// Only call this AFTER the send succeeds: echoing an unsent message would tell the user
  /// the club had received something it never did.
  static Future<SentMessage> append(
      int userId, String threadKey, String text) async {
    final msg = SentMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      at: DateTime.now(),
    );
    final all = await _readAll(userId);
    all[threadKey] = [...(all[threadKey] ?? const []), msg];
    await _writeAll(userId, all);
    return msg;
  }

  /// Wipe this member's echo — used on logout so the next account starts clean.
  static Future<void> clear(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {}
  }
}

class SentMessage {
  final String id;
  final String text;
  final DateTime at;

  const SentMessage({required this.id, required this.text, required this.at});

  factory SentMessage.fromJson(Map json) => SentMessage(
        id: (json['id'] ?? '').toString(),
        text: (json['text'] ?? '').toString(),
        at: DateTime.tryParse((json['at'] ?? '').toString()) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'at': at.toIso8601String()};
}

/// One bubble in a conversation — either a club message or one of ours.
class ChatBubble {
  final String key;
  final bool mine;
  final String text;
  final String? subject;
  final DateTime? at;

  const ChatBubble({
    required this.key,
    required this.mine,
    required this.text,
    this.subject,
    this.at,
  });
}

DateTime? messageTime(Map row) => DateTime.tryParse(
    '${row['notifyDate'] ?? row['createdDate'] ?? row['notificationDate'] ?? row['date'] ?? ''}');

/// Build a conversation from the member's OWN notification rows plus the local echo.
///
/// Incoming rows must come from `MyNotifications` filtered by groupId — never from
/// `GET /Profile/NotificationDetails/{groupId}`. That route is not scoped to the caller:
/// probed on prod, one groupId returned 32 rows naming 30 different students, including
/// their fee amounts. Rendering it would show every member the others' business.
List<ChatBubble> buildThread({
  required List<dynamic> myNotifications,
  required String groupId,
  required List<SentMessage> sent,
}) {
  final bubbles = <ChatBubble>[];

  for (final n in myNotifications) {
    if (n is! Map) continue;
    if ((n['groupId'] ?? '').toString() != groupId) continue;
    bubbles.add(ChatBubble(
      key: 'in-${n['id']}',
      mine: false,
      text: (n['value'] ?? '').toString().trim(),
      subject: (n['text'] ?? '').toString().trim().isEmpty
          ? null
          : (n['text'] ?? '').toString().trim(),
      at: messageTime(n),
    ));
  }

  for (final m in sent) {
    bubbles.add(
        ChatBubble(key: 'out-${m.id}', mine: true, text: m.text, at: m.at));
  }

  bubbles.sort((a, b) {
    final x = a.at, y = b.at;
    if (x == null && y == null) return 0;
    if (x == null) return -1;
    if (y == null) return 1;
    return x.compareTo(y);
  });
  return bubbles;
}

/// A conversation in the list view.
class ChatThreadSummary {
  final String key;
  final String title;
  final String preview;
  final DateTime? at;
  final int unread;

  /// False when the rows carry no groupId, so the key is a synthesised fallback.
  ///
  /// `Reply2Notification` answers 200 to ANY groupId — including one that matches nothing —
  /// so replying on such a thread would be echoed to the user and then silently dropped.
  /// Those threads open read-only.
  final bool replyable;

  const ChatThreadSummary({
    required this.key,
    required this.title,
    required this.preview,
    required this.unread,
    required this.replyable,
    this.at,
  });
}

/// Group the member's notifications into conversations, newest activity first.
List<ChatThreadSummary> buildThreadList({
  required List<dynamic> myNotifications,
  required Map<String, List<SentMessage>> sentByThread,
}) {
  final byGroup = <String, List<Map>>{};
  final hadGroupId = <String, bool>{};

  for (final n in myNotifications) {
    if (n is! Map) continue;
    final gid = (n['groupId'] ?? '').toString();
    final key = gid.isNotEmpty ? gid : '${n['id']}';
    byGroup.putIfAbsent(key, () => []).add(n);
    hadGroupId[key] = (hadGroupId[key] ?? false) || gid.isNotEmpty;
  }

  final out = <ChatThreadSummary>[];
  byGroup.forEach((key, rows) {
    rows.sort((a, b) {
      final x = messageTime(a);
      final y = messageTime(b);
      if (x == null || y == null) return 0;
      return x.compareTo(y);
    });
    final last = rows.last;
    final lastAt = messageTime(last);

    final mine = sentByThread[key] ?? const <SentMessage>[];
    final lastMine = mine.isEmpty ? null : mine.last;
    final mineIsNewer =
        lastMine != null && (lastAt == null || lastMine.at.isAfter(lastAt));

    out.add(ChatThreadSummary(
      key: key,
      title: (last['text'] ?? '').toString().trim().isEmpty
          ? 'Club message'
          : (last['text'] ?? '').toString().trim(),
      preview: mineIsNewer
          ? 'You: ${lastMine.text}'
          : (last['value'] ?? '').toString().trim(),
      at: mineIsNewer ? lastMine.at : lastAt,
      unread: rows.where((r) => r['isRead'] != true).length,
      replyable: hadGroupId[key] ?? false,
    ));
  });

  out.sort((a, b) {
    final x = a.at, y = b.at;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return y.compareTo(x);
  });
  return out;
}
