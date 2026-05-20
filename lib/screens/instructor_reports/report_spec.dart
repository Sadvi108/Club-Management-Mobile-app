import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../services/api.dart';
import 'student_list_fetch.dart';

/// A filter control a report can show.
enum RFilter { trainingCenter, examCenter, dateRange, status, nameText, icText }

/// User-chosen filter values for a report.
class ReportQuery {
  int tCenterId;
  int eCenterId;
  DateTime? fromDate;
  DateTime? toDate;
  String name;
  String ic;
  String? status;

  ReportQuery({
    this.tCenterId = 0,
    this.eCenterId = 0,
    this.fromDate,
    this.toDate,
    this.name = '',
    this.ic = '',
    this.status,
  });
}

typedef SpecFetch = Future<dynamic> Function(ReportQuery q);
typedef RowStatus = String Function(Map row);
typedef RowTap = void Function(BuildContext ctx, Map<String, dynamic> row);

/// Per-report configuration.
class ReportSpec {
  final String title;
  final List<RFilter> filters;
  final SpecFetch fetch;
  final List<String> statusOptions;
  final RowStatus? rowStatus;
  final String statusLabel;
  final bool trainingTimeMode;
  /// Optional row-tap handler — when set, rows become tappable (e.g. open
  /// a per-student detail screen from the Student List report).
  final RowTap? onRowTap;

  const ReportSpec({
    required this.title,
    required this.fetch,
    this.filters = const [],
    this.statusOptions = const [],
    this.rowStatus,
    this.statusLabel = 'Status',
    this.trainingTimeMode = false,
    this.onRowTap,
  });
}

/// Build the `/Reports/*` request body from the chosen filters. Only
/// non-default values are sent; `Api._reportBody` fills the rest.
Map<String, dynamic> reportBody(ReportQuery q) {
  final m = <String, dynamic>{};
  if (q.tCenterId != 0) m['tCenterId'] = q.tCenterId;
  if (q.eCenterId != 0) m['eCenterId'] = q.eCenterId;
  if (q.fromDate != null) {
    final f = q.fromDate!;
    // Start of the picked day.
    m['fromDate'] = DateTime(f.year, f.month, f.day).toIso8601String();
  }
  if (q.toDate != null) {
    final t = q.toDate!;
    // End of the picked day — a midnight toDate would exclude every
    // record timestamped later that same day.
    m['toDate'] =
        DateTime(t.year, t.month, t.day, 23, 59, 59).toIso8601String();
  }
  return m;
}

/// Specs keyed by the route slug (last path segment of the report route).
/// Routes not present here fall back to a no-filter spec built in the
/// router from a bare fetcher.
final Map<String, ReportSpec> kReportSpecs = {
  'student-list': ReportSpec(
    title: 'Student List',
    filters: const [
      RFilter.trainingCenter,
      RFilter.nameText,
      RFilter.icText,
    ],
    // /Reports/StudentDetails returns the instructor's schedule rows
    // (tCenterName / dayOfWeek / instructorName), NOT students. The
    // aggregator below pulls real students from listingStudentListByTcId
    // and enriches them with stats from /Outstanding/Fetch.
    fetch: fetchInstructorStudentList,
    onRowTap: (ctx, row) =>
        ctx.push('/instructor/student-detail', extra: row),
  ),
  'training-time': ReportSpec(
    title: 'Training Time',
    filters: const [RFilter.trainingCenter],
    trainingTimeMode: true,
    fetch: (q) => q.tCenterId == 0
        ? Future<dynamic>.value(const <dynamic>[])
        : Api.listingTrainingTimeByTcId(q.tCenterId),
  ),
  'grading-schedule': ReportSpec(
    title: 'Grading Schedule',
    filters: const [RFilter.examCenter, RFilter.dateRange],
    fetch: (q) => Api.reportsGradingSchedule(reportBody(q)),
  ),
  'grading-past': ReportSpec(
    title: 'Grading Past',
    filters: const [RFilter.examCenter, RFilter.dateRange],
    fetch: (q) => Api.reportsGradingSchedule(reportBody(q)),
  ),
  'receipt': ReportSpec(
    title: 'Receipt',
    filters: const [RFilter.trainingCenter, RFilter.dateRange, RFilter.status],
    statusLabel: 'Payment mode',
    statusOptions: const ['Cash', 'Online', 'Bank Transfer', 'Cheque'],
    rowStatus: (r) =>
        (r['paymentMode'] ?? r['mode'] ?? r['paymentType'] ?? '').toString(),
    fetch: (q) => Api.reportsReceipts(reportBody(q)),
  ),
  'attendance': ReportSpec(
    title: 'Attendance Report',
    filters: const [RFilter.dateRange],
    fetch: (q) => Api.reportsAttendance(reportBody(q)),
  ),
  'purchase-request': ReportSpec(
    title: 'Purchase Request',
    filters: const [RFilter.trainingCenter, RFilter.status],
    statusLabel: 'Action status',
    statusOptions: const ['Pending', 'Approved', 'Rejected'],
    rowStatus: (r) =>
        (r['actionStatus'] ?? r['status'] ?? r['approvalStatus'] ?? '')
            .toString(),
    fetch: (q) => Api.reportsPurchaseRequests(reportBody(q)),
  ),
  'payment-slip': ReportSpec(
    title: 'Payment Slip',
    filters: const [RFilter.trainingCenter, RFilter.status],
    statusLabel: 'Action status',
    statusOptions: const ['Pending', 'Approved', 'Rejected'],
    rowStatus: (r) =>
        (r['actionStatus'] ?? r['status'] ?? r['approvalStatus'] ?? '')
            .toString(),
    fetch: (q) => Api.reportsPaymentSlips(reportBody(q)),
  ),
  'reimbursement': ReportSpec(
    title: 'Reimbursement',
    filters: const [RFilter.dateRange, RFilter.status],
    statusLabel: 'Status',
    statusOptions: const ['Reimbursed', 'Not Reimbursed'],
    rowStatus: (r) {
      final v = r['isReimbursed'] ?? r['reimbursed'];
      if (v is bool) return v ? 'Reimbursed' : 'Not Reimbursed';
      final s = (r['status'] ?? r['reimbursementStatus'] ?? '')
          .toString()
          .toLowerCase();
      if (s.contains('not')) return 'Not Reimbursed';
      if (s.contains('reimburs')) return 'Reimbursed';
      return '';
    },
    fetch: (q) => Api.reportsReimbursement(reportBody(q)),
  ),
  'contribution': ReportSpec(
    title: 'Contribution',
    filters: const [RFilter.dateRange],
    fetch: (q) => Api.reportsContribution(reportBody(q)),
  ),
};
