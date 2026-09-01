import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, RefreshControl } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { SkeletonList } from "../src/ui/skeleton";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import { useNotifications } from "../src/notifications/NotificationsProvider";
import type { AppNotification } from "../src/api/types";

function fmtWhen(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  const now = new Date();
  const mins = Math.round((now.getTime() - d.getTime()) / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`;
  return d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export default function Notifications() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const { token } = useAuth();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  // Guarded on token: a cold open via deep link/web URL would otherwise fire unauthenticated,
  // take a 401, and trip the global handler that wipes the session — a silent logout.
  const notif = useApi(() => (token ? api.myNotifications() : Promise.resolve([])), [token]);
  const live = useNotifications(); // keeps the home-bell badge in sync when we mark read
  const [readIds, setReadIds] = useState<Set<number>>(new Set());
  const [expanded, setExpanded] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);

  // Instructor MyNotifications can come back without a `data` array — guard so .filter never throws.
  const items: AppNotification[] = Array.isArray(notif.data) ? notif.data : [];
  const isRead = (n: AppNotification) => n.isRead || readIds.has(n.id);
  const unreadCount = items.filter((n) => !isRead(n)).length;

  async function onTap(n: AppNotification) {
    setExpanded((e) => (e === n.id ? null : n.id));
    if (!isRead(n)) {
      try {
        await api.markNotificationRead(n.id);
        setReadIds((prev) => new Set(prev).add(n.id));
        live.markReadLocal([n.id]);
      } catch {
        /* keep showing as unread on failure */
      }
    }
  }

  async function markAll() {
    const unread = items.filter((n) => !isRead(n));
    if (unread.length === 0) return;
    setBusy(true);
    try {
      await Promise.all(unread.map((n) => api.markNotificationRead(n.id).catch(() => {})));
      setReadIds((prev) => {
        const next = new Set(prev);
        unread.forEach((n) => next.add(n.id));
        return next;
      });
      live.markReadLocal(unread.map((n) => n.id));
    } finally {
      setBusy(false);
    }
  }

  function refresh() {
    setReadIds(new Set());
    setExpanded(null);
    notif.reload();
  }

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => safeBack(router)} testID="ntf-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <View style={styles.titleWrap}>
            <Text style={styles.title}>Notifications</Text>
            {unreadCount > 0 && <Text style={styles.titleSub}>{unreadCount} unread</Text>}
          </View>
          <TouchableOpacity style={styles.markAll} hitSlop={8} onPress={markAll} disabled={busy || unreadCount === 0} testID="ntf-mark-all">
            {busy ? <ActivityIndicator size="small" color={colors.primary} /> : (
              <Ionicons name="checkmark-done" size={20} color={unreadCount === 0 ? colors.textMuted : colors.primary} />
            )}
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <ScrollView
        contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }}
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={notif.loading} onRefresh={refresh} tintColor={colors.primary} colors={[colors.primary]} />}
      >
        {notif.loading && items.length === 0 && <SkeletonList rows={6} lines={2} style={{ padding: 0, paddingTop: 4 }} />}
        {notif.error && <Text style={styles.errTxt}>{notif.error}</Text>}
        {!notif.loading && items.length === 0 && (
          <View style={styles.empty}>
            <Ionicons name="notifications-off-outline" size={48} color={colors.textMuted} />
            <Text style={styles.emptyTxt}>No notifications</Text>
            <Text style={styles.emptySub}>You&apos;re all caught up</Text>
          </View>
        )}

        {items.map((n) => {
          const read = isRead(n);
          const open = expanded === n.id;
          return (
            <TouchableOpacity
              key={n.id}
              style={[styles.card, !read && styles.cardUnread]}
              activeOpacity={0.85}
              onPress={() => onTap(n)}
              testID={`ntf-${n.id}`}
            >
              <View style={[styles.iconWrap, !read && { backgroundColor: colors.primary }]}>
                <Ionicons name="notifications" size={18} color={read ? colors.primary : "#fff"} />
              </View>
              <View style={{ flex: 1 }}>
                <View style={styles.cardTop}>
                  <Text style={[styles.cardTitle, !read && { fontWeight: "800" }]} numberOfLines={1}>
                    {n.text?.trim() || "Notification"}
                  </Text>
                  <Text style={styles.cardWhen}>{fmtWhen(n.notifyDate)}</Text>
                </View>
                <Text style={styles.cardMsg} numberOfLines={open ? undefined : 2}>
                  {(n.value || "").trim()}
                </Text>
                {!!n.notificationType && <Text style={styles.cardType}>{n.notificationType}</Text>}
              </View>
              {!read && <View style={styles.unreadDot} />}
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    titleWrap: { flex: 1, alignItems: "center" },
    title: { ...font.h3, color: colors.textPrimary },
    titleSub: { fontSize: 11, color: colors.primary, fontWeight: "700", marginTop: 1 },
    markAll: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    errTxt: { color: colors.danger, fontSize: 13, marginBottom: 10 },

    empty: { alignItems: "center", paddingVertical: 70, gap: 6 },
    emptyTxt: { ...font.h4, color: colors.textPrimary, marginTop: 10 },
    emptySub: { fontSize: 13, color: colors.textSecondary },

    card: { flexDirection: "row", gap: 12, alignItems: "flex-start", backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, marginBottom: 10, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    cardUnread: { backgroundColor: mode === "dark" ? colors.surfaceAlt : "#FFF7ED", borderWidth: 1, borderColor: colors.primary + "55" },
    iconWrap: { width: 40, height: 40, borderRadius: 20, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    cardTop: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", gap: 8 },
    cardTitle: { flex: 1, fontSize: 14, fontWeight: "700", color: colors.textPrimary },
    cardWhen: { fontSize: 11, color: colors.textSecondary, fontWeight: "600" },
    cardMsg: { fontSize: 13, color: colors.textSecondary, marginTop: 4, lineHeight: 18 },
    cardType: { fontSize: 11, color: colors.primary, fontWeight: "700", marginTop: 6 },
    unreadDot: { width: 9, height: 9, borderRadius: 5, backgroundColor: colors.primary, marginTop: 4 },
  });
}
