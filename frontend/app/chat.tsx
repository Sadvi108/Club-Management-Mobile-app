import { useEffect, useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, RefreshControl } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { useNotifications } from "../src/notifications/NotificationsProvider";
import { threadsWithSent, HELPDESK_THREAD, type SentMsg } from "../src/chat/store";
import { SkeletonList } from "../src/ui/skeleton";
import type { AppNotification } from "../src/api/types";

function fmtWhen(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "";
  const mins = Math.round((Date.now() - d.getTime()) / 60000);
  if (mins < 1) return "now";
  if (mins < 60) return `${mins}m`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h`;
  return d.toLocaleDateString("en-GB", { day: "2-digit", month: "short" });
}

type Thread = {
  key: string; // groupId or HELPDESK_THREAD
  title: string;
  preview: string;
  at?: string;
  unread: number;
};

// Conversations = notification groups (server truth) merged with locally-sent messages.
export default function Chat() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user } = useAuth();
  const { items, loading, refresh } = useNotifications();
  const [sentMap, setSentMap] = useState<Record<string, SentMsg[]>>({});

  useEffect(() => {
    if (user?.id) void threadsWithSent(user.id).then(setSentMap);
  }, [user?.id, items]);

  const threads = useMemo<Thread[]>(() => {
    const byGroup = new Map<string, AppNotification[]>();
    for (const n of items) {
      const g = n.groupId || String(n.id);
      const arr = byGroup.get(g) ?? [];
      arr.push(n);
      byGroup.set(g, arr);
    }
    const list: Thread[] = [];
    for (const [g, msgs] of byGroup) {
      msgs.sort((a, b) => (a.notifyDate || "").localeCompare(b.notifyDate || ""));
      const last = msgs[msgs.length - 1];
      const sent = sentMap[g] ?? [];
      const lastSent = sent[sent.length - 1];
      const newer = lastSent && (!last.notifyDate || lastSent.at > last.notifyDate) ? lastSent : null;
      list.push({
        key: g,
        title: last.text?.trim() || "Club message",
        preview: (newer ? `You: ${newer.text}` : last.value || "").trim(),
        at: newer ? newer.at : last.notifyDate,
        unread: msgs.filter((m) => !m.isRead).length,
      });
    }
    list.sort((a, b) => (b.at || "").localeCompare(a.at || ""));
    return list;
  }, [items, sentMap]);

  const helpdeskSent = sentMap[HELPDESK_THREAD] ?? [];
  const helpdeskLast = helpdeskSent[helpdeskSent.length - 1];

  const openThread = (key: string, title: string) =>
    router.push(`/chat-thread?g=${encodeURIComponent(key)}&t=${encodeURIComponent(title)}` as any);

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => safeBack(router)} testID="chat-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Chat Academy</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      <ScrollView
        contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }}
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={loading} onRefresh={() => void refresh()} tintColor={colors.primary} colors={[colors.primary]} />}
      >
        {/* Pinned: talk to the club (starts a new helpdesk conversation) */}
        <TouchableOpacity style={[styles.row, styles.pinned]} activeOpacity={0.85} onPress={() => openThread(HELPDESK_THREAD, "Club Help Desk")} testID="chat-helpdesk">
          <View style={[styles.avatar, { backgroundColor: colors.primary }]}>
            <Ionicons name="headset" size={20} color="#fff" />
          </View>
          <View style={{ flex: 1 }}>
            <View style={styles.rowTop}>
              <Text style={styles.rowTitle}>{user?.clubName?.trim() || "Club"} · Help Desk</Text>
              <Text style={styles.rowWhen}>{helpdeskLast ? fmtWhen(helpdeskLast.at) : ""}</Text>
            </View>
            <Text style={styles.rowPreview} numberOfLines={1}>
              {helpdeskLast ? `You: ${helpdeskLast.text}` : "Message your club admin / instructor"}
            </Text>
          </View>
          <Ionicons name="chevron-forward" size={16} color={colors.textMuted} />
        </TouchableOpacity>

        <Text style={styles.sectionLbl}>CONVERSATIONS</Text>
        {loading && items.length === 0 && <SkeletonList rows={5} lines={2} style={{ padding: 0, paddingTop: 4 }} />}
        {!loading && threads.length === 0 && (
          <View style={styles.empty}>
            <Ionicons name="chatbubbles-outline" size={44} color={colors.textMuted} />
            <Text style={styles.emptyTxt}>No conversations yet</Text>
            <Text style={styles.emptySub}>Messages from your club appear here.</Text>
          </View>
        )}

        {threads.map((t) => (
          <TouchableOpacity key={t.key} style={styles.row} activeOpacity={0.85} onPress={() => openThread(t.key, t.title)} testID={`chat-thread-${t.key}`}>
            <View style={styles.avatar}>
              <Ionicons name="chatbubble-ellipses-outline" size={19} color={colors.primary} />
            </View>
            <View style={{ flex: 1 }}>
              <View style={styles.rowTop}>
                <Text style={[styles.rowTitle, t.unread > 0 && { fontWeight: "800" }]} numberOfLines={1}>{t.title}</Text>
                <Text style={styles.rowWhen}>{fmtWhen(t.at)}</Text>
              </View>
              <Text style={[styles.rowPreview, t.unread > 0 && { color: colors.textPrimary, fontWeight: "600" }]} numberOfLines={1}>
                {t.preview || "…"}
              </Text>
            </View>
            {t.unread > 0 && (
              <View style={styles.unreadPill}><Text style={styles.unreadTxt}>{t.unread}</Text></View>
            )}
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },

    sectionLbl: { fontSize: 10, fontWeight: "800", letterSpacing: 1, color: colors.textMuted, marginTop: 18, marginBottom: 10 },

    row: { flexDirection: "row", gap: 12, alignItems: "center", backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, marginBottom: 10, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    pinned: { borderWidth: 1, borderColor: colors.primary + "44", backgroundColor: mode === "dark" ? colors.surfaceAlt : "#FFF7ED" },
    avatar: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    rowTop: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", gap: 8 },
    rowTitle: { flex: 1, fontSize: 14, fontWeight: "700", color: colors.textPrimary },
    rowWhen: { fontSize: 11, color: colors.textSecondary, fontWeight: "600" },
    rowPreview: { fontSize: 12.5, color: colors.textSecondary, marginTop: 3 },
    unreadPill: { minWidth: 20, height: 20, borderRadius: 10, paddingHorizontal: 5, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center" },
    unreadTxt: { color: "#fff", fontSize: 10.5, fontWeight: "800" },

    empty: { alignItems: "center", paddingVertical: 50, gap: 6 },
    emptyTxt: { ...font.h4, color: colors.textPrimary, marginTop: 8 },
    emptySub: { fontSize: 12.5, color: colors.textSecondary },
  });
}
