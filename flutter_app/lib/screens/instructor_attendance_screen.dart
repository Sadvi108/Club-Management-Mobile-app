import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/api.dart';
import '../services/api_service.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../utils/qr_content.dart';
import '../widgets/app_header.dart';
import '../widgets/gradient_button.dart';

/// Attendance/Add identifies the token holder; it cannot mark another student.
/// Match Expo's class list + centre QR flow instead of offering unsupported writes.
class InstructorAttendanceScreen extends StatefulWidget {
  const InstructorAttendanceScreen({super.key});
  @override
  State<InstructorAttendanceScreen> createState() =>
      _InstructorAttendanceScreenState();
}

class _InstructorAttendanceScreenState extends State<InstructorAttendanceScreen>
    with LiveRefreshMixin<InstructorAttendanceScreen> {
  @override
  bool get canLiveRefresh => !_loading && !_loadingClass && !_posterBusy;
  @override
  Future<void> refreshLiveData() async {
    final center = _centerId;
    if (center == null) return _loadCenters();
    final generation = _generation;
    try {
      final results = await Future.wait([
        Api.listingTrainingTimeByTcId(center),
        Api.listingStudentListByTcId(center),
      ]);
      if (!mounted || generation != _generation || center != _centerId) return;
      setState(() {
        _times = findRecordList(results[0]).whereType<Map>().toList();
        _students = findRecordList(results[1]).whereType<Map>().toList();
        if (!_times.any((row) => '${row['id']}' == _timeId)) _timeId = null;
        _error = null;
      });
    } catch (e) {
      if (mounted && generation == _generation)
        setState(() => _error = friendlyError(e));
    }
  }

  List<Map> _centers = [], _times = [], _students = [];
  String? _centerId, _timeId, _error;
  bool _loading = true, _loadingClass = false, _posterBusy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadCenters();
  }

  Future<void> _loadCenters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = findRecordList(await Api.listingDropdownListByType(3))
          .whereType<Map>()
          .toList();
      if (mounted) setState(() => _centers = rows);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClass(String id) async {
    final generation = ++_generation;
    setState(() {
      _centerId = id;
      _timeId = null;
      _times = [];
      _students = [];
      _loadingClass = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.listingTrainingTimeByTcId(id),
        Api.listingStudentListByTcId(id)
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _times = findRecordList(results[0]).whereType<Map>().toList();
        _students = findRecordList(results[1]).whereType<Map>().toList();
      });
    } catch (e) {
      if (mounted && generation == _generation)
        setState(() => _error = friendlyError(e));
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loadingClass = false);
    }
  }

  String _label(List<Map> rows, String? id) =>
      '${rows.where((r) => '${r['id']}' == id).firstOrNull?['text'] ?? ''}';

  Future<void> _showQr() async {
    final id = int.tryParse(_centerId ?? '');
    if (id == null || id <= 0) return;
    final name = _label(_centers, _centerId);
    final code = QrContent.trainingCenter(id);
    // Capture the centre when opening, so changing selection cannot relabel an old QR.
    final image =
        Api.utilitiesQRCodeBytes(content: code, width: 300, height: 300);
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(_label(_times, _timeId)),
                  const SizedBox(height: 16),
                  FutureBuilder<Uint8List>(
                      future: image,
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(friendlyError(snapshot.error)));
                        if (!snapshot.hasData)
                          return const SizedBox(
                              height: 240,
                              child:
                                  Center(child: CircularProgressIndicator()));
                        return Image.memory(snapshot.data!,
                            width: 260,
                            height: 260,
                            errorBuilder: (_, __, ___) =>
                                const Text('QR image unavailable'));
                      }),
                  const SizedBox(height: 12),
                  Text(code),
                  const SizedBox(height: 6),
                  const Text(
                      'Students scan this QR in their own app to check in.',
                      textAlign: TextAlign.center),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close')),
                ]))));
  }

  Future<void> _openPoster() async {
    final clubId = UserSession.instance.authData?['clubId'];
    if (clubId == null || _centerId == null) return;
    setState(() => _posterBusy = true);
    try {
      final bytes = await ApiService.getBytes(
          '/Utilities/TrainingCenterQRCode/${Uri.encodeComponent('$clubId')}/${Uri.encodeComponent(_centerId!)}');
      await Printing.sharePdf(
          bytes: bytes,
          filename:
              'CENTRE_QR_${QrContent.trainingCenter(int.parse(_centerId!))}.pdf');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _posterBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    Widget picker(String label, List<Map> rows, String? selected,
            ValueChanged<String?>? changed) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<String>(
                key: ValueKey('$label-$selected-${rows.length}'),
                initialValue: selected,
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                hint: const Text('Select'),
                items: [
                  for (final row in rows)
                    DropdownMenuItem(
                        value: '${row['id']}',
                        child: Text('${row['text'] ?? ''}',
                            overflow: TextOverflow.ellipsis))
                ],
                onChanged: changed));
    return Scaffold(
        body: Column(children: [
      AppHeader(
          title: 'Class Check-In',
          subtitle: _centerId == null
              ? null
              : '${_students.length} students at this centre',
          showBack: true),
      Expanded(
          child: RefreshIndicator(
              onRefresh: () async {
                await _loadCenters();
                if (_centerId != null) await _loadClass(_centerId!);
              },
              child: ListView(padding: const EdgeInsets.all(20), children: [
                picker(
                    'Training Centre',
                    _centers,
                    _centerId,
                    _loading
                        ? null
                        : (id) {
                            if (id != null) _loadClass(id);
                          }),
                picker(
                    'Training Time',
                    _times,
                    _timeId,
                    _loadingClass || _centerId == null
                        ? null
                        : (id) => setState(() => _timeId = id)),
                if (_loading || _loadingClass)
                  const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Column(children: [
                    Text(_error!),
                    TextButton(
                        onPressed: () {
                          if (_centerId != null) {
                            _loadClass(_centerId!);
                          } else {
                            _loadCenters();
                          }
                        },
                        child: const Text('Retry'))
                  ]),
                const SizedBox(height: 12),
                GradientButton(
                    label: 'Show Centre QR',
                    trailingIcon: AppIcons.qr_code,
                    onPressed: _centerId == null ? null : _showQr),
                const SizedBox(height: 14),
                const Text(
                    'Students check in by scanning the centre QR on their own phones. This list shows who trains at the centre; it is not a live attendance register.'),
                if (_centerId != null &&
                    UserSession.instance.authData?['clubId'] != null)
                  TextButton.icon(
                      onPressed: _posterBusy ? null : _openPoster,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                          _posterBusy ? 'Opening…' : 'Open QR Poster (PDF)')),
                const SizedBox(height: 20),
                if (_centerId == null)
                  const Text('Select a training centre to see its class list.')
                else if (!_loadingClass && _error == null && _students.isEmpty)
                  const Text('No students at this centre.')
                else
                  for (final student in _students)
                    Card(
                        color: c.surface,
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: c.surfaceAlt,
                              child: Icon(AppIcons.person_outline,
                                  color: c.primary)),
                          title: Text(
                              '${student['text'] ?? student['name'] ?? 'Student'}'),
                          subtitle: Text('${student['value'] ?? ''}'),
                        )),
              ]))),
    ]));
  }
}
