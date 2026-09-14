import 'dart:async';

/// Successful writes invalidate live reads. A 200 checkout URL is not a paid invoice,
/// and an Attendance/Add class-time prompt is not a completed check-in.
class ApiChanges {
  static final _events = StreamController<String>.broadcast();
  static Stream<String> get stream => _events.stream;
  static void emit(String topic) => _events.add(topic);

  static void accepted(String endpoint, dynamic response) {
    final path = Uri.parse(endpoint).path;
    if (path == '/Attendance/Add') {
      final data = response is Map ? response['data'] : null;
      if (data is Map && '${data['status']}' == '0') emit('attendance');
    } else if (path == '/ClassBooking/BookNow') {
      emit('booking');
    } else if (path == '/Outstanding/PayInvoices' ||
        path.startsWith('/Outstanding/UpdateCollectionCount/')) {
      emit('payments');
    } else if (path == '/Profile/UpdateProfile') {
      emit('profile');
    } else if (path == '/Profile/Reply2Notification' ||
        path == '/Profile/Send2ClubHelpDesk' ||
        path == '/Profile/UpdateNotification2Read' ||
        path == '/Profile/UpdateNotificationAction') {
      emit('notifications');
    } else if (path == '/Account/ApproveStudent' ||
        path == '/Account/RejectStudent') {
      emit('students');
    }
  }
}
