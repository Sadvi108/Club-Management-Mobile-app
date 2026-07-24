import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useBottomTabBarHeight } from "@react-navigation/bottom-tabs";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../../src/theme";
import { useAuth } from "../../src/api/auth";
import { api, defaultRange } from "../../src/api/endpoints";
import { useApi } from "../../src/api/useApi";

export default function Training() {
  const { colors, shadow, mode } = useTheme();
  const router = useRouter();
  const { user } = useAuth();
  const tabBarHeight = useBottomTabBarHeight();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const info = useApi(() => api.myInfo(), []);
  const range = useMemo(() => defaultRange(), []);
  const att = useApi(() => api.attendanceReport({ fromDate: range.fromDate, toDate: range.toDate }), []);

  const records = att.data ?? [];
  const present = records.filter((r) => r.attendanceTypeId === 0 || /present/i.test(r.attendanceType || "")).length;

  const grade = info.data?.currentGrade || user?.currentGrade || "—";
  const gradeNum = (() => {
    const m = grade.match(/Grade\s*(\d+)/i);
    return m ? parseInt(m[1], 10) : null;
  })();
  const beltName = (() => {
    const m = grade.match(/\(([^)]+)\)/);
    return m ? m[1] : grade;
  })();
  const progress = gradeNum != null ? Math.min(100, Math.max(8, Math.round(((10 - gradeNum) / 10) * 100))) : 50;
  const accent = colors.primary;

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <View style={styles.headerLeft}>
            <Text style={styles.title} numberOfLines={1}>My Training</Text>
            <Text style={styles.sub} numberOfLines={1}>{info.data?.tCenterName || user?.clubName || "Keep pushing!"}</Text>
          </View>
          <TouchableOpacity style={styles.filterBtn} testID="training-filter-btn" onPress={() => att.reload()}>
            <Ionicons name="refresh" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: tabBarHeight + 24 }} showsVerticalScrollIndicator={false}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.heroCard, shadow.strong]}>
          <View style={styles.heroRow}>
            <Ionicons name="trophy" size={22} color="#FFF7ED" />
            <Text style={styles.heroBadge}>SESSIONS ATTENDED</Text>
          </View>
          {att.loading ? (
            <ActivityIndicator color="#fff" style={{ alignSelf: "flex-start", marginVertical: 12 }} />
          ) : (
            <Text style={styles.heroNum}>{present} <Text style={styles.heroUnit}>classes</Text></Text>
          )}
          <Text style={styles.heroMsg}>Train consistently to advance your grade 🔥</Text>
          <View style={styles.heroStatsRow}>
            <View style={styles.heroStat}><Text style={styles.heroStatNum}>{records.length}</Text><Text style={styles.heroStatLbl}>Recorded</Text></View>
            <View style={styles.heroStat}><Text style={styles.heroStatNum}>{beltName}</Text><Text style={styles.heroStatLbl}>Belt</Text></View>
            <View style={styles.heroStat}><Text style={styles.heroStatNum}>1</Text><Text style={styles.heroStatLbl}>Program</Text></View>
          </View>
        </LinearGradient>

        <Text style={styles.section}>Enrolled Program</Text>

        {info.loading ? (
          <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />
        ) : (
          <View style={styles.programCard} testID="program-current">
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.programBanner}>
              <Ionicons name="medal" size={40} color="#FFF7ED" />
              <Text style={styles.bannerTxt} numberOfLines={1}>{user?.clubName || "Martial Arts"}</Text>
            </LinearGradient>
            <View style={styles.programBody}>
              <View style={styles.programTop}>
                <Text style={styles.programSport} numberOfLines={1}>{info.data?.tCenterName || "Training"}</Text>
                <View style={[styles.levelPill, { backgroundColor: accent + (mode === "dark" ? "33" : "18") }]}>
                  <Text style={[styles.levelTxt, { color: accent }]} numberOfLines={1}>{beltName}</Text>
                </View>
              </View>
              <View style={styles.trainerRow}>
                <Ionicons name="person-circle-outline" size={16} color={colors.textSecondary} />
                <Text style={styles.trainerTxt} numberOfLines={1}>{info.data?.instructorName || "Instructor"}</Text>
              </View>
              <View style={styles.progressHead}>
                <Text style={styles.progLbl}>Current grade: {grade}</Text>
                <Text style={[styles.progVal, { color: accent }]}>{progress}%</Text>
              </View>
              <View style={styles.progBg}><View style={[styles.progFill, { width: `${progress}%`, backgroundColor: accent }]} /></View>
              <View style={styles.actionRow}>
                <TouchableOpacity style={[styles.actionBtn, { backgroundColor: colors.primary }]} testID="program-attendance" onPress={() => router.push("/attendance")}>
                  <Ionicons name="checkmark-done" size={14} color="#fff" />
                  <Text style={styles.actionBtnPrimaryTxt}>View Attendance</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.actionBtnGhost} onPress={() => router.push("/progress")}>
                  <Ionicons name="trending-up" size={18} color={colors.textSecondary} />
                </TouchableOpacity>
              </View>
            </View>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingHorizontal: spacing.xl, paddingVertical: 14 },
    headerLeft: { flex: 1, marginRight: spacing.md },
    title: { ...font.h1, color: colors.textPrimary, fontSize: 26 },
    sub: { color: colors.textSecondary, fontSize: 12, marginTop: 2 },
    filterBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },

    heroCard: { borderRadius: radius.xl, padding: 20, marginBottom: 20 },
    heroRow: { flexDirection: "row", alignItems: "center", gap: 8 },
    heroBadge: { color: "#FFF7ED", fontSize: 11, fontWeight: "800", letterSpacing: 1.2 },
    heroNum: { color: "#fff", fontSize: 44, fontWeight: "800", marginTop: 4, letterSpacing: -1 },
    heroUnit: { fontSize: 16, fontWeight: "500", color: "rgba(255,255,255,0.8)" },
    heroMsg: { color: "rgba(255,255,255,0.9)", fontSize: 12, marginTop: 2 },
    heroStatsRow: { flexDirection: "row", marginTop: 16, gap: 12 },
    heroStat: { flex: 1, backgroundColor: "rgba(255,255,255,0.2)", borderRadius: radius.md, paddingVertical: 10, alignItems: "center" },
    heroStatNum: { color: "#fff", fontSize: 16, fontWeight: "800" },
    heroStatLbl: { color: "rgba(255,255,255,0.85)", fontSize: 10, marginTop: 2 },

    section: { ...font.h3, color: colors.textPrimary, marginBottom: 14 },
    programCard: { backgroundColor: colors.surface, borderRadius: radius.xl, overflow: "hidden", marginBottom: 16, ...shadow.card, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    programBanner: { height: 120, alignItems: "center", justifyContent: "center", gap: 8 },
    bannerTxt: { color: "#fff", fontWeight: "800", fontSize: 16 },
    programBody: { padding: 16 },
    programTop: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", gap: spacing.sm },
    programSport: { fontSize: 18, fontWeight: "800", color: colors.textPrimary, flex: 1 },
    levelPill: { paddingHorizontal: 10, paddingVertical: 5, borderRadius: 20, flexShrink: 0 },
    levelTxt: { fontSize: 11, fontWeight: "700" },
    trainerRow: { flexDirection: "row", gap: 4, alignItems: "center", marginTop: 6 },
    trainerTxt: { color: colors.textSecondary, fontSize: 13, fontWeight: "500", flex: 1 },
    progressHead: { flexDirection: "row", justifyContent: "space-between", marginTop: 14, marginBottom: 6 },
    progLbl: { color: colors.textSecondary, fontSize: 11, fontWeight: "600" },
    progVal: { fontSize: 13, fontWeight: "800" },
    progBg: { height: 8, backgroundColor: colors.surfaceAlt, borderRadius: 4, overflow: "hidden" },
    progFill: { height: "100%", borderRadius: 4 },
    actionRow: { flexDirection: "row", gap: 10, marginTop: 14 },
    actionBtn: { flex: 1, paddingVertical: 12, borderRadius: radius.md, alignItems: "center", justifyContent: "center", flexDirection: "row", gap: 6 },
    actionBtnPrimaryTxt: { color: "#fff", fontWeight: "700", fontSize: 13 },
    actionBtnGhost: { width: 44, borderRadius: radius.md, alignItems: "center", justifyContent: "center", backgroundColor: colors.surfaceAlt },
  });
}
