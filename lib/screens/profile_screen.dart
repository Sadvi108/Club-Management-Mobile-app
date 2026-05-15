import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_icon_button.dart';

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}

/// Production-style sibling picker — full-height sheet with a header,
/// search box, and a list that marks the current student as "(Selected)".
class _SiblingPicker extends StatefulWidget {
  final List<Map<String, dynamic>> siblings;
  final String currentName;
  final ScrollController scrollController;
  final void Function(dynamic sid, String name) onPick;
  final dynamic rawResponse;
  final String? fetchError;
  final VoidCallback? onRetry;

  const _SiblingPicker({
    required this.siblings,
    required this.currentName,
    required this.scrollController,
    required this.onPick,
    this.rawResponse,
    this.fetchError,
    this.onRetry,
  });

  @override
  State<_SiblingPicker> createState() => _SiblingPickerState();
}

class _SiblingPickerState extends State<_SiblingPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final filtered = widget.siblings.where((s) {
      if (_query.isEmpty) return true;
      final name = (s['name'] ?? s['fullName'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
          child: Column(children: [
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2),
              ),
            )),
            Row(children: [
              Text('Select Sibling',
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
                    color: const Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 18),
                ),
              ),
            ]),
          ]),
        ),
        // Search box
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: c.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: c.textMuted, size: 22),
                hintText: 'Search',
                hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        // List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty(c)
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: c.border.withOpacity(0.6),
                      indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    // /Listing/MySiblings rows: {id, value (login), text (name)}.
                    final sid = s['id'] ?? s['studentId'] ?? s['code'] ?? s['studentID'];
                    final rawName = (s['text'] ?? s['name'] ?? s['fullName'] ?? s['studentName'] ?? '?').toString();
                    final regNo = (s['value'] ?? s['registrationNo'] ?? s['regNo'] ?? s['code'] ?? '').toString();
                    final isCurrent = rawName.toUpperCase() == widget.currentName;
                    return InkWell(
                      onTap: isCurrent ? null : () => widget.onPick(sid, rawName),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(children: [
                          // Initial avatar
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isCurrent
                                    ? c.gradient
                                    : [c.surfaceAlt, c.surfaceAlt],
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              rawName.isEmpty
                                  ? '?'
                                  : rawName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: isCurrent ? Colors.white : c.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        color: c.textPrimary,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3),
                                    children: [
                                      TextSpan(text: rawName.toUpperCase()),
                                      if (isCurrent)
                                        TextSpan(
                                          text: '  ( Selected )',
                                          style: TextStyle(
                                              color: c.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                if (regNo.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(regNo,
                                      style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ],
                            ),
                          ),
                          if (!isCurrent)
                            Icon(Icons.chevron_right,
                                color: c.textMuted, size: 22),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildEmpty(AppColors c) {
    final hasError = widget.fetchError != null;
    final isFiltered = widget.siblings.isNotEmpty && _query.isNotEmpty;
    String preview;
    try {
      preview = widget.rawResponse?.toString() ?? 'null';
    } catch (_) {
      preview = 'unprintable';
    }
    if (preview.length > 800) {
      preview = '${preview.substring(0, 800)}\n…(${preview.length - 800} more chars)';
    }
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 20),
        Icon(
          hasError ? Icons.cloud_off_outlined : Icons.family_restroom,
          size: 56,
          color: hasError ? c.danger : c.textMuted,
        ),
        const SizedBox(height: 14),
        Text(
          isFiltered
              ? 'No matches for "$_query"'
              : (hasError ? 'Could not load siblings' : 'No siblings linked'),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          isFiltered
              ? 'Clear the search to see everyone again.'
              : (hasError
                  ? widget.fetchError!
                  : 'This account isn\'t linked to any sibling profiles in /Listing/MySiblings. If you expected results, tap "Show raw response" below to see what the API returned.'),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4),
        ),
        const SizedBox(height: 18),
        if (widget.onRetry != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            onPressed: widget.onRetry,
          ),
        const SizedBox(height: 14),
        // Inline raw-response viewer
        if (!isFiltered) ...[
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                'Show raw API response',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: SelectableText(
                    preview,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _openEditSheet() async {
    final session = UserSession.instance;
    final info = session.myInfo ?? <String, dynamic>{};
    final name = TextEditingController(text: (info['name'] ?? '').toString());
    final phone = TextEditingController(text: (info['handPhone'] ?? info['phone'] ?? '').toString());
    final email = TextEditingController(text: (info['email'] ?? '').toString());
    final c = context.appColors;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Edit Profile', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                try {
                  await Api.profileUpdateProfile(<String, dynamic>{
                    'name': name.text,
                    'handPhone': phone.text,
                    'email': email.text,
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated')),
                  );
                  await UserSession.instance.refresh();
                } catch (e) {
                  debugPrint('UpdateProfile failed: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              },
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.md)),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _markNotificationRead(dynamic id) async {
    if (id == null) return;
    try {
      await Api.profileUpdateNotification2Read(<String, dynamic>{'id': id, 'groupId': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification marked read')),
        );
      }
      await UserSession.instance.refresh();
    } catch (e) {
      debugPrint('UpdateNotification2Read failed: $e');
    }
  }

  Future<List<dynamic>?> _safeList(Future<dynamic> Function() fn) async {
    try {
      final r = await fn();
      // Use the robust findList — handles nested wrappers + indexed-by-id Maps.
      return UserSession.findList(r);
    } catch (e) {
      debugPrint('safeList failed: $e');
    }
    return null;
  }

  /// Raw siblings response — kept for the in-modal diagnostic so the user
  /// can see exactly what came back when the list shows up empty.
  dynamic _lastSiblingsRaw;

  Future<void> _openSwitchStudent() async {
    // Capture both the parsed list and the raw response so the picker
    // can offer a "what came back?" diagnostic if it's empty.
    dynamic raw;
    List<dynamic>? list;
    String? error;
    try {
      raw = await Api.listingMySiblings();
      list = UserSession.findList(raw);
    } catch (e) {
      error = e.toString();
      debugPrint('listingMySiblings failed: $e');
    }
    _lastSiblingsRaw = raw;

    if (!mounted) return;
    final currentName = UserSession.instance.displayName.toUpperCase();
    final siblings = (list ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => _SiblingPicker(
          siblings: siblings,
          currentName: currentName,
          scrollController: scrollCtrl,
          rawResponse: raw,
          fetchError: error,
          onRetry: () async {
            Navigator.pop(ctx);
            _openSwitchStudent();
          },
          onPick: (sid, name) async {
            Navigator.pop(ctx);
            if (sid == null) return;
            final ok = await UserSession.instance.switchStudent(sid);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok
                  ? 'Switched to $name'
                  : 'Switch failed: ${UserSession.instance.error ?? "unknown"}'),
            ));
          },
        ),
      ),
    );
  }

  Future<void> _openSwitchClub() async {
    final c = context.appColors;
    final session = UserSession.instance;
    final clubCode = (session.authData?['clubCode'] ?? session.authData?['code'] ?? '').toString();
    List<dynamic>? branches;
    if (clubCode.isNotEmpty) {
      branches = await _safeList(() => Api.listingGetBranchesByClubCode(clubCode));
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text('Switch Club', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (branches == null || branches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No branches available.', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            )
          else
            ...branches.whereType<Map>().map((b) {
              final bid = b['id'] ?? b['branchId'] ?? b['code'];
              final name = (b['name'] ?? b['branchName'] ?? '?').toString();
              return InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  if (bid == null) return;
                  final ok = await UserSession.instance
                      .switchBranch(bid, clubCode: clubCode);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok
                        ? 'Switched to $name'
                        : 'Switch failed: ${UserSession.instance.error ?? "unknown"}'),
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle), child: Icon(Icons.business, color: c.primary, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary))),
                    Icon(Icons.chevron_right, color: c.textMuted),
                  ]),
                ),
              );
            }),
        ]),
      ),
    );
  }

  Future<void> _openHelpDesk() async {
    final c = context.appColors;
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Help Desk', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 10),
            TextField(controller: messageCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Message')),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                try {
                  await Api.profileSend2ClubHelpDesk(<String, dynamic>{
                    'subject': subjectCtrl.text,
                    'message': messageCtrl.text,
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Help desk message sent')),
                  );
                } catch (e) {
                  debugPrint('Send2HelpDesk failed: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c.gradient),
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: Shadows.strong(c),
                ),
                child: const Text('Send', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openStudentDetails() async {
    final c = context.appColors;
    final session = UserSession.instance;
    // Merge myInfo + studentAddtnlInfo into one map, labelling keys properly.
    final raw = <String, dynamic>{
      ...?session.myInfo,
      ...?session.studentAddtnlInfo,
    };
    // Remove noisy / internal fields
    const skip = {'accessToken', 'refreshToken', 'userType', 'clubList', 'branchList'};
    final entries = raw.entries
        .where((e) => !skip.contains(e.key) && e.value != null && e.value.toString().isNotEmpty)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: ListView(controller: ctrl, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            Text('Student Details', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Text('No details available.', style: TextStyle(color: c.textSecondary))
            else
              ...entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 130,
                    child: Text(_humanizeKey(e.key),
                        style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Text(e.value.toString(),
                        style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ]),
              )),
          ]),
        ),
      ),
    );
  }

  /// Converts camelCase / PascalCase API keys into readable labels.
  static String _humanizeKey(String key) {
    final spaced = key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}');
    final result = spaced[0].toUpperCase() + spaced.substring(1);
    // Common abbreviation fixes
    return result
        .replaceAll('I C ', 'IC ')
        .replaceAll('T Center', 'Training Center')
        .replaceAll('S Center', 'Student Center')
        .replaceAll('Hand Phone', 'Phone')
        .replaceAll('Addtnl', 'Additional')
        .trim();
  }

  Future<void> _openMyPurchases() async {
    final c = context.appColors;
    final list = await _safeList(Api.reportsPurchaseRequests);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text('My Purchases', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Flexible(
            child: (list == null || list.isEmpty)
                ? Text('No purchases yet.', style: TextStyle(fontSize: 13, color: c.textSecondary))
                : ListView(
                    shrinkWrap: true,
                    children: list.whereType<Map>().map((p) {
                      final label = (p['name'] ?? p['description'] ?? p['text'] ?? 'Purchase').toString();
                      final amt = (p['amount'] ?? p['value'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                            if (amt.isNotEmpty) Text('RM $amt', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                          ])),
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                final r = await Api.purchaseRequestFetchProducts();
                                final products = r is List ? r : (r is Map && r['data'] is List ? r['data'] as List : const <dynamic>[]);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Loaded ${products.length} products')),
                                );
                              } catch (e) {
                                debugPrint('FetchProducts failed: $e');
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                              }
                            },
                            icon: Icon(Icons.replay, size: 14, color: c.primary),
                            label: Text('Reorder', style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _personalInfoCard(AppColors c, UserSession session) {
    // Build rows from live API data — only show non-empty values.
    final rows = <_InfoRow>[
      if (session.phone.isNotEmpty)        _InfoRow(Icons.phone_outlined,          'Phone',            session.phone),
      if (session.email.isNotEmpty)        _InfoRow(Icons.email_outlined,           'Email',            session.email),
      if (session.currentGrade.isNotEmpty) _InfoRow(Icons.military_tech_outlined,   'Belt / Grade',     session.currentGrade),
      if (session.tCenterName.isNotEmpty)  _InfoRow(Icons.place_outlined,           'Training Center',  session.tCenterName),
      if (session.instructorName.isNotEmpty) _InfoRow(Icons.person_outline,         'Instructor',       session.instructorName),
      if (session.trainingTime.isNotEmpty) _InfoRow(Icons.schedule_outlined,        'Training Time',    session.trainingTime),
      // Extra fields from studentAddtnlInfo
      ..._extraInfoRows(c, session),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gaps.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title row with accent bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.primary.withOpacity(0.18), c.primary.withOpacity(0.30)],
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.badge_outlined, size: 16, color: c.primary),
            ),
            const SizedBox(width: 10),
            Text('Personal Info',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${rows.length} fields',
                  style: TextStyle(color: c.primary, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: List.generate(rows.length, (i) {
              final r = rows[i];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: i == rows.length - 1
                    ? null
                    : BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: c.border.withOpacity(0.5)),
                        ),
                      ),
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(r.icon, size: 16, color: c.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.label,
                            style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2)),
                        const SizedBox(height: 2),
                        Text(r.value,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ]),
              );
            }),
          ),
        ),
      ]),
    );
  }

  List<_InfoRow> _extraInfoRows(AppColors c, UserSession session) {
    final extra = session.studentAddtnlInfo;
    if (extra == null) return [];
    // Server returns lowercase keys: standardid, height, classname,
    // tshirtSize, schoolname, dob, bloodtype, healthstatus, foodtype.
    // (Some deployments also include parent/address fields — kept as
    // fallbacks for cross-account compatibility.)
    const fieldMap = <String, List<dynamic>>{
      'dob':          [Icons.cake_outlined,          'Date of Birth'],
      'schoolname':   [Icons.school_outlined,        'School'],
      'school':       [Icons.school_outlined,        'School'],
      'classname':    [Icons.class_outlined,         'Class'],
      'standardid':   [Icons.format_list_numbered,   'Standard'],
      'height':       [Icons.height,                 'Height'],
      'tshirtSize':   [Icons.checkroom_outlined,     'T-shirt Size'],
      'bloodtype':    [Icons.bloodtype_outlined,     'Blood Type'],
      'healthstatus': [Icons.health_and_safety_outlined, 'Health Status'],
      'foodtype':     [Icons.restaurant_outlined,    'Food Preference'],
      // Cross-account fallbacks (legacy/instructor accounts).
      'icNo':         [Icons.credit_card_outlined,   'IC Number'],
      'passportNo':   [Icons.book_outlined,          'Passport'],
      'parentName':   [Icons.family_restroom,        'Parent Name'],
      'parentPhone':  [Icons.phone_in_talk_outlined, 'Parent Phone'],
      'address':      [Icons.home_outlined,          'Address'],
      'gender':       [Icons.person_outline,         'Gender'],
      'nationality':  [Icons.flag_outlined,          'Nationality'],
    };
    final rows = <_InfoRow>[];
    final seenLabels = <String>{};
    for (final entry in fieldMap.entries) {
      final raw = extra[entry.key];
      if (raw == null) continue;
      var v = raw.toString().trim();
      if (v.isEmpty || v == '0' || v == '0.0') continue;
      // Truncate ISO date stamps to yyyy-MM-dd.
      if (entry.key == 'dob' && v.length >= 10 && v.contains('T')) {
        v = v.substring(0, 10);
      }
      final label = entry.value[1] as String;
      if (seenLabels.contains(label)) continue;
      seenLabels.add(label);
      rows.add(_InfoRow(entry.value[0] as IconData, label, v));
    }
    return rows;
  }

  Widget _actionTile(AppColors c, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Gaps.xl, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: Shadows.card(c),
        ),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle), child: Icon(icon, color: c.primary, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary))),
          Icon(Icons.chevron_right, color: c.textMuted),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = context.watch<ThemeProvider>();
    final session = context.watch<UserSession>();
    final liveName = session.displayName.isNotEmpty ? session.displayName : 'Student';
    final liveId = session.registrationNo.isNotEmpty ? session.registrationNo : '—';
    final livePhoto = session.studentPhoto.isNotEmpty ? session.studentPhoto : '';
    final liveMembership = session.clubName.isNotEmpty ? session.clubName : '';
    final liveBelt = session.currentGrade.isNotEmpty ? session.currentGrade : '';
    final liveLevel = session.tCenterName.isNotEmpty ? session.tCenterName : '';
    return Container(
      color: c.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          children: [
            // Gradient header
            Container(
              padding: EdgeInsets.fromLTRB(Gaps.xl, MediaQuery.of(context).padding.top + 6, Gaps.xl, 50),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(children: [
                Row(children: [
                  const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  AppIconButton(
                    icon: Icons.edit,
                    onPressed: _openEditSheet,
                    backgroundColor: Colors.white.withOpacity(0.22),
                    foregroundColor: Colors.white,
                    size: 38,
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.6), width: 2)),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white.withOpacity(0.22),
                    backgroundImage: livePhoto.isNotEmpty
                        ? CachedNetworkImageProvider(livePhoto)
                        : null,
                    child: livePhoto.isNotEmpty
                        ? null
                        : Text(
                            liveName.isNotEmpty ? liveName[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(liveName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(liveId, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.verified_user, size: 14, color: Color(0xFFFFF7ED)),
                    const SizedBox(width: 4),
                    Text(liveMembership, style: const TextStyle(color: Color(0xFFFFF7ED), fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),

            // Virtual ID card (overlapping)
            Transform.translate(
              offset: const Offset(0, -36),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Gaps.xl),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(Radii.xl),
                  border: c.isDark ? Border.all(color: c.border) : null,
                  boxShadow: Shadows.card(c),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.asset(kLogoAssetPath, width: 22, height: 22, fit: BoxFit.cover)),
                          const SizedBox(width: 8),
                          Text('D-CLIX', style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        ]),
                        const SizedBox(height: 8),
                        Text(liveName, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('$liveLevel · $liveBelt', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                        const SizedBox(height: 10),
                        Row(children: List.generate(20, (i) =>
                          Padding(padding: const EdgeInsets.only(right: 2), child: Container(width: 2, height: (20 + (i * 7) % 12).toDouble(), color: c.textPrimary.withOpacity(i % 3 == 0 ? 1 : 0.6))))),
                        const SizedBox(height: 4),
                        Text(liveId, style: TextStyle(color: c.textPrimary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Icon(Icons.qr_code_2, size: 60, color: c.primary),
                  ),
                ]),
              ),
            ),

            // Personal info card
            _personalInfoCard(c, session),
            const SizedBox(height: 12),

            // Theme toggle
            Container(
              margin: const EdgeInsets.symmetric(horizontal: Gaps.xl).copyWith(top: 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(Radii.xl),
                border: c.isDark ? Border.all(color: c.border) : null,
                boxShadow: Shadows.card(c),
              ),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                  child: Icon(theme.isDark ? Icons.dark_mode : Icons.light_mode, color: c.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(theme.isDark ? 'Dark Mode' : 'Light Mode', style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(theme.isDark ? 'Orange & black' : 'Orange & white', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: theme.isDark,
                  onChanged: (v) => theme.setDark(v),
                  activeColor: Colors.white,
                  activeTrackColor: c.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: c.border,
                ),
              ]),
            ),

            const SizedBox(height: 12),
            _actionTile(c, Icons.swap_horiz, 'Switch Student', _openSwitchStudent),
            _actionTile(c, Icons.business, 'Switch Club', _openSwitchClub),
            _actionTile(c, Icons.support_agent, 'Help Desk', _openHelpDesk),
            _actionTile(c, Icons.badge_outlined, 'Student Details', _openStudentDetails),
            _actionTile(c, Icons.shopping_bag_outlined, 'My Purchases', _openMyPurchases),
            const SizedBox(height: 12),
            _notificationsCard(context, c, session),
            const SizedBox(height: 18),
            _logoutBtn(context, c),
            const SizedBox(height: 8),
            Text('D-Clix · v1.0.0', style: TextStyle(color: c.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _notificationsCard(BuildContext ctx, AppColors c, UserSession session) {
    final notifs = (session.notifications ?? const []).whereType<Map>().toList();
    if (notifs.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gaps.xl),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notifications_active, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('LIVE · Notifications (${notifs.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...notifs.take(8).map((n) {
            final id = n['id'] ?? n['groupId'] ?? n['groupid'];
            final title = (n['text'] ?? n['title'] ?? n['name'] ?? '').toString();
            final body = (n['value'] ?? n['description'] ?? '').toString()
                .replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();
            return InkWell(
              onTap: () {
                final gid = (n['groupId'] ?? n['groupid'] ?? id);
                if (gid != null) {
                  context.push('/notification/${Uri.encodeComponent(gid.toString())}');
                } else {
                  _markNotificationRead(id);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  if (body.isNotEmpty)
                    Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _logoutBtn(BuildContext ctx, AppColors c) => InkWell(
        onTap: () {
          UserSession.instance.logout();
          ctx.go('/login');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.logout, color: c.danger, size: 18),
            const SizedBox(width: 8),
            Text('Logout', style: TextStyle(color: c.danger, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      );
}
