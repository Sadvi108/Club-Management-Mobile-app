import React, { createContext, useContext, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AppState, Platform } from "react-native";
import { router } from "expo-router";
import { useAuth } from "../api/auth";
import type { AppNotification } from "../api/types";
import { ensureNotificationPermissions, diffAndAlert } from "./service";
import { registerBackgroundNotificationTask } from "./background";

const POLL_MS = 60_000; // foreground poll cadence

type NotifCtx = {
  items: AppNotification[];
  unreadCount: number;
  loading: boolean;
  /** re-fetch now (e.g. after marking read) */
  refresh: () => Promise<void>;
  /** optimistically mark ids read in local state (server call is the caller's job) */
  markReadLocal: (ids: number[]) => void;
};

const Ctx = createContext<NotifCtx | null>(null);

export function NotificationsProvider({ children }: { children: React.ReactNode }) {
  const { token, user } = useAuth();
  const [items, setItems] = useState<AppNotification[]>([]);
  const [readIds, setReadIds] = useState<Set<number>>(new Set());
  const [loading, setLoading] = useState(false);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  const userId = user?.id;

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
    void ensureNotificationPermissions();
    void registerBackgroundNotificationTask();
    void refresh();

    timer.current = setInterval(() => {
      // only poll while the app is frontmost; background is the OS task's job
      if (AppState.currentState === "active") void refresh();
    }, POLL_MS);

    const sub = AppState.addEventListener("change", (st) => {
      if (st === "active") void refresh();
    });
    return () => {
      if (timer.current) clearInterval(timer.current);
      sub.remove();
    };
  }, [token, userId, refresh]);

  // Tapping a system notification opens the in-app notifications screen.
  useEffect(() => {
    if (Platform.OS === "web") return;
    let sub: { remove: () => void } | undefined;
    try {
      const Notifications: typeof import("expo-notifications") = require("expo-notifications");
      sub = Notifications.addNotificationResponseReceivedListener(() => {
        router.push("/notifications");
      });
    } catch {}
    return () => sub?.remove();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
    };
  }, [items, readIds, loading, refresh]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useNotifications(): NotifCtx {
  const v = useContext(Ctx);
  if (!v) throw new Error("useNotifications must be used within NotificationsProvider");
  return v;
}
