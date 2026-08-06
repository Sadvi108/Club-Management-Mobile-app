import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, SelectField, DateField, KV, toISODate, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useAuth } from "../src/api/auth";
import type { ReportRow } from "../src/api/types";

const STATUS_OPTS: Option[] = [
  { id: "Reimbursed", text: "Reimbursed" },
  { id: "Pending", text: "Pending" },
];

function fmtDate(x?: string) {
  if (!x) return "";
  const d = new Date(x);
  return isNaN(d.getTime())
    ? x
    : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

function fmtAmount(x: any) {
  return "RM " + Number(x || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export default function ReportReimbursement() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();

  const [from, setFrom] = useState<Date>(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [to, setTo] = useState<Date>(new Date());
  const [status, setStatus] = useState<number | string>("Reimbursed");

  const [rows, setRows] = useState<ReportRow[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);

  const onSearch = async () => {
    if (!token) return;
    setSearching(true);
    setSearchError(null);
    try {
      const data = await api.reimbursementReport({
        fromDate: toISODate(from),
        toDate: toISODate(to),
        reportType: String(status),
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
    <View testID="rep-reimbursement" style={{ flex: 1 }}>
      <ReportScaffold<ReportRow>
        title="Reimbursement Report"
        loading={searching}
        error={searchError}
        data={rows}
        onSearch={onSearch}
        emptyText="No reimbursement records."
        filters={
          <>
            <View style={styles.dateRow}>
              <DateField label="From" value={from} onChange={setFrom} testID="rep-reim-from" />
              <DateField label="To" value={to} onChange={setTo} testID="rep-reim-to" />
            </View>
            <SelectField
              label="Status"
              placeholder="Select status"
              value={status}
              options={STATUS_OPTS}
              onChange={(id) => setStatus(id)}
              testID="rep-reim-status"
            />
          </>
        }
        renderItem={(item) => {
          const amount = item.amount;
          const date = item.date || item.invoiceDate;
          return (
            <View style={styles.card}>
              <Text style={styles.cardTitle} numberOfLines={1}>
                {item.name || item.studentName || "Reimbursement"}
              </Text>
              {amount != null && <KV label="Amount" value={fmtAmount(amount)} strong />}
              {date != null && date !== "" && <KV label="Date" value={fmtDate(date)} />}
              {item.status != null && item.status !== "" && <KV label="Status" value={item.status} />}
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
  });
}
