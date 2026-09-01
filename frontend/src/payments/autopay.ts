// ─────────────────────────────────────────────────────────────────────────────
// Auto Pay (recurring payments) — UI SHELL ONLY.
//
// Nothing in this file talks to the network. It exists so `app/autopay.tsx` and
// `app/autopay-setup.tsx` can be built, laid out and reviewed against realistic
// shapes before the backend exists. Every value below is PLACEHOLDER data.
//
// ── WIRING CHECKLIST (when the API lands) ────────────────────────────────────
// Club.Api has no recurring-payment routes today — the live prod swagger exposes
// 69 paths and none of them cover mandates, schedules or standing instructions.
// So this needs backend work first, not just an app change. What the screens
// below assume, and what each placeholder should become:
//
//   PLACEHOLDER_PLAN     → GET  /Autopay/MyPlan            (the caller's plan, or null)
//   PLACEHOLDER_UPCOMING → GET  /Autopay/Schedule          (future charges)
//   PLACEHOLDER_HISTORY  → GET  /Autopay/Charges           (past charges)
//   enable / edit        → POST /Autopay/Enroll            (returns plan + gateway mandate url)
//   pause / resume       → POST /Autopay/SetStatus         ({ planId, status })
//   cancel               → POST /Autopay/Cancel            ({ planId })
//
// Two things a recurring gateway needs that a one-off payment does not, and that
// the route names above gloss over:
//   1. A MANDATE. Charging later with no user present means the gateway must
//      store a reusable token (Boost calls this a standing instruction). Enroll
//      therefore has to return a consent/authorisation URL to open in the browser
//      the same way `api.startPayment()` does, and the plan only becomes `active`
//      after the mandate is confirmed — never optimistically on the app's say-so.
//   2. RECONCILIATION. A charge that the gateway reports as taken is not proof the
//      invoice was settled. `api.confirmPayment()` already models this correctly
//      (reconcile against /Outstanding/Fetch, never assume) — the autopay charge
//      list must be driven by the same source of truth, not by gateway status alone.
//
// Until the routes exist the screens render this static data and every action is
// a no-op that says so out loud. Search for "TODO(autopay)" for the exact call sites.
// ─────────────────────────────────────────────────────────────────────────────

export type AutopayFrequency = "monthly" | "quarterly" | "yearly";

/** `none` = the account has never enrolled; there is no plan object at all. */
export type AutopayStatus = "active" | "paused" | "none";

export type ChargeStatus = "scheduled" | "paid" | "failed" | "skipped";

/** The standing instruction itself — one per student account. */
export type AutopayPlan = {
  id: number;
  studentId: number;
  studentName: string;
  /** Amount charged each cycle, in RM. */
  amount: number;
  frequency: AutopayFrequency;
  /** 1-31. Months shorter than this charge on their last day — see `clampDay`. */
  chargeDay: number;
  /** ISO yyyy-mm-dd. */
  startDate: string;
  nextChargeDate: string;
  status: AutopayStatus;
  /** Display label for the authorised instrument, e.g. "Boost •••• 4821". */
  methodLabel: string;
};

/** One occurrence — past or future — of a plan's charge. */
export type AutopayCharge = {
  id: number;
  planId: number;
  /** ISO yyyy-mm-dd. */
  dueDate: string;
  amount: number;
  status: ChargeStatus;
  /** Present once the charge has produced a receipt. */
  receiptNo?: string;
  /** Present on `failed`; shown verbatim to the user. */
  failureReason?: string;
};

// ── Placeholder data ─────────────────────────────────────────────────────────
// Shaped to match the live student account used throughout development
// (DARSHAN MUTHUSIGAMANI, id 35842, RM 80/month at SMK KK2) so the layout is
// exercised with realistic string lengths and amounts.

export const PLACEHOLDER_PLAN: AutopayPlan = {
  id: 1,
  studentId: 35842,
  studentName: "DARSHAN MUTHUSIGAMANI",
  amount: 80,
  frequency: "monthly",
  chargeDay: 1,
  startDate: "2026-09-01",
  nextChargeDate: "2026-09-01",
  status: "active",
  methodLabel: "Boost •••• 4821",
};

export const PLACEHOLDER_UPCOMING: AutopayCharge[] = [
  { id: 101, planId: 1, dueDate: "2026-09-01", amount: 80, status: "scheduled" },
  { id: 102, planId: 1, dueDate: "2026-10-01", amount: 80, status: "scheduled" },
  { id: 103, planId: 1, dueDate: "2026-11-01", amount: 80, status: "scheduled" },
];

