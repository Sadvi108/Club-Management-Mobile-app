import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/chat_store.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'chat_thread_screen.dart';

/// Chat Academy — the club's messages as conversations, plus a pinned Help Desk.
///
/// Every notification the backend sends carries its OWN groupId (verified on prod: 15 rows,
/// 15 distinct groupIds), so these are one-message threads rather than long histories. The
/// club's reply to a help desk message likewise arrives as a new notification with a new
/// groupId, i.e. as a separate conversation. That is the backend's data model, not a bug —
/// the UI just presents what exists honestly.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatThreadSummary> _threads = [];
  List<SentMessage> _helpdeskSent = [];
  bool _loading = true;
  String? _error;
  int _feedRevision = -1;
  int _feedBuild = 0;

  @override
  void initState() {
    super.initState();
    UserSession.instance.addListener(_feedChanged);
    _load();
  }

  @override
  void dispose() {
    UserSession.instance.removeListener(_feedChanged);
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
    final sent = await ChatStore.threads(userId);
    if (!mounted ||
        build != _feedBuild ||
        userId != (session.authenticatedUserId ?? 0)) return;
    setState(() {
      _threads = buildThreadList(
          myNotifications: session.notifications ?? const [],
          sentByThread: sent);
      _helpdeskSent = sent[ChatStore.helpdeskThread] ?? const [];
      _error = session.notificationsError;
      _loading = false;
    });
  }

  Future<void> _load() async {
    await UserSession.instance.refreshNotifications();
    if (mounted) await _rebuildFeed();
  }

  Future<void> _open(String key, String title, bool replyable) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ChatThreadScreen(threadKey: key, title: title, replyable: replyable),
    ));
    if (mounted) _load(); // reflect anything sent or read while inside
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // Scaffold, not a bare Container: these are STANDALONE routes, so nothing above them
    // provides Material, and AppHeader's back button is an InkWell — which asserts
    // "No Material widget found". The tab screens get away with a Container only because
    // TabsShell wraps them in its own Scaffold.
    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(title: 'Chat Academy', showBack: true),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        Gaps.lg, Gaps.md, Gaps.lg, Gaps.xxxl),
                    children: [
                      if (_error != null) _errorBanner(c, _error!),
                      _helpdeskTile(c),
                      const SizedBox(height: Gaps.lg),
                      Text('CONVERSATIONS',
                          style: TextStyle(
                              color: c.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                      const SizedBox(height: Gaps.sm),
                      if (_threads.isEmpty)
                        _empty(c)
                      else
                        ..._threads.map((t) => _threadTile(c, t)),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _errorBanner(AppColors c, String msg) => Container(
        margin: const EdgeInsets.only(bottom: Gaps.md),
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        ),
        child:
            Text(msg, style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
      );

  Widget _helpdeskTile(AppColors c) {
    final last = _helpdeskSent.isEmpty ? null : _helpdeskSent.last;
    return GestureDetector(
      onTap: () => _open(ChatStore.helpdeskThread, 'Club Help Desk', true),
      child: Container(
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.primary.withValues(alpha: 0.45)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
            child: const Icon(Icons.headset_mic, size: 19, color: Colors.white),
          ),
          const SizedBox(width: Gaps.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${UserSession.instance.clubDisplayName.isEmpty ? 'Your club' : UserSession.instance.clubDisplayName} · Help Desk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                  last == null
                      ? 'Message your club admin / instructor'
                      : 'You: ${last.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ]),
          ),
          Icon(AppIcons.chevron_right, size: 20, color: c.textMuted),
        ]),
      ),
    );
  }

  Widget _threadTile(AppColors c, ChatThreadSummary t) => GestureDetector(
        onTap: () => _open(t.key, t.title, t.replyable),
        child: Container(
          margin: const EdgeInsets.only(bottom: Gaps.sm),
          padding: const EdgeInsets.all(Gaps.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
              child:
                  Icon(Icons.chat_bubble_outline, size: 18, color: c.primary),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13.5,
                                fontWeight: t.unread > 0
                                    ? FontWeight.w800
                                    : FontWeight.w700)),
                      ),
                      Text(_ago(t.at),
                          style: TextStyle(color: c.textMuted, fontSize: 10.5)),
                    ]),
                    const SizedBox(height: 2),
                    Text(t.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 12, height: 1.3)),
                  ]),
            ),
            if (t.unread > 0) ...[
              const SizedBox(width: Gaps.sm),
              Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: c.primary, shape: BoxShape.circle),
              ),
            ],
          ]),
        ),
      );

  String _ago(DateTime? d) {
    if (d == null) return '';
    final mins = DateTime.now().difference(d).inMinutes;
    if (mins < 1) return 'now';
    if (mins < 60) return '${mins}m';
    if (mins < 1440) return '${mins ~/ 60}h';
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
    return '${d.day} ${m[d.month - 1]}';
  }

  Widget _empty(AppColors c) => Container(
        padding: const EdgeInsets.symmetric(vertical: Gaps.xxl),
        alignment: Alignment.center,
        child: Column(children: [
          Icon(AppIcons.forum_outlined, size: 34, color: c.textMuted),
          const SizedBox(height: Gaps.sm),
          Text('No conversations yet',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('Messages from your club appear here.',
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ]),
      );
}

/// Route helper so other screens can open the help desk directly.
void openHelpDesk(BuildContext context) => context.push('/chat');
