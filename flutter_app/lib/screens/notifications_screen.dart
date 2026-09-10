import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/notification_diff.dart';
import '../services/notification_prefs.dart';
import '../services/response_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_icon_button.dart';

/// Notifications — everything the club has sent this member.
///
/// Rows come from `/Profile/MyNotifications`, which IS scoped to the caller. Tapping one
/// expands it and marks it read; the read state is also tracked locally so a row does not
/// jump back to unread when the server list is refetched before it catches up.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  final Set<int> _readLocally = {};
  int? _expanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.profileMyNotifications();
      // Instructor accounts can come back without a list at all — guard rather than throw.
      final rows = findRecordList(res)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _readLocally.clear();
        _expanded = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  int _idOf(Map<String, dynamic> m) {
    final v = m['id'] ?? m['Id'] ?? m['notificationId'];
    if (v is int) return v;
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  bool _isRead(Map<String, dynamic> m) =>
      m['isRead'] == true || _readLocally.contains(_idOf(m));

  Future<void> _markRead(int id) async {
    if (id <= 0) return;
    try {
      await Api.profileUpdateNotification2Read({'id': id});
      if (!mounted) return;
      setState(() => _readLocally.add(id));
    } catch (_) {
      // Leave it showing as unread: claiming it was read when the server never recorded
      // it means the badge comes back on the next poll and the row looks flaky.
    }
  }

  Future<void> _markAll() async {
    final unread = _rows.where((m) => !_isRead(m)).map(_idOf).where((i) => i > 0).toList();
    if (unread.isEmpty) return;
    setState(() => _busy = true);
    // Sequentially, not in parallel: this backend is a shared shoestring host and a burst
    // of writes has it drop some silently.
    for (final id in unread) {
      try {
        await Api.profileUpdateNotification2Read({'id': id});
        _readLocally.add(id);
      } catch (_) {/* keep the rest going */}
    }
    if (!mounted) return;
    setState(() => _busy = false);
  }

  String _fmtWhen(String raw) {
    final d = DateTime.tryParse(raw.trim());
    if (d == null) return raw.trim();
    final mins = DateTime.now().difference(d).inMinutes;
    if (mins < 1) return 'just now';
    if (mins < 60) return '${mins}m ago';
    if (mins < 1440) return '${mins ~/ 60}h ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final unread = _rows.where((m) => !_isRead(m)).length;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        AppHeader(
          title: 'Notifications',
          subtitle: unread == 0 ? 'All caught up' : '$unread unread',
          showBack: true,
          trailing: AppIconButton(
            icon: Icons.refresh,
            onPressed: _loading || _busy ? null : _load,
            backgroundColor: c.surfaceAlt,
            foregroundColor: c.primary,
          ),
        ),
        if (unread > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy ? null : _markAll,
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(_busy ? 'Marking...' : 'Mark all read'),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        Gaps.lg, Gaps.sm, Gaps.lg, Gaps.xxxl),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Column(children: [
                            Icon(Icons.error_outline, size: 36, color: c.danger),
                            const SizedBox(height: Gaps.sm),
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: c.danger, fontSize: 13)),
                            TextButton(
                                onPressed: _load, child: const Text('Try again')),
                          ]),
                        ),
                      if (_error == null && _rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 70),
                          child: Column(children: [
                            Icon(Icons.notifications_none,
                                size: 48, color: c.textMuted),
                            const SizedBox(height: Gaps.sm),
                            Text('No notifications yet.',
                                style: TextStyle(
                                    color: c.textSecondary, fontSize: 14)),
                          ]),
                        ),
                      for (final m in _rows) _row(c, m),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _row(AppColors c, Map<String, dynamic> m) {
    final id = _idOf(m);
    final read = _isRead(m);
    final title = titleOf(m);
    final body = bodyOf(m);
    final when = _fmtWhen('${m['createdDate'] ?? m['date'] ?? m['notificationDate'] ?? ''}');
    final open = _expanded == id;
    final category = categoryOf(m);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gaps.sm),
      child: GestureDetector(
        onTap: () {
          setState(() => _expanded = open ? null : id);
          if (!read) _markRead(id);
        },
        child: Container(
          padding: const EdgeInsets.all(Gaps.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: read ? c.border : c.primary.withValues(alpha: 0.5)),
            boxShadow: Shadows.card(c),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
              child: Icon(_iconFor(category), size: 18, color: c.primary),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: read ? FontWeight.w600 : FontWeight.w800)),
                  ),
                  if (!read)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration:
                          BoxDecoration(color: c.primary, shape: BoxShape.circle),
                    ),
                ]),
                if (body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(body,
                        maxLines: open ? null : 2,
                        overflow: open ? null : TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 12.5, height: 1.4)),
                  ),
                if (when.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(when,
                        style: TextStyle(color: c.textMuted, fontSize: 11)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  IconData _iconFor(NotifCategory c) => switch (c) {
        NotifCategory.payments => Icons.account_balance_wallet_outlined,
        NotifCategory.classes => Icons.fitness_center,
        NotifCategory.general => Icons.campaign_outlined,
      };
}
