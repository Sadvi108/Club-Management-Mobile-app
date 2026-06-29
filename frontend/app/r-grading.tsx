import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, SelectField, DateField, KV, toISODate, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { GradingRow } from "../src/api/types";

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export default function GradingSchedule() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const [from, setFrom] = useState<Date>(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [to, setTo] = useState<Date>(new Date());
  const [examCenterId, setExamCenterId] = useState<number | string | null>(null);
  const [params, setParams] = useState<{ eCenterId: number | string | null; fromDate: string; toDate: string } | null>(null);

  const centers = useApi(() => (token ? api.dropdownListByType(2) : Promise.resolve([])), [token]);
  const centerOptions: Option[] = (centers.data ?? []).map((o) => ({ id: o.id, text: o.text }));

  const report = useApi<GradingRow[]>(
    () =>
      token && params
        ? (api.gradingSchedule({
            eCenterId: params.eCenterId == null ? null : Number(params.eCenterId),
            fromDate: params.fromDate,
            toDate: params.toDate,
          }) as Promise<GradingRow[]>)
        : Promise.resolve([]),
    [token, params]
  );

  const onSearch = () =>
    setParams({
      eCenterId: examCenterId,
      fromDate: toISODate(from),
      toDate: toISODate(to),
    });

  return (
    <View style={styles.root} testID="rep-grading">
      <ReportScaffold<GradingRow>
        title="Grading Schedule"
        loading={report.loading && !!params}
        error={report.error}
        data={params ? report.data : []}
        onSearch={onSearch}
        emptyText="No grading schedule found."
        filters={
          <>
            <View style={styles.dateRow}>
              <DateField label="From" value={from} onChange={setFrom} testID="rep-from" />
              <DateField label="To" value={to} onChange={setTo} testID="rep-to" />
            </View>
            <SelectField
              label="Exam Center"
              placeholder="Select center"
              value={examCenterId}
              options={centerOptions}
              onChange={(id) => setExamCenterId(id)}
              loading={centers.loading}
              testID="rep-center"
            />
          </>
        }
        renderItem={(item) => (
          <View style={styles.card}>
            <Text style={styles.cardTitle} numberOfLines={1}>{item.ecName}</Text>
            <KV label="Exam Date" value={fmtDate(item.examDate)} />
            <KV label="Closing Date" value={fmtDate(item.closingDate)} />
            <KV label="Exam Time" value={item.examTime} />
          </View>
        )}
      />
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    dateRow: { flexDirection: "row", gap: 10 },
    card: {
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      padding: 14,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    cardTitle: { fontSize: 15, fontWeight: "800", color: colors.textPrimary, marginBottom: 2 },
  });
}
