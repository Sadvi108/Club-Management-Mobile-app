import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';

/// Shared student switcher — used by both the Profile screen and the
/// Home avatar dropdown. Fetches /Listing/MySiblings, shows a sheet with
/// an "All Students" aggregate option plus one row per sibling, and
/// applies the pick through [UserSession.switchStudent] (a pure
/// client-side filter — no /Account/ChangeStudent call).
Future<void> showStudentSwitcher(BuildContext context) async {
  final c = context.appColors;
  dynamic raw;
  String? error;
  try {
    raw = await Api.listingMySiblings();
  } catch (e) {
    error = e.toString();
    debugPrint('listingMySiblings failed: $e');
  }
  final siblings = (UserSession.findList(raw) ?? const [])
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
  // Cache for any other consumer.
  UserSession.instance.siblings = siblings;

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) =>
          _SwitcherSheet(c: c, siblings: siblings, fetchError: error,
              scrollController: scrollCtrl),
    ),
  );
}

class _SwitcherSheet extends StatefulWidget {
  final AppColors c;
  final List<Map<String, dynamic>> siblings;
  final String? fetchError;
  final ScrollController scrollController;
  const _SwitcherSheet({
    required this.c,
    required this.siblings,
    required this.fetchError,
    required this.scrollController,
  });

  @override
  State<_SwitcherSheet> createState() => _SwitcherSheetState();
}

class _SwitcherSheetState extends State<_SwitcherSheet> {
  String _query = '';

  void _pick(BuildContext ctx, Object? sid, String name) {
    Navigator.pop(ctx);
    final session = UserSession.instance;
    if (sid == null) {
      session.showAllStudents();
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Showing all students')));
      return;
    }
    session.switchStudent(sid, studentName: name);
    ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Switched to $name')));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final active = UserSession.instance.activeStudentName;
    final filtered = widget.siblings.where((s) {
      if (_query.isEmpty) return true;
      final name = (s['text'] ?? s['name'] ?? s['fullName'] ?? '')
          .toString()
          .toLowerCase();
      final reg = (s['value'] ?? '').toString().toLowerCase();
      final q = _query.toLowerCase();
      return name.contains(q) || reg.contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Column(children: [
            Center(
                child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2)))),
            Row(children: [
              Text('Switch Student',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: c.surfaceAlt, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(Icons.close, color: c.textSecondary, size: 18),
                ),
              ),
            ]),
            if (widget.siblings.length > 4) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: c.border),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon:
                        Icon(Icons.search, color: c.textMuted, size: 20),
                    hintText: 'Search',
                    hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ]),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              // Aggregate option.
              if (_query.isEmpty)
                _tile(
                  c,
                  icon: Icons.groups_outlined,
                  title: 'All Students',
                  subtitle: 'Combined view across children',
                  selected: active == null,
                  onTap: () => _pick(context, null, 'All Students'),
                ),
              if (widget.siblings.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(children: [
                    Icon(Icons.person_off_outlined,
                        size: 36, color: c.textMuted),
                    const SizedBox(height: 10),
                    Text(
                        widget.fetchError != null
                            ? 'Could not load students'
                            : 'No linked students',
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                )
              else
                ...filtered.map((s) {
                  final sid = s['id'] ??
                      s['studentId'] ??
                      s['code'] ??
                      s['studentID'];
                  final name = (s['text'] ??
                          s['name'] ??
                          s['fullName'] ??
                          s['studentName'] ??
                          '?')
                      .toString();
                  final reg = (s['value'] ?? '').toString();
                  final isActive = active != null &&
                      name.toUpperCase() == active.toUpperCase();
                  return _tile(
                    c,
                    avatarText:
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                    title: name,
                    subtitle: reg.isNotEmpty ? reg : null,
                    selected: isActive,
                    onTap: isActive
                        ? null
                        : () => _pick(context, sid, name),
                  );
                }),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _tile(
    AppColors c, {
    IconData? icon,
    String? avatarText,
    required String title,
    String? subtitle,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? c.primary.withOpacity(0.10) : c.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: selected ? c.primary : c.border),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(colors: c.gradient)
                    : null,
                color: selected ? null : c.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon,
                      size: 19,
                      color: selected ? Colors.white : c.primary)
                  : Text(avatarText ?? '?',
                      style: TextStyle(
                          color: selected ? Colors.white : c.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  if (subtitle != null)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: c.primary, size: 20),
          ]),
        ),
      ),
    );
  }
}
