import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, SelectField, DateField, KV, toISODate, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { ReportRow } from "../src/api/types";

const TYPES: Option[] = [
  { id: "HQ", text: "Contribution Paid to HQ" },
  { id: "BRANCH", text: "Received from Branches" },
];

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

function fmtAmount(x: any) {
  return "RM " + Number(x || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export default function ContributionReport() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const [from, setFrom] = useState<Date>(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [to, setTo] = useState<Date>(new Date());
  const [type, setType] = useState<string>("HQ");
  const [params, setParams] = useState<{ fromDate: string; toDate: string; reportType: string } | null>(null);

  const report = useApi<ReportRow[]>(
    () =>
      token && params
        ? api.contributionReport({
            fromDate: params.fromDate,
            toDate: params.toDate,
            reportType: params.reportType,
          })
        : Promise.resolve([]),
    [token, params]
  );

  const onSearch = () =>
    setParams({
      fromDate: toISODate(from),
      toDate: toISODate(to),
      reportType: type,
    });

  return (
    <View style={styles.root} testID="rep-contribution">
      <ReportScaffold<ReportRow>
        title="Contribution Report"
        loading={report.loading && !!params}
        error={report.error}
        data={params ? report.data : []}
        onSearch={onSearch}
        emptyText="No contribution records."
        filters={
          <>
            <View style={styles.dateRow}>
              <DateField label="From" value={from} onChange={setFrom} testID="rep-from" />
              <DateField label="To" value={to} onChange={setTo} testID="rep-to" />
            </View>
            <SelectField
              label="Type"
              placeholder="Select type"
              value={type}
              options={TYPES}
              onChange={(id) => setType(String(id))}
              testID="rep-type"
            />
          </>
        }
        renderItem={(item) => (
          <View style={styles.card}>
            <Text style={styles.cardTitle} numberOfLines={1}>
              {item.name || item.centerName || item.studentName || "Contribution"}
            </Text>
            {item.amount != null && <KV label="Amount" value={fmtAmount(item.amount)} strong />}
            {(item.date != null || item.invoiceDate != null) && (
              <KV label="Date" value={fmtDate(item.date || item.invoiceDate)} />
            )}
            {item.status != null && <KV label="Status" value={item.status} />}
            {(item.centerName != null || item.tcName != null) && (
              <KV label="Center" value={item.centerName || item.tcName} />
            )}
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
