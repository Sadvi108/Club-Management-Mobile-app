import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { colors, font, radius, shadow, spacing } from "../src/theme";
import { attendanceData } from "../src/mockData";

export default function Attendance() {
  const router = useRouter();
  const weeks = [0, 1, 2, 3];

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => router.back()} testID="att-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Attendance</Text>
          <TouchableOpacity style={styles.backBtn} onPress={() => router.push("/qr-scan")} testID="att-qr">
            <Ionicons name="qr-code-outline" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.heroCard}>
          <View style={styles.ringWrap}>
            <View style={styles.ringOuter}>
              <View style={styles.ringInner}>
                <Text style={styles.pct}>{attendanceData.percentage}%</Text>
                <Text style={styles.pctLbl}>Attended</Text>
              </View>
            </View>
          </View>
          <View style={styles.heroRight}>
            <Text style={styles.heroTitle}>Great Discipline!</Text>
            <Text style={styles.heroSub}>Keep it above 80% to qualify for events</Text>
            <View style={styles.miniStats}>
              <View style={styles.mStat}>
                <Text style={styles.mNum}>{attendanceData.present}</Text>
                <Text style={styles.mLbl}>Present</Text>
              </View>
              <View style={styles.mStat}>
                <Text style={styles.mNum}>{attendanceData.total - attendanceData.present}</Text>
                <Text style={styles.mLbl}>Missed</Text>
              </View>
              <View style={styles.mStat}>
                <Text style={styles.mNum}>{attendanceData.total}</Text>
                <Text style={styles.mLbl}>Total</Text>
              </View>
            </View>
          </View>
        </LinearGradient>

        <View style={styles.card}>
          <View style={styles.cardHead}>
            <Text style={styles.cardTitle}>Feb 2026</Text>
            <View style={styles.legendRow}>
              <View style={styles.legend}><View style={[styles.legendDot, { backgroundColor: colors.success }]} /><Text style={styles.legendTxt}>Present</Text></View>
              <View style={styles.legend}><View style={[styles.legendDot, { backgroundColor: colors.danger }]} /><Text style={styles.legendTxt}>Missed</Text></View>
            </View>
          </View>
          <View style={styles.calRow}>
            {["S", "M", "T", "W", "T", "F", "S"].map((d, i) => (
              <Text key={i} style={styles.calHead}>{d}</Text>
            ))}
          </View>
          {weeks.map((w) => (
            <View key={w} style={styles.calRow}>
              {attendanceData.thisMonth.slice(w * 7, w * 7 + 7).map((d) => (
                <View key={d.day} style={styles.calCell}>
                  <View style={[
                    styles.calDay,
                    d.status === "present" && { backgroundColor: colors.success },
                    d.status === "missed" && { backgroundColor: colors.danger },
                    d.status === "off" && { backgroundColor: colors.surfaceAlt },
                    d.status === "future" && { borderWidth: 1, borderColor: colors.border, backgroundColor: "transparent" },
                  ]}>
                    <Text style={[
                      styles.calNum,
                      (d.status === "present" || d.status === "missed") && { color: "#fff" },
                      d.status === "future" && { color: colors.textMuted },
                    ]}>{d.day}</Text>
                  </View>
                </View>
              ))}
            </View>
          ))}
        </View>

        <TouchableOpacity style={styles.qrCheckIn} onPress={() => router.push("/qr-scan")} testID="att-checkin">
          <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.qrInner}>
            <Ionicons name="qr-code" size={22} color="#fff" />
            <View style={{ flex: 1, marginLeft: 12 }}>
              <Text style={styles.qrTitle}>Scan QR to Check In</Text>
              <Text style={styles.qrSub}>Mark attendance for today&apos;s class</Text>
            </View>
            <Ionicons name="arrow-forward" size={18} color="#fff" />
          </LinearGradient>
        </TouchableOpacity>

        <Text style={styles.section}>Missed Class History</Text>
        {attendanceData.missed.map((m, i) => (
          <View key={i} style={styles.missedCard}>
            <View style={styles.missedIcon}>
              <Ionicons name="close-circle" size={20} color={colors.danger} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.missedTitle}>{m.class}</Text>
              <Text style={styles.missedMeta}>{m.date} · {m.reason}</Text>
            </View>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.background },
  header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
  backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
  title: { ...font.h3, color: colors.textPrimary },

  heroCard: { flexDirection: "row", borderRadius: radius.xxl, padding: 18, ...shadow.strong, alignItems: "center" },
  ringWrap: { width: 120, height: 120, alignItems: "center", justifyContent: "center" },
  ringOuter: { width: 120, height: 120, borderRadius: 60, borderWidth: 6, borderColor: "rgba(255,255,255,0.2)", alignItems: "center", justifyContent: "center" },
  ringInner: { width: 100, height: 100, borderRadius: 50, borderTopWidth: 6, borderRightWidth: 6, borderBottomWidth: 6, borderLeftWidth: 6, borderTopColor: "#FDE68A", borderRightColor: "#FDE68A", borderBottomColor: "rgba(255,255,255,0.4)", borderLeftColor: "rgba(255,255,255,0.4)", alignItems: "center", justifyContent: "center", transform: [{ rotate: "-45deg" }] },
  pct: { color: "#fff", fontSize: 22, fontWeight: "800", transform: [{ rotate: "45deg" }] },
  pctLbl: { color: "rgba(255,255,255,0.85)", fontSize: 9, fontWeight: "700", transform: [{ rotate: "45deg" }] },
  heroRight: { flex: 1, marginLeft: 16 },
  heroTitle: { color: "#fff", fontSize: 18, fontWeight: "800" },
  heroSub: { color: "rgba(255,255,255,0.85)", fontSize: 11, marginTop: 4 },
  miniStats: { flexDirection: "row", gap: 8, marginTop: 12 },
  mStat: { flex: 1, backgroundColor: "rgba(255,255,255,0.18)", borderRadius: radius.sm, paddingVertical: 8, alignItems: "center" },
  mNum: { color: "#fff", fontWeight: "800", fontSize: 16 },
  mLbl: { color: "rgba(255,255,255,0.85)", fontSize: 9, marginTop: 2 },

  card: { backgroundColor: "#fff", borderRadius: radius.xl, padding: 16, marginTop: 16, ...shadow.soft },
  cardHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 12 },
  cardTitle: { ...font.h4, color: colors.textPrimary },
  legendRow: { flexDirection: "row", gap: 10 },
  legend: { flexDirection: "row", gap: 4, alignItems: "center" },
  legendDot: { width: 8, height: 8, borderRadius: 4 },
  legendTxt: { fontSize: 10, color: colors.textSecondary, fontWeight: "600" },
  calRow: { flexDirection: "row", justifyContent: "space-around", marginVertical: 4 },
  calHead: { flex: 1, textAlign: "center", fontSize: 10, color: colors.textMuted, fontWeight: "700" },
  calCell: { flex: 1, alignItems: "center" },
  calDay: { width: 34, height: 34, borderRadius: 17, alignItems: "center", justifyContent: "center" },
  calNum: { fontSize: 12, color: colors.textPrimary, fontWeight: "700" },

  qrCheckIn: { marginTop: 16 },
  qrInner: { flexDirection: "row", alignItems: "center", padding: 16, borderRadius: radius.xl, ...shadow.strong },
  qrTitle: { color: "#fff", fontSize: 14, fontWeight: "800" },
  qrSub: { color: "rgba(255,255,255,0.85)", fontSize: 11, marginTop: 2 },

  section: { ...font.h4, color: colors.textPrimary, marginTop: 20, marginBottom: 10 },
  missedCard: { flexDirection: "row", gap: 12, alignItems: "center", backgroundColor: "#fff", padding: 14, borderRadius: radius.md, marginBottom: 10, ...shadow.soft },
  missedIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: "#FEE2E2", alignItems: "center", justifyContent: "center" },
  missedTitle: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
  missedMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
});
