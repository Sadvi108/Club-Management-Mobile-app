import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, SelectField, DateField, KV, toISODate, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { AttendanceRecord } from "../src/api/types";

const NO_OPTS: Option[] = [];

function fmtDateTime(x?: string) {
  if (!x) return "";
  const d = new Date(x);
  if (isNaN(d.getTime())) return x;
  const date = d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
  const time = d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
  return `${date} ${time}`;
}

export default function ReportAttendance() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();

  const [centerId, setCenterId] = useState<number | string | null>(null);
  const [timeId, setTimeId] = useState<number | string | null>(null);
  const [studentId, setStudentId] = useState<number | string | null>(null);
  const [from, setFrom] = useState<Date>(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [to, setTo] = useState<Date>(new Date());

  const [rows, setRows] = useState<AttendanceRecord[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);

  const centers = useApi(
    () => (token ? api.dropdownListByType(3) : Promise.resolve([])),
    [token]
  );
  const times = useApi(
    () => (token && centerId != null ? api.trainingTimeByTcId(Number(centerId)) : Promise.resolve([])),
    [token, centerId]
  );
  const students = useApi(
    () => (token && centerId != null ? api.studentListByTcId(Number(centerId)) : Promise.resolve([])),
    [token, centerId]
  );

  const centerOpts: Option[] = (centers.data ?? []).map((o) => ({ id: o.id, text: o.text }));
  const timeOpts: Option[] = (times.data ?? []).map((o) => ({ id: o.id, text: o.text }));
  const studentOpts: Option[] = (students.data ?? []).map((o) => ({ id: o.id, text: o.text }));

  const onCenter = (id: number | string) => {
    setCenterId(id);
    setTimeId(null);
    setStudentId(null);
  };

  const onSearch = async () => {
    if (!token) return;
    setSearching(true);
    setSearchError(null);
    try {
      const data = await api.attendanceReport({
        tCenterId: centerId == null ? null : Number(centerId),
        tTimeId: timeId == null ? null : Number(timeId),
        sourceKeyId: studentId == null ? null : Number(studentId),
        fromDate: toISODate(from),
        toDate: toISODate(to),
      });
      setRows(data ?? []);
    } catch (e: any) {
      setSearchError(e?.message || "Failed to load");
      setRows([]);
    } finally {
      setSearching(false);
    }
  };

  return (
    <View testID="rep-attendance" style={{ flex: 1 }}>
      <ReportScaffold<AttendanceRecord>
        title="Attendance Report"
        loading={searching}
        error={searchError}
        data={rows}
        onSearch={onSearch}
        emptyText="No attendance records."
        keyExtractor={(item, i) => `${item.id}-${i}`}
        filters={
          <>
            <SelectField
              label="Training Center"
              placeholder="Select training center"
              value={centerId}
              options={centerOpts}
              onChange={onCenter}
              loading={centers.loading}
              testID="rep-att-center"
            />
            <SelectField
              label="Training Time"
              placeholder="Select training time"
              value={timeId}
              options={centerId == null ? NO_OPTS : timeOpts}
              onChange={(id) => setTimeId(id)}
              loading={times.loading}
              disabled={centerId == null}
              testID="rep-att-time"
            />
            <View style={styles.dateRow}>
              <DateField label="From" value={from} onChange={setFrom} testID="rep-att-from" />
              <DateField label="To" value={to} onChange={setTo} testID="rep-att-to" />
            </View>
            <SelectField
              label="Student"
              placeholder="All students"
              value={studentId}
              options={centerId == null ? NO_OPTS : studentOpts}
              onChange={(id) => setStudentId(id)}
              loading={students.loading}
              disabled={centerId == null}
              testID="rep-att-student"
            />
          </>
        }
        renderItem={(item) => {
          const present = item.attendanceType === "Present";
          return (
            <View style={styles.card}>
              <Text style={styles.cardTitle} numberOfLines={1}>{item.name || "—"}</Text>
              <KV label="IC No" value={item.icNo} />
              <View style={styles.typeRow}>
                <Text style={styles.typeLabel}>Type</Text>
                <Text style={[styles.typeValue, { color: present ? colors.success : colors.danger }]} numberOfLines={1}>
                  {item.attendanceType || "—"}
                </Text>
              </View>
              <KV label="Date/Time" value={fmtDateTime(item.recordedTime)} />
              <KV label="Center" value={item.trainingCenter} />
            </View>
          );
        }}
      />
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    dateRow: { flexDirection: "row", gap: 10 },
    card: {
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      padding: 14,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    cardTitle: { fontSize: 15, fontWeight: "800", color: colors.textPrimary },
    typeRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 4, gap: 12 },
    typeLabel: { fontSize: 12, color: colors.textSecondary, fontWeight: "600" },
    typeValue: { fontSize: 13, fontWeight: "800", flexShrink: 1, textAlign: "right" },
  });
}
