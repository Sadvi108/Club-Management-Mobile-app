import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api, defaultRange } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";

const BELTS = [
  { name: "White", color: "#E5E7EB" },
  { name: "Yellow", color: "#FDE68A" },
  { name: "Orange", color: "#FED7AA" },
  { name: "Green", color: "#86EFAC" },
  { name: "Blue", color: "#93C5FD" },
  { name: "Purple", color: "#C4B5FD" },
  { name: "Brown", color: "#D6D3D1" },
  { name: "Black", color: "#1F2937" },
];

export default function Progress() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const { user } = useAuth();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const info = useApi(() => api.myInfo(), []);
  const range = useMemo(() => defaultRange(), []);
  const grading = useApi(() => api.gradingSchedule({ fromDate: range.fromDate, toDate: range.toDate }), []);
  const att = useApi(() => api.attendanceReport({ fromDate: range.fromDate, toDate: range.toDate }), []);

  const grade = info.data?.currentGrade || user?.currentGrade || "—";
  const beltName = (grade.match(/\(([^)]+)\)/)?.[1] || "White").trim();
  const currentIdx = Math.max(0, BELTS.findIndex((b) => b.name.toLowerCase() === beltName.toLowerCase()));

  const records = att.data ?? [];
  const present = records.filter((r) => r.attendanceTypeId === 0 || /present/i.test(r.attendanceType || "")).length;
  const pct = records.length ? Math.round((present / records.length) * 100) : 0;
  const gradeRows = grading.data ?? [];

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} onPress={() => safeBack(router)} testID="progress-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Progress</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.fitCard, shadow.strong]}>
          <View style={{ flex: 1 }}>
            <Text style={styles.fitLbl}>CURRENT GRADE</Text>
            <Text style={styles.fitNum} numberOfLines={1}>{beltName}</Text>
            <Text style={styles.fitMsg} numberOfLines={2}>{grade}</Text>
          </View>
          <View style={styles.fitIconWrap}><Ionicons name="ribbon" size={48} color="rgba(255,255,255,0.9)" /></View>
        </LinearGradient>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Belt Journey</Text>
          <View style={styles.beltLine}>
            {BELTS.map((b, i) => {
              const done = i < currentIdx;
              const current = i === currentIdx;
              return (
                <View key={b.name} style={styles.beltItem}>
                  <View style={[styles.beltDot, { backgroundColor: b.color }, current && { width: 32, height: 32, borderRadius: 16, borderWidth: 2, borderColor: colors.primary, backgroundColor: colors.primary }]}>
                    {done && <Ionicons name="checkmark" size={12} color="#0F172A" />}
                    {current && <Ionicons name="star" size={14} color="#fff" />}
                  </View>
                  {i < BELTS.length - 1 && <View style={[styles.beltConnector, done && { backgroundColor: colors.primary }]} />}
                </View>
              );
            })}
          </View>
          <View style={styles.beltLabels}>
            {BELTS.map((b, i) => (<Text key={b.name} style={[styles.beltLbl, i === currentIdx && { color: colors.primary, fontWeight: "800" }]}>{b.name[0]}</Text>))}
          </View>
          <View style={styles.beltStatus}>
            <View style={{ flex: 1 }}><Text style={styles.beltStatusLbl}>CURRENT BELT</Text><Text style={styles.beltStatusVal}>{beltName}</Text></View>
            <View style={{ flex: 1, alignItems: "flex-end" }}><Text style={styles.beltStatusLbl}>NEXT BELT</Text><Text style={styles.beltStatusVal}>{BELTS[Math.min(currentIdx + 1, BELTS.length - 1)].name}</Text></View>
          </View>
        </View>

        <Text style={styles.section}>Training Activity</Text>
        <View style={styles.card}>
          <View style={styles.actRow}>
            <View style={styles.actStat}><Text style={styles.actNum}>{present}</Text><Text style={styles.actLbl}>Present</Text></View>
            <View style={styles.actStat}><Text style={styles.actNum}>{records.length}</Text><Text style={styles.actLbl}>Total</Text></View>
            <View style={styles.actStat}><Text style={[styles.actNum, { color: colors.primary }]}>{pct}%</Text><Text style={styles.actLbl}>Rate</Text></View>
          </View>
        </View>

        <Text style={styles.section}>Grading Schedule</Text>
        {grading.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 16 }} />}
        {!grading.loading && gradeRows.length === 0 && (
          <View style={styles.commentCard}>
            <View style={styles.quoteIcon}><Ionicons name="calendar-outline" size={16} color={colors.primary} /></View>
            <Text style={styles.commentTxt}>No upcoming grading scheduled. Your academy will notify you when the next exam is set.</Text>
          </View>
        )}
        {gradeRows.map((g: any, i: number) => (
          <View key={i} style={styles.commentCard}>
            <View style={styles.quoteIcon}><Ionicons name="school" size={16} color={colors.primary} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.commentTxt} numberOfLines={2}>{g.examName || g.name || g.gradeName || g.centerName || "Grading"}</Text>
              <Text style={styles.commentMeta} numberOfLines={1}>{g.examDate || g.gradeDate || g.date || g.scheduleDate || ""}</Text>
            </View>
          </View>
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

    fitCard: { flexDirection: "row", borderRadius: radius.xxl, padding: 20 },
    fitLbl: { color: "#FDECEC", fontSize: 11, fontWeight: "800", letterSpacing: 1.2 },
    fitNum: { color: "#fff", fontSize: 38, fontWeight: "800", marginTop: 4, letterSpacing: -1 },
    fitMsg: { color: "rgba(255,255,255,0.9)", fontSize: 12 },
    fitIconWrap: { width: 80, height: 80, borderRadius: 40, backgroundColor: "rgba(255,255,255,0.18)", alignItems: "center", justifyContent: "center" },

    card: { backgroundColor: colors.surface, borderRadius: radius.xl, padding: 18, marginTop: 16, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    cardTitle: { ...font.h4, color: colors.textPrimary, marginBottom: 14 },

    beltLine: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
    beltItem: { flexDirection: "row", alignItems: "center", flex: 1 },
    beltDot: { width: 26, height: 26, borderRadius: 13, alignItems: "center", justifyContent: "center" },
    beltConnector: { flex: 1, height: 2, backgroundColor: colors.border },
    beltLabels: { flexDirection: "row", justifyContent: "space-between", marginTop: 8, paddingHorizontal: 6 },
    beltLbl: { fontSize: 10, color: colors.textSecondary, fontWeight: "600", width: 26, textAlign: "center" },
    beltStatus: { flexDirection: "row", marginTop: 16, paddingTop: 14, borderTopWidth: 1, borderTopColor: colors.borderLight },
    beltStatusLbl: { fontSize: 10, color: colors.textSecondary, fontWeight: "700", letterSpacing: 0.5 },
    beltStatusVal: { fontSize: 15, color: colors.textPrimary, fontWeight: "800", marginTop: 4 },

    section: { ...font.h4, color: colors.textPrimary, marginTop: 22, marginBottom: 10 },
    actRow: { flexDirection: "row" },
    actStat: { flex: 1, alignItems: "center" },
    actNum: { fontSize: 22, fontWeight: "800", color: colors.textPrimary },
    actLbl: { fontSize: 11, color: colors.textSecondary, marginTop: 2, fontWeight: "600" },

    commentCard: { flexDirection: "row", gap: 12, backgroundColor: colors.surface, padding: 14, borderRadius: radius.lg, marginBottom: 10, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border, alignItems: "center" },
    quoteIcon: { width: 32, height: 32, borderRadius: 16, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    commentTxt: { flex: 1, fontSize: 13, color: colors.textPrimary, fontWeight: "500", lineHeight: 18 },
    commentMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 6, fontWeight: "600" },
  });
}
