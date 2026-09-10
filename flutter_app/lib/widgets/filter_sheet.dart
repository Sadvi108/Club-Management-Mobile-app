import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';

/// Reusable filter bottom sheet that aggregates all the listing/reports
/// dropdowns the boss wants exposed (student centers, training centers,
/// exam centers, students, generic dropdown values).
///
/// Wire it up by passing an [AppHeader] trailing icon onPressed that calls
/// [showFilterSheet]. The sheet returns the selected filter map (or null on
/// cancel) so callers can refresh their lists with the picks.
Future<Map<String, dynamic>?> showFilterSheet(BuildContext context) {
  final c = context.appColors;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FilterSheet(c: c),
  );
}

class _FilterSheet extends StatefulWidget {
  final AppColors c;
  const _FilterSheet({required this.c});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  List<dynamic>? _studentCenters;
  List<dynamic>? _trainingCenters;
  List<dynamic>? _examCenters;
  List<dynamic>? _reportsTrainingCenters;
  List<dynamic>? _reportsStudentCenters;
  List<dynamic>? _genericDropdown;
  bool _loading = true;

  dynamic _scId;
  dynamic _tcId;
  dynamic _examId;
  dynamic _genericId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Future<List<dynamic>?> safe(Future<dynamic> Function() fn) async {
      try {
        final r = await fn();
        if (r is List) return r;
        if (r is Map && r['data'] is List) return r['data'] as List;
      } catch (e) {
        debugPrint('filter load failed: $e');
      }
      return null;
    }

    final results = await Future.wait([
      safe(Api.listingStudentCenters),
      safe(Api.listingTrainingCenters),
      safe(Api.reportsExamCenters),
      safe(Api.reportsTrainingCenters),
      safe(Api.reportsStudentCenters),
      safe(() => Api.listingDropdownListByType(1)),
    ]);
    if (!mounted) return;
    setState(() {
      _studentCenters = results[0];
      _trainingCenters = results[1];
      _examCenters = results[2];
      _reportsTrainingCenters = results[3];
      _reportsStudentCenters = results[4];
      _genericDropdown = results[5];
      _loading = false;
    });
  }

  Future<void> _loadTrainingByScId(dynamic scId) async {
    if (scId == null) return;
    try {
      final r = await Api.listingTrainingCentersByScId(scId);
      List<dynamic>? list;
      if (r is List) list = r;
      if (r is Map && r['data'] is List) list = r['data'] as List;
      if (mounted && list != null) setState(() => _trainingCenters = list);
    } catch (e) {
      debugPrint('listingTrainingCentersByScId failed: $e');
    }
  }

  String _label(dynamic m) {
    if (m is Map) {
      return (m['name'] ?? m['text'] ?? m['title'] ?? m['description'] ?? '?')
          .toString();
    }
    return m.toString();
  }

  dynamic _idOf(dynamic m) {
    if (m is Map) return m['id'] ?? m['code'] ?? m['value'];
    return m;
  }

  Widget _dropdown<T>({
    required String label,
    required List<dynamic>? items,
    required dynamic value,
    required ValueChanged<dynamic> onChanged,
  }) {
    final c = widget.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<dynamic>(
                isExpanded: true,
                value: value,
                hint: Text(items == null ? 'Loading…' : 'Any',
                    style: TextStyle(color: c.textMuted, fontSize: 13)),
                items: (items ?? const <dynamic>[])
                    .map((e) => DropdownMenuItem<dynamic>(
                          value: _idOf(e),
                          child: Text(_label(e),
                              style: TextStyle(
                                  color: c.textPrimary, fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => onChanged(v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text('Filters',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary)),
              const SizedBox(height: 12),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c.primary)),
                    const SizedBox(width: 8),
                    Text('Loading filter options…',
                        style:
                            TextStyle(fontSize: 12, color: c.textSecondary)),
                  ]),
                ),
              _dropdown(
                  label: 'Student Center',
                  items: _studentCenters ?? _reportsStudentCenters,
                  value: _scId,
                  onChanged: (v) {
                    setState(() => _scId = v);
                    _loadTrainingByScId(v);
                  }),
              _dropdown(
                  label: 'Training Center',
                  items: _trainingCenters ?? _reportsTrainingCenters,
                  value: _tcId,
                  onChanged: (v) => setState(() => _tcId = v)),
              _dropdown(
                  label: 'Exam Center',
                  items: _examCenters,
                  value: _examId,
                  onChanged: (v) => setState(() => _examId = v)),
              _dropdown(
                  label: 'Report Type',
                  items: _genericDropdown,
                  value: _genericId,
                  onChanged: (v) => setState(() => _genericId = v)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => Navigator.pop(context, <String, dynamic>{
                  'studentCenterId': _scId,
                  'trainingCenterId': _tcId,
                  'examCenterId': _examId,
                  'reportTypeId': _genericId,
                }),
                borderRadius: BorderRadius.circular(Radii.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.gradient),
                    borderRadius: BorderRadius.circular(Radii.md),
                    boxShadow: Shadows.strong(c),
                  ),
                  child: const Text('Apply',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(color: c.textSecondary, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
