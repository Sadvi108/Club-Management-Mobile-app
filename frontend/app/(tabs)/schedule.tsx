import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { radius, spacing, font, useTheme } from "../../src/theme";
import { schedule, holidays } from "../../src/mockData";

export default function Schedule() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const [active, setActive] = useState(0);
  const day = schedule[active];

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <View>
            <Text style={styles.title}>Schedule</Text>
            <Text style={styles.sub}>Feb 2026 · Week 4</Text>
          </View>
          <TouchableOpacity style={styles.iconBtn} testID="schedule-reschedule-btn">
            <Ionicons name="swap-horizontal" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.daysRow}>
        {schedule.map((d, i) => {
          const activeTab = i === active;
          return (
            <TouchableOpacity key={d.day} onPress={() => setActive(i)} testID={`schedule-day-${d.day}`} style={[styles.dayChip, activeTab && styles.dayChipActive]}>
              <Text style={[styles.dayLbl, activeTab && styles.dayLblActive]}>{d.day}</Text>
              <Text style={[styles.dayNum, activeTab && styles.dayNumActive]}>{d.date}</Text>
              {d.sessions.length > 0 && <View style={[styles.dayDot, activeTab && { backgroundColor: "#fff" }]} />}
            </TouchableOpacity>
          );
        })}
      </ScrollView>

      <ScrollView contentContainerStyle={{ paddingHorizontal: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        <Text style={styles.section}>{day.sessions.length > 0 ? `${day.sessions.length} session${day.sessions.length > 1 ? "s" : ""} scheduled` : "Rest Day"}</Text>

        {day.sessions.length === 0 && (
          <View style={styles.emptyCard}>
            <Ionicons name="bed-outline" size={40} color={colors.textMuted} />
            <Text style={styles.emptyTxt}>Enjoy your rest day</Text>
            <Text style={styles.emptySub}>Recovery is part of the journey</Text>
          </View>
        )}

        {day.sessions.map((s, i) => (
          <View key={i} style={styles.sessionCard}>
            <View style={styles.timeCol}>
              <Text style={styles.timeTxt}>{s.time.split(" ")[0]}</Text>
              <Text style={styles.timeAmPm}>{s.time.split(" ")[1]}</Text>
            </View>
            <View style={[styles.verticalBar, { backgroundColor: s.color }]} />
            <View style={{ flex: 1 }}>
              <Text style={styles.sessionTitle}>{s.title}</Text>
              <View style={styles.metaRow}>
                <Ionicons name="time-outline" size={12} color={colors.textSecondary} />
                <Text style={styles.metaTxt}>{s.duration}</Text>
                <Ionicons name="person-outline" size={12} color={colors.textSecondary} style={{ marginLeft: 6 }} />
                <Text style={styles.metaTxt}>{s.trainer}</Text>
              </View>
              <View style={styles.sessionActions}>
                <TouchableOpacity style={styles.sessActBtn}><Text style={styles.sessActTxt}>Details</Text></TouchableOpacity>
                <TouchableOpacity style={[styles.sessActBtn, { backgroundColor: colors.primary }]}><Text style={[styles.sessActTxt, { color: "#fff" }]}>Remind Me</Text></TouchableOpacity>
              </View>
            </View>
          </View>
        ))}

        <View style={styles.holidayCard}>
          <View style={styles.holidayIcon}><Ionicons name="sunny" size={20} color={colors.warning} /></View>
          <View style={{ flex: 1 }}>
            <Text style={styles.holidayTitle}>Upcoming Holidays</Text>
            {holidays.map((h) => (<Text key={h.date} style={styles.holidayItem}>• {h.date} — {h.name}</Text>))}
          </View>
        </View>
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingHorizontal: spacing.xl, paddingVertical: 14 },
    title: { ...font.h1, color: colors.textPrimary, fontSize: 26 },
    sub: { color: colors.textSecondary, fontSize: 12, marginTop: 2 },
    iconBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },

    daysRow: { paddingHorizontal: spacing.xl, gap: 10, paddingVertical: 10 },
    dayChip: { width: 62, paddingVertical: 12, backgroundColor: colors.surface, borderRadius: radius.lg, alignItems: "center", ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    dayChipActive: { backgroundColor: colors.primary, borderColor: colors.primary },
    dayLbl: { fontSize: 11, fontWeight: "700", color: colors.textSecondary, letterSpacing: 1 },
    dayLblActive: { color: "rgba(255,255,255,0.85)" },
    dayNum: { fontSize: 20, fontWeight: "800", color: colors.textPrimary, marginTop: 4 },
    dayNumActive: { color: "#fff" },
    dayDot: { width: 4, height: 4, borderRadius: 2, backgroundColor: colors.primary, marginTop: 6 },

    section: { ...font.h4, color: colors.textSecondary, marginTop: 10, marginBottom: 14 },
    emptyCard: { alignItems: "center", paddingVertical: 60 },
    emptyTxt: { ...font.h3, color: colors.textPrimary, marginTop: 12 },
    emptySub: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },

    sessionCard: { flexDirection: "row", backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, marginBottom: 12, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    timeCol: { width: 60, alignItems: "center", justifyContent: "center" },
    timeTxt: { fontSize: 16, fontWeight: "800", color: colors.textPrimary },
    timeAmPm: { fontSize: 10, color: colors.textSecondary, fontWeight: "700" },
    verticalBar: { width: 4, borderRadius: 2, marginHorizontal: 10 },
    sessionTitle: { fontSize: 15, fontWeight: "700", color: colors.textPrimary },
    metaRow: { flexDirection: "row", gap: 4, alignItems: "center", marginTop: 6 },
    metaTxt: { fontSize: 11, color: colors.textSecondary, fontWeight: "500" },
    sessionActions: { flexDirection: "row", gap: 8, marginTop: 12 },
    sessActBtn: { paddingHorizontal: 12, paddingVertical: 7, borderRadius: radius.sm, backgroundColor: colors.surfaceAlt },
    sessActTxt: { fontSize: 11, fontWeight: "700", color: colors.textPrimary },

    holidayCard: { flexDirection: "row", gap: 12, backgroundColor: mode === "dark" ? "#2D1A0A" : "#FEF3C7", borderRadius: radius.lg, padding: 16, marginTop: 16 },
    holidayIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: mode === "dark" ? "#3F2410" : "#FDE68A", alignItems: "center", justifyContent: "center" },
    holidayTitle: { fontSize: 14, fontWeight: "800", color: mode === "dark" ? "#FDBA74" : "#92400E" },
    holidayItem: { fontSize: 12, color: mode === "dark" ? "#FED7AA" : "#92400E", marginTop: 4 },
  });
}
