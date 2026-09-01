import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, SelectField, DateField, KV, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { GradingRow } from "../src/api/types";

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

/** Day-precision timestamp of a row's date, or null when it hasn't got a usable one. */
function dayOf(iso?: string): number | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (isNaN(d.getTime())) return null;
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();

const ALL_CENTERS = "";

export default function GradingSchedule() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const [from, setFrom] = useState<Date>(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [to, setTo] = useState<Date>(new Date());
  const [examCenterId, setExamCenterId] = useState<number | string>(ALL_CENTERS);
  // Snapshot of the filters as of the last Search press — editing a field must not silently
  // re-filter the list underneath the user.
  const [applied, setApplied] = useState<{ centerText: string; from: number; to: number } | null>(null);

  const centers = useApi(() => (token ? api.dropdownListByType(2) : Promise.resolve([])), [token]);
  const centerOptions: Option[] = useMemo(
    () => [{ id: ALL_CENTERS, text: "All centers" }, ...(centers.data ?? []).map((o) => ({ id: o.id, text: o.text }))],
    [centers.data]
  );

  // The report is fetched once and narrowed here. /Reports/GradingSchedule accepts eCenterId,
  // fromDate and toDate but applies none of them — a one-week window in 2026 and the whole of
  // 2019 both return the identical 713 rows (probed live 2026-08-10) — so sending the filters
  // and trusting the response is what made this screen look broken.
  const report = useApi<GradingRow[]>(
    () => (token ? (api.gradingSchedule({ eCenterId: null, fromDate: null, toDate: null }) as Promise<GradingRow[]>) : Promise.resolve([])),
    [token]
  );

  const rows = useMemo(() => {
    if (!applied) return [];
    const all = Array.isArray(report.data) ? report.data : [];
    const wanted = applied.centerText.trim().toLowerCase();
    return all
      .filter((r) => {
        if (wanted && (r.ecName || "").trim().toLowerCase() !== wanted) return false;
        const day = dayOf(r.examDate);
        // A row with no readable exam date can't be placed in the window — keep it rather than
        // hide a real exam behind a parsing failure.
        if (day == null) return true;
        return day >= applied.from && day <= applied.to;
      })
      .sort((a, b) => (dayOf(a.examDate) ?? 0) - (dayOf(b.examDate) ?? 0));
  }, [report.data, applied]);

  const onSearch = () => {
    const opt = centerOptions.find((o) => String(o.id) === String(examCenterId));
    setApplied({
      centerText: examCenterId === ALL_CENTERS ? "" : opt?.text ?? "",
      from: startOfDay(from),
      to: startOfDay(to),
    });
  };

  return (
    <View style={styles.root} testID="rep-grading">
      <ReportScaffold<GradingRow>
        title="Grading Schedule"
        subtitle={applied ? `${rows.length} exam${rows.length === 1 ? "" : "s"} in range` : undefined}
        loading={report.loading}
        error={report.error}
        data={applied ? rows : []}
        onSearch={onSearch}
        emptyText={
          applied ? "No grading scheduled for these dates." : "Choose a date range and press Search."
        }
        keyExtractor={(item, i) => `${item.resultId ?? item.id ?? "row"}-${i}`}
        filters={
          <>
            <View style={styles.dateRow}>
              <DateField label="From" value={from} onChange={setFrom} testID="rep-from" />
              <DateField label="To" value={to} onChange={setTo} testID="rep-to" />
            </View>
            <SelectField
              label="Exam Center"
              placeholder="All centers"
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
