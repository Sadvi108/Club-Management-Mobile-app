// Device alert layer. The backend has NO push-token endpoint, so real FCM/APNs push is
// impossible — instead we poll MyNotifications and raise LOCAL system notifications for
// anything new. Native uses expo-notifications; web uses the browser Notification API.
import { Platform } from "react-native";
import { storage } from "../api/storage";
import { api } from "../api/endpoints";
import type { AppNotification } from "../api/types";

// expo-notifications pulls in native modules — require lazily and guard for web,
// where we use window.Notification instead.
let Notifications: typeof import("expo-notifications") | null = null;
if (Platform.OS !== "web") {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  Notifications = require("expo-notifications");
  Notifications!.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: true,
      shouldSetBadge: true,
    }),
  });
}

const LAST_SEEN_KEY = (userId: number) => `dclix.notif.lastSeen.v1.${userId}`;

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
      await Notifications.setNotificationChannelAsync("default", {
        name: "Club notifications",
        importance: Notifications.AndroidImportance.MAX,
        vibrationPattern: [0, 250, 250, 250],
        lightColor: "#F97316",
      });
    }
    const cur = await Notifications.getPermissionsAsync();
    if (cur.granted) return true;
    const req = await Notifications.requestPermissionsAsync();
    return req.granted;
  } catch {
    return false;
  }
}

export async function presentAlert(title: string, body: string) {
  try {
    if (Platform.OS === "web") {
      if (typeof window !== "undefined" && "Notification" in window && window.Notification.permission === "granted") {
        // eslint-disable-next-line no-new
        new window.Notification(title, { body, icon: "/favicon.ico" });
      }
      return;
    }
    if (!Notifications) return;
    await Notifications.scheduleNotificationAsync({
      content: { title, body, sound: true },
      trigger: null, // fire immediately
    });
  } catch {
    /* alerts are best-effort */
  }
}

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
  const maxId = ids.length ? Math.max(...ids) : null;
  const raw = await storage.get(LAST_SEEN_KEY(userId));
  const parsedSeen = raw != null ? Number(raw) : NaN;
  const lastSeen = Number.isFinite(parsedSeen) ? parsedSeen : null;
  // Recover installs already poisoned by a previously stored "NaN".
  if (raw != null && !Number.isFinite(parsedSeen)) await storage.remove(LAST_SEEN_KEY(userId));

  // First run: don't spam alerts for the whole backlog — just set the mark.
  if (lastSeen != null) {
    const fresh = items.filter((n) => Number.isFinite(Number(n.id)) && Number(n.id) > lastSeen);
    for (const n of fresh.slice(0, 3)) {
      await presentAlert(n.text?.trim() || "Club notification", (n.value || "").trim());
    }
    if (fresh.length > 3) {
      await presentAlert("Club notifications", `${fresh.length - 3} more new notifications`);
    }
  }
  if (maxId != null && (lastSeen == null || maxId > lastSeen)) {
    await storage.set(LAST_SEEN_KEY(userId), String(maxId));
  }
  return items;
}
