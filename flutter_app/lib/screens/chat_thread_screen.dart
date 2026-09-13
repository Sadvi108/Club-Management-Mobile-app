import '../theme/app_icons.dart';
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/chat_store.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// One conversation with the club.
///
/// Incoming messages are the member's OWN rows from `MyNotifications`, filtered by groupId.
/// This screen deliberately does NOT call `GET /Profile/NotificationDetails/{groupId}`,
/// which the previous version used: that route is not scoped to the caller. Probed on prod,
/// a single groupId returned 32 rows naming 30 different students along with their fee
/// amounts, so rendering it showed every member the others' business.
///
/// Outgoing messages come from the local echo — the backend delivers a reply to the club's
/// admin panel but exposes no way to read it back (see ChatStore).
class ChatThreadScreen extends StatefulWidget {
  /// groupId of the conversation, or [ChatStore.helpdeskThread] for a new one.
  final String threadKey;
  final String title;

  /// False when the thread has no real groupId to reply into — see [ChatThreadSummary].
  final bool replyable;

  const ChatThreadScreen({
    super.key,
    required this.threadKey,
    this.title = 'Conversation',
    this.replyable = true,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<ChatBubble> _bubbles = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int _feedRevision = -1;
  int _feedBuild = 0;

  bool get _isHelpdesk => widget.threadKey == ChatStore.helpdeskThread;
  bool get _canSend => _isHelpdesk || widget.replyable;

  @override
  void initState() {
    super.initState();
    UserSession.instance.addListener(_feedChanged);
    _load();
  }

  @override
  void dispose() {
    UserSession.instance.removeListener(_feedChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _feedChanged() {
    final session = UserSession.instance;
    if (_feedRevision == session.notificationsRevision &&
        _error == session.notificationsError) return;
    _rebuildFeed();
  }

  Future<void> _rebuildFeed() async {
    final session = UserSession.instance;
    final userId = session.authenticatedUserId ?? 0;
    final build = ++_feedBuild;
    _feedRevision = session.notificationsRevision;
    final incoming = session.notifications ?? const [];
    final atBottom = !_scroll.hasClients || _scroll.position.extentAfter < 80;
    final sent = await ChatStore.sent(userId, widget.threadKey);
    if (!mounted ||
        build != _feedBuild ||
        userId != (session.authenticatedUserId ?? 0)) return;
    setState(() {
      _bubbles = buildThread(
          myNotifications: incoming, groupId: widget.threadKey, sent: sent);
      _error = session.notificationsError;
      _loading = false;
    });
    _markRead(incoming);
    if (atBottom) _jumpToEnd();
  }

  Future<void> _load() async {
    await UserSession.instance.refreshNotifications();
    if (mounted) await _rebuildFeed();
  }

  /// Opening a conversation is reading it.
  final Set<String> _markingRead = {};
  Future<void> _markRead(List<dynamic> incoming) async {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    for (final n in incoming) {
      if (n is! Map) continue;
      if ((n['groupId'] ?? '').toString() != widget.threadKey) continue;
      if (n['isRead'] == true) continue;
      final id = n['id'];
      if (id == null || !_markingRead.add('$id')) continue;
      try {
        await Api.profileUpdateNotification2Read(id);
        UserSession.instance.acknowledgeNotificationRead(id);
      } catch (_) {/* Retry on the next update. */} finally {
        _markingRead.remove('$id');
      }
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || !_canSend) return;

    final userId = UserSession.instance.authenticatedUserId ?? 0;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (_isHelpdesk) {
        await Api.profileSend2ClubHelpDesk({
          'text': 'Chat',
          'value': text,
          'notificationType': 'HelpDesk',
        });
      } else {
        await Api.profileReply2Notification({
          'id': 0,
          'notificationType': '',
          'text': 'Reply',
          'groupId': widget.threadKey,
          'value': text,
        });
      }

      // Only echo AFTER the server accepted it — echoing an unsent message would tell the
      // member the club received something it never did.
      final msg = await ChatStore.append(userId, widget.threadKey, text);
      if (!mounted || userId != (UserSession.instance.authenticatedUserId ?? 0))
        return;
      setState(() {
        _bubbles = [
          ..._bubbles,
          ChatBubble(
              key: 'out-${msg.id}', mine: true, text: msg.text, at: msg.at),
        ];
        _input.clear();
        _sending = false;
      });
      _jumpToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        AppHeader(
          title: widget.title,
          subtitle: UserSession.instance.clubDisplayName,
          showBack: true,
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _bubbles.isEmpty
                  ? _empty(c)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                          Gaps.lg, Gaps.md, Gaps.lg, Gaps.md),
                      itemCount: _bubbles.length,
                      itemBuilder: (_, i) => _bubble(c, _bubbles[i]),
                    ),
        ),
        if (_error != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: 4),
            child:
                Text(_error!, style: TextStyle(color: c.danger, fontSize: 12)),
          ),
        _canSend ? _composer(c) : _readOnlyNotice(c),
      ]),
    );
  }

  Widget _empty(AppColors c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Gaps.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.forum_outlined, size: 40, color: c.textMuted),
            const SizedBox(height: Gaps.md),
            Text(_isHelpdesk ? 'Start a conversation' : 'No messages yet',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              _isHelpdesk
                  ? 'Ask the club admin anything — fees, schedules, membership.'
                  : 'Messages from your club appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 12.5),
            ),
          ]),
        ),
      );

  Widget _bubble(AppColors c, ChatBubble b) {
    final mine = b.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: Gaps.sm),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? c.primary : c.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
          border: mine ? null : Border.all(color: c.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!mine && b.subject != null) ...[
            Text(b.subject!,
                style: TextStyle(
                    color: c.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
          ],
          Text(b.text,
              style: TextStyle(
                  color: mine ? Colors.white : c.textPrimary,
                  fontSize: 13.5,
                  height: 1.35)),
          const SizedBox(height: 4),
          Text(_when(b.at),
              style: TextStyle(
                  color: mine ? Colors.white70 : c.textMuted, fontSize: 10)),
        ]),
      ),
    );
  }

  String _when(DateTime? d) {
    if (d == null) return '';
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${m[d.month - 1]} · $hh:$mm';
  }

  Widget _readOnlyNotice(AppColors c) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg,
            Gaps.md + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(children: [
          Icon(AppIcons.info_outline, size: 16, color: c.textSecondary),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: Text(
              "This announcement can't be replied to. Use the Club Help Desk to start a conversation.",
              style:
                  TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35),
            ),
          ),
        ]),
      );

  Widget _composer(AppColors c) => Container(
        padding: EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg,
            Gaps.sm + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: c.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: TextStyle(color: c.textMuted, fontSize: 13.5),
                filled: true,
                fillColor: c.surfaceAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: Gaps.sm),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _sending ? c.primary.withValues(alpha: 0.5) : c.primary,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 18, color: Colors.white),
            ),
          ),
        ]),
      );
}
