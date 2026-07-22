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
        lightColor: "#E11D2A",
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

  const maxId = Math.max(...items.map((n) => n.id));
  const raw = await storage.get(LAST_SEEN_KEY(userId));
  const lastSeen = raw ? Number(raw) : null;

  // First run: don't spam alerts for the whole backlog — just set the mark.
  if (lastSeen != null && Number.isFinite(lastSeen)) {
    const fresh = items.filter((n) => n.id > lastSeen);
    for (const n of fresh.slice(0, 3)) {
      await presentAlert(n.text?.trim() || "Club notification", (n.value || "").trim());
    }
    if (fresh.length > 3) {
      await presentAlert("Club notifications", `${fresh.length - 3} more new notifications`);
    }
  }
  if (lastSeen == null || maxId > lastSeen) await storage.set(LAST_SEEN_KEY(userId), String(maxId));
  return items;
}
