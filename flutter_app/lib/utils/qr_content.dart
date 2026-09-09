/// Builds and parses the official D-Clix attendance code formats used by
/// the club system's printed QR posters and NFC tags:
///
///   Training center: 'TC-' + tcId zero-padded to 8 digits   (TC-00001636)
///   Student:         'ST-' + studentId zero-padded to 8     (ST-00022410)
///
/// The same string is the `qrCode` field of POST /Attendance/Add, whether
/// it arrives from a QR scan, an NFC tag read, or the instructor's manual
/// marking list.
library;

enum QrType { trainingCenter, student }

class QrPayload {
  final QrType type;
  final int id;
  const QrPayload(this.type, this.id);

  /// Human-readable label for scan feedback UIs.
  String get label => type == QrType.trainingCenter
      ? 'Training Center #$id'
      : 'Student #$id';

  /// The canonical code string this payload round-trips to.
  String get code => type == QrType.trainingCenter
      ? QrContent.trainingCenter(id)
      : QrContent.student(id);
}

class QrContent {
  QrContent._();

  static String _pad8(int id) => id.toString().padLeft(8, '0');

  static String trainingCenter(int tcId) => 'TC-${_pad8(tcId)}';

  static String student(int studentId) => 'ST-${_pad8(studentId)}';

  /// Builds the student code from a dynamic id source (API rows carry ids
  /// as int or string). Null when [id] isn't a positive integer.
  static String? studentFromRaw(Object? id) {
    final n = int.tryParse(id?.toString().trim() ?? '');
    return (n == null || n <= 0) ? null : student(n);
  }

  static final _re = RegExp(r'^(TC|ST)-(\d{1,12})$');

  /// Parses a scanned / tag string; null when it isn't an attendance code.
  static QrPayload? parse(String? raw) {
    final m = _re.firstMatch(raw?.trim() ?? '');
    if (m == null) return null;
    final id = int.tryParse(m.group(2)!);
    if (id == null || id <= 0) return null;
    return QrPayload(
        m.group(1) == 'TC' ? QrType.trainingCenter : QrType.student, id);
  }
}
