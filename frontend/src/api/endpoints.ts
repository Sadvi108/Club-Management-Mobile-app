import { http } from "./http";
import type {
  AppNotification,
  AttendanceRecord,
  AttendanceResult,
  AuthRequest,
  BookClassRequest,
  BookingInfo,
  HomePageStats,
  IdValueText,
  Invoice,
  MyInfo,
  ExamCenterRow,
  OnlineSubmissionRow,
  OnlineSubmissionDetail,
  ApproveSubmissionRequest,
  OutstandingRequest,
  PackageInfo,
  PurchaseProduct,
  Receipt,
  ReportRequest,
  ReportRow,
  StudentAddtnlInfo,
  StudentCenterRow,
  TrainingCenterRow,
  TrainingSlot,
} from "./types";

// Default report window: last 18 months → end of next year (covers receipts/attendance).
export function defaultRange(): { fromDate: string; toDate: string } {
  const now = new Date();
  const from = new Date(now);
  from.setMonth(from.getMonth() - 18);
  const to = new Date(now.getFullYear() + 1, 11, 31);
  return { fromDate: from.toISOString(), toDate: to.toISOString() };
}

export const api = {
  // ── Account ──
  authenticate: (body: AuthRequest) =>
    http.raw("/Account/Authenticate", { method: "POST", body, auth: false }),
  branchesByClubCode: (clubCode: string) =>
    http.get<IdValueText[]>(`/Account/GetBranchesByClubCode/${encodeURIComponent(clubCode)}`, {
      auth: false,
    }),

  // ── Profile ──
  myInfo: () => http.get<MyInfo>("/Profile/MyInfo"),
  // Edit profile + optional photo. Multipart (PascalCase fields). Returns the new DP url if a photo was sent.
  updateProfile: (fields: Record<string, string | number>, photo?: any) => {
    const form = new FormData();
    Object.entries(fields).forEach(([k, v]) => form.append(k, v == null ? "" : String(v)));
    if (photo) form.append("files", photo);
    return http.postForm<string | null>("/Profile/UpdateProfile", form);
  },
  studentAddtnlInfo: () => http.get<StudentAddtnlInfo>("/Profile/StudentAddtnlInfo"),
  myClubStats: () => http.get<IdValueText[]>("/Profile/MyClubStats"),
  myNotifications: () => http.get<AppNotification[]>("/Profile/MyNotifications"),
  unreadNotificationCount: () => http.get<number>("/Profile/MyUnreadNotificationCount"),
  notificationDetails: (groupId: string) =>
    http.get<AppNotification[]>(`/Profile/NotificationDetails/${encodeURIComponent(groupId)}`),
  markNotificationRead: (id: number) =>
    http.get<any>(`/Profile/UpdateNotification2Read?id=${id}`),
  // Reply into a notification thread (groupId). 200 = delivered to the club admin side;
  // the API keeps no copy for the sender (chat UI local-echoes it).
  reply2Notification: (body: { groupId: string; value: string; text?: string }) =>
    http.post<any>("/Profile/Reply2Notification", {
      id: 0,
      notificationType: "",
      text: "Reply",
      ...body,
    }),
  mySiblings: () => http.get<IdValueText[]>("/Listing/MySiblings"),

  // ── Home / Reports ──
  homePageStats: () => http.get<HomePageStats>("/Reports/HomePageStats"),
  receipts: (body: ReportRequest) => http.post<Receipt[]>("/Reports/Receipts", body),
  attendanceReport: (body: ReportRequest) =>
    http.post<AttendanceRecord[]>("/Reports/Attendance", body),
  gradingSchedule: (body: ReportRequest) =>
    http.post<ReportRow[]>("/Reports/GradingSchedule", body),
  tournamentSummary: (body: ReportRequest) =>
    http.post<ReportRow[]>("/Reports/TournamentSummary", body),
  purchaseRequests: (body: ReportRequest) =>
    http.post<ReportRow[]>("/Reports/PurchaseRequests", body),
  // structured training schedule rows (dayOfWeek, tTimeFrom/tTimeTo, instructor)
  studentDetails: (body: ReportRequest) =>
    http.post<ReportRow[]>("/Reports/StudentDetails", body),
  paymentSlips: (body: ReportRequest) =>
    http.post<ReportRow[]>("/Reports/PaymentSlips", body),

  // ── Help desk ──
  send2ClubHelpDesk: (body: { text?: string; value?: string; notificationType?: string }) =>
    http.post<any>("/Profile/Send2ClubHelpDesk", body),

  // ── Outstanding (fees) ──
  outstanding: (body: OutstandingRequest) => http.post<Invoice[]>("/Outstanding/Fetch", body),
  // Returns full invoice-shaped rows (real invoiceId + dueAmount) for upcoming months.
  fetchTermPayments: (body: { studentIds: number[]; year: number; months: number[] }) =>
    http.post<Invoice[]>("/Outstanding/FetchTermPayments", body),
  // PayInvoices is multipart/form-data: repeated InvoiceIds + PaymentMethod (2=Online, 1=Bank-In).
  // Online → returns a Billplz bill URL string to open in the browser.
  // payTermPayments=true is used for advance (term) payments. NOTE (probed 2026-07-03): the server
  // only ever bills the real InvoiceIds — FetchTermPayments rows with invoiceId 0 (months the
  // academy hasn't invoiced yet) cannot be paid; no binding of the PayTermPayments query model
  // (prefixed/bare/JSON/indexed) makes the backend create those invoices.
  payInvoicesOnline: (invoiceIds: number[], payTermPayments = false) => {
    const form = new FormData();
    invoiceIds.forEach((id) => form.append("InvoiceIds", String(id)));
    form.append("PaymentMethod", "2");
    return http.postForm<string>(`/Outstanding/PayInvoices?PayTermPayments=${payTermPayments}&PurchaseItems=false`, form);
  },
  // Direct Bank-In → upload the payment slip image (`files`). slip = RN {uri,name,type} or a web File/Blob.
  payInvoicesBankIn: (invoiceIds: number[], slip: any, payTermPayments = false) => {
    const form = new FormData();
    invoiceIds.forEach((id) => form.append("InvoiceIds", String(id)));
    form.append("PaymentMethod", "1");
    form.append("files", slip);
    return http.postForm<any>(`/Outstanding/PayInvoices?PayTermPayments=${payTermPayments}&PurchaseItems=false`, form);
  },
  paymentCompleted: (status: string) =>
    http.get<any>(`/Payment/Completed/${encodeURIComponent(status)}`),
  // Public PDF URL (no auth). The id from Outstanding/Reports.Receipts is an INVOICE id and goes
  // in the invoiceId slot (paymentId=0) — that renders the full populated receipt/invoice. Passing
  // it as paymentId returns a BLANK template.
  receiptPdfUrl: (clubId: number, paymentId: number, invoiceId: number) =>
    `${require("./config").API_BASE_URL}/Utilities/ReceiptAsPDF/${clubId}/${paymentId}/${invoiceId}`,

  // Public PNG QR (no auth) — usable directly in <Image>. StudentQRCode returns a PDF, so we
  // render a QRCode PNG of the student's content instead.
  qrCodeUrl: (content: string | number, size = 300) =>
    `${require("./config").API_BASE_URL}/Utilities/QRCode/${size}/${size}/${encodeURIComponent(String(content))}`,

  // ── Listings (for class booking) ──
  trainingCenters: () => http.get<IdValueText[]>("/Listing/TrainingCenters"),
  studentCenters: () => http.get<IdValueText[]>("/Listing/StudentCenters"),
  instructors: () => http.get<IdValueText[]>("/Listing/Instructors"),

  // ── Attendance (self check-in via scanned center QR) ──
  // Returns AttendanceResult; data.status === -1 means the QR isn't a valid D-CLIX center QR.
  addAttendance: (body: { qrCode?: string | null; attendanceType: number; tTimeId?: number | null }) =>
    http.post<AttendanceResult>("/Attendance/Add", body),

  // ── Class booking ──
  // Bookable time slots for a center+instructor in a given month.
  trainingSlots: (month: number, year: number, tCenterId: number, instructorId: number) =>
    http.get<TrainingSlot[]>(
      `/ClassBooking/TrainingTimeWithDateAndInstructor/${month}/${year}/${tCenterId}/${instructorId}`
    ),
  packageInfo: (studentId: number, month: number, year: number) =>
    http.get<PackageInfo>(`/ClassBooking/PackageInfo/${studentId}?month=${month}&year=${year}`),
  // Creates a booking; returns the new booking id. Body = BookClassViewModel.
  bookNow: (body: BookClassRequest) => http.post<{ id: number }>("/ClassBooking/BookNow", body),
  nextBookings: () => http.get<BookingInfo[]>("/ClassBooking/NextBookings"),
  getBookings: (studentId?: number) =>
    http.get<BookingInfo[]>(
      `/ClassBooking/GetBookings${studentId ? `?studentId=${studentId}` : ""}`
    ),

  // ── Instructor: Collections ──
  // { cash, fpx (online), dbt (bank-in slips) } counts for the Collections screen.
  collectionCount: () => http.get<{ cash: number; fpx: number; dbt: number }>("/Outstanding/CollectionCount"),
  // Detail list for a collection type (1=cash, 2=online/fpx, 3=bank-in slip).
  collectionCountList: (typeId: number) =>
    http.get<ReportRow[]>(`/Outstanding/CollectionCountList/${typeId}`),
  // Recalculates/syncs the collection count for a type server-side; returns "OK".
  updateCollectionCount: (typeId: number) =>
    http.get<string>(`/Outstanding/UpdateCollectionCount/${typeId}`),

  // ── Instructor: New Student (online submission) approval ──
  // PROPOSED CONTRACT — not yet on the backend (returns 404 today; the UI shows an
  // "awaiting backend" state, never fake data). Paths chosen to match the /Reports + /Account
  // conventions; adjust these four lines to the real routes once the backend ships them.
  onlineSubmissions: () => http.get<OnlineSubmissionRow[]>("/Reports/OnlineSubmissions"),
  onlineSubmissionDetail: (id: number) =>
    http.get<OnlineSubmissionDetail>(`/Reports/OnlineSubmissionDetails/${id}`),
  approveSubmission: (body: ApproveSubmissionRequest) =>
    http.post<any>("/Account/ApproveStudent", body),
  rejectSubmission: (id: number, remarks?: string) =>
    http.post<any>("/Account/RejectStudent", { id, remarks: remarks || "" }),

  // ── Instructor: Reports ──
  // GET (no body): center summary reports.
  reportTrainingCenters: () => http.get<TrainingCenterRow[]>("/Reports/TrainingCenters"),
  reportExamCenters: () => http.get<ExamCenterRow[]>("/Reports/ExamCenters"),
  reportStudentCenters: () => http.get<StudentCenterRow[]>("/Reports/StudentCenters"),
  // POST ReportRequest: filtered list reports (rows are Record<string,any>; screens read known fields).
  reimbursementReport: (body: ReportRequest) => http.post<ReportRow[]>("/Reports/Reimbursement", body),
  activityReport: (body: ReportRequest) => http.post<ReportRow[]>("/Reports/Activity", body),
  contributionReport: (body: ReportRequest) => http.post<ReportRow[]>("/Reports/Contribution", body),

  // ── Instructor: filter dropdown sources ──
  // DropdownListByType: 2=exam centers, 3=training centers, 4=student centers, 1=branches/academies.
  dropdownListByType: (typeId: number | string) =>
    http.get<IdValueText[]>(`/Listing/DropdownListByType/${encodeURIComponent(String(typeId))}`),
  studentListByTcId: (tCenterId: number) => http.get<IdValueText[]>(`/Listing/StudentListByTcId/${tCenterId}`),
  trainingTimeByTcId: (tCenterId: number) => http.get<IdValueText[]>(`/Listing/TrainingTimeByTcId/${tCenterId}`),
  invoiceTypes: () => http.get<{ id: string; text: string }[]>("/Listing/InvoceTypes"),

  // ── Student: purchase request ──
  purchaseProducts: () => http.post<PurchaseProduct[]>("/PurchaseRequest/FetchProducts", {}),

  // ── Utilities ──
  studentQRCodeUrl: (clubId: number, branchId: number, studentIds: number | string) =>
    `${require("./config").API_BASE_URL}/Utilities/StudentQRCode/${clubId}/${branchId}/${studentIds}`,
  trainingCenterQRCodeUrl: (clubId: number, tcid: number) =>
    `${require("./config").API_BASE_URL}/Utilities/TrainingCenterQRCode/${clubId}/${tcid}`,
};
