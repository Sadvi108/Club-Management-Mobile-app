import { http, ApiError } from "./http";
import { getApiBaseUrl, getApiEnv } from "./config";
import type {
  AppNotification,
  AttendanceRecord,
  AttendanceResult,
  AuthRequest,
  BcpgPayRequest,
  BcpgVerifyResult,
  BookClassRequest,
  BookingInfo,
  OnlinePaymentResult,
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
  PaymentIntent,
  PaymentOutcome,
  PurchaseProduct,
  PurchaseRequestLine,
  Receipt,
  ReportRequest,
  ReportRow,
  StudentAddtnlInfo,
  StudentCenterRow,
  TrainingCenterRow,
  TrainingSlot,
} from "./types";

/**
 * Payment gateways hand the browser back with the reference in the query string
 * (/Bcpg/Redirect takes `referenceId`). Pull it out of whatever URL the gateway
 * returned so the app can verify the payment afterwards. Returns null when the URL
 * carries no recognisable reference — verification is then skipped, never faked.
 *
 * The query-parameter names below cover the /Bcpg/Redirect contract (`referenceId`,
 * `uuid`) plus the usual gateway spellings.
 *
 * NOTE (verified live 2026-07-29): a real Boost link looks like
 * `https://stage-pay.boostconnect.biz/?t=2yoYIRarviWYHSfWLc0D7n`. That `t` is the
 * checkout-session token, NOT a reference the API knows — `/Bcpg/VerifyPayment/{t}`
 * answers `{"status":"NotFound"}` — so it is deliberately not matched here. The real
 * reference is minted by the gateway and only appears on the /Bcpg/Redirect return leg,
 * which goes to the browser, not to the app. Payments are therefore confirmed by
 * reconciliation (see `confirmPayment`), and this parser only fires if a future gateway
 * URL genuinely carries the reference.
 */
