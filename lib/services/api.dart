import 'dart:typed_data';
import 'api_service.dart';

/// Typed wrapper around every Swagger endpoint exposed by
/// http://apimac.zyncbook.com.
///
/// All methods proxy through [ApiService] so the bearer token / auth header
/// (managed by [ApiService.setToken]) is applied automatically.
///
/// Each method returns the raw decoded JSON (`Map`, `List`, primitive or
/// `null`). Path parameters are URL-encoded with [Uri.encodeComponent].
/// POST / PUT helpers accept a `Map<String, dynamic>` body.
class Api {
  static String _enc(Object? v) => Uri.encodeComponent(v?.toString() ?? '');

  // ---------------------------------------------------------------------------
  // Account
  // ---------------------------------------------------------------------------
  static Future<dynamic> accountAuthenticate(Map<String, dynamic> body) =>
      ApiService.post('/Account/Authenticate', body);

  static Future<dynamic> accountChangeStudent(Map<String, dynamic> body) =>
      ApiService.post('/Account/ChangeStudent', body);

  static Future<dynamic> accountChangeClub(Map<String, dynamic> body) =>
      ApiService.post('/Account/ChangeClub', body);

  static Future<dynamic> accountGetBranchesByClubCode(String clubCode) =>
      ApiService.get('/Account/GetBranchesByClubCode/${_enc(clubCode)}');

  static Future<dynamic> accountForgotPassword(Map<String, dynamic> body) =>
      ApiService.post('/Account/ForgotPassword', body);

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------
  static Future<dynamic> attendanceAdd(Map<String, dynamic> body) =>
      ApiService.post('/Attendance/Add', body);

  // ---------------------------------------------------------------------------
  // ClassBooking
  // ---------------------------------------------------------------------------
  static Future<dynamic> classBookingTrainingTimeWithDateAndInstructor({
    required Object month,
    required Object year,
    required Object tCenterId,
    required Object instructorId,
  }) =>
      ApiService.get(
          '/ClassBooking/TrainingTimeWithDateAndInstructor/${_enc(month)}/${_enc(year)}/${_enc(tCenterId)}/${_enc(instructorId)}');

  static Future<dynamic> classBookingPackageInfo(Object studentId) =>
      ApiService.get('/ClassBooking/PackageInfo/${_enc(studentId)}');

  static Future<dynamic> classBookingSessionOrPackages(Object typeId) =>
      ApiService.get('/ClassBooking/SessionOrPackages/${_enc(typeId)}');

  static Future<dynamic> classBookingBookingsByInstructor({
    required Object instructorId,
    required Object month,
    required Object year,
  }) =>
      ApiService.get(
          '/ClassBooking/BookingsByInstructor/${_enc(instructorId)}/${_enc(month)}/${_enc(year)}');

  static Future<dynamic> classBookingBookingCountByPackageSession({
    required Object packageTypeId,
    required Object packageId,
    required Object studentId,
    required Object month,
    required Object year,
  }) =>
      ApiService.get(
          '/ClassBooking/BookingCountByPackageSession/${_enc(packageTypeId)}/${_enc(packageId)}/${_enc(studentId)}/${_enc(month)}/${_enc(year)}');

  static Future<dynamic> classBookingNextBookings() =>
      ApiService.get('/ClassBooking/NextBookings');

  static Future<dynamic> classBookingGetBookings() =>
      ApiService.get('/ClassBooking/GetBookings');

  static Future<dynamic> classBookingBookNow(Map<String, dynamic> body) =>
      ApiService.post('/ClassBooking/BookNow', body);

  // ---------------------------------------------------------------------------
  // Listing
  // ---------------------------------------------------------------------------
  static Future<dynamic> listingGetBranchesByClubCode(String clubCode) =>
      ApiService.get('/Listing/GetBranchesByClubCode/${_enc(clubCode)}');

  static Future<dynamic> listingStoreVersion(Object platform) =>
      ApiService.get('/Listing/StoreVersion/${_enc(platform)}');

  static Future<dynamic> listingDropdownListByType(Object reportTypeId) =>
      ApiService.get('/Listing/DropdownListByType/${_enc(reportTypeId)}');

  static Future<dynamic> listingInvoceTypes() =>
      ApiService.get('/Listing/InvoceTypes');

  static Future<dynamic> listingStudentCenters() =>
      ApiService.get('/Listing/StudentCenters');

  static Future<dynamic> listingStudentListByTcId(Object tCenterId) =>
      ApiService.get('/Listing/StudentListByTcId/${_enc(tCenterId)}');

  static Future<dynamic> listingTrainingCentersByScId(Object sCenterId) =>
      ApiService.get('/Listing/TrainingCentersByScId/${_enc(sCenterId)}');

  static Future<dynamic> listingTrainingCenters() =>
      ApiService.get('/Listing/TrainingCenters');

