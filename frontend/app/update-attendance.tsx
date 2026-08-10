import { useMemo, useState } from "react";
import { View, Text, StyleSheet, TouchableOpacity, FlatList, ActivityIndicator } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, useTheme } from "../src/theme";
import { ScreenHeader, SelectField, DateField, toISODate, Option } from "../src/ui/reportkit";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import type { IdValueText, AttendanceRecord } from "../src/api/types";

export default function UpdateAttendance() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();

  const [type, setType] = useState<"student" | "instructor">("student");
  const [date, setDate] = useState(new Date());
  const [centerId, setCenterId] = useState<number | string>("");
  const [timeId, setTimeId] = useState<number | string>("");

  const centers = useApi<IdValueText[]>(() => (token ? api.dropdownListByType(3) : Promise.resolve([])), [token]);
  const times = useApi<IdValueText[]>(
    () => (token && centerId ? api.trainingTimeByTcId(Number(centerId)) : Promise.resolve([])),
    [token, centerId]
  );
  const roster = useApi<IdValueText[]>(
    () => {
      if (!token) return Promise.resolve([]);
      if (type === "instructor") return api.instructors();
      return centerId ? api.studentListByTcId(Number(centerId)) : Promise.resolve([]);
    },
    [token, type, centerId]
  );
  // Who's already checked in for this centre + date (used to flag the roster live).
  const attendance = useApi<AttendanceRecord[]>(
    () =>
      token && centerId
        ? api.attendanceReport({
            tCenterId: Number(centerId),
            tTimeId: timeId ? Number(timeId) : null,
            fromDate: toISODate(date),
            toDate: toISODate(date),
          })
        : Promise.resolve([]),
    [token, centerId, timeId, date]
  );

  /**
   * Who is actually checked in, keyed by student id.
   *
   * This used to key on the uppercased name, which marks the wrong people present: names are
   * not unique in a roster (training centre 3303 alone has two students called "TEST"), so one
   * student checking in flagged every namesake as present too. `AttendanceRecord.id` and the
   * roster row's `id` are both the student id, which is the only reliable join — the roster's
   * `value` is the registration code (RTT/KCP/2025/00208) while the attendance row's `icNo` is
   * the IC number, so those two don't match either.
   *
   * Rows that explicitly record an absence are excluded rather than requiring the word
   * "present": the full set of attendanceType values isn't documented, and treating an
   * unrecognised one as absent would hide genuinely present students.
   */
  const presentIds = useMemo(() => {
    const rows = Array.isArray(attendance.data) ? attendance.data : [];
    return new Set(
      rows
        .filter((a) => !/absent|leave|excused/i.test(String(a.attendanceType || "")))
        .map((a) => a.id)
        .filter((id) => id != null)
    );
  }, [attendance.data]);
  const roster_ = Array.isArray(roster.data) ? roster.data : [];
  const presentCount = roster_.filter((s) => presentIds.has(s.id)).length;

  const centerOptions: Option[] = (centers.data ?? []).map((o) => ({ id: o.id, text: o.text }));
  const timeOptions: Option[] = [{ id: "", text: "All times" }, ...(times.data ?? []).map((o) => ({ id: o.id, text: o.text }))];

  return (
    <View style={styles.root} testID="update-attendance">
      <ScreenHeader title="Update Attendance" subtitle={centerId ? `${presentCount}/${roster_.length} present` : undefined} />

      <FlatList
        data={roster_}
        keyExtractor={(item, i) => `${item.id}-${i}`}
        contentContainerStyle={{ paddingBottom: 120 }}
        showsVerticalScrollIndicator={false}
        ListHeaderComponent={
          <View>
            <View style={styles.filterCard}>
              {/* Attendance Type */}
              <View style={styles.segRow}>
                {(["student", "instructor"] as const).map((t) => (
                  <TouchableOpacity
                    key={t}
                    style={[styles.seg, type === t && styles.segOn]}
                    onPress={() => { setType(t); setCenterId(t === "instructor" ? centerId : centerId); }}
                    testID={`ua-type-${t}`}
                    activeOpacity={0.85}
                  >
                    <Text style={[styles.segTxt, type === t && styles.segTxtOn]}>{t === "student" ? "Student" : "Instructor"}</Text>
                  </TouchableOpacity>
                ))}
              </View>
              <View style={styles.row}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.fieldLbl}>ATTENDANCE DATE</Text>
                  <DateField value={date} onChange={setDate} testID="ua-date" />
                </View>
              </View>
              <SelectField
                label="Training Centre"
                placeholder="Select centre"
                value={centerId}
                options={centerOptions}
                loading={centers.loading}
                onChange={(id) => { setCenterId(id); setTimeId(""); }}
                testID="ua-centre"
              />
              {type === "student" && (
                <SelectField
                  label="Training Time"
                  placeholder={centerId ? "All times" : "Select centre first"}
                  value={timeId}
                  options={timeOptions}
                  loading={times.loading}
                  disabled={!centerId}
                  onChange={(id) => setTimeId(id)}
                  testID="ua-time"
                />
              )}
            </View>

            {/* Scan-to-mark CTA (attendance is recorded by scanning the centre QR) */}
            <TouchableOpacity style={styles.scanBtnWrap} onPress={() => router.push("/qr-scan")} activeOpacity={0.9} testID="ua-scan">
              <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.scanBtn, shadow.strong]}>
                <Ionicons name="qr-code" size={20} color="#fff" />
                <Text style={styles.scanTxt}>Scan QR to mark attendance</Text>
              </LinearGradient>
            </TouchableOpacity>

            <View style={styles.listHead}>
              <Text style={styles.listTitle}>{type === "student" ? "Students" : "Instructors"}</Text>
              {attendance.loading ? <ActivityIndicator color={colors.primary} /> : <Text style={styles.presentChip}>{presentCount} present</Text>}
            </View>
          </View>
        }
        renderItem={({ item, index }) => {
          const present = presentIds.has(item.id);
          return (
            <View style={styles.card}>
              <Text style={styles.sno}>{index + 1}</Text>
              <View style={styles.avatar}>
                <Ionicons name={type === "instructor" ? "school" : "person"} size={18} color={colors.primary} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.name} numberOfLines={1}>{item.text || "—"}</Text>
                {!!item.value && <Text style={styles.meta} numberOfLines={1}>{item.value}</Text>}
              </View>
              <View style={[styles.badge, { backgroundColor: (present ? colors.success : colors.textMuted) + "22" }]}>
                <Ionicons name={present ? "checkmark-circle" : "ellipse-outline"} size={14} color={present ? colors.success : colors.textMuted} />
                <Text style={[styles.badgeTxt, { color: present ? colors.success : colors.textMuted }]}>{present ? "Present" : "Not marked"}</Text>
              </View>
            </View>
          );
        }}
        ListEmptyComponent={
          roster.loading ? (
            <View style={styles.center}><ActivityIndicator color={colors.primary} size="large" /></View>
          ) : (
            <View style={styles.center}>
              <Ionicons name="people-outline" size={44} color={colors.textMuted} />
              <Text style={styles.emptyTxt}>{type === "student" && !centerId ? "Select a training centre to load the roster." : "No records."}</Text>
            </View>
          )
        }
      />
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    filterCard: { backgroundColor: colors.surfaceAlt, marginHorizontal: spacing.xl, marginTop: 4, borderRadius: radius.xl, padding: 14, gap: 10 },
    segRow: { flexDirection: "row", gap: 8, backgroundColor: colors.surface, borderRadius: radius.full, padding: 4 },
    seg: { flex: 1, alignItems: "center", paddingVertical: 9, borderRadius: radius.full },
    segOn: { backgroundColor: colors.primary },
    segTxt: { fontSize: 13, fontWeight: "700", color: colors.textSecondary },
    segTxtOn: { color: "#fff" },
    row: { flexDirection: "row", gap: 10 },
    fieldLbl: { fontSize: 11, fontWeight: "600", letterSpacing: 0.5, color: colors.textSecondary, marginBottom: 6, textTransform: "uppercase" },

    scanBtnWrap: { marginHorizontal: spacing.xl, marginTop: 14 },
    scanBtn: { flexDirection: "row", gap: 10, alignItems: "center", justifyContent: "center", paddingVertical: 14, borderRadius: radius.full },
    scanTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },

    listHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginHorizontal: spacing.xl, marginTop: 22, marginBottom: 10 },
    listTitle: { fontSize: 16, fontWeight: "800", color: colors.textPrimary },
    presentChip: { fontSize: 12, fontWeight: "800", color: colors.success, backgroundColor: colors.success + "22", paddingHorizontal: 10, paddingVertical: 4, borderRadius: 12, overflow: "hidden" },

    card: { flexDirection: "row", alignItems: "center", gap: 10, backgroundColor: colors.surface, borderRadius: radius.lg, padding: 12, marginHorizontal: spacing.xl, marginBottom: 8, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    sno: { width: 20, fontSize: 12, fontWeight: "700", color: colors.textMuted, textAlign: "center" },
    avatar: { width: 40, height: 40, borderRadius: 20, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    name: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },
    meta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
    badge: { flexDirection: "row", alignItems: "center", gap: 4, paddingHorizontal: 8, paddingVertical: 5, borderRadius: radius.full },
    badgeTxt: { fontSize: 11, fontWeight: "700" },

    center: { alignItems: "center", justifyContent: "center", padding: 40, gap: 10 },
    emptyTxt: { color: colors.textSecondary, fontSize: 14, textAlign: "center" },
  });
}
