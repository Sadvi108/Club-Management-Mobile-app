import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../../src/theme";
import { api } from "../../src/api/endpoints";
import { useApi } from "../../src/api/useApi";

const SESSION_COLORS = ["#4F46E5", "#F59E0B", "#10B981", "#EF4444", "#9333EA", "#0EA5E9", "#DB2777"];

export default function Schedule() {
  const { colors, shadow, mode } = useTheme();
  const router = useRouter();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const info = useApi(() => api.myInfo(), []);
  const next = useApi(() => api.nextBookings(), []);

  // Parse the free-text training-time string into individual session lines.
  const sessions = useMemo(() => {
    const raw = info.data?.trainingTme || "";
    return raw
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter(Boolean);
  }, [info.data?.trainingTme]);

  const bookings = next.data ?? [];

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <View>
            <Text style={styles.title}>Schedule</Text>
            <Text style={styles.sub}>{info.data?.tCenterName || "Your training times"}</Text>
          </View>
          <TouchableOpacity style={styles.iconBtn} testID="schedule-reschedule-btn" onPress={() => info.reload()}>
            <Ionicons name="refresh" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ paddingHorizontal: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        <Text style={styles.section}>My Training Times</Text>

        {info.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />}

        {!info.loading && sessions.length === 0 && (
          <View style={styles.emptyCard}>
            <Ionicons name="bed-outline" size={40} color={colors.textMuted} />
            <Text style={styles.emptyTxt}>No training time set</Text>
            <Text style={styles.emptySub}>Contact your academy to schedule</Text>
          </View>
        )}

        {sessions.map((s, i) => (
          <View key={i} style={styles.sessionCard}>
            <View style={styles.timeCol}>
              <Ionicons name="time-outline" size={20} color={colors.primary} />
            </View>
            <View style={[styles.verticalBar, { backgroundColor: SESSION_COLORS[i % SESSION_COLORS.length] }]} />
            <View style={{ flex: 1 }}>
              <Text style={styles.sessionTitle}>{s}</Text>
              <View style={styles.metaRow}>
                <Ionicons name="location-outline" size={12} color={colors.textSecondary} />
                <Text style={styles.metaTxt}>{info.data?.tCenterName}</Text>
                <Ionicons name="person-outline" size={12} color={colors.textSecondary} style={{ marginLeft: 6 }} />
                <Text style={styles.metaTxt}>{info.data?.instructorName}</Text>
              </View>
            </View>
          </View>
        ))}

        <Text style={styles.section}>Upcoming Bookings</Text>
        {next.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 16 }} />}
        {!next.loading && bookings.length === 0 && (
          <View style={styles.emptyCardSmall}>
            <Ionicons name="calendar-outline" size={28} color={colors.textMuted} />
            <Text style={styles.emptySub}>No upcoming class bookings</Text>
          </View>
        )}
        {bookings.map((b: any, i: number) => (
          <View key={i} style={styles.sessionCard}>
            <View style={styles.timeCol}><Ionicons name="calendar" size={18} color={colors.primary} /></View>
            <View style={[styles.verticalBar, { backgroundColor: colors.primary }]} />
            <View style={{ flex: 1 }}>
              <Text style={styles.sessionTitle}>{b.title || b.className || b.name || "Class Booking"}</Text>
              <Text style={styles.metaTxt}>{b.date || b.bookingDate || b.trainingDate || ""}</Text>
            </View>
          </View>
        ))}

        <View style={styles.holidayCard}>
          <View style={styles.holidayIcon}><Ionicons name="information-circle" size={20} color={colors.warning} /></View>
          <View style={{ flex: 1 }}>
            <Text style={styles.holidayTitle}>Grade</Text>
            <Text style={styles.holidayItem}>{info.data?.currentGrade || "—"}</Text>
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

    section: { ...font.h4, color: colors.textSecondary, marginTop: 16, marginBottom: 14 },
    emptyCard: { alignItems: "center", paddingVertical: 50 },
    emptyCardSmall: { alignItems: "center", paddingVertical: 24, gap: 6 },
    emptyTxt: { ...font.h3, color: colors.textPrimary, marginTop: 12 },
    emptySub: { fontSize: 12, color: colors.textSecondary, marginTop: 4 },

    sessionCard: { flexDirection: "row", backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, marginBottom: 12, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border, alignItems: "center" },
    timeCol: { width: 40, alignItems: "center", justifyContent: "center" },
    verticalBar: { width: 4, alignSelf: "stretch", borderRadius: 2, marginHorizontal: 10 },
    sessionTitle: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },
    metaRow: { flexDirection: "row", gap: 4, alignItems: "center", marginTop: 6, flexWrap: "wrap" },
    metaTxt: { fontSize: 11, color: colors.textSecondary, fontWeight: "500" },

    holidayCard: { flexDirection: "row", gap: 12, backgroundColor: mode === "dark" ? "#2D1A0A" : "#FEF3C7", borderRadius: radius.lg, padding: 16, marginTop: 16 },
    holidayIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: mode === "dark" ? "#3F2410" : "#FDE68A", alignItems: "center", justifyContent: "center" },
    holidayTitle: { fontSize: 14, fontWeight: "800", color: mode === "dark" ? "#FDBA74" : "#92400E" },
    holidayItem: { fontSize: 12, color: mode === "dark" ? "#FED7AA" : "#92400E", marginTop: 4 },
  });
}
