import '../../services/api.dart';
import '../../services/response_utils.dart';
import 'report_spec.dart';

/// Aggregate the instructor's real student list from
/// `/Listing/StudentListByTcId` (one call per training centre) and enrich
/// each row with per-student stats from `/Outstanding/Fetch` (grade,
/// attendanceCount, dueAmount, paymentStatus).
///
/// `/Reports/StudentDetails` is unusable here — for an instructor token it
/// returns the instructor's training-time schedule rows, not students.
Future<Map<String, dynamic>> fetchInstructorStudentList(ReportQuery q) async {
  // 1) Resolve which training centres to scan.
  final centreIds = <int>[];
  if (q.tCenterId != 0) {
    centreIds.add(q.tCenterId);
  } else {
    try {
      final tcResp = await Api.listingTrainingCenters();
      for (final r in findRecordList(tcResp).whereType<Map>()) {
        final id = r['id'] ?? r['centerId'] ?? r['tCenterId'] ?? r['value'];
        final i = id is int ? id : int.tryParse(id.toString()) ?? 0;
        if (i != 0) centreIds.add(i);
      }
    } catch (_) {
      // fall through with empty centre list
    }
  }

  // 2) Fetch the per-centre student lists in parallel.
  final perCentre = await Future.wait(centreIds.map((id) async {
    try {
      final resp = await Api.listingStudentListByTcId(id);
      return MapEntry(id, findRecordList(resp).whereType<Map>().toList());
    } catch (_) {
      return MapEntry(id, const <Map>[]);
    }
  }));

  // 3) Centre label lookup so each student row can show its training centre.
  final centreLabels = <int, String>{};
  try {
    final tcResp = await Api.listingTrainingCenters();
    for (final r in findRecordList(tcResp).whereType<Map>()) {
      final id = r['id'] ?? r['centerId'] ?? r['tCenterId'] ?? r['value'];
      final i = id is int ? id : int.tryParse(id.toString()) ?? 0;
      final label = pickField(Map<String, dynamic>.from(r), [
        'name', 'centerName', 'tCenterName', 'text',
      ]);
      if (i != 0 && label.isNotEmpty) centreLabels[i] = label;
    }
  } catch (_) {}

  // 4) Outstanding index — keyed by studentId, icNo, and lowercased name —
  // so any of those keys can join into the enriched row.
  final byId = <String, Map<String, dynamic>>{};
  final byIc = <String, Map<String, dynamic>>{};
  final byName = <String, Map<String, dynamic>>{};
  try {
    final osResp = await Api.outstandingFetch();
    for (final r in findRecordList(osResp).whereType<Map>()) {
      final m = Map<String, dynamic>.from(r);
      final sid = (m['studentId'] ?? '').toString().trim();
      final ic = (m['icNo'] ?? '').toString().trim().toLowerCase();
      final nm = (m['studentName'] ?? m['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      // Aggregate: sum dueAmount per student, count invoices, keep grade /
      // attendanceCount / centerName / paymentStatus from the first row.
      void merge(Map<String, Map<String, dynamic>> idx, String key) {
        if (key.isEmpty) return;
        final existing = idx[key];
        if (existing == null) {
          idx[key] = {
            'studentId': m['studentId'],
            'icNo': m['icNo'],
            'studentName': m['studentName'] ?? m['name'],
            'grade': m['grade'],
            'attendanceCount': m['attendanceCount'],
            'centerName': m['centerName'],
            'paymentStatus': m['paymentStatus'],
            'dueAmount': _toNum(m['dueAmount']),
            'outstandingCount': 1,
          };
        } else {
          existing['dueAmount'] =
              (existing['dueAmount'] as num) + _toNum(m['dueAmount']);
          existing['outstandingCount'] =
              (existing['outstandingCount'] as int) + 1;
        }
      }

      merge(byId, sid);
      merge(byIc, ic);
      merge(byName, nm);
    }
  } catch (_) {}

  // 5) Build the enriched student rows.
  final enriched = <Map<String, dynamic>>[];
  for (final entry in perCentre) {
    final tcId = entry.key;
    final tcLabel = centreLabels[tcId] ?? '';
    for (final s in entry.value) {
      final sid = (s['id'] ?? s['studentId'] ?? '').toString().trim();
      final regNo = (s['value'] ?? s['registrationNo'] ?? '').toString();
      final name = (s['text'] ?? s['name'] ?? s['fullName'] ?? '').toString();
      final stats = byId[sid] ?? byName[name.toLowerCase()];
      enriched.add(<String, dynamic>{
        'studentId': s['id'] ?? s['studentId'],
        'name': name,
        'registrationNo': regNo,
        'tCenterId': tcId,
        'trainingCenter': tcLabel,
        if (stats != null) ...{
          'grade': stats['grade'],
          'attendanceCount': stats['attendanceCount'],
          'dueAmount': stats['dueAmount'],
          'outstandingInvoices': stats['outstandingCount'],
          'paymentStatus': stats['paymentStatus'],
        },
      });
    }
  }

  // 6) Apply free-text filters (name / IC). Server doesn't accept them on
  // listingStudentListByTcId, so we filter the merged set client-side.
  Iterable<Map<String, dynamic>> rows = enriched;
  if (q.name.isNotEmpty) {
    final w = q.name.toLowerCase();
    rows = rows.where(
        (r) => (r['name'] ?? '').toString().toLowerCase().contains(w));
  }
  if (q.ic.isNotEmpty) {
    final w = q.ic.toLowerCase();
    rows = rows.where((r) =>
        (r['registrationNo'] ?? '').toString().toLowerCase().contains(w));
  }

  return <String, dynamic>{'data': rows.toList()};
}

num _toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) {
    return num.tryParse(v.replaceAll(RegExp(r'[^\d.\-]'), '')) ?? 0;
  }
  return 0;
}
