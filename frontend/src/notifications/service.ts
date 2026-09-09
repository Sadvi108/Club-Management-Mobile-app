// Device alert layer. The backend has NO push-token endpoint (confirmed against the live
// Swagger: 69 routes, none of them device/token registration), so server-initiated FCM/APNs
// push is impossible without backend work. Instead we poll MyNotifications and raise LOCAL
// system notifications for anything new — which the OS renders identically to a remote push,
// tray entry and sound included.
//
// Sound, per platform:
//   Android 8+  the CHANNEL owns the sound and vibration; content-level `sound` is ignored.
//               So we pick a channel per (category, loudness) and let the OS play the
//               bundled res/raw/dclix_alert.wav even with the app closed.
//   iOS         content.sound names the bundled dclix_alert.wav.
//   Web         `new Notification()` is silent by spec, so we synthesise the same chime
//               with the Web Audio API — see ./sound.
import { Platform } from "react-native";
import { storage } from "../api/storage";
import { api } from "../api/endpoints";
import type { AppNotification } from "../api/types";
import { playAlertChime, vibrateWeb } from "./sound";
import {
  loadPrefs,
  peekPrefs,
  categorise,
  shouldAlert,
  isAllowed,
  inQuietHours,
  DEFAULT_PREFS,
  type Category,
  type NotifPrefs,
} from "./prefs";

// expo-notifications pulls in native modules — require lazily and guard for web,
// where we use window.Notification instead.
let Notifications: typeof import("expo-notifications") | null = null;
if (Platform.OS !== "web") {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  Notifications = require("expo-notifications");
  Notifications!.setNotificationHandler({
    handleNotification: async () => {
      // Prefs decide whether a notification arriving while the app is frontmost also makes
      // noise. peek (not load) — this handler is on the OS's critical path.
      const p = peekPrefs() ?? DEFAULT_PREFS;
      return {
        shouldShowBanner: true,
        shouldShowList: true,
        shouldPlaySound: p.enabled && p.sound,
        shouldSetBadge: true,
      };
    },
  });
}

/** Bundled by the expo-notifications config plugin into res/raw (Android) and the app bundle (iOS). */
export const ALERT_SOUND_FILE = "dclix_alert.wav";

const LAST_SEEN_KEY = (userId: number) => `dclix.notif.lastSeen.v1.${userId}`;

// ── Android channels ────────────────────────────────────────────────────────────────
// A channel's sound and vibration are FROZEN at creation — Android ignores every later
// edit to an existing channel. So loudness is baked into the channel id and we switch
// channels rather than mutate one. Bump the vN suffix if these definitions ever change,
// or existing installs keep the old behaviour forever.
type Loudness = "alert" | "vibrate" | "quiet";

const CHANNEL_GROUP = "dclix-notifications";
const created = new Set<string>();

function channelId(category: Category, loudness: Loudness): string {
  return `dclix-${category}-${loudness}-v1`;
}

const CATEGORY_NAME: Record<Category, string> = {
  payments: "Fees & payments",
  classes: "Classes & training",
  general: "Club announcements",
};

const LOUDNESS_SUFFIX: Record<Loudness, string> = {
  alert: "",
  vibrate: " (vibrate only)",
  quiet: " (silent)",
};

/**
 * Create the channel for this combination on first use. Creating lazily means a user who
 * never touches the settings screen sees exactly three channels in Android's notification
 * settings instead of nine.
 *
 * Returns null if the channel could not be created. That distinction matters: Android 8+
 * silently DROPS a notification posted to a channel id that does not exist, so a caller
 * that got null must fall back to the default channel rather than post into the void.
 */
async function ensureChannel(category: Category, loudness: Loudness): Promise<string | null> {
  const id = channelId(category, loudness);
  if (!Notifications || Platform.OS !== "android") return id;
  if (created.has(id)) return id;
  try {
    await Notifications.setNotificationChannelGroupAsync(CHANNEL_GROUP, { name: "D-CLIX" });
    await Notifications.setNotificationChannelAsync(id, {
      name: CATEGORY_NAME[category] + LOUDNESS_SUFFIX[loudness],
      groupId: CHANNEL_GROUP,
      // MAX is what earns a heads-up banner over whatever the user is doing.
      importance:
        loudness === "quiet"
          ? Notifications.AndroidImportance.DEFAULT
          : Notifications.AndroidImportance.MAX,
      sound: loudness === "alert" ? ALERT_SOUND_FILE : null,
      enableVibrate: loudness !== "quiet",
      vibrationPattern: loudness === "quiet" ? undefined : [0, 250, 200, 250],
      enableLights: true,
      lightColor: "#F97316",
      showBadge: true,
    });
    created.add(id);
    return id;
  } catch {
    // Fall back to the default channel: a quieter alert still beats no alert.
    return null;
  }
}

