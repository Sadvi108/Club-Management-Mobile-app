import { http } from "./http";
import type {
  AppNotification,
  AttendanceRecord,
  AuthRequest,
  HomePageStats,
  IdValueText,
  Invoice,
  MyInfo,
  OutstandingRequest,
  Receipt,
  ReportRequest,
  ReportRow,
  StudentAddtnlInfo,
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
  studentAddtnlInfo: () => http.get<StudentAddtnlInfo>("/Profile/StudentAddtnlInfo"),
  myClubStats: () => http.get<IdValueText[]>("/Profile/MyClubStats"),
  myNotifications: () => http.get<AppNotification[]>("/Profile/MyNotifications"),
  unreadNotificationCount: () => http.get<number>("/Profile/MyUnreadNotificationCount"),
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

  // ── Outstanding (fees) ──
  outstanding: (body: OutstandingRequest) => http.post<Invoice[]>("/Outstanding/Fetch", body),
  fetchTermPayments: (body: { studentIds: number[]; year: number; months: number[] }) =>
    http.post<import("./types").TermPayment[]>("/Outstanding/FetchTermPayments", body),
  // shape UNRESOLVED — all probed bodies returned 400; needs gateway inspection
  payInvoices: (invoices: any[], opts?: { payTermPayments?: boolean }) =>
    http.post<import("./types").PayInvoicesResult>(
      `/Outstanding/PayInvoices?PayTermPayments=${opts?.payTermPayments ? "true" : "false"}`,
      invoices
    ),
  paymentCompleted: (status: string) =>
    http.get<any>(`/Payment/Completed/${encodeURIComponent(status)}`),
  // Authed PDF URL. paymentId for paid receipt, or 0 with invoiceId for an unpaid invoice.
  receiptPdfUrl: (clubId: number, paymentId: number, invoiceId: number) =>
    `${require("./config").API_BASE_URL}/Utilities/ReceiptAsPDF/${clubId}/${paymentId}/${invoiceId}`,

  // ── Attendance (self check-in via scanned center QR) ──
  addAttendance: (body: { qrCode?: string | null; attendanceType: number; tTimeId?: number | null }) =>
    http.post<any>("/Attendance/Add", body),

  // ── Class booking ──
  nextBookings: () => http.get<ReportRow[]>("/ClassBooking/NextBookings"),
  getBookings: () => http.get<ReportRow[]>("/ClassBooking/GetBookings"),

  // ── Utilities ──
  studentQRCodeUrl: (clubId: number, branchId: number, studentIds: number | string) =>
    `${require("./config").API_BASE_URL}/Utilities/StudentQRCode/${clubId}/${branchId}/${studentIds}`,
};
