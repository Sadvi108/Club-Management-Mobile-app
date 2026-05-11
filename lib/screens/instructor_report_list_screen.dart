import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

typedef ReportFetcher = Future<dynamic> Function();

/// Generic list-of-records screen used by every instructor "drill-down"
/// report route. Calls [fetcher] and renders the resulting JSON as cards.
class InstructorReportListScreen extends StatefulWidget {
  final String title;
  final ReportFetcher fetcher;

  const InstructorReportListScreen({
    super.key,
    required this.title,
    required this.fetcher,
  });

  @override
  State<InstructorReportListScreen> createState() =>
      _InstructorReportListScreenState();
}

class _InstructorReportListScreenState
    extends State<InstructorReportListScreen> {
  dynamic _data;
  bool _loading = true;
  String? _error;

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
      final resp = await widget.fetcher();
      final data =
          resp is Map && resp.containsKey('data') ? resp['data'] : resp;
      setState(() => _data = data);
    } catch (e) {
      debugPrint('${widget.title} failed: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _rows() {
    final d = _data;
    if (d is List) {
      return d
          .map((e) => e is Map
              ? Map<String, dynamic>.from(e)
              : <String, dynamic>{'value': e})
          .toList();
    }
    if (d is Map) {
      return [Map<String, dynamic>.from(d)];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final rows = _rows();
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(title: widget.title, showBack: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: c.primary,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 24),
                children: [
                  if (rows.isNotEmpty && _error == null) _liveBanner(c),
                  const SizedBox(height: Gaps.sm),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: c.primary),
                      ),
                    )
                  else if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(Gaps.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        'Couldn\'t load: $_error',
                        style: TextStyle(
                            color: c.danger, fontWeight: FontWeight.w600),
                      ),
                    )
                  else if (rows.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(Gaps.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        'No records.',
                        style: TextStyle(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    for (final row in rows) _rowCard(c, row),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _liveBanner(AppColors c) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.sm),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Icon(Icons.cloud_done_outlined, size: 16, color: c.primary),
          const SizedBox(width: 8),
          Text('LIVE',
              style: TextStyle(
                  color: c.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Showing latest data',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _rowCard(AppColors c, Map<String, dynamic> row) {
    final entries = row.entries.take(4).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
        boxShadow: Shadows.card(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      e.key.toString(),
                      style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value?.toString() ?? '',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