function loudnessFor(p: NotifPrefs): Loudness {
  if (p.sound) return "alert";
  return p.vibrate ? "vibrate" : "quiet";
}

// ── Permissions ─────────────────────────────────────────────────────────────────────

export type PermissionState = "granted" | "denied" | "undetermined" | "unsupported";

/** Read the OS permission WITHOUT prompting — for the settings screen. */
export async function getPermissionState(): Promise<PermissionState> {
  try {
    if (Platform.OS === "web") {
      if (typeof window === "undefined" || !("Notification" in window)) return "unsupported";
      const p = window.Notification.permission;
      return p === "granted" ? "granted" : p === "denied" ? "denied" : "undetermined";
    }
    if (!Notifications) return "unsupported";
    const cur = await Notifications.getPermissionsAsync();
    if (cur.granted) return "granted";
    return cur.canAskAgain ? "undetermined" : "denied";
  } catch {
    return "unsupported";
  }
}

export async function ensureNotificationPermissions(): Promise<boolean> {
  try {
    if (Platform.OS === "web") {
      if (typeof window === "undefined" || !("Notification" in window)) return false;
      if (window.Notification.permission === "granted") return true;
      if (window.Notification.permission === "denied") return false;
      return (await window.Notification.requestPermission()) === "granted";
    }
    if (!Notifications) return false;
    if (Platform.OS === "android") {
      // Pre-create the channel the user will actually get, so the very first alert is
      // already loud instead of landing on a default-importance fallback.
      const p = await loadPrefs();
      await ensureChannel("general", loudnessFor(p));
    }
    const cur = await Notifications.getPermissionsAsync();
    if (cur.granted) return true;
    const req = await Notifications.requestPermissionsAsync();
    return req.granted;
  } catch {
    return false;
  }
}

// ── Presenting ──────────────────────────────────────────────────────────────────────

type AlertOpts = {
  category?: Category;
  /** Server notification id, so a tap can open the right row later. */
  notificationId?: number;
  /** Bypass the category/quiet-hours filter — used by the "send test alert" button. */
  force?: boolean;
  /**
   * Web dedupe key suffix. Alerts sharing a tag REPLACE each other in the tray, so
   * anything that is not a specific server row needs its own.
   */
  tag?: string;
};

/**
 * Raise one OS-level notification on whatever platform we are running on.
 * Returns true if it was actually presented (false = filtered out, or no permission).
 */
export async function presentAlert(title: string, body: string, opts: AlertOpts = {}): Promise<boolean> {
  const category = opts.category ?? "general";
  try {
    const p = await loadPrefs();
    if (!opts.force && !shouldAlert(p, category)) return false;
    // The master switch still applies to the test button — otherwise "test" would lie
    // about what a real notification does.
    if (opts.force && !p.enabled) return false;

    if (Platform.OS === "web") {
      if (typeof window === "undefined" || !("Notification" in window)) return false;
      if (window.Notification.permission !== "granted") return false;
      // A stable tag collapses repeats of the same server row instead of stacking them.
      const n = new window.Notification(title, {
        body,
        icon: "/favicon.ico",
        tag:
          opts.notificationId != null
            ? `dclix-row-${opts.notificationId}`
            : `dclix-${opts.tag ?? category}`,
      });
      n.onclick = () => {
        try {
          window.focus();
          window.location.assign("/notifications");
        } catch {}
        n.close();
      };
      if (p.sound) playAlertChime();
      if (p.vibrate) vibrateWeb();
      return true;
    }

    if (!Notifications) return false;
    const ch = await ensureChannel(category, loudnessFor(p));
    await Notifications.scheduleNotificationAsync({
      content: {
        title,
        body,
        // iOS reads `sound`; on Android 8+ the channel wins and sound/vibrate/priority
        // here are ignored — they only matter on Android 7 and below, which has no channels.
        sound: p.sound ? ALERT_SOUND_FILE : false,
        vibrate: p.vibrate ? [0, 250, 200, 250] : undefined,
        priority: Notifications.AndroidNotificationPriority.MAX,
        data: { route: "/notifications", category, notificationId: opts.notificationId },
      },
      // A bare `{ channelId }` IS the "deliver immediately" trigger — it is the only place
      // expo-notifications accepts a channel, and `trigger: null` would silently fall back
      // to the default channel and lose our sound. `ch` is null only when the channel
      // could not be created, where the default channel is the safe fallback.
      trigger: Platform.OS === "android" && ch ? { channelId: ch } : null,
    });
    return true;
  } catch {
    return false; /* alerts are best-effort */
  }
}

