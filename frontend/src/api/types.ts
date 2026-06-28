// Response models, shaped from live /swagger/v1/swagger.json + real responses.

export type UserType = 0 | 2 | 3; // 0 = Instructor, 3 = Student

export type AuthRequest = {
  userType: UserType;
  username: string;
  password: string;
  accessMethod?: number; // 0
  clubCode?: string | null;
  branchId?: number;
  deviceType?: string | null;
  deviceId?: string | null;
};

export type IdValueText = { id: number; value: string; text: string };

// data of POST /Account/Authenticate
export type AuthUser = {
  id: number;
  userId: number;
  code: string;
  icNo: string;
  name: string;
  emailAddress: string;
  userType: UserType;
  branchId: number;
  branchIds: number[];
  clubList: IdValueText[];
  clubId: number;
  roleId: number;
  isAllowAttendance: boolean;
  isClassBookingEnabled: boolean;
  isHqBranch: boolean;
  accessToken: string;
  gender?: string;
  handPhone?: string;
  address1?: string;
  address2?: string;
  address3?: string;
  address4?: string;
  postalCode?: string;
  currentGrade?: string;
  profilePic?: string; // student display photo (Files/DP/...); distinct from clubPic
  clubPic?: string;
  clubName?: string;
  status?: string;
  permissions?: Record<string, boolean>;
};

// GET /Reports/HomePageStats
export type OfferAttachment = { documentUrl: string };
export type Offer = {
  id: number;
  code: string;
  name: string;
  description: string;
  expiryDate?: string;
  attachments?: OfferAttachment[];
  previewImages?: OfferAttachment[];
};
export type HomePageStats = {
  invoiceCount: number;
  dueAmount: number;
  mynews: any[];
  myoffers: Offer[];
};

// GET /Profile/MyInfo
export type MyInfo = {
  id: number;
  icNo: string;
  name: string;
  registrationNo: string;
  eCenterName: string;
  tCenterName: string;
  currentGrade: string;
  trainingTme: string;
  instructorName: string;
  instructorId: number;
};

// GET /Profile/StudentAddtnlInfo
export type StudentAddtnlInfo = {
  standardid: number;
  classname: string;
  tshirtSize: string;
  schoolname: string;
  dob: string;
  bloodtype: string;
  healthstatus: string;
  foodtype: string;
};

// POST /Reports/Receipts
export type Receipt = {
  id: number;
  tcName: string;
  receiptNo: number;
  receiptDate: string;
  receiptAmount: number;
  paymentMethod: string;
  icNo: string;
  name: string;
};

// POST /Outstanding/Fetch
export type Invoice = {
  sno: number;
  transactionType: string;
  invoiceDate: string;
  invoiceId: number;
  studentId: number;
  icNo: string;
  studentName: string;
  invoiceAmount: number;
  dueAmount: number;
  discountAmount: number;
  paidAmount: number;
  centerName: string;
  grade: string;
  period: string;
  invoiceDescription: string;
  contactNo: string;
  paymentStatus: string;
  attendanceCount: number;
};

// POST /Reports/Attendance
export type AttendanceRecord = {
  id: number;
  attendanceTypeId: number;
  attendanceType: string;
  icNo: string;
  name: string;
  recordedTime: string;
  sCenterName: string;
  trainingCenter: string;
};

// GET /Profile/MyNotifications
export type AppNotification = {
  id: number;
  value: string;
  text: string;
  notifyDate: string;
  notificationType: string;
  receiverName: string;
  groupId: string;
  receiverType: string;
  isRead: boolean;
};

// POST /Reports/GradingSchedule, TournamentSummary, etc. — generic rows
export type ReportRow = Record<string, any>;

// Request body shared by /Reports/* and used loosely by Outstanding
export type ReportRequest = {
  sCenterId?: number | null;
  tCenterId?: number | null;
  eCenterId?: number | null;
  tTimeId?: number | null;
  sourceKeyId?: number | null;
  reportType?: string | null;
  fromDate?: string | null;
  toDate?: string | null;
};

export type OutstandingRequest = {
  studentId?: number | null;
  studentName?: string | null;
  icNo?: string | null;
  startDate?: string | null;
  endDate?: string | null;
  eCenterId?: number | null;
  tCenterId?: number | null;
  sCenterId?: number | null;
  transactionType?: string | null;
};

// POST /Outstanding/FetchTermPayments
export type TermPayment = {
  studentId: number;
  studentName?: string;
  year: number;
  month: number;
  period?: string;
  amount: number;
  invoiceType?: string;
};

// POST /Outstanding/PayInvoices → returns a Billplz bill URL (string) or { url }
export type PayInvoicesResult = { url?: string } | string;

// ── Class booking ──────────────────────────────────────────────────────────
// GET /ClassBooking/TrainingTimeWithDateAndInstructor/{month}/{year}/{tCenterId}/{instructorId}
export type TrainingSlot = {
  id: number; // = timeId, used as BookNow.timeSlots[].timeId
  name: string; // "18:00 To 19:00 (Monday) - Normal training"
  dayOfWeek: string; // "Monday"
  classLimit: number; // 0 = no seats / unavailable
  centerName: string;
  instructorId: number;
  instructorName: string;
};

// GET /ClassBooking/GetBookings + /NextBookings → BookingInfoViewModel[]
export type BookingInfo = {
  bookingId: number;
  timeId: number;
  trainingDate: string;
  status: string; // "Pending", ...
  title: string; // slot label
  name: string; // student name
  centerName: string;
  instructorName: string;
};

// GET /ClassBooking/PackageInfo/{studentId}?month&year
export type PackageInfo = {
  packageType: string; // "Monthly"
  packageId: number;
  packageName: string;
  noOfClasses: number;
};

// POST /ClassBooking/BookNow body (BookClassViewModel)
export type BookClassRequest = {
  id: number;
  tCenterId: number;
  instructorId: number;
  studentId: number;
  packageType?: string | null;
  sessionId: number;
  remarks?: string | null;
  timeSlots: Partial<BookingInfo>[];
};

// data of POST /Attendance/Add — inner status is the real result flag (-1 = invalid QR).
export type AttendanceResult = {
  status: number; // -1 = "Invalid QR Code"; >= 0 = checked in
  message: string;
  attendance: any[];
  tTimeSession: any[];
};
