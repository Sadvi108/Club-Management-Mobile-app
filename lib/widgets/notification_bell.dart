import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import 'list_search.dart';

/// Reusable notification bell with a live unread badge.
///
/// Reads `unreadNotifications` and `notifications` from [UserSession] so it
/// rebuilds automatically when the background poller picks up new items.
/// Tapping opens a bottom sheet listing notifications; tapping a row
/// navigates to the detail screen and marks it read.
class NotificationBell extends StatelessWidget {
  /// Tint of the bell glyph (defaults to `c.primary`).
  final Color? iconColor;

  /// Optional circular background colour behind the bell.
  final Color? backgroundColor;

  /// Border colour around the circular background (used over gradient headers).
  final Color? borderColor;

  /// Bell glyph size.
  final double iconSize;

  /// Diameter of the circular hit target.
  final double tapSize;

  const NotificationBell({
    super.key,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.iconSize = 22,
    this.tapSize = 42,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final count = session.unreadNotifications;
    final has = count > 0;

    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(tapSize),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: tapSize,
            height: tapSize,
            decoration: BoxDecoration(
              color: backgroundColor ?? c.surfaceAlt,
              shape: BoxShape.circle,
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 1)
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              has ? Icons.notifications_active : Icons.notifications_outlined,
              size: iconSize,
              color: iconColor ?? c.primary,
            ),
          ),
          if (has)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: c.danger,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationsSheet(),
    );
  }
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _unreadOnly = false;
  String? _typeFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final allItems = (session.notifications ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final typeOptions = <String>{
      for (final r in allItems)
        if ((r['text'] ?? '').toString().trim().isNotEmpty)
          r['text'].toString().trim(),
    }.toList()
      ..sort();
    final q = _query.trim().toLowerCase();
    final items = allItems.where((n) {
      if (_unreadOnly && n['isRead'] == true) return false;
      if (_typeFilter != null &&
          _typeFilter!.isNotEmpty &&
          n['text']?.toString() != _typeFilter) return false;
      if (q.isNotEmpty) {
        final hay = '${n['text'] ?? ''} ${n['value'] ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Handle + header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Column(children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.gradient),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.notifications_active,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${session.unreadNotifications} unread · ${allItems.length} total',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: c.primary, size: 20),
                  tooltip: 'Refresh',
                  onPressed: () async {
                    await UserSession.instance.refresh();
                    if (mounted) setState(() {});
                  },
                ),
              ]),
              if (allItems.length > 4) ...[
                const SizedBox(height: 12),
                ListSearchBar(
                  hint: 'Search notifications…',
                  controller: _searchCtrl,
                  onSearch: (v) => setState(() => _query = v),
                  filters: [
                    ListFilter.toggle(
                      label: 'Unread only',
                      value: _unreadOnly,
                      onChanged: (v) => setState(() => _unreadOnly = v),
                    ),
                    if (typeOptions.isNotEmpty)
                      ListFilter(
                        label: 'Type',
                        options: typeOptions,
                        selected: _typeFilter,
                        onSelected: (v) =>
                            setState(() => _typeFilter = v),
                      ),
                  ],
                  resultCount: items.length,
                  totalCount: allItems.length,
                  onClearAll: () => setState(() {
                    _query = '';
                    _unreadOnly = false;
                    _typeFilter = null;
                  }),
                ),
              ],
            ]),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 56, color: c.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: c.border.withOpacity(0.5)),
                    itemBuilder: (_, i) => _NotificationRow(
                      data: items[i],
                      onTap: () => _open(context, items[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  void _open(BuildContext context, Map<String, dynamic> n) {
    final gid = n['groupId'] ?? n['groupid'] ?? n['id'];
    if (gid != null) {
      Navigator.pop(context);
      context.push('/notification/${Uri.encodeComponent(gid.toString())}');
      // Best-effort mark as read.
      Api.profileUpdateNotification2Read({'id': gid, 'groupId': gid})
          .catchError((e) {
        debugPrint('mark-read failed: $e');
        return null;
      });
    } else {
      Navigator.pop(context);
    }
  }
}

class _NotificationRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _NotificationRow({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final title =
        (data['text'] ?? data['title'] ?? data['name'] ?? '').toString();
    final body = (data['value'] ?? data['description'] ?? '')
        .toString()
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
    final isUnread = (data['isRead'] == false) ||
        (data['read'] == false) ||
        (data['unread'] == true);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
              color: isUnread ? c.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.textMuted, size: 20),
        ]),
      ),
    );
  }
}
