import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { api, defaultRange } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { weekday: "short", day: "2-digit", month: "short", year: "numeric" });
}
function isPresent(t?: string, id?: number) {
  return id === 0 || /present/i.test(t || "");
}

export default function Attendance() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const range = useMemo(() => defaultRange(), []);
  const att = useApi(() => api.attendanceReport({ fromDate: range.fromDate, toDate: range.toDate }), []);

  const records = att.data ?? [];
  const total = records.length;
  const present = records.filter((r) => isPresent(r.attendanceType, r.attendanceTypeId)).length;
  const missed = total - present;
  const percentage = total > 0 ? Math.round((present / total) * 100) : 0;
  const absentRecords = records.filter((r) => !isPresent(r.attendanceType, r.attendanceTypeId));

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => safeBack(router)} testID="att-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Attendance</Text>
          <TouchableOpacity style={styles.backBtn} onPress={() => router.push("/qr-scan")} testID="att-qr">
            <Ionicons name="qr-code-outline" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.heroCard, shadow.strong]}>
          <View style={styles.ringWrap}>
            <View style={styles.ringOuter}>
              <View style={styles.ringInner}>
                <Text style={styles.pct}>{percentage}%</Text>
                <Text style={styles.pctLbl}>Attended</Text>
              </View>
            </View>
          </View>
          <View style={styles.heroRight}>
            <Text style={styles.heroTitle} numberOfLines={1}>{percentage >= 80 ? "Great Discipline!" : "Keep Going!"}</Text>
            <Text style={styles.heroSub} numberOfLines={2}>Keep it above 80% to qualify for events</Text>
            <View style={styles.miniStats}>
              <View style={styles.mStat}><Text style={styles.mNum}>{present}</Text><Text style={styles.mLbl}>Present</Text></View>
              <View style={styles.mStat}><Text style={styles.mNum}>{missed}</Text><Text style={styles.mLbl}>Absent</Text></View>
              <View style={styles.mStat}><Text style={styles.mNum}>{total}</Text><Text style={styles.mLbl}>Total</Text></View>
            </View>
          </View>
        </LinearGradient>

        <TouchableOpacity style={styles.qrCheckIn} onPress={() => router.push("/qr-scan")} testID="att-checkin">
          <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.qrInner, shadow.strong]}>
            <Ionicons name="qr-code" size={22} color="#fff" />
            <View style={{ flex: 1, marginLeft: 12 }}>
              <Text style={styles.qrTitle} numberOfLines={1}>Scan QR to Check In</Text>
              <Text style={styles.qrSub} numberOfLines={1}>Mark attendance for today&apos;s class</Text>
            </View>
            <Ionicons name="arrow-forward" size={18} color="#fff" />
          </LinearGradient>
        </TouchableOpacity>

        <Text style={styles.section}>Recent Attendance</Text>
        {att.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 20 }} />}
        {att.error && <Text style={styles.errTxt}>{att.error}</Text>}
        {!att.loading && total === 0 && <Text style={styles.emptyTxt}>No attendance records found.</Text>}
        {records.slice(0, 60).map((r, i) => {
          const ok = isPresent(r.attendanceType, r.attendanceTypeId);
          return (
            <View key={i} style={styles.recCard}>
              <View style={[styles.recIcon, { backgroundColor: (ok ? colors.success : colors.danger) + (mode === "dark" ? "33" : "1A") }]}>
                <Ionicons name={ok ? "checkmark-circle" : "close-circle"} size={20} color={ok ? colors.success : colors.danger} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.recTitle} numberOfLines={1}>{r.trainingCenter || r.sCenterName || "Class"}</Text>
                <Text style={styles.recMeta} numberOfLines={1}>{fmtDate(r.recordedTime)}</Text>
              </View>
              <Text style={[styles.recStatus, { color: ok ? colors.success : colors.danger }]} numberOfLines={1}>{r.attendanceType || (ok ? "Present" : "Absent")}</Text>
            </View>
          );
        })}

        {absentRecords.length > 0 && (
          <>
            <Text style={styles.section}>Missed Class History</Text>
            {absentRecords.slice(0, 20).map((m, i) => (
              <View key={i} style={styles.missedCard}>
                <View style={styles.missedIcon}><Ionicons name="close-circle" size={20} color={colors.danger} /></View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.missedTitle} numberOfLines={1}>{m.trainingCenter || m.sCenterName || "Class"}</Text>
                  <Text style={styles.missedMeta} numberOfLines={1}>{fmtDate(m.recordedTime)} · {m.attendanceType}</Text>
                </View>
              </View>
            ))}
          </>
        )}
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.xl, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },

    heroCard: { flexDirection: "row", borderRadius: radius.xxl, padding: 18, alignItems: "center" },
    ringWrap: { width: 120, height: 120, alignItems: "center", justifyContent: "center" },
    ringOuter: { width: 120, height: 120, borderRadius: 60, borderWidth: 6, borderColor: "rgba(255,255,255,0.22)", alignItems: "center", justifyContent: "center" },
    ringInner: { width: 100, height: 100, borderRadius: 50, borderTopWidth: 6, borderRightWidth: 6, borderBottomWidth: 6, borderLeftWidth: 6, borderTopColor: "#FFF7ED", borderRightColor: "#FFF7ED", borderBottomColor: "rgba(255,255,255,0.4)", borderLeftColor: "rgba(255,255,255,0.4)", alignItems: "center", justifyContent: "center", transform: [{ rotate: "-45deg" }] },
    pct: { color: "#fff", fontSize: 22, fontWeight: "800", transform: [{ rotate: "45deg" }] },
    pctLbl: { color: "rgba(255,255,255,0.85)", fontSize: 9, fontWeight: "700", transform: [{ rotate: "45deg" }] },
    heroRight: { flex: 1, marginLeft: 16 },
    heroTitle: { color: "#fff", fontSize: 18, fontWeight: "800" },
    heroSub: { color: "rgba(255,255,255,0.9)", fontSize: 11, marginTop: 4 },
    miniStats: { flexDirection: "row", gap: 8, marginTop: 12 },
    mStat: { flex: 1, backgroundColor: "rgba(255,255,255,0.2)", borderRadius: radius.sm, paddingVertical: 8, alignItems: "center" },
    mNum: { color: "#fff", fontWeight: "800", fontSize: 16 },
    mLbl: { color: "rgba(255,255,255,0.9)", fontSize: 9, marginTop: 2 },

    qrCheckIn: { marginTop: 16 },
    qrInner: { flexDirection: "row", alignItems: "center", padding: 16, borderRadius: radius.xl },
    qrTitle: { color: "#fff", fontSize: 14, fontWeight: "800" },
    qrSub: { color: "rgba(255,255,255,0.9)", fontSize: 11, marginTop: 2 },

    section: { ...font.h4, color: colors.textPrimary, marginTop: 20, marginBottom: 10 },
    errTxt: { color: colors.danger, fontSize: 13, marginBottom: 10 },
    emptyTxt: { color: colors.textSecondary, fontSize: 13, marginBottom: 10 },

    recCard: { flexDirection: "row", gap: 12, alignItems: "center", backgroundColor: colors.surface, padding: 13, borderRadius: radius.md, marginBottom: 9, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    recIcon: { width: 36, height: 36, borderRadius: 18, alignItems: "center", justifyContent: "center" },
    recTitle: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
    recMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
    recStatus: { fontSize: 12, fontWeight: "700", marginLeft: spacing.sm },

    missedCard: { flexDirection: "row", gap: 12, alignItems: "center", backgroundColor: colors.surface, padding: 14, borderRadius: radius.md, marginBottom: 10, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    missedIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: mode === "dark" ? "#3F1212" : "#FEE2E2", alignItems: "center", justifyContent: "center" },
    missedTitle: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
    missedMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
  });
}
