import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../services/online_submissions.dart';
import '../services/response_utils.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/report_kit.dart';
import '../widgets/rn_kit.dart';

/// `toLocaleString("en-GB", {day, month: short, year, hour, minute})`.
String _fmtWhen(dynamic iso) {
  final s = '${iso ?? ''}';
  if (s.isEmpty) return '—';
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  return '${fmtDateGB(s)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

bool _is404(Object e) => e is ApiException && e.statusCode == 404;

/// Port of `frontend/app/new-student.tsx` (Expo v2.11.1) — online submission approvals.
///
/// The routes are a proposed contract not yet on the backend: a 404 renders "Awaiting
/// backend", never fabricated rows.
class NewStudentScreen extends StatefulWidget {
  const NewStudentScreen({super.key});
  @override
  State<NewStudentScreen> createState() => _NewStudentScreenState();
}

class _NewStudentScreenState extends State<NewStudentScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;
  bool _notReady = false;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _notReady = false;
    });
    try {
      final rows = await OnlineSubmissions.fetch();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        if (_is404(e)) {
          _notReady = true;
        } else {
          _error = friendlyError(e);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _id(Map r) => (r['id'] as num?)?.toInt() ?? int.tryParse('${r['id']}') ?? 0;

  void _openParticulars(Map r) => context.push(
      '/instructor/student-particulars/${_id(r)}?name=${Uri.encodeQueryComponent('${r['studentName'] ?? ''}')}');

  Future<void> _approve(Map<String, dynamic> r) async {
    final ok = await confirmDialog(context, 'Approve registration',
        message:
            'Approve ${r['studentName']}? Make sure Training Centre, Student Centre, Present Grade and Fee Type are set (open the student to review). An auto WhatsApp with the login is sent to the parent.',
        confirmLabel: 'Approve');
    if (!ok) return;
    setState(() => _busyId = _id(r));
    try {
      await OnlineSubmissions.approve({'id': _id(r)});
      if (mounted) await notify(context, 'Approved', '${r['studentName']} has been approved.');
      _load();
    } catch (e) {
      if (mounted) await notify(context, 'Approve failed', friendlyError(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    final ok = await confirmDialog(context, 'Reject registration',
        message: "Reject and remove ${r['studentName']}'s submission?", confirmLabel: 'Reject', destructive: true);
    if (!ok) return;
    setState(() => _busyId = _id(r));
    try {
      await OnlineSubmissions.reject(_id(r));
      if (mounted) await notify(context, 'Rejected', "${r['studentName']}'s submission was rejected.");
      _load();
    } catch (e) {
      if (mounted) await notify(context, 'Reject failed', friendlyError(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    Widget stateBox({Widget? icon, String? title, required String sub, String? retryLabel}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
          child: Column(children: [
            if (icon != null) icon,
            if (title != null) ...[
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ],
            const SizedBox(height: 8),
            Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 19 / 13)),
            if (retryLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Touchable(
                  onPress: _load,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.primary.hexA('55'), width: 1.5)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Ion.refresh, size: 15, color: c.primary),
                      const SizedBox(width: 6),
                      Text(retryLabel, style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
          ]),
        );

    Widget kv(String label, dynamic v) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(children: [
            Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${v ?? ''}'.trim().isEmpty ? '—' : '$v'.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12.5, color: c.textPrimary, fontWeight: FontWeight.w700)),
            ),
          ]),
        );

    Widget tag(bool on, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c.primary : c.textMuted)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.textSecondary)),
          ]),
        );

    Widget actBtn(String label, IconData icon, Color fg, Color bg, VoidCallback? onTap, {int flex = 1}) => Expanded(
          flex: flex,
          child: Touchable(
            activeOpacity: 0.85,
            onPress: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ]),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ScreenHeader(title: 'New Student', subtitle: 'Online submission approvals'),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 60),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: c.primary.hexA('22')),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                      child: Icon(Ion.informationCircle, size: 20, color: c.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Approving a new student',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary)),
                        const SizedBox(height: 4),
                        Text('1. Open a submission and confirm Training Centre, Student Centre, Present Grade and Fee Type.',
                            style: TextStyle(fontSize: 12, color: c.textSecondary, height: 17 / 12)),
                        const SizedBox(height: 2),
                        Text('2. Tap Approve — an auto WhatsApp with the user ID + password is sent to the parent.',
                            style: TextStyle(fontSize: 12, color: c.textSecondary, height: 17 / 12)),
                      ]),
                    ),
                  ]),
                ),
                if (_loading) const SkeletonList(rows: 4, lines: 3, padding: EdgeInsets.only(top: 6)),
                if (!_loading && _notReady)
                  stateBox(
                    icon: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                      child: Icon(Ion.cloudOfflineOutline, size: 30, color: c.primary),
                    ),
                    title: 'Awaiting backend',
                    sub:
                        "Online submission approvals aren't available on the app server yet. This screen goes live automatically once the club API exposes the submissions endpoint — no update needed.",
                    retryLabel: 'Check again',
                  ),
                if (!_loading && !_notReady && _error != null)
                  stateBox(icon: Icon(Ion.alertCircleOutline, size: 34, color: c.danger), sub: _error!, retryLabel: 'Retry'),
                if (!_loading && !_notReady && _error == null && _rows.isEmpty)
                  stateBox(
                    icon: Icon(Ion.checkmarkDoneCircleOutline, size: 34, color: c.success),
                    title: 'All caught up',
                    sub: 'No pending online submissions right now.',
                  ),
                if (!_loading)
                  for (final r in _rows)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: rnCard(c, radius: Radii.xl),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Touchable(
                          activeOpacity: 0.8,
                          onPress: () => _openParticulars(r),
                          child: Row(children: [
                            Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                              child: Text(('${r['studentName'] ?? '?'}'.trim().isEmpty ? '?' : '${r['studentName']}'.trim())[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${r['studentName'] ?? ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.textPrimary)),
                                const SizedBox(height: 2),
                                Text(
                                    [r['gender'], r['presentGrade']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · ').isEmpty
                                        ? '—'
                                        : [r['gender'], r['presentGrade']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
                              ]),
                            ),
                            Icon(Ion.chevronForward, size: 18, color: c.textMuted),
                          ]),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                          child: Column(children: [
                            kv('School', r['schoolName']),
                            kv('Training centre', r['trainingCentre']),
                            kv('Guardian', r['guardianName']),
                            kv('Contact', r['contactNo']),
                            kv('Submitted', _fmtWhen(r['submissionDate'])),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(spacing: 6, runSpacing: 6, children: [
                            if (r['isOldStudent'] != null) tag(r['isOldStudent'] == true, r['isOldStudent'] == true ? 'Old student' : 'New student'),
                            if (r['uniformRequested'] == true) tag(true, 'Uniform requested'),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Row(children: [
                            actBtn('Particulars', Ion.documentTextOutline, c.primary, c.surfaceAlt, () => _openParticulars(r)),
                            const SizedBox(width: 8),
                            actBtn('Reject', Ion.close, c.danger, c.danger.hexA('14'), _busyId == _id(r) ? null : () => _reject(r)),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 12,
                              child: Touchable(
                                activeOpacity: 0.9,
                                onPress: _busyId == _id(r) ? null : () => _approve(r),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(gradient: LinearGradient(colors: c.gradient), borderRadius: BorderRadius.circular(Radii.md)),
                                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(Ion.checkmark, size: 16, color: Colors.white),
                                    SizedBox(width: 5),
                                    Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                                  ]),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// Port of `frontend/app/student-particulars.tsx` (Expo v2.11.1).
class StudentParticularsScreen extends StatefulWidget {
  final int id;
  final String name;
  const StudentParticularsScreen({super.key, required this.id, this.name = ''});
  @override
  State<StudentParticularsScreen> createState() => _StudentParticularsScreenState();
}

class _StudentParticularsScreenState extends State<StudentParticularsScreen> {
  static const _required = [
    (key: 'trainingCentre', label: 'Training Centre'),
    (key: 'studentCentre', label: 'Student Centre'),
    (key: 'presentGrade', label: 'Present Grade'),
    (key: 'feeType', label: 'Fee Type'),
  ];

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _notReady = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id == 0) {
      setState(() {
        _error = 'Missing submission id.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _notReady = false;
    });
    try {
      final d = await OnlineSubmissions.detail(widget.id);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_is404(e)) {
          _notReady = true;
        } else {
          _error = friendlyError(e);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _missing => _data == null ? const [] : [for (final r in _required) if ('${_data![r.key] ?? ''}'.trim().isEmpty) r.label];

  Future<void> _approve() async {
    final d = _data;
    if (d == null) return;
    if (_missing.isNotEmpty) {
      await notify(context, 'Missing required fields', 'Set these first (in the club system): ${_missing.join(', ')}.');
      return;
    }
    final ok = await confirmDialog(context, 'Approve registration',
        message: 'Approve ${d['studentName']}? An auto WhatsApp with the login is sent to the parent.', confirmLabel: 'Approve');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await OnlineSubmissions.approve({...d, 'id': widget.id});
      if (!mounted) return;
      await notify(context, 'Approved', '${d['studentName']} has been approved.');
      if (mounted) safeBack(context);
    } catch (e) {
      if (mounted) await notify(context, 'Approve failed', friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final d = _data;
    if (d == null) return;
    final ok = await confirmDialog(context, 'Reject registration',
        message: "Reject ${d['studentName']}'s submission?", confirmLabel: 'Reject', destructive: true);
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await OnlineSubmissions.reject(widget.id);
      if (!mounted) return;
      await notify(context, 'Rejected', "${d['studentName']}'s submission was rejected.");
      if (mounted) safeBack(context);
    } catch (e) {
      if (mounted) await notify(context, 'Reject failed', friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final d = _data;
    final missing = _missing;
    final canApprove = d != null && missing.isEmpty;
    final headerName = (widget.name.isNotEmpty ? widget.name : '${d?['studentName'] ?? 'Student'}').trim();

    Widget kv(String label, dynamic value, {bool req = false}) {
      final s = '${value ?? ''}'.trim();
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
        child: Row(children: [
          Expanded(
            child: Text('$label${req ? ' *' : ''}',
                style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 13,
            child: Text(s.isEmpty ? '—' : s,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: req && s.isEmpty ? c.danger : c.textPrimary)),
          ),
        ]),
      );
    }

    Widget section(String title, List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: rnCard(c, radius: Radii.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: c.primary)),
            ),
            ...children,
          ]),
        );

    String yesNo(dynamic v) => v == null ? '' : (v == true ? 'Yes' : 'No');

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: c.primary,
          padding: EdgeInsets.only(top: top),
          child: Container(
            padding: const EdgeInsets.fromLTRB(Gaps.lg, 6, Gaps.lg, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Touchable(
                onPress: () => safeBack(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                  child: const Icon(Ion.chevronBack, size: 22, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('STUDENT PARTICULARS',
                        style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 2),
                  Text(headerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                  if ('${d?['regNo'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${d!['regNo']}',
                          style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 120),
            children: [
              if (_loading) const SkeletonList(rows: 5, lines: 2, padding: EdgeInsets.zero),
              if (!_loading && _notReady)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                  child: Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                      child: Icon(Ion.cloudOfflineOutline, size: 28, color: c.primary),
                    ),
                    const SizedBox(height: 12),
                    Text('Awaiting backend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Student particulars load here once the club API exposes the submission-details endpoint.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 19 / 13)),
                  ]),
                ),
              if (!_loading && !_notReady && _error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                  child: Column(children: [
                    Icon(Ion.alertCircleOutline, size: 32, color: c.danger),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ]),
                ),
              if (!_loading && d != null) ...[
                if (missing.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.warning.hexA('1A'),
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: c.warning.hexA('44')),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Ion.warningOutline, size: 18, color: c.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(TextSpan(
                          text: 'Required before approval: ',
                          style: TextStyle(fontSize: 12.5, color: c.textPrimary, height: 18 / 12.5),
                          children: [
                            TextSpan(text: missing.join(', '), style: const TextStyle(fontWeight: FontWeight.w800)),
                            const TextSpan(text: '. Set them in the club system, then refresh.'),
                          ],
                        )),
                      ),
                    ]),
                  ),
                section('Registration', [
                  kv('Reg. No', d['regNo']),
                  kv('QR Code', d['qrCode']),
                  kv('Present Grade', d['presentGrade'], req: true),
                  kv('IC / Passport', d['icNo']),
                  kv('Gender', d['gender']),
                  kv('Date of Birth', d['dateOfBirth']),
                  kv('Old Student', yesNo(d['isOldStudent'])),
                ]),
                section('Training', [
                  kv('Training Centre', d['trainingCentre'], req: true),
                  kv('Student Centre', d['studentCentre'], req: true),
                  kv('School / Workplace', d['schoolWorkplace'] ?? d['schoolName']),
                  kv('Exam Centre', d['examCentre']),
                  kv('Training Day', d['trainingDay']),
                  kv('Training Time', d['trainingTime']),
                  kv('Commencement', d['classCommencementDate']),
                ]),
                section('Guardian & Contact', [
                  kv('Parent / Guardian', d['guardianName']),
                  kv('Occupation', d['guardianOccupation']),
                  kv('Contact / WhatsApp', d['contactNo']),
                  kv('Email', d['emailAddress']),
                  kv('Address', [d['addressLine1'], d['addressLine2'], d['city'], d['state'], d['postcode']].where((x) => '${x ?? ''}'.isNotEmpty).join(', ')),
                ]),
                section('Fees & Membership', [
                  kv('Fee Type', d['feeType'], req: true),
                  kv('Package / Session', d['packageSession']),
                  kv('Registration Year', d['registrationYear']),
                  kv('Material (Uniform)', d['material']),
                  kv('Uniform Requested', yesNo(d['uniformRequested'])),
                  kv('Outstanding', d['outstandingAmount'] == null ? '' : 'RM ${(d['outstandingAmount'] as num).toStringAsFixed(2)}'),
                  kv('Health Remarks', d['healthRemarks']),
                ]),
              ],
            ],
          ),
        ),
        if (!_loading && d != null)
          Container(
            padding: EdgeInsets.fromLTRB(Gaps.xl, 12, Gaps.xl, bottom + 12 > 20 ? bottom + 12 : 20),
            decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border)), boxShadow: Shadows.card(c)),
            child: Row(children: [
              Touchable(
                activeOpacity: 0.85,
                onPress: _busy ? null : _reject,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(color: c.danger.hexA('14'), borderRadius: BorderRadius.circular(Radii.md)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Ion.close, size: 18, color: c.danger),
                    const SizedBox(width: 6),
                    Text('Reject', style: TextStyle(color: c.danger, fontWeight: FontWeight.w800, fontSize: 14)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: canApprove ? 1 : 0.5,
                  child: Touchable(
                    activeOpacity: 0.9,
                    onPress: _busy ? null : _approve,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: c.gradient), borderRadius: BorderRadius.circular(Radii.md)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Ion.checkmark, size: 18, color: Colors.white),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(canApprove ? 'Approve' : 'Complete fields to approve',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
