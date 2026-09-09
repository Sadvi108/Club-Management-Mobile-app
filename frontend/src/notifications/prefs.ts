// Device-level alert preferences. Deliberately NOT per-user: these describe how this
// handset should behave, so switching student/sibling must not reset them.
import { storage } from "../api/storage";

/** Buckets we can sort a server notification into, so the user can mute one and keep the rest. */
export type Category = "payments" | "classes" | "general";

export const CATEGORIES: { key: Category; label: string; hint: string; icon: string }[] = [
  { key: "payments", label: "Fees & payments", hint: "Invoices, receipts, dues reminders", icon: "wallet" },
  { key: "classes", label: "Classes & training", hint: "Bookings, timetable, attendance, grading", icon: "barbell" },
  { key: "general", label: "Club announcements", hint: "Events, offers, help desk replies", icon: "megaphone" },
];

export type NotifPrefs = {
  /** Master kill switch — app-side, independent of the OS permission. */
  enabled: boolean;
  sound: boolean;
  vibrate: boolean;
  categories: Record<Category, boolean>;
  /** Suppress alerts overnight. Wraps midnight when start > end. */
  quietHours: { enabled: boolean; startHour: number; endHour: number };
};

export const DEFAULT_PREFS: NotifPrefs = {
  enabled: true,
  sound: true,
  vibrate: true,
  categories: { payments: true, classes: true, general: true },
  quietHours: { enabled: false, startHour: 22, endHour: 7 },
};

const PREFS_KEY = "dclix.notif.prefs.v1";

/** Listeners so the provider re-renders when the settings screen saves. */
type Listener = (p: NotifPrefs) => void;
const listeners = new Set<Listener>();

// Cached so the alert path (which runs inside a headless background task) never has to
// await storage mid-flight after the first read.
let cache: NotifPrefs | null = null;

function coerce(raw: any): NotifPrefs {
  const d = DEFAULT_PREFS;
  if (!raw || typeof raw !== "object") return { ...d, categories: { ...d.categories }, quietHours: { ...d.quietHours } };
  const cats = raw.categories && typeof raw.categories === "object" ? raw.categories : {};
  const qh = raw.quietHours && typeof raw.quietHours === "object" ? raw.quietHours : {};
  const hour = (v: any, fallback: number) => (Number.isInteger(v) && v >= 0 && v <= 23 ? v : fallback);
  return {
    enabled: typeof raw.enabled === "boolean" ? raw.enabled : d.enabled,
    sound: typeof raw.sound === "boolean" ? raw.sound : d.sound,
    vibrate: typeof raw.vibrate === "boolean" ? raw.vibrate : d.vibrate,
    categories: {
      payments: typeof cats.payments === "boolean" ? cats.payments : d.categories.payments,
      classes: typeof cats.classes === "boolean" ? cats.classes : d.categories.classes,
      general: typeof cats.general === "boolean" ? cats.general : d.categories.general,
    },
    quietHours: {
      enabled: typeof qh.enabled === "boolean" ? qh.enabled : d.quietHours.enabled,
      startHour: hour(qh.startHour, d.quietHours.startHour),
      endHour: hour(qh.endHour, d.quietHours.endHour),
    },
  };
}

export async function loadPrefs(): Promise<NotifPrefs> {
  if (cache) return cache;
  let parsed: any = null;
  try {
    const raw = await storage.get(PREFS_KEY);
    if (raw) parsed = JSON.parse(raw);
  } catch {
    /* corrupt blob → fall through to defaults rather than stranding the user with no alerts */
  }
  cache = coerce(parsed);
  return cache;
}

/** Last value read, without awaiting. Null until loadPrefs() has run once. */
export function peekPrefs(): NotifPrefs | null {
  return cache;
}

export async function savePrefs(next: NotifPrefs): Promise<NotifPrefs> {
  cache = coerce(next);
  try {
    await storage.set(PREFS_KEY, JSON.stringify(cache));
  } catch {
    /* keep the in-memory value so the session still honours the change */
  }
  listeners.forEach((fn) => fn(cache!));
  return cache;
}

export function subscribePrefs(fn: Listener): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

/**
 * True when `at` falls inside the configured quiet window. Handles the normal
 * overnight case (22:00 → 07:00) where start > end and the range wraps midnight.
 */
export function inQuietHours(p: NotifPrefs, at: Date = new Date()): boolean {
  if (!p.quietHours.enabled) return false;
  const { startHour, endHour } = p.quietHours;
  if (startHour === endHour) return false; // empty window, not a 24h mute
  const h = at.getHours();
  return startHour < endHour ? h >= startHour && h < endHour : h >= startHour || h < endHour;
}

// Probed against prod on 2026-09-03 (the student test account, 15 rows): `notificationType`
// is ALWAYS the empty string, `text` is a short subject from a fixed set ("Reminder",
// "Class Activity", "ClassReplacement"), and the only real content is `value` — written
// in MALAY ("Sila jelaskan yuran tertunggak RM85.00 anda secepat mungkin"). So the body
// has to be part of the match, and matching English alone would file every live fee
// reminder under "general". Both languages are matched; the club's admin panel can emit
// either.
const PAYMENT_WORDS =
  /(fee|payment|invoice|receipt|due|outstanding|bill|paid|refund|reimburse|purchase|arrear|yuran|tertunggak|bayar|pembayaran|resit|invois|hutang|caj|denda|rm\s*\d)/;
const CLASS_WORDS =
  /(class|training|book|attend|schedul|timetable|grad|belt|exam|tournament|competit|replacement|kelas|latihan|jadual|kehadiran|peperiksaan|ujian|pertandingan|gred|tali ?pinggang)/;

/**
 * Map a server notification onto a category so the user can mute one kind and keep the
 * rest. Falls back to "general" — an unrecognised notification must still alert, never
 * silently vanish. Payments is tested first: a fee reminder about a class is still a
 * fee reminder.
 */
export function categorise(notificationType?: string, subject?: string, body?: string): Category {
  const s = `${notificationType || ""} ${subject || ""} ${body || ""}`.toLowerCase();
  if (PAYMENT_WORDS.test(s)) return "payments";
  if (CLASS_WORDS.test(s)) return "classes";
  return "general";
}

/**
 * Master switch + category only, ignoring the clock. This is the "the user WANTS this
 * kind of alert" test, as distinct from "right now is a good time" — the poller needs
 * them apart, because a muted category is discarded for good while a quiet-hours
 * suppression must merely be deferred.
 */
export function isAllowed(p: NotifPrefs, category: Category): boolean {
  return p.enabled && p.categories[category] !== false;
}

/** Should an alert in `category` be raised right now? */
export function shouldAlert(p: NotifPrefs, category: Category, at: Date = new Date()): boolean {
  return isAllowed(p, category) && !inQuietHours(p, at);
}
