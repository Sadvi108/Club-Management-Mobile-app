import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Alert, Image } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { radius, spacing, font, useTheme, LOGO_URL } from "../../src/theme";
import { api, defaultRange } from "../../src/api/endpoints";
import { useApi } from "../../src/api/useApi";

const DOW_SHORT = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
const DOW_FULL = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const SESSION_COLORS = ["#4F46E5", "#F59E0B", "#10B981", "#EF4444", "#9333EA", "#0EA5E9", "#DB2777"];

export default function Schedule() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  // 10 days starting today
  const days = useMemo(() => {
    const base = new Date();
    return [...Array(10)].map((_, i) => {
      const d = new Date(base);
      d.setDate(base.getDate() + i);
      return d;
    });
  }, []);
  const [active, setActive] = useState(0);
  const selected = days[active];
  const selectedDow = DOW_FULL[selected.getDay()];
  const monthLabel = days[0].toLocaleDateString("en-GB", { month: "short", year: "numeric" });

  const range = useMemo(() => defaultRange(), []);
  const details = useApi(() => api.studentDetails({ fromDate: range.fromDate, toDate: range.toDate }), []);
  const rows = details.data ?? [];

  // training rows matching the selected weekday
  const classes = rows.filter(
    (r: any) => String(r.dayOfWeek || "").toLowerCase() === selectedDow.toLowerCase()
  );
  // weekdays that have any training (to show a dot on the pill)
  const trainingDows = useMemo(
    () => new Set(rows.map((r: any) => String(r.dayOfWeek || "").toLowerCase())),
    [rows]
  );

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <View>
            <Text style={styles.title}>Schedule</Text>
            <Text style={styles.sub}>{monthLabel}</Text>
          </View>
          <Image source={{ uri: LOGO_URL }} style={styles.logo} />
        </View>
      </SafeAreaView>

      <View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.daysRow}>
          {days.map((d, i) => {
            const on = i === active;
            const hasTraining = trainingDows.has(DOW_FULL[d.getDay()].toLowerCase());
            return (
              <TouchableOpacity key={i} onPress={() => setActive(i)} testID={`schedule-day-${i}`} style={[styles.dayChip, on && styles.dayChipActive]} activeOpacity={0.85}>
                <Text style={[styles.dayLbl, on && styles.dayLblActive]}>{DOW_SHORT[d.getDay()]}</Text>
                <Text style={[styles.dayNum, on && styles.dayNumActive]}>{d.getDate()}</Text>
                {hasTraining && <View style={[styles.dayDot, on && { backgroundColor: "#fff" }]} />}
              </TouchableOpacity>
            );
          })}
        </ScrollView>
      </View>

      <ScrollView contentContainerStyle={{ paddingHorizontal: spacing.xl, paddingBottom: 160 }} showsVerticalScrollIndicator={false}>
        {details.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 40 }} />}

        {!details.loading && classes.length === 0 && (
          <>
            <Text style={styles.restTitle}>Rest Day</Text>
            <View style={styles.emptyCard}>
              <Ionicons name="bed-outline" size={44} color={colors.textMuted} />
              <Text style={styles.emptyTxt}>No classes scheduled</Text>
              <Text style={styles.emptySub}>Recovery is part of the journey</Text>
            </View>
          </>
        )}

        {!details.loading && classes.length > 0 && (
          <>
            <Text style={styles.section}>{classes.length} session{classes.length > 1 ? "s" : ""} · {selectedDow}</Text>
            {classes.map((c: any, i: number) => (
              <View key={i} style={styles.sessionCard}>
                <View style={styles.timeCol}>
                  <Text style={styles.timeTxt}>{c.tTimeFrom || "—"}</Text>
                  <Text style={styles.timeAmPm}>to {c.tTimeTo || "—"}</Text>
                </View>
                <View style={[styles.verticalBar, { backgroundColor: SESSION_COLORS[i % SESSION_COLORS.length] }]} />
                <View style={{ flex: 1 }}>
                  <Text style={styles.sessionTitle}>{c.tCenterName || "Training"}</Text>
                  <View style={styles.metaRow}>
                    <Ionicons name="person-outline" size={12} color={colors.textSecondary} />
                    <Text style={styles.metaTxt}>{c.instructorName || "Instructor"}</Text>
                    {!!c.currentGrade && (
                      <>
                        <Ionicons name="ribbon-outline" size={12} color={colors.textSecondary} style={{ marginLeft: 6 }} />
                        <Text style={styles.metaTxt}>{c.currentGrade}</Text>
                      </>
                    )}
                  </View>
                </View>
              </View>
            ))}
          </>
        )}
      </ScrollView>

      <TouchableOpacity style={styles.bookBtn} testID="schedule-book" onPress={() => Alert.alert("Book a class", "Class booking is coming soon.")} activeOpacity={0.9}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.bookInner, shadow.strong]}>
          <Ionicons name="add" size={20} color="#fff" />
          <Text style={styles.bookTxt}>Book a class</Text>
        </LinearGradient>
      </TouchableOpacity>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingHorizontal: spacing.xl, paddingVertical: 14 },
    title: { ...font.h1, color: colors.textPrimary, fontSize: 26 },
    sub: { color: colors.textSecondary, fontSize: 13, marginTop: 2 },
    logo: { width: 40, height: 40, borderRadius: 12 },

    daysRow: { paddingHorizontal: spacing.xl, gap: 10, paddingVertical: 12 },
    dayChip: { width: 62, paddingVertical: 12, backgroundColor: colors.surface, borderRadius: radius.lg, alignItems: "center", ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    dayChipActive: { backgroundColor: colors.primary, borderColor: colors.primary },
    dayLbl: { fontSize: 11, fontWeight: "700", color: colors.textSecondary, letterSpacing: 1 },
    dayLblActive: { color: "rgba(255,255,255,0.85)" },
    dayNum: { fontSize: 20, fontWeight: "800", color: colors.textPrimary, marginTop: 4 },
    dayNumActive: { color: "#fff" },
    dayDot: { width: 5, height: 5, borderRadius: 3, backgroundColor: colors.primary, marginTop: 6 },

    section: { ...font.h4, color: colors.textSecondary, marginTop: 8, marginBottom: 14 },
    restTitle: { ...font.h2, color: colors.textPrimary, marginTop: 8 },
    emptyCard: { alignItems: "center", paddingVertical: 70 },
    emptyTxt: { ...font.h2, color: colors.textPrimary, marginTop: 16, fontSize: 22 },
    emptySub: { fontSize: 14, color: colors.textSecondary, marginTop: 6 },

    sessionCard: { flexDirection: "row", backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, marginBottom: 12, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border, alignItems: "center" },
    timeCol: { width: 64, alignItems: "center", justifyContent: "center" },
    timeTxt: { fontSize: 15, fontWeight: "800", color: colors.textPrimary },
    timeAmPm: { fontSize: 10, color: colors.textSecondary, fontWeight: "700", marginTop: 2 },
    verticalBar: { width: 4, alignSelf: "stretch", borderRadius: 2, marginHorizontal: 12 },
    sessionTitle: { fontSize: 15, fontWeight: "700", color: colors.textPrimary },
    metaRow: { flexDirection: "row", gap: 4, alignItems: "center", marginTop: 6, flexWrap: "wrap" },
    metaTxt: { fontSize: 11, color: colors.textSecondary, fontWeight: "500" },

    bookBtn: { position: "absolute", right: spacing.xl, bottom: 90 },
    bookInner: { flexDirection: "row", gap: 8, alignItems: "center", paddingHorizontal: 22, paddingVertical: 15, borderRadius: radius.full },
    bookTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },
  });
}