  static Future<dynamic> listingTrainingTimeByTcId(Object tCenterId) =>
      ApiService.get('/Listing/TrainingTimeByTcId/${_enc(tCenterId)}');

  static Future<dynamic> listingInstructors() =>
      ApiService.get('/Listing/Instructors');

  static Future<dynamic> listingMySiblings() =>
      ApiService.get('/Listing/MySiblings');

  // ---------------------------------------------------------------------------
  // Outstanding
  // ---------------------------------------------------------------------------
  // NOTE: Swagger marks these as POST, not GET — empty body is fine.
  static Future<dynamic> outstandingFetch([Map<String, dynamic> body = const {}]) =>
      ApiService.post('/Outstanding/Fetch', body);

  static Future<dynamic> outstandingFetchTermPayments(
          [Map<String, dynamic> body = const {}]) =>
      ApiService.post('/Outstanding/FetchTermPayments', body);

  static Future<dynamic> outstandingFetchTranxCharges(
          [Map<String, dynamic> body = const {}]) =>
      ApiService.post('/Outstanding/FetchTranxCharges', body);

  static Future<dynamic> outstandingFetchOsManualCollection(
          [Map<String, dynamic> body = const {}]) =>
      ApiService.post('/Outstanding/FetchOsManualCollection', body);

  static Future<dynamic> outstandingPayInvoices(Map<String, dynamic> body) =>
      ApiService.post('/Outstanding/PayInvoices', body);

  static Future<dynamic> outstandingCollectionCount() =>
      ApiService.get('/Outstanding/CollectionCount');

  static Future<dynamic> outstandingCollectionCountList(Object typeId) =>
      ApiService.get('/Outstanding/CollectionCountList/${_enc(typeId)}');

  /// GET per swag.json — server treats the typeId path param as the
  /// whole payload, no body required.
  static Future<dynamic> outstandingUpdateCollectionCount(Object typeId) =>
      ApiService.get('/Outstanding/UpdateCollectionCount/${_enc(typeId)}');

  // ---------------------------------------------------------------------------
  // Payment
  // ---------------------------------------------------------------------------
  // Initiate + Finalizing are GET in the swagger; the body's filter fields
  // can be appended as query params if needed. Most callers send empty.
  static Future<dynamic> paymentInitiate([Map<String, dynamic>? body]) =>
      ApiService.get('/Payment/Initiate${_qs(body)}');

  static Future<dynamic> paymentFinalizing([Map<String, dynamic>? body]) =>
      ApiService.get('/Payment/Finalizing${_qs(body)}');

