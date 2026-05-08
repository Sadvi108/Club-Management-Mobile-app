import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

class NotificationDetailScreen extends StatefulWidget {
  final String groupId;
  const NotificationDetailScreen({super.key, required this.groupId});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final _replyCtrl = TextEditingController();
  List<dynamic>? _messages;
  Map<String, dynamic>? _root;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Api.profileNotificationDetails(widget.groupId);
      if (r is List) {
        _messages = r;
      } else if (r is Map) {
        if (r['data'] is List) {
          _messages = r['data'] as List;
        } else if (r['data'] is Map) {
          _root = Map<String, dynamic>.from(r['data'] as Map);
          _messages = (_root!['messages'] as List?) ??
              (_root!['replies'] as List?) ??
              <dynamic>[_root];
        } else {
          _root = Map<String, dynamic>.from(r);
          _messages = <dynamic>[_root];
        }
      }
      // Mark thread as seen.
      try {
        await Api.profileMyUnreadNotifications();
      } catch (e) {
        debugPrint('MyUnreadNotifications failed: $e');
      }
    } catch (e) {
      debugPrint('NotificationDetails failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final txt = _replyCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() => _sending = true);
    try {
      await Api.profileReply2Notification(<String, dynamic>{
        'groupId': widget.groupId,
        'message': txt,
      });
      _replyCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent')),
      );
      await _load();
    } catch (e) {
      debugPrint('Reply2Notification failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _action(int action) async {
    try {
      await Api.profileUpdateNotificationAction(<String, dynamic>{
        'groupId': widget.groupId,
        'action': action,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 1 ? 'Accepted' : 'Declined')),
      );
      await _load();
    } catch (e) {
      debugPrint('UpdateNotificationAction failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  bool get _actionable {
    final r = _root;
    if (r == null) return false;
    if (r['actionable'] == true) return true;
    if (r['hasAction'] == true) return true;
    if (r['actionType'] != null && r['actionType'] != 0) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(children: [
          AppHeader(title: 'Notification', subtitle: 'Thread #${widget.groupId}', showBack: true),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: c.primary),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gaps.xl, 8, Gaps.xl, 16),
                children: [
                  if (_messages == null || _messages!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No messages.',
                            style: TextStyle(color: c.textSecondary)),
                      ),
                    )
                  else
                    ..._messages!.map((m) => _messageCard(c, m)),
                  if (_actionable) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _action(1),
                          borderRadius: BorderRadius.circular(Radii.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.success,
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: const Text('Accept',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _action(2),
                          borderRadius: BorderRadius.circular(Radii.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.danger,
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: const Text('Decline',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(Gaps.xl, 8, Gaps.xl,
                MediaQuery.of(context).viewInsets.bottom + 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  decoration: const InputDecoration(hintText: 'Write a reply…'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sending ? null : _sendReply,
                icon: Icon(Icons.send, color: c.primary),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _messageCard(AppColors c, dynamic m) {
    final mp = m is Map ? m : <dynamic, dynamic>{};
    final title = (mp['title'] ?? mp['text'] ?? mp['name'] ?? '').toString();
    final body = (mp['message'] ?? mp['value'] ?? mp['description'] ?? '')
        .toString()
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
    final date = (mp['date'] ?? mp['createdAt'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title.isNotEmpty)
          Text(title,
              style: TextStyle(
                  color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: c.textSecondary, fontSize: 13)),
        ],
        if (date.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(date, style: TextStyle(color: c.textMuted, fontSize: 11)),
        ],
      ]),
    );
  }
}
