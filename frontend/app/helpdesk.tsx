import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, TextInput, ActivityIndicator, KeyboardAvoidingView, Platform } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { notify, safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";

export default function HelpDesk() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user } = useAuth();
  const [subject, setSubject] = useState("");
  const [message, setMessage] = useState("");
  const [sending, setSending] = useState(false);

  const submit = async () => {
    if (!message.trim()) {
      notify("Help Desk", "Please type your message.");
      return;
    }
    setSending(true);
    try {
      await api.send2ClubHelpDesk({ text: subject.trim() || "Help Desk", value: message.trim(), notificationType: "HelpDesk" });
      setSending(false);
      await notify("Sent", "Your message has been sent to the club help desk.");
      safeBack(router);
    } catch (e: any) {
      setSending(false);
      notify("Failed", e?.message || "Could not send your message. Try again.");
    }
  };

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => safeBack(router)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} testID="hd-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Help Desk</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>
      <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : undefined} style={{ flex: 1 }}>
        <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
          <View style={styles.banner}>
            <View style={styles.bannerIcon}><Ionicons name="headset" size={24} color={colors.primary} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.bannerTitle} numberOfLines={1}>{user?.clubName || "Club"} Help Desk</Text>
              <Text style={styles.bannerSub} numberOfLines={2}>Send a message and the club will get back to you.</Text>
            </View>
          </View>

          <Text style={styles.label}>Subject</Text>
          <TextInput
            style={styles.input}
            placeholder="e.g. Payment query"
            placeholderTextColor={colors.textMuted}
            value={subject}
            onChangeText={setSubject}
            testID="hd-subject"
          />

          <Text style={styles.label}>Message</Text>
          <TextInput
            style={[styles.input, styles.textarea]}
            placeholder="Type your message…"
            placeholderTextColor={colors.textMuted}
            value={message}
            onChangeText={setMessage}
            multiline
            testID="hd-message"
          />

          <TouchableOpacity onPress={submit} activeOpacity={0.9} disabled={sending} testID="hd-send">
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.sendBtn, shadow.strong]}>
              {sending ? <ActivityIndicator color="#fff" /> : (
                <>
                  <Ionicons name="send" size={16} color="#fff" />
                  <Text style={styles.sendTxt}>Send Message</Text>
                </>
              )}
            </LinearGradient>
          </TouchableOpacity>
        </ScrollView>
      </KeyboardAvoidingView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.xl, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },
    banner: { flexDirection: "row", gap: 14, alignItems: "center", backgroundColor: colors.surface, borderRadius: radius.xl, padding: 16, marginBottom: 20, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    bannerIcon: { width: 50, height: 50, borderRadius: 25, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    bannerTitle: { fontSize: 15, fontWeight: "800", color: colors.textPrimary },
    bannerSub: { fontSize: 12, color: colors.textSecondary, marginTop: 3 },
    label: { fontSize: 13, fontWeight: "700", color: colors.textSecondary, marginBottom: 8, marginTop: 6 },
    input: { backgroundColor: colors.surface, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 14, paddingVertical: 12, fontSize: 15, color: colors.textPrimary, marginBottom: 16 },
    textarea: { height: 130, textAlignVertical: "top" },
    sendBtn: { flexDirection: "row", gap: 8, paddingVertical: 16, borderRadius: radius.md, alignItems: "center", justifyContent: "center", marginTop: 6, minHeight: 52 },
    sendTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },
  });
}
