import { useEffect, useMemo, useRef, useState } from "react";
import {
  View, Text, StyleSheet, TouchableOpacity, TextInput, FlatList, KeyboardAvoidingView, Platform, ActivityIndicator,
} from "react-native";
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter, useLocalSearchParams } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";
import { useNotifications } from "../src/notifications/NotificationsProvider";
import { getSent, appendSent, HELPDESK_THREAD, type SentMsg } from "../src/chat/store";

type Bubble = { key: string; mine: boolean; text: string; sub?: string; at: string };

function fmtTime(iso: string) {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "";
  return d.toLocaleString("en-GB", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
}

// One conversation. Incoming = the user's own notification rows for this group (server
// truth); outgoing = Reply2Notification / Send2ClubHelpDesk with a persisted local echo
// (the API keeps no sender-side copy — see the design doc).
export default function ChatThread() {
  const router = useRouter();
  const { g, t } = useLocalSearchParams<{ g?: string; t?: string }>();
  const threadKey = g || HELPDESK_THREAD;
  const isHelpdesk = threadKey === HELPDESK_THREAD;
  const { colors, shadow, mode } = useTheme();
  const insets = useSafeAreaInsets();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user } = useAuth();
  const { items, refresh, markReadLocal } = useNotifications();

  const [sent, setSent] = useState<SentMsg[]>([]);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const listRef = useRef<FlatList<Bubble>>(null);

  const incoming = useMemo(
    () => (isHelpdesk ? [] : items.filter((n) => n.groupId === threadKey)),
    [items, threadKey, isHelpdesk]
  );

  // Load the local echo history.
  useEffect(() => {
    if (user?.id) void getSent(user.id, threadKey).then(setSent);
  }, [user?.id, threadKey]);

  // Opening the thread marks its unread messages read (server + badge).
  useEffect(() => {
    const unread = incoming.filter((n) => !n.isRead);
    if (unread.length === 0) return;
    void Promise.all(unread.map((n) => api.markNotificationRead(n.id).catch(() => {}))).then(() => {
      markReadLocal(unread.map((n) => n.id));
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [incoming.length]);

  const bubbles = useMemo<Bubble[]>(() => {
    const all: Bubble[] = [
      ...incoming.map((n) => ({
        key: `in-${n.id}`,
        mine: false,
        text: (n.value || "").trim(),
        sub: n.text?.trim() || undefined,
        at: n.notifyDate || "",
      })),
      ...sent.map((m) => ({ key: `out-${m.id}`, mine: true, text: m.text, at: m.at })),
    ];
    all.sort((a, b) => a.at.localeCompare(b.at));
    return all;
  }, [incoming, sent]);

  useEffect(() => {
    const id = setTimeout(() => listRef.current?.scrollToEnd({ animated: true }), 80);
    return () => clearTimeout(id);
  }, [bubbles.length]);

  async function send() {
    const text = draft.trim();
    if (!text || sending || !user?.id) return;
    setSending(true);
    setSendError(null);
    try {
      if (isHelpdesk) {
        await api.send2ClubHelpDesk({ text: "Chat", value: text, notificationType: "HelpDesk" });
      } else {
        await api.reply2Notification({ groupId: threadKey, value: text });
      }
      const msg = await appendSent(user.id, threadKey, text);
      setSent((prev) => [...prev, msg]);
      setDraft("");
    } catch (e: any) {
      setSendError(e?.message || "Could not send. Try again.");
    } finally {
      setSending(false);
    }
  }

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => safeBack(router)} testID="thread-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <View style={styles.titleWrap}>
            <Text style={styles.title} numberOfLines={1}>{t || (isHelpdesk ? "Club Help Desk" : "Conversation")}</Text>
            <Text style={styles.titleSub} numberOfLines={1}>{user?.clubName?.trim() || "Your club"}</Text>
          </View>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => void refresh()} testID="thread-refresh">
            <Ionicons name="refresh" size={18} color={colors.textPrimary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={{ flex: 1 }}>
        <FlatList
          ref={listRef}
          data={bubbles}
          keyExtractor={(b) => b.key}
          contentContainerStyle={{ padding: spacing.xl, paddingBottom: 16, flexGrow: 1 }}
          ListEmptyComponent={
            <View style={styles.empty}>
              <Ionicons name="chatbubbles-outline" size={44} color={colors.textMuted} />
              <Text style={styles.emptyTxt}>{isHelpdesk ? "Say hello to your club" : "No messages yet"}</Text>
              <Text style={styles.emptySub}>
                {isHelpdesk
                  ? "Your message goes straight to the club admin."
                  : "Reply below — the club admin will see it."}
              </Text>
            </View>
          }
          renderItem={({ item: b }) => (
            <View style={[styles.bubbleRow, b.mine ? { justifyContent: "flex-end" } : { justifyContent: "flex-start" }]}>
              <View style={[styles.bubble, b.mine ? styles.bubbleMine : styles.bubbleTheirs]}>
                {!b.mine && !!b.sub && <Text style={styles.bubbleTag}>{b.sub}</Text>}
                <Text style={[styles.bubbleTxt, b.mine && { color: "#fff" }]}>{b.text}</Text>
                <Text style={[styles.bubbleWhen, b.mine && { color: "rgba(255,255,255,0.75)" }]}>{fmtTime(b.at)}</Text>
              </View>
            </View>
          )}
        />

        {!!sendError && <Text style={styles.sendErr}>{sendError}</Text>}
        <View style={[styles.composer, { paddingBottom: Math.max(insets.bottom, 10) }]}>
          <TextInput
            style={styles.input}
            placeholder="Type a message…"
            placeholderTextColor={colors.textMuted}
            value={draft}
            onChangeText={setDraft}
            multiline
            testID="thread-input"
          />
          <TouchableOpacity
            style={[styles.sendBtn, (!draft.trim() || sending) && { opacity: 0.5 }]}
            onPress={send}
            disabled={!draft.trim() || sending}
            testID="thread-send"
          >
            {sending ? <ActivityIndicator size="small" color="#fff" /> : <Ionicons name="send" size={18} color="#fff" />}
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10, gap: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    titleWrap: { flex: 1, alignItems: "center" },
    title: { ...font.h4, color: colors.textPrimary },
    titleSub: { fontSize: 11, color: colors.textSecondary, marginTop: 1 },

    empty: { flex: 1, alignItems: "center", justifyContent: "center", gap: 6, paddingVertical: 60 },
    emptyTxt: { ...font.h4, color: colors.textPrimary, marginTop: 8 },
    emptySub: { fontSize: 12.5, color: colors.textSecondary, textAlign: "center", paddingHorizontal: 30 },

    bubbleRow: { flexDirection: "row", marginBottom: 10 },
    bubble: { maxWidth: "82%", borderRadius: radius.lg, paddingHorizontal: 14, paddingVertical: 10, ...shadow.soft },
    bubbleTheirs: { backgroundColor: colors.surface, borderTopLeftRadius: 4, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    bubbleMine: { backgroundColor: colors.primary, borderBottomRightRadius: 4 },
    bubbleTag: { fontSize: 10, fontWeight: "800", color: colors.primary, letterSpacing: 0.4, marginBottom: 3 },
    bubbleTxt: { fontSize: 13.5, color: colors.textPrimary, lineHeight: 19 },
    bubbleWhen: { fontSize: 10, color: colors.textMuted, marginTop: 5, alignSelf: "flex-end" },

    sendErr: { color: colors.danger, fontSize: 12, paddingHorizontal: spacing.xl, paddingBottom: 4 },
    composer: { flexDirection: "row", alignItems: "flex-end", gap: 10, paddingHorizontal: spacing.lg, paddingTop: 8, backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border },
    input: { flex: 1, minHeight: 42, maxHeight: 120, borderRadius: radius.lg, backgroundColor: colors.surfaceAlt, paddingHorizontal: 14, paddingVertical: 10, color: colors.textPrimary, fontSize: 14 },
    sendBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center" },
  });
}
