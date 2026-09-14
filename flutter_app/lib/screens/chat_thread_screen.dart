import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/chat_store.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/rn_kit.dart';

/// `toLocaleString("en-GB", {day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"})`.
String _fmtTime(DateTime? d) {
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Port of `frontend/app/chat-thread.tsx` (Expo v2.11.1).
///
/// Incoming = the member's own notification rows for this group (server truth); outgoing =
/// Reply2Notification / Send2ClubHelpDesk with a persisted local echo (the API keeps no
/// sender-side copy).
class ChatThreadScreen extends StatefulWidget {
  /// groupId of the conversation, or [ChatStore.helpdeskThread] for a new one.
  final String threadKey;
  final String title;

  /// False when the thread has no real groupId to reply into — see [ChatThreadSummary].
  final bool replyable;

  const ChatThreadScreen({super.key, required this.threadKey, this.title = 'Conversation', this.replyable = true});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<SentMessage> _sent = const [];
  int _revision = -1;
  bool _sending = false;
  String? _sendError;
  final Set<String> _markingRead = {};

  bool get _isHelpdesk => widget.threadKey == ChatStore.helpdeskThread;
  bool get _readOnly => !widget.replyable && !_isHelpdesk;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    UserSession.instance.refreshNotifications();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSent() async {
    final session = UserSession.instance;
    final userId = session.authenticatedUserId ?? 0;
    final sent = await ChatStore.sent(userId, widget.threadKey);
    if (mounted && userId == (session.authenticatedUserId ?? 0)) setState(() => _sent = sent);
    _scrollToEnd();
  }

  /// Opening the thread marks its unread messages read (server + badge).
  Future<void> _markRead(List<Map> incoming) async {
    for (final n in incoming) {
      if (n['isRead'] == true) continue;
      final id = n['id'];
      if (id == null || !_markingRead.add('$id')) continue;
      try {
        await Api.profileUpdateNotification2Read({'id': id});
        UserSession.instance.acknowledgeNotificationRead(id);
      } catch (_) {
        /* keep showing as unread */
      }
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });

  Future<void> _send() async {
    final text = _input.text.trim();
    final userId = UserSession.instance.authenticatedUserId ?? 0;
    if (text.isEmpty || _sending || userId == 0 || _readOnly) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      if (_isHelpdesk) {
        await Api.profileSend2ClubHelpDesk({'text': 'Chat', 'value': text, 'notificationType': 'HelpDesk'});
      } else {
        await Api.profileReply2Notification(
            {'id': 0, 'notificationType': '', 'text': 'Reply', 'groupId': widget.threadKey, 'value': text});
      }
      // Only echo AFTER the server accepted it.
      final msg = await ChatStore.append(userId, widget.threadKey, text);
      if (!mounted) return;
      setState(() {
        _sent = [..._sent, msg];
        if (_input.text.trim() == text) _input.clear();
      });
      _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _sendError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: UserSession.instance, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.appColors;
    final session = UserSession.instance;
    if (_revision != session.notificationsRevision) {
      _revision = session.notificationsRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSent());
    }
    final all = session.notifications ?? const [];
    final incoming = _isHelpdesk
        ? const <Map>[]
        : all.whereType<Map>().where((n) => '${n['groupId'] ?? ''}' == widget.threadKey).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(incoming));
    final bubbles = buildThread(myNotifications: incoming, groupId: widget.threadKey, sent: _sent);
    final clubName = '${session.authData?['clubName'] ?? ''}'.trim();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final canSend = _input.text.trim().isNotEmpty && !_sending;

    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: c.background,
          padding: EdgeInsets.fromLTRB(Gaps.lg, MediaQuery.paddingOf(context).top + 10, Gaps.lg, 10),
          child: Row(children: [
            RnCircleButton(icon: Ion.chevronBack, onPress: () => safeBack(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(children: [
                Text(widget.title.isNotEmpty ? widget.title : (_isHelpdesk ? 'Club Help Desk' : 'Conversation'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                const SizedBox(height: 1),
                Text(clubName.isEmpty ? 'Your club' : clubName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ]),
            ),
            const SizedBox(width: 10),
            RnCircleButton(icon: Ion.refresh, iconSize: 18, onPress: () => session.refreshNotifications()),
          ]),
        ),
        Expanded(
          child: bubbles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Ion.chatbubblesOutline, size: 44, color: c.textMuted),
                      const SizedBox(height: 14),
                      Text(_isHelpdesk ? 'Say hello to your club' : 'No messages yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      const SizedBox(height: 6),
                      Text(
                          _isHelpdesk
                              ? 'Your message goes straight to the club admin.'
                              : 'Reply below — the club admin will see it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                    ]),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 16),
                  itemCount: bubbles.length,
                  itemBuilder: (_, i) {
                    final b = bubbles[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: b.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: b.mine ? c.primary : c.surface,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(b.mine ? Radii.lg : 4),
                                  topRight: const Radius.circular(Radii.lg),
                                  bottomLeft: const Radius.circular(Radii.lg),
                                  bottomRight: Radius.circular(b.mine ? 4 : Radii.lg),
                                ),
                                boxShadow: Shadows.soft(c),
                                border: !b.mine && c.isDark ? Border.all(color: c.border) : null,
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                if (!b.mine && b.subject != null)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(b.subject!,
                                          style: TextStyle(
                                              fontSize: 10, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 0.4)),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(b.text,
                                      style: TextStyle(
                                          fontSize: 13.5, color: b.mine ? Colors.white : c.textPrimary, height: 19 / 13.5)),
                                ),
                                const SizedBox(height: 5),
                                Text(_fmtTime(b.at),
                                    style: TextStyle(fontSize: 10, color: b.mine ? const Color(0xBFFFFFFF) : c.textMuted)),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (_sendError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 4),
            child: Text(_sendError!, style: TextStyle(color: c.danger, fontSize: 12)),
          ),
        if (_readOnly)
          Container(
            padding: EdgeInsets.fromLTRB(Gaps.lg, 10, Gaps.lg, bottom > 10 ? bottom : 10),
            decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
            child: Row(children: [
              Icon(Ion.informationCircleOutline, size: 16, color: c.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text("This announcement can't be replied to. Use the Club Help Desk to start a conversation.",
                    style: TextStyle(fontSize: 12, color: c.textSecondary, height: 17 / 12)),
              ),
            ]),
          )
        else
          Container(
            padding: EdgeInsets.fromLTRB(Gaps.lg, 8, Gaps.lg, bottom > 10 ? bottom : 10),
            decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 42, maxHeight: 120),
                  child: TextField(
                    controller: _input,
                    maxLines: null,
                    cursorColor: c.primary,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: c.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      hintText: 'Type a message…',
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.lg), borderSide: BorderSide.none),
                      enabledBorder:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.lg), borderSide: BorderSide.none),
                      focusedBorder:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.lg), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Opacity(
                opacity: canSend ? 1 : 0.5,
                child: Touchable(
                  // _send guards an empty draft itself, so a tap that lands before the
                  // rebuild that follows typing still goes through.
                  onPress: _sending ? null : _send,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                    child: _sending
                        ? const Center(
                            child: SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                        : const Icon(Ion.send, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
