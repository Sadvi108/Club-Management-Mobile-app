import React, { createContext, useContext, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AppState, Platform } from "react-native";
import { router } from "expo-router";
import { useAuth } from "../api/auth";
import type { AppNotification } from "../api/types";
import {
  ensureNotificationPermissions,
  getPermissionState,
  diffAndAlert,
  sendTestAlert,
  clearBadge,
  type PermissionState,
} from "./service";
import { registerBackgroundNotificationTask } from "./background";
import { loadPrefs, savePrefs, subscribePrefs, DEFAULT_PREFS, type NotifPrefs, type Category } from "./prefs";
import { unlockWebAudio } from "./sound";

const POLL_MS = 60_000; // foreground poll cadence

type NotifCtx = {
  items: AppNotification[];
  unreadCount: number;
  loading: boolean;
  /** re-fetch now (e.g. after marking read) */
  refresh: () => Promise<void>;
  /** optimistically mark ids read in local state (server call is the caller's job) */
  markReadLocal: (ids: number[]) => void;

  /** device alert preferences (sound, vibration, categories, quiet hours) */
  prefs: NotifPrefs;
  /** merge a partial change and persist it */
  updatePrefs: (patch: Partial<NotifPrefs>) => Promise<void>;
  /** OS-level permission, refreshed on foreground */
  permission: PermissionState;
  /** prompt for the OS permission; returns the state afterwards */
  requestPermission: () => Promise<PermissionState>;
  /** fire a sample alert so the user can hear it */
  testAlert: (category?: Category) => Promise<boolean>;
};

const Ctx = createContext<NotifCtx | null>(null);

export function NotificationsProvider({ children }: { children: React.ReactNode }) {
  const { token, user } = useAuth();
  const [items, setItems] = useState<AppNotification[]>([]);
  const [readIds, setReadIds] = useState<Set<number>>(new Set());
  const [loading, setLoading] = useState(false);
  const [prefs, setPrefs] = useState<NotifPrefs>(DEFAULT_PREFS);
  const [permission, setPermission] = useState<PermissionState>("undetermined");
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  const userId = user?.id;

  // Load persisted prefs once, then track saves from anywhere (settings screen, background).
  useEffect(() => {
    let alive = true;
    void loadPrefs().then((p) => {
      if (alive) setPrefs(p);
    });
    const unsub = subscribePrefs((p) => setPrefs(p));
    return () => {
      alive = false;
      unsub();
    };
  }, []);

  // Browsers refuse to play audio until the page has seen a real user gesture, and the
  // poller that raises alerts is not one. Arm the AudioContext on the first interaction
  // of the session so the very first chime is audible.
  useEffect(() => {
    if (Platform.OS !== "web" || typeof window === "undefined") return;
    const arm = () => unlockWebAudio();
    const opts = { once: true, capture: true } as const;
    window.addEventListener("pointerdown", arm, opts);
    window.addEventListener("keydown", arm, opts);
    return () => {
      window.removeEventListener("pointerdown", arm, true);
      window.removeEventListener("keydown", arm, true);
    };
  }, []);

  const refreshPermission = useCallback(async () => {
    const st = await getPermissionState();
    setPermission(st);
    return st;
  }, []);

  const refresh = useCallback(async () => {
    if (!token || !userId) return;
    setLoading(true);
    try {
      const list = await diffAndAlert(userId); // fetch + system alerts for new items
      setItems(Array.isArray(list) ? list : []);
    } catch {
      /* keep last known list on transient errors */
    } finally {
      setLoading(false);
    }
  }, [token, userId]);

  // Session lifecycle: ask permission, register the background task, start polling.
  useEffect(() => {
    if (!token || !userId) {
      setItems([]);
      setReadIds(new Set());
      return;
    }
    void ensureNotificationPermissions().then(() => void refreshPermission());
    void registerBackgroundNotificationTask();
    void refresh();

    timer.current = setInterval(() => {
      // only poll while the app is frontmost; background is the OS task's job
      if (AppState.currentState === "active") void refresh();
    }, POLL_MS);

    const sub = AppState.addEventListener("change", (st) => {
      if (st === "active") {
        void refresh();
        // The user may have flipped the permission in system settings while away.
        void refreshPermission();
      }
    });
    return () => {
      if (timer.current) clearInterval(timer.current);
      sub.remove();
    };
  }, [token, userId, refresh, refreshPermission]);

  // Tapping a system notification opens the in-app notifications screen.
  useEffect(() => {
    if (Platform.OS === "web") return;
    let sub: { remove: () => void } | undefined;
    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const Notifications: typeof import("expo-notifications") = require("expo-notifications");
      sub = Notifications.addNotificationResponseReceivedListener((res) => {
        const route = (res?.notification?.request?.content?.data as any)?.route;
        void clearBadge();
        router.push((typeof route === "string" && route ? route : "/notifications") as any);
      });
    } catch {}
    return () => sub?.remove();
  }, []);

  const updatePrefs = useCallback(async (patch: Partial<NotifPrefs>) => {
    const current = await loadPrefs();
    const next = await savePrefs({ ...current, ...patch });
    setPrefs(next);
  }, []);

  const requestPermission = useCallback(async () => {
    await ensureNotificationPermissions();
    return refreshPermission();
  }, [refreshPermission]);

  const value = useMemo<NotifCtx>(() => {
    const unreadCount = items.filter((n) => !n.isRead && !readIds.has(n.id)).length;
    return {
      items,
      unreadCount,
      loading,
      refresh,
      markReadLocal: (ids) =>
        setReadIds((prev) => {
          const next = new Set(prev);
          ids.forEach((id) => next.add(id));
          return next;
        }),
      prefs,
      updatePrefs,
      permission,
      requestPermission,
      testAlert: sendTestAlert,
    };
  }, [items, readIds, loading, refresh, prefs, updatePrefs, permission, requestPermission]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useNotifications(): NotifCtx {
  const v = useContext(Ctx);
  if (!v) throw new Error("useNotifications must be used within NotificationsProvider");
  return v;
}
