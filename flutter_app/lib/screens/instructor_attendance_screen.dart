import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api.dart';
import '../services/attendance_outcome.dart';
import '../services/nfc_service.dart';
import '../theme/app_theme.dart';
import '../utils/qr_content.dart';
import '../widgets/app_header.dart';

/// Instructor attendance hub — three ways to mark students present:
///
///   Manual : pick the class, see the roster, tap to mark each student.
///   QR     : scan the venue's TC poster once, then student QRs continuously.
///   NFC    : same as QR but reading the students' linked NFC tags.
///
/// Plus "Link NFC Tag": writes a student's official ST-XXXXXXXX code onto a
/// blank NDEF tag (the tag then behaves exactly like the student's QR).
///
/// Every mode posts the same body: POST /Attendance/Add
///   {qrCode: 'ST-…'|'TC-…', attendanceType: 1, tTimeId: selected or 0}
class InstructorAttendanceScreen extends StatefulWidget {
  const InstructorAttendanceScreen({super.key});
  @override
  State<InstructorAttendanceScreen> createState() =>
      _InstructorAttendanceScreenState();
}

enum _RowState { idle, pending, done, failed }

class _InstructorAttendanceScreenState
    extends State<InstructorAttendanceScreen> {
  int _mode = 0; // 0 manual · 1 qr · 2 nfc

  // Class context ------------------------------------------------------------
  List<Map<String, dynamic>> _centers = const [];
  Object? _tcId;
  String _tcName = '';
  List<Map<String, dynamic>> _times = const [];
  Object? _timeId; // null = not specified → posts 0
  bool _loadingCenters = true;
  String? _centersError;

  // Roster (manual tab + tag writer) ------------------------------------------
  List<Map<String, dynamic>> _students = const [];
  bool _loadingStudents = false;
  String? _studentsError;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Marking state shared by all modes -----------------------------------------
  final Map<String, _RowState> _rowState = {}; // key: ST-/TC- code
  final List<String> _feed = []; // newest first, "HH:mm — label"
  String? _hint; // transient invalid-code hint
  Timer? _hintTimer;

  // QR tab ---------------------------------------------------------------------
  MobileScannerController? _scanner;
  bool _tcScanned = false; // step-1 done (or skipped via dropdown)

  // NFC tab ----------------------------------------------------------------------
  bool? _nfcAvailable;
  bool _nfcReading = false;

  @override
  void initState() {
    super.initState();
    _loadCenters();
    NfcService.isAvailable().then((v) {
      if (mounted) setState(() => _nfcAvailable = v);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _searchCtrl.dispose();
    _scanner?.dispose();
    if (_nfcReading) NfcService.stop();
    super.dispose();
  }

  // -- Data loading -----------------------------------------------------------

  static List<Map<String, dynamic>> _rows(dynamic resp) {
    final list = resp is List
        ? resp
        : (resp is Map && resp['data'] is List ? resp['data'] as List : const []);
    return [
      for (final r in list)
        if (r is Map) Map<String, dynamic>.from(r)
    ];
  }

  Future<void> _loadCenters() async {
    setState(() {
      _loadingCenters = true;
      _centersError = null;
    });
    try {
      final rows = _rows(await Api.listingTrainingCenters());
      if (!mounted) return;
      setState(() {
        _centers = rows;
        _loadingCenters = false;
      });
      if (rows.length == 1) _selectCenter(rows.first);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCenters = false;
        _centersError = 'Could not load training centres.';
      });
    }
  }

  void _selectCenter(Map<String, dynamic> row) {
    setState(() {
      _tcId = row['id'];
      _tcName = (row['text'] ?? row['value'] ?? '').toString();
      _times = const [];
      _timeId = null;
      _students = const [];
      _tcScanned = true; // dropdown selection replaces the TC scan step
    });
    _loadTimes();
    _loadStudents();
  }

  Future<void> _loadTimes() async {
    final id = _tcId;
    if (id == null) return;
    try {
      final rows = _rows(await Api.listingTrainingTimeByTcId(id));
      if (mounted && _tcId == id) setState(() => _times = rows);
    } catch (_) {/* class time stays optional */}
  }

  Future<void> _loadStudents() async {
    final id = _tcId;
    if (id == null) return;
    setState(() {
      _loadingStudents = true;
      _studentsError = null;
    });
    try {
      final rows = _rows(await Api.listingStudentListByTcId(id));
      if (!mounted || _tcId != id) return;
      setState(() {
        _students = rows;
        _loadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStudents = false;
        _studentsError = 'Could not load the student list.';
      });
    }
  }

  // -- Marking ------------------------------------------------------------------

  int get _tTimeId => int.tryParse(_timeId?.toString() ?? '') ?? 0;

  /// Posts one attendance record. Dedupes per code for the session.
  ///
  /// The endpoint answers HTTP 200 with a `data.status` envelope: 0 means
  /// recorded, 1 means "pick a class time" (it returns the sessions — we
  /// re-POST with the chosen id), anything else is a rejection.
  Future<void> _mark(String code, String label, {int? tTimeId}) async {
    final st = _rowState[code];
    if (tTimeId == null &&
        (st == _RowState.pending || st == _RowState.done)) {
      return;
    }
    setState(() => _rowState[code] = _RowState.pending);
    try {
      final resp = await Api.attendanceAdd(<String, dynamic>{
        'qrCode': code,
        'attendanceType': 1,
        'tTimeId': tTimeId ?? _tTimeId,
      });
      if (!mounted) return;
      final outcome = AttendanceOutcome.parse(resp);
      if (outcome.success) {
        final t = TimeOfDay.now();
        final hh = t.hour.toString().padLeft(2, '0');
        final mm = t.minute.toString().padLeft(2, '0');
        setState(() {
          _rowState[code] = _RowState.done;
          _feed.insert(0, '$hh:$mm — $label');
        });
        return;
      }
      if (outcome.needsClassTime && tTimeId == null) {
        final picked = await _pickSession(outcome.sessions);
        if (!mounted) return;
        if (picked != null) {
          // Remember the choice so subsequent marks skip the prompt.
          setState(() => _timeId = picked.id);
          await _mark(code, label, tTimeId: picked.id);
          return;
        }
      }
      setState(() => _rowState[code] = _RowState.failed);
      _showHint(outcome.message ?? 'Rejected by server');
    } catch (e) {
      if (!mounted) return;
      setState(() => _rowState[code] = _RowState.failed);
      _showHint('Failed: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<AttendanceSession?> _pickSession(List<AttendanceSession> sessions) {
    if (sessions.length == 1) return Future.value(sessions.first);
    return showModalBottomSheet<AttendanceSession>(
      context: context,
      builder: (ctx) {
        final c = ctx.appColors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(height: 14),
              Text('Select the class time',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...sessions.map((s) => ListTile(
                    leading: Icon(Icons.schedule, color: c.primary, size: 20),
                    title: Text(s.text,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(ctx, s),
                  )),
            ]),
          ),
        );
      },
    );
  }

  void _showHint(String msg) {
    _hintTimer?.cancel();
    setState(() => _hint = msg);
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  /// Common entry for codes arriving from the QR scanner or an NFC tag.
  void _onCode(String raw, {required String source}) {
    final payload = QrContent.parse(raw);
    if (payload == null) {
      _showHint(source == 'nfc'
          ? 'Unrecognised tag — link it to a student first'
          : 'Not a D-Clix attendance code');
      return;
    }
    if (payload.type == QrType.trainingCenter) {
      if (!_tcScanned) setState(() => _tcScanned = true);
      _mark(payload.code, 'Checked in at ${payload.label}');
      return;
    }
    // Student code.
    if (!_tcScanned && _mode == 1) {
      _showHint('Scan the training centre QR first');
      return;
    }
    _mark(payload.code, _studentLabel(payload));
  }

  String _studentLabel(QrPayload p) {
    for (final s in _students) {
      if (int.tryParse((s['id'] ?? '').toString()) == p.id) {
        return (s['text'] ?? p.label).toString();
      }
    }
    return p.label;
  }

  // -- Tab lifecycle ---------------------------------------------------------------

  void _setMode(int m) {
    if (m == _mode) return;
    // Leaving QR: stop the camera. Leaving NFC: stop the session.
    if (_mode == 1) _scanner?.stop();
    if (_mode == 2 && _nfcReading) {
      NfcService.stop();
      _nfcReading = false;
    }
    setState(() => _mode = m);
    if (m == 1) {
      _scanner ??= MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
      _scanner!.start();
    }
  }

  Future<void> _toggleNfcRead() async {
    if (_nfcReading) {
      await NfcService.stop();
      if (mounted) setState(() => _nfcReading = false);
      return;
    }
    setState(() => _nfcReading = true);
    try {
      await NfcService.startReadSession(
        onCode: (code) => _onCode(code, source: 'nfc'),
        onUnreadable: () => _showHint('Unreadable tag'),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _nfcReading = false);
        _showHint('NFC failed to start');
      }
    }
  }

  // -- Tag writer --------------------------------------------------------------------

  Future<void> _openTagWriter() async {
    if (_nfcAvailable != true) {
      _showHint('NFC is not available on this device');
      return;
    }
    if (_tcId == null) {
      _showHint('Select a training centre first');
      return;
    }
    if (_students.isEmpty) await _loadStudents();
    if (!mounted) return;
    final student = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StudentPickerSheet(students: _students),
    );
    if (student == null || !mounted) return;
    final code = QrContent.studentFromRaw(student['id']);
    if (code == null) {
      _showHint('This student row has no usable id');
      return;
    }
    await _runTagWrite(student, code);
  }

  Future<void> _runTagWrite(Map<String, dynamic> student, String code) async {
    final name = (student['text'] ?? '').toString();
    final reg = (student['value'] ?? '').toString();
    String status = 'Hold a blank NFC tag against the phone…';
    bool finished = false, success = false;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        if (!finished && status.startsWith('Hold')) {
          NfcService.startWriteSession(
            code: code,
            onSuccess: () {
              NfcService.stop();
              setSheet(() {
                finished = true;
                success = true;
                status = 'Tag linked to $name ($reg)';
              });
            },
            onError: (msg) => setSheet(() => status = msg),
          ).catchError((_) {
            setSheet(() {
              finished = true;
              status = 'Could not start the NFC session.';
            });
          });
        }
        final c = ctx.appColors;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(99)),
            ),
            const SizedBox(height: 20),
            Icon(
              finished
                  ? (success ? Icons.check_circle : Icons.error_outline)
                  : Icons.nfc,
              size: 56,
              color: finished
                  ? (success ? c.success : c.danger)
                  : c.primary,
            ),
            const SizedBox(height: 14),
            Text('Link tag · $name',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(status,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Text(code,
                style: TextStyle(
                    color: c.textMuted,
                    fontSize: 12,
                    fontFamily: 'monospace')),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(finished ? 'Done' : 'Cancel'),
            ),
          ]),
        );
      }),
    );
    await NfcService.stop();
  }

  // -- UI ------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      body: Column(children: [
        AppHeader(
          title: 'Attendance',
          subtitle: _tcName.isEmpty ? 'Mark students present' : _tcName,
          showBack: true,
          trailing: IconButton(
            tooltip: 'Link NFC tag to a student',
            onPressed: _openTagWriter,
            icon: Icon(Icons.nfc, color: c.primary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.md),
          child: Column(children: [
            _contextSelectors(c),
            const SizedBox(height: Gaps.md),
            _modeSwitcher(c),
            if (_hint != null) ...[
              const SizedBox(height: Gaps.sm),
              _hintBanner(c, _hint!),
            ],
          ]),
        ),
        Expanded(
          child: switch (_mode) {
            1 => _qrTab(c),
            2 => _nfcTab(c),
            _ => _manualTab(c),
          },
        ),
      ]),
    );
  }

  Widget _contextSelectors(AppColors c) {
    return Column(children: [
      _dropdown<Object?>(
        c,
        hint: _loadingCenters
            ? 'Loading centres…'
            : (_centersError ?? 'Training centre'),
        value: _tcId,
        items: [
          for (final r in _centers)
            DropdownMenuItem(
                value: r['id'],
                child: Text((r['text'] ?? r['value'] ?? '').toString(),
                    overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          final row = _centers.firstWhere((r) => r['id'] == v,
              orElse: () => const {});
          if (row.isNotEmpty) _selectCenter(row);
        },
      ),
      const SizedBox(height: Gaps.sm),
      _dropdown<Object?>(
        c,
        hint: 'Class time (optional)',
        // A class time picked via the server's "select class time" prompt
        // may not exist in the dropdown's list — show as unselected then.
        value: _times.any((r) => r['id'] == _timeId) ? _timeId : null,
        items: [
          const DropdownMenuItem(value: null, child: Text('Any class time')),
          for (final r in _times)
            DropdownMenuItem(
                value: r['id'],
                child: Text((r['text'] ?? r['value'] ?? '').toString(),
                    overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => _timeId = v),
      ),
    ]);
  }

  Widget _dropdown<T>(AppColors c,
      {required String hint,
      required T? value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint,
              style: TextStyle(color: c.textMuted, fontSize: 13.5)),
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600),
          dropdownColor: c.surface,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _modeSwitcher(AppColors c) {
    Widget seg(int m, IconData icon, String label) {
      final active = _mode == m;
      return Expanded(
        child: InkWell(
          onTap: () => _setMode(m),
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? c.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: active ? Colors.white : c.textMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : c.textMuted)),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        seg(0, Icons.checklist, 'Manual'),
        seg(1, Icons.qr_code_scanner, 'QR'),
        seg(2, Icons.nfc, 'NFC'),
      ]),
    );
  }

  Widget _hintBanner(AppColors c, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.danger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: c.danger.withOpacity(0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: c.danger, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  // -- Manual tab ------------------------------------------------------------------

  List<Map<String, dynamic>> get _filteredStudents {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _students;
    return [
      for (final s in _students)
        if ((s['text'] ?? '').toString().toLowerCase().contains(q) ||
            (s['value'] ?? '').toString().toLowerCase().contains(q))
          s
    ];
  }

  Widget _manualTab(AppColors c) {
    if (_tcId == null) {
      return _emptyState(c, Icons.school_outlined,
          'Select a training centre to load its students.');
    }
    if (_loadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_studentsError != null) {
      return _emptyState(c, Icons.cloud_off, _studentsError!,
          retry: _loadStudents);
    }
    if (_students.isEmpty) {
      return _emptyState(
          c, Icons.group_off_outlined, 'No students in this centre.');
    }
    final rows = _filteredStudents;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Icon(Icons.search, size: 18, color: c.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: 'Search name or registration no.',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              InkWell(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: Icon(Icons.close, size: 18, color: c.textMuted),
              ),
          ]),
        ),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(Gaps.lg, 4, Gaps.lg, 120),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _studentRow(c, rows[i]),
        ),
      ),
    ]);
  }

  Widget _studentRow(AppColors c, Map<String, dynamic> s) {
    final name = (s['text'] ?? '').toString();
    final reg = (s['value'] ?? '').toString();
    final code = QrContent.studentFromRaw(s['id']);
    final state = code == null ? _RowState.idle : (_rowState[code] ?? _RowState.idle);
    // Defensive: instructor accounts may expose a photo field one day.
    final photo = ['photo', 'pic', 'image', 'profilePic']
        .map((k) => (s[k] ?? '').toString())
        .firstWhere((v) => v.startsWith('http'), orElse: () => '');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
            color: state == _RowState.done ? c.success : c.border),
        boxShadow: Shadows.card(c),
      ),
      child: Row(children: [
        _avatar(c, name, photo),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? '—' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(reg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textMuted, fontSize: 11.5)),
          ]),
        ),
        const SizedBox(width: 8),
        _markButton(c, code, name, state),
      ]),
    );
  }

  Widget _avatar(AppColors c, String name, String photoUrl) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
          radius: 21, backgroundImage: NetworkImage(photoUrl));
    }
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
    final hue = (name.hashCode % 360).abs().toDouble();
    final bg = HSLColor.fromAHSL(1, hue, 0.55, c.isDark ? 0.32 : 0.85).toColor();
    final fg = HSLColor.fromAHSL(1, hue, 0.6, c.isDark ? 0.85 : 0.30).toColor();
    return CircleAvatar(
      radius: 21,
      backgroundColor: bg,
      child: Text(initials,
          style: TextStyle(
              color: fg, fontSize: 14, fontWeight: FontWeight.w800)),
    );
  }

  Widget _markButton(
      AppColors c, String? code, String name, _RowState state) {
    switch (state) {
      case _RowState.done:
        return Icon(Icons.check_circle, color: c.success, size: 28);
      case _RowState.pending:
        return const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5));
      case _RowState.failed:
      case _RowState.idle:
        return InkWell(
          onTap: code == null ? null : () => _mark(code, name),
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: code == null
                  ? null
                  : LinearGradient(colors: c.gradient),
              color: code == null ? c.border : null,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Text(state == _RowState.failed ? 'Retry' : 'Mark',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        );
    }
  }

  Widget _emptyState(AppColors c, IconData icon, String text,
      {VoidCallback? retry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: c.textMuted),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13.5)),
          if (retry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: retry, child: const Text('Retry')),
          ],
        ]),
      ),
    );
  }

  // -- QR tab ---------------------------------------------------------------------

  Widget _qrTab(AppColors c) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.sm),
        child: _stepBanner(
          c,
          _tcScanned
              ? 'Scanning students — point at each student\'s QR'
              : 'Step 1 · Scan the training centre QR poster',
          _tcScanned ? Icons.qr_code_scanner : Icons.location_on_outlined,
        ),
      ),
      Expanded(
        flex: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: _scanner == null
                ? Container(color: Colors.black)
                : MobileScanner(
                    controller: _scanner!,
                    onDetect: (capture) {
                      final raw = capture.barcodes.isNotEmpty
                          ? capture.barcodes.first.rawValue
                          : null;
                      if (raw != null) _onCode(raw, source: 'qr');
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: const Text('Camera unavailable',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
          ),
        ),
      ),
      Expanded(flex: 2, child: _feedList(c)),
    ]);
  }

  // -- NFC tab -----------------------------------------------------------------------

  Widget _nfcTab(AppColors c) {
    if (_nfcAvailable == false) {
      return _emptyState(c, Icons.do_not_disturb_alt,
          'NFC is not available on this device.\nEnable NFC in system settings if your phone supports it.');
    }
    return Column(children: [
      const SizedBox(height: Gaps.md),
      Icon(Icons.nfc,
          size: 72, color: _nfcReading ? c.primary : c.textMuted),
      const SizedBox(height: 10),
      Text(
        _nfcReading
            ? 'Hold a student\'s tag against the phone'
            : 'Start a session, then tap student tags one by one',
        textAlign: TextAlign.center,
        style: TextStyle(color: c.textSecondary, fontSize: 13),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
        child: FilledButton.icon(
          onPressed: _nfcAvailable == null ? null : _toggleNfcRead,
          icon: Icon(_nfcReading ? Icons.stop : Icons.play_arrow),
          label: Text(_nfcReading ? 'Stop scanning' : 'Start scanning'),
        ),
      ),
      const SizedBox(height: Gaps.md),
      Expanded(child: _feedList(c)),
    ]);
  }

  // -- Shared feed -----------------------------------------------------------------------

  Widget _feedList(AppColors c) {
    if (_feed.isEmpty) {
      return Center(
        child: Text('No one marked yet this session',
            style: TextStyle(color: c.textMuted, fontSize: 12.5)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 110),
      itemCount: _feed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Icon(Icons.check_circle, size: 16, color: c.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_feed[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  Widget _stepBanner(AppColors c, String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: c.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ),
        if (!_tcScanned)
          TextButton(
            onPressed: _tcId == null
                ? null
                : () => setState(() => _tcScanned = true),
            child: const Text('Skip'),
          ),
      ]),
    );
  }
}

/// Bottom sheet listing the centre's students for the tag writer.
class _StudentPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  const _StudentPickerSheet({required this.students});
  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final q = _q.trim().toLowerCase();
    final rows = [
      for (final s in widget.students)
        if (q.isEmpty ||
            (s['text'] ?? '').toString().toLowerCase().contains(q) ||
            (s['value'] ?? '').toString().toLowerCase().contains(q))
          s
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(height: 14),
          Text('Link NFC tag — choose student',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
                hintText: 'Search name or registration no.'),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(color: c.borderLight),
              itemBuilder: (_, i) {
                final s = rows[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text((s['text'] ?? '').toString(),
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text((s['value'] ?? '').toString(),
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                  trailing: Icon(Icons.nfc, size: 18, color: c.primary),
                  onTap: () => Navigator.pop(context, s),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