export function extractReferenceId(url: string): string | null {
  if (!url) return null;
  const q =
    /[?&](?:referenceId|reference_id|referenceid|reference|uuid|order_?id|bill_?id|transaction_?id)=([^&#]+)/i.exec(
      url
    );
  return q ? decodeURIComponent(q[1]) : null;
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/** `Attendance/Add.attendanceType` — see the note on `api.addAttendance`. */
export const ATTENDANCE_TYPE = { selfCheckIn: 1, instructorMark: 2 } as const;

/** `data.status` of `Attendance/Add`. */
export const ATTENDANCE_RESULT = { checkedIn: 0, needsClassTime: 1, invalidQr: -1 } as const;

/**
 * Training-centre check-in QR content: `TC-` + the centre id padded to 8 digits
 * (`TC-00001945` = centre 1945). Returns the centre id, or null for anything else —
 * the student QR (`ST-00035842`) is not a check-in code.
 */
export function parseCenterQr(value: string): number | null {
  const m = /^\s*TC-?(\d{1,10})\s*$/i.exec(value || "");
  if (!m) return null;
  const id = parseInt(m[1], 10);
  return Number.isFinite(id) && id > 0 ? id : null;
}

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

  // ── Boost payment gateway (/Bcpg) ──
  // New on UAT/staging. JSON (not multipart like /Outstanding/PayInvoices) and both the
  // term model and the purchase lines ride in the body instead of the query string.
  // Returns the gateway URL in `data`.
  bcpgPayInvoices: (body: BcpgPayRequest) =>
    http.post<string>("/Bcpg/PayInvoices", {
      invoiceIds: body.invoiceIds ?? [],
      payTermPayments: body.payTermPayments ?? null,
      purchaseItems: body.purchaseItems ?? null,
    }),
  // Authenticated. Bare { status } object — "NotFound" for an unknown reference.
  bcpgVerifyPayment: (referenceId: string) =>
    http.get<BcpgVerifyResult>(`/Bcpg/VerifyPayment/${encodeURIComponent(referenceId)}`),

  /**
   * Start an online payment and get the gateway URL to open.
   *
   * One intent covers everything the Boost route can bill in a single gateway session:
   * existing invoices, advance (term) months, and purchase-request lines.
   *
   * Route selection:
   * - Boost server (`hasBoostGateway`) → `POST /Bcpg/PayInvoices` (JSON).
   * - Otherwise, or if /Bcpg is missing (404/405) → legacy `POST /Outstanding/PayInvoices`
   *   `PaymentMethod=2`, which can only bill existing invoice ids. A term or purchase
   *   intent has no legacy equivalent (both were query-bound there and never worked), so
   *   it fails loudly instead of silently billing less than the user selected.
   */
  startPayment: async (intent: PaymentIntent): Promise<OnlinePaymentResult> => {
    const invoiceIds = (intent.invoiceIds ?? []).filter((id) => id > 0);
    const term = intent.term && intent.term.months.length && intent.term.studentIds.length ? intent.term : null;
    const purchaseItems = intent.purchaseItems?.length ? intent.purchaseItems : null;
    const preferBoost = intent.preferBoost !== false;

    if (!invoiceIds.length && !term && !purchaseItems) {
      throw new ApiError("Nothing was selected to pay.", 0, null);
    }
    // Probed live 2026-07-29: a body with BOTH purchaseItems and a (bogus) invoice id still
    // returns a gateway URL, while the same invoice id alone fails — i.e. the server takes
    // the purchase path and the invoices are not demonstrably billed. Never risk charging a
    // user for a bill that silently dropped their invoices: keep purchases in their own session.
    if (purchaseItems && (invoiceIds.length || term)) {
      throw new ApiError("Purchases have to be paid on their own — pay your invoices in a separate payment.", 0, null);
    }

    const legacy = async (): Promise<OnlinePaymentResult> => {
      if (term || purchaseItems) {
        throw new ApiError(
          "This server does not support the Boost gateway, which is what handles advance months and purchases. Switch to a server with the Boost gateway, or pay issued invoices instead.",
          0,
          null
        );
      }
      const url = await api.payInvoicesOnline(invoiceIds, false);
      if (!url || typeof url !== "string") throw new ApiError("No payment link was returned.", 0, url);
      return { url, gateway: "legacy", referenceId: extractReferenceId(url) };
    };

    if (!preferBoost || !getApiEnv().hasBoostGateway) return legacy();

    try {
      const url = await api.bcpgPayInvoices({ invoiceIds, payTermPayments: term, purchaseItems });
      if (!url || typeof url !== "string") throw new ApiError("No payment link was returned by the Boost gateway.", 0, url);
      return { url, gateway: "bcpg", referenceId: extractReferenceId(url) };
    } catch (e: any) {
      // Route missing on this server → use the legacy gateway instead. Any other failure
      // (gateway/config error) is surfaced as-is; we never silently pretend it worked.
      if (e instanceof ApiError && (e.status === 404 || e.status === 405)) return legacy();
      throw e;
    }
  },

  /**
   * What happened to a payment the user was sent off to the gateway for.
   *
   * The browser never tells us — `/Bcpg/Redirect` takes the *browser* back, not the app —
   * so this asks the server two independent ways and reports only what it can back up:
   *
   * 1. `GET /Bcpg/VerifyPayment/{referenceId}` when the gateway URL carried a reference,
   *    polled a few times because the gateway callback can land after the user returns.
   * 2. Reconciliation: refetch `Outstanding/Fetch` and see whether the invoices that were
   *    being paid are gone — or, for a purchase, whether a new purchase-request row
   *    appeared. This is the signal that actually fires in practice: the Boost link carries
   *    a checkout token rather than a reference (see `extractReferenceId`).
   *
   * Returns "unknown" rather than guessing when neither signal is conclusive.
   */
  confirmPayment: async (args: {
    referenceId?: string | null;
    invoiceIds?: number[];
    studentId?: number | null;
    /** Number of purchase-request rows before the payment — a new row means it went through. */
    purchaseBaseline?: number | null;
    attempts?: number;
    delayMs?: number;
  }): Promise<PaymentOutcome> => {
    const { referenceId, invoiceIds = [], studentId = null, purchaseBaseline = null, attempts = 3, delayMs = 2000 } = args;
    let gatewayStatus: string | null = null;

    if (referenceId) {
      for (let i = 0; i < Math.max(1, attempts); i++) {
        if (i) await sleep(delayMs);
        try {
          const v = await api.bcpgVerifyPayment(referenceId);
          const status = String(v?.status ?? "").trim();
          if (status) gatewayStatus = status;
          if (/^(success|successful|paid|completed|complete|captured|settled|approved)$/i.test(status)) {
            return { outcome: "paid", gatewayStatus: status, message: `Payment confirmed by the gateway (ref ${referenceId}).` };
          }
          if (/^(failed|failure|cancelled|canceled|declined|rejected|expired)$/i.test(status)) {
            return { outcome: "unpaid", gatewayStatus: status, message: `The gateway reported this payment as ${status.toLowerCase()}.` };
          }
          // "NotFound" / "Pending" / anything else → give the callback another moment.
        } catch {
          /* verification is best-effort — fall through to reconciliation */
        }
      }
    }

    // Reconcile against the invoice list. Only meaningful when we were paying invoices.
    const payable = invoiceIds.filter((id) => id > 0);
    if (payable.length) {
      try {
        const range = defaultRange();
        const rows = await api.outstanding({
          studentId,
          startDate: range.fromDate,
          endDate: range.toDate,
        });
        const stillDue = new Set((rows ?? []).map((r) => r.invoiceId));
        const remaining = payable.filter((id) => stillDue.has(id));
        if (remaining.length === 0) {
          return { outcome: "paid", gatewayStatus, message: "Payment received — these invoices are settled." };
        }
        if (remaining.length === payable.length) {
          return {
            outcome: "unpaid",
            gatewayStatus,
            message: gatewayStatus
              ? `Gateway status: ${gatewayStatus}. Your invoices are unchanged.`
              : "No payment was recorded — your invoices are unchanged.",
          };
        }
        return {
          outcome: "unknown",
          gatewayStatus,
          message: `${payable.length - remaining.length} of ${payable.length} invoices were settled. Pull to refresh in a moment for the rest.`,
        };
      } catch {
        /* fall through to the honest unknown below */
      }
    }

    // Purchases don't touch the invoice list — a paid one shows up as a purchase request.
    if (purchaseBaseline != null) {
      try {
        const range = defaultRange();
        const rows = await api.purchaseRequests({ fromDate: range.fromDate, toDate: range.toDate });
        if ((rows?.length ?? 0) > purchaseBaseline) {
          return { outcome: "paid", gatewayStatus, message: "Payment received — your purchase request has been raised." };
        }
        return {
          outcome: "unknown",
          gatewayStatus,
          message: "Back from the payment gateway. Your purchase will appear under Purchase Requests once the payment is confirmed.",
        };
      } catch {
        /* fall through to the honest unknown below */
      }
    }

    return {
      outcome: "unknown",
      gatewayStatus,
      message: gatewayStatus
        ? `Gateway status: ${gatewayStatus}. Refreshing your account.`
        : "Back from the payment gateway. Refreshing your account — a completed payment can take a moment to show up.",
    };
  },
  // Public PDF URL (no auth). The id from Outstanding/Reports.Receipts is an INVOICE id and goes
  // in the invoiceId slot (paymentId=0) — that renders the full populated receipt/invoice. Passing
  // it as paymentId returns a BLANK template.
  receiptPdfUrl: (clubId: number, paymentId: number, invoiceId: number) =>
    `${getApiBaseUrl()}/Utilities/ReceiptAsPDF/${clubId}/${paymentId}/${invoiceId}`,

  // Public PNG QR (no auth) — usable directly in <Image>. StudentQRCode returns a PDF, so we
  // render a QRCode PNG of the student's content instead.
  qrCodeUrl: (content: string | number, size = 300) =>
    `${getApiBaseUrl()}/Utilities/QRCode/${size}/${size}/${encodeURIComponent(String(content))}`,

  // ── Listings (for class booking) ──
  trainingCenters: () => http.get<IdValueText[]>("/Listing/TrainingCenters"),
  studentCenters: () => http.get<IdValueText[]>("/Listing/StudentCenters"),
  instructors: () => http.get<IdValueText[]>("/Listing/Instructors"),

  // ── Attendance (self check-in via scanned training-centre QR) ──
  //
  // Contract probed live on UAT 2026-07-29 (student DARSHANMUTHU, centre 1945):
  //
  //   attendanceType 1 = student self check-in with the CENTRE QR  ← what the scanner uses
  //   attendanceType 2 = instructor marking (rejects a student token: "Invalid Instructor details")
  //   attendanceType 0 / 3 = always -1, not usable from the app
  //
  // The centre QR (`GET /Utilities/TrainingCenterQRCode/{clubId}/{tcid}`, a PDF poster) encodes
  // `TC-00001945` — "TC-" + the training-centre id zero-padded to 8 digits. The student QR
  // encodes `ST-00035842` and is NOT accepted for check-in.
  //
  // data.status: 0 = checked in, 1 = "Select your training class time" (resend with tTimeId),
  // -1 = the QR isn't a D-CLIX centre code.
  addAttendance: (body: { qrCode?: string | null; attendanceType?: number; tTimeId?: number | null }) =>
    http.post<AttendanceResult>("/Attendance/Add", {
      ...body,
      attendanceType: body.attendanceType ?? ATTENDANCE_TYPE.selfCheckIn,
    }),

  // ── Class booking ──
  //
  // Contract probed live on UAT 2026-07-29 (student 35842, centre 1945 SMK KK2):
  //
  // - The weekly timetable for a centre+instructor. The month/year in the path make no
  //   difference to the response (July, August and September return the identical rows) —
  //   these are recurring weekly slots, and the calendar date is the app's job.
  // - `classLimit` is the class's configured capacity, **not** seats remaining and not an
  //   availability flag: a slot with `classLimit: 0` booked fine (booking 3280) and the value
  //   never moved afterwards. Do not use it to disable a slot.
  trainingSlots: (month: number, year: number, tCenterId: number, instructorId: number) =>
    http.get<TrainingSlot[]>(
      `/ClassBooking/TrainingTimeWithDateAndInstructor/${month}/${year}/${tCenterId}/${instructorId}`
    ),
  // The student's package (packageType feeds BookNow). month/year are accepted but ignored.
  packageInfo: (studentId: number, month?: number, year?: number) =>
    http.get<PackageInfo>(
      `/ClassBooking/PackageInfo/${studentId}` +
        (month && year ? `?month=${month}&year=${year}` : "")
    ),
  // Creates a booking; returns the new booking id. Body = BookClassViewModel.
  //
  // The server validates almost nothing: it accepts a duplicate of an existing booking, and
  // accepts a trainingDate whose weekday doesn't match the slot (a Friday slot booked on a
  // Tuesday returned 200). Only an empty `timeSlots` is refused ("Invalid Request"). So the
  // date and the duplicate check are the app's responsibility — see `app/book-class.tsx`.
  bookNow: (body: BookClassRequest) => http.post<{ id: number }>("/ClassBooking/BookNow", body),
  // Returns [] even when the student has a future booking (verified against booking 3280,
  // dated 2026-08-07) — unusable. Use getBookings() and filter by date instead.
  nextBookings: () => http.get<BookingInfo[]>("/ClassBooking/NextBookings"),
  // Every booking for the student, past and future. `studentId` is optional — a student token
  // returns its own bookings either way.
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
  /**
   * Build one `purchaseItems` line (PurchaseRequestLineViewModel) for /Bcpg/PayInvoices.
   * There is no separate "create purchase request" route in the mobile API — paying for
   * the lines through the Boost gateway is how a purchase is raised.
   * `id`/`purchaseRequestId` are 0 because the server creates both.
   */
  purchaseLine: (product: PurchaseProduct, qty: number): PurchaseRequestLine => {
    const price = Number(product.price || 0);
    const n = Math.max(0, Math.trunc(qty));
    return {
      id: 0,
      purchaseRequestId: 0,
      productId: product.productId,
      qty: n,
      price,
      unitTax: 0,
      totalTax: 0,
      totalAmount: Number((price * n).toFixed(2)),
    };
  },

  // ── Utilities ──
  studentQRCodeUrl: (clubId: number, branchId: number, studentIds: number | string) =>
    `${getApiBaseUrl()}/Utilities/StudentQRCode/${clubId}/${branchId}/${studentIds}`,
  trainingCenterQRCodeUrl: (clubId: number, tcid: number) =>
    `${getApiBaseUrl()}/Utilities/TrainingCenterQRCode/${clubId}/${tcid}`,
};
