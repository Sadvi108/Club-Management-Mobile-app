/// Parses the /Attendance/Add response envelope.
///
/// The endpoint always answers HTTP 200; the real result is in `data`:
///   {status: 0, message: 'Attendance updated successfully', ...}   → recorded
///   {status: 1, message: 'Select your training class time',
///    tTimeSession: [{id, text}, …]}                                → re-POST
///                                       with one of the offered tTimeId's
///   {status: -1, message: 'Invalid QR Code', ...}                  → rejected
class AttendanceSession {
  final int id;
  final String text;
  const AttendanceSession(this.id, this.text);
}

class AttendanceOutcome {
  final int status;
  final String? message;
  final List<AttendanceSession> sessions;

  const AttendanceOutcome({
    required this.status,
    this.message,
    this.sessions = const [],
  });

  bool get success => status == 0;
  bool get needsClassTime => status == 1 && sessions.isNotEmpty;

  static AttendanceOutcome parse(dynamic resp) {
    final data = resp is Map ? resp['data'] : null;
    if (data is! Map) {
      // Legacy/unknown shape on a 2xx — assume recorded.
      return const AttendanceOutcome(status: 0);
    }
    final status = _toInt(data['status']) ?? 0;
    final message = (data['message'] ?? '').toString();
    final sessions = <AttendanceSession>[];
    final raw = data['tTimeSession'];
    if (raw is List) {
      for (final s in raw) {
        if (s is! Map) continue;
        final id = _toInt(s['id']);
        if (id == null) continue;
        sessions.add(AttendanceSession(id, (s['text'] ?? '').toString()));
      }
    }
    return AttendanceOutcome(
      status: status,
      message: message.isEmpty ? null : message,
      sessions: sessions,
    );
  }

  /// Int from num or numeric string; null otherwise.
  static int? _toInt(Object? v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}
