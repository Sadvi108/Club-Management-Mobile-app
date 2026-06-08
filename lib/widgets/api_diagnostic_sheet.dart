import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_session.dart';
import '../theme/app_theme.dart';

/// Bottom-sheet diagnostic that shows the raw responses for the home
/// page stats and outstanding endpoints. Use this whenever the dueAmount /
/// invoiceCount appear stuck at 0 — it tells you whether the API is
/// returning data and (if so) which field names need to be added to the
/// parser.
class ApiDiagnosticSheet extends StatelessWidget {
  const ApiDiagnosticSheet({super.key});

  static Future<void> open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ApiDiagnosticSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = UserSession.instance;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: ListView(
          controller: ctrl,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('API Diagnostic',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Responses for the endpoints feeding the invoice + due '
              'amount strip. If a number is 0 here it means the API returned '
              '0 (not a parser bug).',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),

            _summary(c, 'Account', session.isInstructor ? 'Instructor' : 'Student'),
            _summary(c, 'Resolved name', session.displayName.isEmpty ? '(empty)' : session.displayName),
            _summary(c, 'Resolved reg no', session.registrationNo.isEmpty ? '(empty)' : session.registrationNo),
            _summary(c, 'Resolved club', session.clubName.isEmpty ? '(empty)' : session.clubName),
            _summary(c, 'User ID', _userId(session)),
            _summary(c, 'Branch ID', (session.authData?['branchId'] ?? '—').toString()),
            _summary(c, 'authData keys', (session.authData?.keys.toList() ?? []).join(', ')),
            _summary(c, 'myInfo keys', (session.myInfo?.keys.toList() ?? []).join(', ')),
            _summary(c, 'Computed invoice count', '${session.invoiceCount}'),
            _summary(c, 'Computed due amount', 'RM ${session.dueAmount.toStringAsFixed(2)}'),
            _summary(c, 'Outstanding records', _listLen(session.outstandingList)),
            _summary(c, 'Notifications unread', '${session.unreadNotifications}'),

            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh APIs'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await UserSession.instance.refresh();
                    if (!context.mounted) return;
                    ApiDiagnosticSheet.open(context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy all JSON'),
                  onPressed: () {
                    final blob = _allJson(session);
                    Clipboard.setData(ClipboardData(text: blob));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied raw responses')),
                    );
                  },
                ),
              ),
            ]),
            const SizedBox(height: 18),

            _section(
              c,
              title: 'POST /Account/Authenticate (cached authData)',
              status: 'ok',
              body: session.authData,
              extra: 'Used to resolve user name when /Profile/MyInfo is empty.',
            ),
            const SizedBox(height: 14),
            _section(
              c,
              title: 'GET /Profile/MyInfo',
              status: session.myInfo == null ? 'error' : 'ok',
              body: session.myInfo,
              extra: 'Primary source for student/instructor name + grade + training center.',
            ),
            const SizedBox(height: 14),
            _section(
              c,
              title: 'GET /Reports/HomePageStats',
              status: session.homeStatsError == null ? 'ok' : 'error',
              body: session.homeStatsRaw,
              error: session.homeStatsError,
            ),
            const SizedBox(height: 14),
            _section(
              c,
              title: 'POST /Outstanding/Fetch',
              status: session.outstandingError == null ? 'ok' : 'error',
              body: session.outstandingRaw,
              error: session.outstandingError,
              extra: 'First row keys: ${_firstRowKeys(session.outstandingList)}',
            ),
            const SizedBox(height: 14),
            _section(
              c,
              title: 'Notifications list',
              status: 'ok',
              body: session.notifications,
            ),
          ],
        ),
      ),
    );
  }

  static String _userId(UserSession s) {
    final keys = ['id', 'userId', 'studentId', 'instructorId', 'code'];
    for (final k in keys) {
      final v = s.authData?[k];
      if (v != null) return '$v';
    }
    return '—';
  }

  static String _listLen(dynamic v) {
    if (v == null) return 'null (not loaded)';
    if (v is List) return '${v.length}';
    return v.runtimeType.toString();
  }

  static String _firstRowKeys(List<dynamic>? list) {
    if (list == null || list.isEmpty) return '—';
    if (list.first is Map) return (list.first as Map).keys.join(', ');
    return list.first.runtimeType.toString();
  }

  static String _allJson(UserSession s) {
    final buf = StringBuffer()
      ..writeln('## resolved name: ${s.displayName}')
      ..writeln('## resolved regNo: ${s.registrationNo}')
      ..writeln('## resolved club: ${s.clubName}')
      ..writeln('## isInstructor: ${s.isInstructor}')
      ..writeln()
      ..writeln('## authData')
      ..writeln(_pretty(s.authData))
      ..writeln()
      ..writeln('## /Profile/MyInfo')
      ..writeln(_pretty(s.myInfo))
      ..writeln()
      ..writeln('## /Reports/HomePageStats')
      ..writeln(_pretty(s.homeStatsRaw))
      ..writeln()
      ..writeln('## /Outstanding/Fetch')
      ..writeln(_pretty(s.outstandingRaw))
      ..writeln()
      ..writeln('## /Profile/MyNotifications')
      ..writeln(_pretty(s.notifications));
    return buf.toString();
  }

  static String _pretty(dynamic v) {
    if (v == null) return 'null';
    try {
      return const JsonEncoder.withIndent('  ').convert(v);
    } catch (_) {
      return v.toString();
    }
  }

  Widget _summary(AppColors c, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: SelectableText(value,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _section(
    AppColors c, {
    required String title,
    required String status,
    required dynamic body,
    String? error,
    String? extra,
  }) {
    final pretty = _pretty(body);
    final preview = pretty.length > 3500
        ? '${pretty.substring(0, 3500)}\n\n…(${pretty.length - 3500} more chars)'
        : pretty;
    final isError = status == 'error' || error != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceAlt.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
                color: isError ? c.danger : c.success,
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
        if (extra != null) ...[
          const SizedBox(height: 6),
          SelectableText(extra,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
        if (error != null) ...[
          const SizedBox(height: 6),
          SelectableText('Error: $error',
              style: TextStyle(color: c.danger, fontSize: 11.5)),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: SelectableText(
            preview,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 10.5,
                fontFamily: 'monospace',
                height: 1.4),
          ),
        ),
      ]),
    );
  }
}
