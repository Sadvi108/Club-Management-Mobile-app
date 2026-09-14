import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/online_submissions.dart';
import '../services/response_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

class NewStudentScreen extends StatefulWidget {
  const NewStudentScreen({super.key});
  @override
  State<NewStudentScreen> createState() => _NewStudentScreenState();
}

class _NewStudentScreenState extends State<NewStudentScreen>
    with LiveRefreshMixin<NewStudentScreen> {
  @override
  bool get canLiveRefresh => !_loading && !_notReady;
  @override
  Future<void> refreshLiveData() => _load();

  bool _loading = true, _notReady = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notReady = false;
      _error = null;
    });
    try {
      final rows = await OnlineSubmissions.fetch();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted)
        setState(() {
          _rows = [];
          _notReady = e is ApiException && e.statusCode == 404;
          _error = friendlyError(e);
        });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
        body: Column(children: [
      const AppHeader(
          title: 'New Student',
          subtitle: 'Online submission approvals',
          showBack: true),
      Expanded(
          child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Card(
                    color: c.surfaceAlt,
                    child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Approving a new student',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                              SizedBox(height: 8),
                              Text(
                                  'Open a submission and confirm Training Centre, Student Centre, Present Grade and Fee Type before approving.'),
                            ]))),
                if ((_loading && !liveRefreshing))
                  const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()))
                else if (_notReady)
                  _SubmissionState(
                      title: 'Awaiting backend',
                      message:
                          "Online submission approvals aren't available on the app server yet. Check again once your club enables this feature.",
                      onRetry: _load)
                else if (_error != null)
                  _SubmissionState(
                      title: 'Could not load submissions',
                      message: _error!,
                      onRetry: _load)
                else if (_rows.isEmpty)
                  const _SubmissionState(
                      title: 'All caught up',
                      message: 'No pending online submissions right now.')
                else
                  for (final row in _rows)
                    Card(
                        color: c.surface,
                        child: ListTile(
                          title: Text('${row['studentName'] ?? 'Student'}'),
                          subtitle: Text([
                            row['trainingCentre'],
                            row['guardianName'],
                            row['contactNo']
                          ].where((v) => v != null).join(' · ')),
                          trailing: const Icon(AppIcons.chevron_right),
                          onTap: () async {
                            final id = int.tryParse('${row['id']}');
                            if (id == null) return;
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    StudentParticularsScreen(id: id)));
                            if (mounted) _load();
                          },
                        )),
              ]))),
    ]));
  }
}

class StudentParticularsScreen extends StatefulWidget {
  final int id;
  const StudentParticularsScreen({super.key, required this.id});
  @override
  State<StudentParticularsScreen> createState() =>
      _StudentParticularsScreenState();
}

class _StudentParticularsScreenState extends State<StudentParticularsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true, _notReady = false, _busy = false;
  static const _required = {
    'trainingCentre': 'Training Centre',
    'studentCentre': 'Student Centre',
    'presentGrade': 'Present Grade',
    'feeType': 'Fee Type'
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notReady = false;
      _error = null;
      _data = null;
    });
    try {
      final data = await OnlineSubmissions.detail(widget.id);
      if (mounted)
        setState(
            () => _data = data == null ? null : {...data, 'id': widget.id});
    } catch (e) {
      if (mounted)
        setState(() {
          _notReady = e is ApiException && e.statusCode == 404;
          _error = friendlyError(e);
        });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(bool approve) async {
    if (_busy || _data == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(
                  approve ? 'Approve registration' : 'Reject registration'),
              content: Text(approve
                  ? "Approve ${_data!['studentName']}? The club system may send login details to the parent."
                  : "Reject and remove ${_data!['studentName']}'s submission?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(approve ? 'Approve' : 'Reject'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (approve) {
        await OnlineSubmissions.approve(_data!);
      } else {
        await OnlineSubmissions.reject(widget.id);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missing = _required.entries
        .where((e) => '${_data?[e.key] ?? ''}'.trim().isEmpty)
        .map((e) => e.value)
        .toList();
    return Scaffold(
        body: Column(children: [
      AppHeader(
          title: '${_data?['studentName'] ?? 'Student Particulars'}',
          showBack: true),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_notReady)
          _SubmissionState(
              title: 'Awaiting backend',
              message:
                  'Student particulars will load once this feature is available.',
              onRetry: _load)
        else if (_error != null)
          _SubmissionState(
              title: 'Could not load particulars',
              message: _error!,
              onRetry: _load)
        else if (_data == null)
          const Text('Submission not found.')
        else ...[
          if (missing.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                    'Required before approval: ${missing.join(', ')}. Set them in the club system, then refresh.')),
          for (final field in const {
            'regNo': 'Registration No.',
            'presentGrade': 'Present Grade',
            'icNo': 'IC / Passport',
            'gender': 'Gender',
            'dateOfBirth': 'Date of Birth',
            'trainingCentre': 'Training Centre',
            'studentCentre': 'Student Centre',
            'schoolName': 'School',
            'examCentre': 'Exam Centre',
            'trainingDay': 'Training Day',
            'feeType': 'Fee Type',
            'guardianName': 'Guardian',
            'contactNo': 'Contact',
            'email': 'Email',
            'address': 'Address',
          }.entries)
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(field.value),
                subtitle: Text(_format(_data![field.key]))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _busy ? null : () => _decide(false),
                    child: const Text('Reject'))),
            const SizedBox(width: 12),
            Expanded(
                child: FilledButton(
                    onPressed: _busy || missing.isNotEmpty
                        ? null
                        : () => _decide(true),
                    child: const Text('Approve'))),
          ]),
          TextButton(
              onPressed: _busy ? null : _load, child: const Text('Refresh')),
        ],
      ])),
    ]));
  }

  String _format(dynamic value) {
    final text = '${value ?? ''}';
    final date = text.contains('T') ? DateTime.tryParse(text) : null;
    return date != null
        ? DateFormat('dd MMM yyyy').format(date)
        : (text.isEmpty ? '—' : text);
  }
}

class _SubmissionState extends StatelessWidget {
  final String title, message;
  final VoidCallback? onRetry;
  const _SubmissionState(
      {required this.title, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(AppIcons.cloud_outlined,
            size: 40, color: context.appColors.primary),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Check again')),
      ]));
}
