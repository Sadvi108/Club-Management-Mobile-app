import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/qr_content.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/student_switcher.dart';

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Ask whether to take a new photo (camera) or pick one from the device
  /// (gallery). Returns the chosen [ImageSource], or null if dismissed.
  Future<ImageSource?> _pickPhotoSource(BuildContext ctx, AppColors c) {
    return showModalBottomSheet<ImageSource>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Profile photo',
              style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _photoSourceTile(sheetCtx, c, Icons.camera_alt_outlined,
              'Take a photo', ImageSource.camera),
          const SizedBox(height: 8),
          _photoSourceTile(sheetCtx, c, Icons.photo_library_outlined,
              'Choose from device', ImageSource.gallery),
        ]),
      ),
    );
  }

  Widget _photoSourceTile(
      BuildContext ctx, AppColors c, IconData icon, String label, ImageSource src) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, src),
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: c.primary.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: c.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Future<void> _openEditSheet() async {
    final session = UserSession.instance;
    final info = session.myInfo ?? <String, dynamic>{};
    final addtnl = session.studentAddtnlInfo ?? <String, dynamic>{};
    final c = context.appColors;

    final ctrls = <String, TextEditingController>{
      'Name': TextEditingController(text: (info['name'] ?? '').toString()),
      'IcNo': TextEditingController(text: (info['icNo'] ?? '').toString()),
      'Gender': TextEditingController(text: (info['gender'] ?? '').toString()),
      'EmailAddress':
          TextEditingController(text: (info['email'] ?? info['emailAddress'] ?? '').toString()),
      'HandPhone': TextEditingController(
          text: (info['handPhone'] ?? info['phone'] ?? '').toString()),
      'Address1': TextEditingController(text: (info['address1'] ?? '').toString()),
      'Address2': TextEditingController(text: (info['address2'] ?? '').toString()),
      'Address3': TextEditingController(text: (info['address3'] ?? '').toString()),
      'Address4': TextEditingController(text: (info['address4'] ?? '').toString()),
      'PostalCode': TextEditingController(text: (info['postalCode'] ?? '').toString()),
      'Height': TextEditingController(text: (addtnl['height'] ?? '').toString()),
      'Weight': TextEditingController(text: (addtnl['weight'] ?? '').toString()),
    };
    const labels = {
      'Name': 'Full name', 'IcNo': 'IC / Reg No', 'Gender': 'Gender',
      'EmailAddress': 'Email', 'HandPhone': 'Phone',
      'Address1': 'Address line 1', 'Address2': 'Address line 2',
      'Address3': 'Address line 3', 'Address4': 'Address line 4',
      'PostalCode': 'Postal code', 'Height': 'Height (cm)', 'Weight': 'Weight (kg)',
    };

    Uint8List? pickedBytes;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        ImageProvider? avatarProvider;
        if (pickedBytes != null) {
          avatarProvider = MemoryImage(pickedBytes!);
        } else if (session.localPhotoB64.isNotEmpty) {
          try {
            avatarProvider = MemoryImage(base64Decode(session.localPhotoB64));
          } catch (_) {}
        } else if (session.studentPhoto.startsWith('http')) {
          avatarProvider = CachedNetworkImageProvider(session.studentPhoto);
        }
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 14),
                  Text('Edit Profile', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  // Avatar picker
                  Center(
                    child: Stack(children: [
                      Container(
                        width: 92, height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: c.gradient),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          backgroundColor: c.surfaceAlt,
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? Icon(Icons.person, size: 40, color: c.primary)
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: InkWell(
                          onTap: () async {
                            final src = await _pickPhotoSource(ctx, c);
                            if (src == null) return;
                            final x = await ImagePicker().pickImage(
                                source: src,
                                maxWidth: 600, imageQuality: 80);
                            if (x == null) return;
                            final bytes = await x.readAsBytes();
                            setSheet(() => pickedBytes = bytes);
                          },
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: c.primary, shape: BoxShape.circle,
                              border: Border.all(color: c.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  for (final key in ctrls.keys) ...[
                    TextField(
                      controller: ctrls[key],
                      keyboardType: (key == 'Height' || key == 'Weight')
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : (key == 'HandPhone'
                              ? TextInputType.phone
                              : TextInputType.text),
                      decoration: InputDecoration(
                        labelText: labels[key],
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: saving
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            final fields = <String, String>{
                              'Id': (info['id'] ?? '').toString(),
                            };
                            ctrls.forEach((k, v) {
                              if (v.text.trim().isNotEmpty) fields[k] = v.text.trim();
                            });
                            String? b64;
                            if (pickedBytes != null) {
                              b64 = base64Encode(pickedBytes!);
                              fields['ProfilePic'] = b64;
                            }
                            try {
                              await Api.profileUpdateProfile(fields);
                              if (b64 != null) {
                                await session.setLocalPhoto(b64);
                              }
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profile updated')),
                              );
                              await session.refresh();
                            } catch (e) {
                              debugPrint('UpdateProfile failed: $e');
                              // Photo still cached locally even if the server
                              // rejected, so the picked avatar persists.
                              if (b64 != null) await session.setLocalPhoto(b64);
                              if (!mounted) return;
                              setSheet(() => saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Saved photo locally; server: $e')),
                              );
                            }
                          },
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: c.gradient),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save changes',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      }),
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

  /// Opens the shared student switcher sheet (also used by the Home
  /// avatar dropdown).
  Future<void> _openSwitchStudent() => showStudentSwitcher(context);

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

  /// Prominent two-up switcher: Switch Student + Switch Club. Each shows
  /// the current selection so the user always knows the active context.
  Widget _switcherRow(AppColors c, UserSession session) {
    Widget card(IconData icon, String label, String value, VoidCallback tap) {
      return Expanded(
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: c.isDark ? Border.all(color: c.border) : null,
              boxShadow: Shadows.card(c),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.12),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: c.primary, size: 17),
                  ),
                  const Spacer(),
                  Icon(Icons.unfold_more, color: c.textMuted, size: 16),
                ]),
                const SizedBox(height: 10),
                Text(label.toUpperCase(),
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
    }

    final club = session.clubDisplayName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
      child: Row(children: [
        card(Icons.swap_horiz, 'Active student', session.displayName,
            _openSwitchStudent),
        const SizedBox(width: 12),
        card(Icons.business, 'Club', club.isNotEmpty ? club : 'Switch club',
            _openSwitchClub),
      ]),
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
    // Locally-cached uploaded photo takes priority over the network URL.
    ImageProvider? avatarImg;
    if (session.localPhotoB64.isNotEmpty) {
      try {
        avatarImg = MemoryImage(base64Decode(session.localPhotoB64));
      } catch (_) {}
    }
    avatarImg ??=
        livePhoto.startsWith('http') ? CachedNetworkImageProvider(livePhoto) : null;
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
                    backgroundImage: avatarImg,
                    child: avatarImg == null
                        ? Text(
                            liveName.isNotEmpty ? liveName[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900),
                          )
                        : null,
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
                        const SizedBox(height: 12),
                        Text(liveId, style: TextStyle(color: c.textPrimary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  _VirtualIdQr(
                    // Official ST-XXXXXXXX format — the same payload as the
                    // club's printed student QR, so an instructor scanning
                    // this card marks attendance for this student.
                    content: QrContent.studentFromRaw(
                            session.authData?['studentId'] ??
                                session.authData?['id']) ??
                        session.registrationNo,
                    size: 90,
                  ),
                ]),
              ),
            ),

            // Prominent switcher row — Switch Student / Switch Club.
            // Kept near the top so guardians don't have to scroll.
            _switcherRow(c, session),
            const SizedBox(height: 12),

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
            _actionTile(c, Icons.qr_code_scanner, 'Scan QR to Check In',
                () => context.push('/qr-scan')),
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
            Text('Notifications (${notifs.length})',
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

/// Real scannable QR for the student's virtual ID card.
///
/// Fetches the official QR image from `/Utilities/QRCode` (same source the
/// in-app scanner resolves against) using the student's id as the payload.
/// Shows a spinner while loading and a clearly-labelled "Unavailable"
/// placeholder on error — never a fake/decorative QR.
class _VirtualIdQr extends StatefulWidget {
  final String content;
  final double size;
  const _VirtualIdQr({required this.content, required this.size});

  @override
  State<_VirtualIdQr> createState() => _VirtualIdQrState();
}

class _VirtualIdQrState extends State<_VirtualIdQr> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VirtualIdQr old) {
    super.didUpdateWidget(old);
    if (old.content != widget.content) _load();
  }

  Future<void> _load() async {
    final content = widget.content.trim();
    if (content.isEmpty || content == 'null') {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // The endpoint returns raw PNG bytes — must skip the JSON decoder.
      final bytes = await Api.utilitiesQRCodeBytes(
          width: 300, height: 300, content: content);
      if (!mounted) return;
      setState(() {
        _bytes = bytes.isEmpty ? null : bytes;
        _loading = false;
        _failed = bytes.isEmpty;
      });
    } catch (e) {
      debugPrint('Virtual ID QR load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: _loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
            )
          : (_failed || _bytes == null)
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.qr_code_2, size: 30, color: c.textMuted),
                  const SizedBox(height: 2),
                  Text('Unavailable',
                      style: TextStyle(fontSize: 8, color: c.textMuted)),
                ])
              : Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.memory(_bytes!,
                      fit: BoxFit.contain, gaplessPlayback: true),
                ),
    );
  }
}