export const PLACEHOLDER_HISTORY: AutopayCharge[] = [
  { id: 91, planId: 1, dueDate: "2026-08-01", amount: 85, status: "paid", receiptNo: "10100033" },
  { id: 90, planId: 1, dueDate: "2026-07-01", amount: 80, status: "paid", receiptNo: "10100021" },
  {
    id: 89,
    planId: 1,
    dueDate: "2026-06-01",
    amount: 80,
    status: "failed",
    failureReason: "Card declined by issuer",
  },
  { id: 88, planId: 1, dueDate: "2026-05-01", amount: 80, status: "paid", receiptNo: "10100008" },
];

// ── Formatting + schedule maths ──────────────────────────────────────────────
// These are pure and belong to the shell: the setup screen has to preview real
// dates for the user to sanity-check a plan before enrolling, and that preview
// must not wait on a backend.

export const FREQUENCY_LABEL: Record<AutopayFrequency, string> = {
  monthly: "Monthly",
  quarterly: "Every 3 months",
  yearly: "Yearly",
};

/** Months advanced per cycle. */
export const FREQUENCY_STEP: Record<AutopayFrequency, number> = {
  monthly: 1,
  quarterly: 3,
  yearly: 12,
};

export const fmtMoney = (n: number) =>
  "RM " + Number(n || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export function fmtDate(iso?: string) {
  const d = parseLocalDate(iso);
  return d ? d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }) : iso || "";
}

export function fmtMonth(iso?: string) {
  const d = parseLocalDate(iso);
  return d ? d.toLocaleDateString("en-GB", { month: "long", year: "numeric" }) : iso || "";
}

/** "Sep 2026" — the long form overflows a one-third-width chip. */
export function fmtMonthShort(iso?: string) {
  const d = parseLocalDate(iso);
  return d ? d.toLocaleDateString("en-GB", { month: "short", year: "numeric" }) : iso || "";
}

/**
 * Parse `yyyy-mm-dd` into a LOCAL date.
 *
 * `new Date("2026-09-01")` is parsed as UTC midnight, which is the previous day
 * for anyone west of Greenwich — the whole schedule would render a day early.
 * Building from parts keeps every date in the user's own timezone, the same rule
 * `app/book-class.tsx` follows when it submits a booking date.
 */
export function parseLocalDate(iso?: string): Date | null {
  if (!iso) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  if (!m) return null;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return isNaN(d.getTime()) ? null : d;
}

/** Local `yyyy-mm-dd` — never `toISOString()`, which would shift the day. */
export function isoDate(d: Date): string {
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** Day 31 in a 30-day month becomes the 30th, and February's 28th/29th. */
export function clampDay(year: number, monthIndex: number, day: number): number {
  const lastDayOfMonth = new Date(year, monthIndex + 1, 0).getDate();
  return Math.min(Math.max(1, day), lastDayOfMonth);
}

/**
 * The next `count` charge dates for a plan, as local ISO dates.
 *
 * The first charge is the chosen day in the start month, unless that day has
 * already passed, in which case it rolls to the next cycle.
 *
 * "Already passed" is measured against TODAY, not against `startISO`. The setup
 * screen offers whole months and passes the 1st of one (`startMonthOptions`), so
 * comparing against `startISO` alone would happily schedule the 1st of the current
 * month — a date in the past — for anyone setting a plan up mid-month. `now` is
 * injectable so the roll-over is testable without touching the clock.
 */
export function previewSchedule(
  startISO: string,
  frequency: AutopayFrequency,
  chargeDay: number,
  count = 3,
  now: Date = new Date()
): string[] {
  const start = parseLocalDate(startISO);
  if (!start) return [];
  const step = FREQUENCY_STEP[frequency];

  // A charge can never be scheduled before today, whatever start month was picked.
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const earliest = start.getTime() > today.getTime() ? start : today;

  let y = earliest.getFullYear();
  let m = earliest.getMonth();
  const firstInStartMonth = new Date(y, m, clampDay(y, m, chargeDay));
  // Day already gone this month → begin one whole cycle later.
  if (firstInStartMonth.getTime() < earliest.getTime()) m += step;

  const out: string[] = [];
  for (let i = 0; i < count; i++) {
    const cursor = new Date(y, m + i * step, 1); // normalises any month overflow
    const cy = cursor.getFullYear();
    const cm = cursor.getMonth();
    out.push(isoDate(new Date(cy, cm, clampDay(cy, cm, chargeDay))));
  }
  return out;
}

/** The three months a plan can start in, beginning with the current one. */
export function startMonthOptions(from = new Date()): string[] {
  return [0, 1, 2].map((i) => isoDate(new Date(from.getFullYear(), from.getMonth() + i, 1)));
}