  /// Build a `?k=v&k2=v2` query string from a map. Returns empty when
  /// the map is null/empty.
  static String _qs(Map<String, dynamic>? body) {
    if (body == null || body.isEmpty) return '';
    final pairs = body.entries
        .where((e) => e.value != null)
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value.toString())}')
        .join('&');
    return pairs.isEmpty ? '' : '?$pairs';
  }

  static Future<dynamic> paymentCompleted(Object status) =>
      ApiService.get('/Payment/Completed/${_enc(status)}');

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------
  static Future<dynamic> profileStudentAddtnlInfo() =>
      ApiService.get('/Profile/StudentAddtnlInfo');

  static Future<dynamic> profileMyInfo() =>
      ApiService.get('/Profile/MyInfo');

  static Future<dynamic> profileMyClubStats() =>
      ApiService.get('/Profile/MyClubStats');

  /// /Profile/UpdateProfile is multipart/form-data (NOT JSON). Pass string
  /// fields (Id, Name, IcNo, Gender, Address1-4, PostalCode, EmailAddress,
  /// HandPhone, Height, Weight, ProfilePic base64, ...).
  static Future<dynamic> profileUpdateProfile(Map<String, String> fields) =>
      ApiService.postMultipart('/Profile/UpdateProfile', fields);

  static Future<dynamic> profileMyNotifications() =>
      ApiService.get('/Profile/MyNotifications');

  static Future<dynamic> profileMyUnreadNotifications() =>
      ApiService.get('/Profile/MyUnreadNotifications');

  static Future<dynamic> profileMyUnreadNotificationCount() =>
      ApiService.get('/Profile/MyUnreadNotificationCount');

  static Future<dynamic> profileNotificationDetails(Object groupId) =>
      ApiService.get('/Profile/NotificationDetails/${_enc(groupId)}');

  static Future<dynamic> profileReply2Notification(Map<String, dynamic> body) =>
      ApiService.post('/Profile/Reply2Notification', body);

  static Future<dynamic> profileSend2ClubHelpDesk(Map<String, dynamic> body) =>
      ApiService.post('/Profile/Send2ClubHelpDesk', body);

  /// GET per swag.json — body fields go on the query string.
  static Future<dynamic> profileUpdateNotification2Read(
          [Map<String, dynamic>? body]) =>
      ApiService.get('/Profile/UpdateNotification2Read${_qs(body)}');

  static Future<dynamic> profileUpdateNotificationAction(
          Map<String, dynamic> body) =>
      ApiService.post('/Profile/UpdateNotificationAction', body);

  static Future<dynamic> profileUpdateToken(Object newBranchId) =>
      ApiService.post('/Profile/UpdateToken/${_enc(newBranchId)}',
          const <String, dynamic>{});

  // ---------------------------------------------------------------------------
  // PurchaseRequest
  // ---------------------------------------------------------------------------
  // Swagger says POST, not GET.
  static Future<dynamic> purchaseRequestFetchProducts(
          [Map<String, dynamic> body = const {}]) =>
      ApiService.post('/PurchaseRequest/FetchProducts', body);

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------
  static Future<dynamic> reportsHomePageStats() =>
      ApiService.get('/Reports/HomePageStats');

  static Future<dynamic> reportsStudentCenters() =>
      ApiService.get('/Reports/StudentCenters');

  static Future<dynamic> reportsExamCenters() =>
      ApiService.get('/Reports/ExamCenters');

  static Future<dynamic> reportsTrainingCenters() =>
      ApiService.get('/Reports/TrainingCenters');

  // Swagger marks all of the below as POST with ReportRequestViewModel
  // body (sCenterId / tCenterId / eCenterId / tTimeId / fromDate / toDate /
  // reportType / sourceKeyId). The server is strict: `reportType` must be
  // a STRING (not int) and date fields must be ISO-8601. Pass an empty
  // map to get the default dataset — [_reportBody] fills in safe defaults.
  static Map<String, dynamic> _reportBody([Map<String, dynamic>? caller]) {
    final now = DateTime.now();
    final from = DateTime(now.year - 2, 1, 1).toIso8601String();
    final to   = DateTime(now.year + 2, 12, 31).toIso8601String();
    final defaults = <String, dynamic>{
      'sCenterId': 0,
      'tCenterId': 0,
      'eCenterId': 0,
      'tTimeId': 0,
      'fromDate': from,
      'toDate': to,
      'reportType': '',  // STRING — server rejects int
      'sourceKeyId': 0,
    };
    if (caller == null || caller.isEmpty) return defaults;
    return {...defaults, ...caller};
  }

  static Future<dynamic> reportsAttendance(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/Attendance', _reportBody(body));

  static Future<dynamic> reportsStudentDetails(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/StudentDetails', _reportBody(body));

  static Future<dynamic> reportsGradingSchedule(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/GradingSchedule', _reportBody(body));

  static Future<dynamic> reportsReceipts(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/Receipts', _reportBody(body));

  static Future<dynamic> reportsPurchaseRequests(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/PurchaseRequests', _reportBody(body));

  static Future<dynamic> reportsPaymentSlips(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/PaymentSlips', _reportBody(body));

  static Future<dynamic> reportsTournamentSummary(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/TournamentSummary', _reportBody(body));

  static Future<dynamic> reportsReimbursement(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/Reimbursement', _reportBody(body));

  static Future<dynamic> reportsContribution(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/Contribution', _reportBody(body));

  static Future<dynamic> reportsActivity(
          [Map<String, dynamic>? body]) =>
      ApiService.post('/Reports/Activity', _reportBody(body));

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------
  static Future<dynamic> utilitiesQRCode({
    required Object width,
    required Object height,
    required Object content,
  }) =>
      ApiService.get(
          '/Utilities/QRCode/${_enc(width)}/${_enc(height)}/${_enc(content)}');

  static Future<dynamic> utilitiesTrainingCenterQRCode({
    required Object clubId,
    required Object tcid,
  }) =>
      ApiService.get(
          '/Utilities/TrainingCenterQRCode/${_enc(clubId)}/${_enc(tcid)}');

  static Future<dynamic> utilitiesStudentQRCode({
    required Object clubId,
    required Object branchId,
    required Object studentIds,
  }) =>
      ApiService.get(
          '/Utilities/StudentQRCode/${_enc(clubId)}/${_enc(branchId)}/${_enc(studentIds)}');

  static Future<dynamic> utilitiesReceiptAsPDF({
    required Object clubId,
    required Object paymentId,
    required Object invoiceId,
  }) =>
      ApiService.get(
          '/Utilities/ReceiptAsPDF/${_enc(clubId)}/${_enc(paymentId)}/${_enc(invoiceId)}');

  /// Raw PDF bytes for a receipt — the endpoint returns a PDF body, not
  /// JSON, so this must use the bytes path.
  static Future<Uint8List> utilitiesReceiptAsPdfBytes({
    required Object clubId,
    required Object paymentId,
    required Object invoiceId,
  }) =>
      ApiService.getPdfSmart(
          '/Utilities/ReceiptAsPDF/${_enc(clubId)}/${_enc(paymentId)}/${_enc(invoiceId)}?asDownload=true');
}
