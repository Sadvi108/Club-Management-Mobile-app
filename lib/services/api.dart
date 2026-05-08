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
  static Future<dynamic> outstandingFetch() =>
      ApiService.get('/Outstanding/Fetch');

  static Future<dynamic> outstandingFetchTermPayments() =>
      ApiService.get('/Outstanding/FetchTermPayments');

  static Future<dynamic> outstandingFetchTranxCharges() =>
      ApiService.get('/Outstanding/FetchTranxCharges');

  static Future<dynamic> outstandingFetchOsManualCollection() =>
      ApiService.get('/Outstanding/FetchOsManualCollection');

  static Future<dynamic> outstandingPayInvoices(Map<String, dynamic> body) =>
      ApiService.post('/Outstanding/PayInvoices', body);

  static Future<dynamic> outstandingCollectionCount() =>
      ApiService.get('/Outstanding/CollectionCount');

  static Future<dynamic> outstandingCollectionCountList(Object typeId) =>
      ApiService.get('/Outstanding/CollectionCountList/${_enc(typeId)}');

  static Future<dynamic> outstandingUpdateCollectionCount(Object typeId) =>
      ApiService.post('/Outstanding/UpdateCollectionCount/${_enc(typeId)}',
          const <String, dynamic>{});

  // ---------------------------------------------------------------------------
  // Payment
  // ---------------------------------------------------------------------------
  static Future<dynamic> paymentInitiate(Map<String, dynamic> body) =>
      ApiService.post('/Payment/Initiate', body);

  static Future<dynamic> paymentFinalizing(Map<String, dynamic> body) =>
      ApiService.post('/Payment/Finalizing', body);

  static Future<dynamic> paymentCallback(Map<String, dynamic> body) =>
      ApiService.post('/Payment/Callback', body);

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

  static Future<dynamic> profileUpdateProfile(Map<String, dynamic> body) =>
      ApiService.post('/Profile/UpdateProfile', body);

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

  static Future<dynamic> profileUpdateNotification2Read(
          Map<String, dynamic> body) =>
      ApiService.post('/Profile/UpdateNotification2Read', body);

  static Future<dynamic> profileUpdateNotificationAction(
          Map<String, dynamic> body) =>
      ApiService.post('/Profile/UpdateNotificationAction', body);

  static Future<dynamic> profileUpdateToken(Object newBranchId) =>
      ApiService.post('/Profile/UpdateToken/${_enc(newBranchId)}',
          const <String, dynamic>{});

  // ---------------------------------------------------------------------------
  // PurchaseRequest
  // ---------------------------------------------------------------------------
  static Future<dynamic> purchaseRequestFetchProducts() =>
      ApiService.get('/PurchaseRequest/FetchProducts');

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

  static Future<dynamic> reportsAttendance() =>
      ApiService.get('/Reports/Attendance');

  static Future<dynamic> reportsStudentDetails() =>
      ApiService.get('/Reports/StudentDetails');

  static Future<dynamic> reportsGradingSchedule() =>
      ApiService.get('/Reports/GradingSchedule');

  static Future<dynamic> reportsReceipts() =>
      ApiService.get('/Reports/Receipts');

  static Future<dynamic> reportsPurchaseRequests() =>
      ApiService.get('/Reports/PurchaseRequests');

  static Future<dynamic> reportsPaymentSlips() =>
      ApiService.get('/Reports/PaymentSlips');

  static Future<dynamic> reportsTournamentSummary() =>
      ApiService.get('/Reports/TournamentSummary');

  static Future<dynamic> reportsReimbursement() =>
      ApiService.get('/Reports/Reimbursement');

  static Future<dynamic> reportsContribution() =>
      ApiService.get('/Reports/Contribution');

  static Future<dynamic> reportsActivity() =>
      ApiService.get('/Reports/Activity');

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
}
