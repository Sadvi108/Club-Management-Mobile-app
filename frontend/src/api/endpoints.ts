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
  OutstandingRequest,
  PackageInfo,
  Receipt,
  ReportRequest,
  ReportRow,
  StudentAddtnlInfo,
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
  payInvoicesOnline: (invoiceIds: number[]) => {
    const form = new FormData();
    invoiceIds.forEach((id) => form.append("InvoiceIds", String(id)));
    form.append("PaymentMethod", "2");
    return http.postForm<string>("/Outstanding/PayInvoices?PayTermPayments=false&PurchaseItems=false", form);
  },
  // Direct Bank-In → upload the payment slip image (`files`). slip = RN {uri,name,type} or a web File/Blob.
  payInvoicesBankIn: (invoiceIds: number[], slip: any) => {
    const form = new FormData();
    invoiceIds.forEach((id) => form.append("InvoiceIds", String(id)));
    form.append("PaymentMethod", "1");
    form.append("files", slip);
    return http.postForm<any>("/Outstanding/PayInvoices?PayTermPayments=false&PurchaseItems=false", form);
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

  // ── Utilities ──
  studentQRCodeUrl: (clubId: number, branchId: number, studentIds: number | string) =>
    `${require("./config").API_BASE_URL}/Utilities/StudentQRCode/${clubId}/${branchId}/${studentIds}`,
};