/** Fire a sample alert so the user can hear exactly what an incoming notification does. */
export function sendTestAlert(category: Category = "general"): Promise<boolean> {
  return presentAlert("D-CLIX test notification", "This is how your alerts will look and sound.", {
    category,
    force: true,
    tag: "test",
  });
}

/** Clear the app-icon badge — called when the user opens the notifications screen. */
export async function clearBadge(): Promise<void> {
  try {
    if (Platform.OS === "web" || !Notifications) return;
    await Notifications.setBadgeCountAsync(0);
  } catch {}
}

// ── Poll + diff ─────────────────────────────────────────────────────────────────────

/** How many individual alerts one poll may raise before it collapses into a summary. */
const MAX_ALERTS_PER_POLL = 3;

/**
 * Fetch the latest notifications, alert for anything newer than what this user has
 * already been alerted about (persisted high-water mark by notification id).
 * Returns the fresh list so callers can also update UI state.
 */
export async function diffAndAlert(userId: number): Promise<AppNotification[]> {
  const list = (await api.myNotifications()) ?? [];
  const items = Array.isArray(list) ? list : [];
  if (items.length === 0) return items;

  // Only finite ids can advance the high-water mark. A single malformed id used to make
  // maxId NaN, which was then persisted as the string "NaN" — after which both the alert
  // branch and this write-back tested false forever and the user silently stopped getting
  // notifications for good, with reinstall the only way out.
  const ids = items.map((n) => Number(n.id)).filter((n) => Number.isFinite(n));
  // reduce, not Math.max(...ids): spreading a few hundred thousand ids as arguments
  // throws RangeError, and this list is server-controlled.
  const maxId = ids.length ? ids.reduce((a, b) => (b > a ? b : a), ids[0]) : null;
  const raw = await storage.get(LAST_SEEN_KEY(userId));
  const parsedSeen = raw != null ? Number(raw) : NaN;
  const lastSeen = Number.isFinite(parsedSeen) ? parsedSeen : null;
  // Recover installs already poisoned by a previously stored "NaN".
  if (raw != null && !Number.isFinite(parsedSeen)) await storage.remove(LAST_SEEN_KEY(userId));

  // Set when quiet hours held alerts back, so the high-water mark is NOT advanced past
  // them and they fire once the window ends.
  let deferred = false;

  // First run: don't spam alerts for the whole backlog — just set the mark.
  if (lastSeen != null) {
    const p = await loadPrefs();
    const fresh = items
      .filter((n) => Number.isFinite(Number(n.id)) && Number(n.id) > lastSeen)
      // Oldest first, so the newest ends up on top of the tray.
      .sort((a, b) => Number(a.id) - Number(b.id))
      .map((n) => ({ n, category: categorise(n.notificationType, n.text, n.value) }));

    // Drop muted categories BEFORE applying the volume cap. Capping first meant that if
    // the three newest rows happened to be in a muted category, every older row the user
    // *did* want was skipped — and then the mark advanced past it, so it never alerted
    // at all. Muting fees must not silence class notices.
    const wanted = fresh.filter((f) => isAllowed(p, f.category));

    // Quiet hours DEFER, they do not delete. Suppressing an alert and then advancing the
    // mark past it would destroy it permanently, which is not what "silence overnight"
    // means to anyone.
    if (wanted.length > 0 && inQuietHours(p)) {
      deferred = true;
    } else {
      const show = wanted.slice(-MAX_ALERTS_PER_POLL);
      let presented = 0;
      for (const { n, category } of show) {
        const ok = await presentAlert(n.text?.trim() || "Club notification", (n.value || "").trim(), {
          category,
          notificationId: Number(n.id),
        });
        if (ok) presented++;
      }
      // Summarise only what the volume cap dropped, and only if something got through.
      // Counting rows a muted category already filtered would leak the very alerts the
      // user turned off; skipping when nothing was presented avoids a lone summary when
      // the OS permission is the real blocker.
      const capped = wanted.length - show.length;
      if (capped > 0 && presented > 0) {
        await presentAlert("Club notifications", `${capped} more new notification${capped > 1 ? "s" : ""}`, {
          category: "general",
          tag: "summary",
        });
      }
    }
  }
  if (!deferred && maxId != null && (lastSeen == null || maxId > lastSeen)) {
    await storage.set(LAST_SEEN_KEY(userId), String(maxId));
  }
  return items;
}
