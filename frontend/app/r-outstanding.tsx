import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme, radius } from "../src/theme";
import { ReportScaffold, SelectField, KV, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { Invoice } from "../src/api/types";

const money = (x: any) =>
  "RM " + Number(x || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export default function ReportOutstanding() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();
  const [type, setType] = useState<string>("");

  const typesQ = useApi<{ id: string; text: string }[]>(
    () => (token ? api.invoiceTypes() : Promise.resolve([])),
    [token]
  );
  const typeOptions: Option[] = useMemo(
    () => [{ id: "", text: "All" }, ...(typesQ.data ?? []).map((t) => ({ id: t.id, text: t.text }))],
    [typesQ.data]
  );

  const { data, loading, error } = useApi<Invoice[]>(
    () =>
      token
        ? api.outstanding({
            studentId: null,
            studentName: null,
            icNo: null,
            startDate: null,
            endDate: null,
            eCenterId: null,
            tCenterId: null,
            sCenterId: null,
            transactionType: type || null,
          })
        : Promise.resolve([]),
    [token, type]
  );

  const rows = data ?? [];
  const totalDue = rows.reduce((sum, r) => sum + Number(r.dueAmount || 0), 0);

  return (
    <ReportScaffold<Invoice>
      title="Outstanding"
      loading={loading}
      error={error}
      data={rows}
      emptyText="No outstanding invoices."
      keyExtractor={(item, i) => `${item.invoiceId}-${i}`}
      filters={
        <View style={{ gap: 10 }}>
          <SelectField
            label="Filter By Transaction Type"
            placeholder="All"
            value={type}
            options={typeOptions}
            onChange={(id) => setType(String(id))}
            loading={typesQ.loading}
            testID="rep-outstanding"
          />
          <View style={styles.summary}>
            <Text style={styles.summaryTxt}>Total Invoice(s): {rows.length}</Text>
            <Text style={styles.summaryStrong}>Due Amt: {money(totalDue)}</Text>
          </View>
        </View>
      }
      renderItem={(item) => (
        <View style={styles.card}>
          <Text style={styles.cardTitle} numberOfLines={2}>{item.studentName || "—"}</Text>
          <KV label="Type" value={item.transactionType} />
          <KV label="Period" value={item.period} />
          <KV label="Due Amt" value={money(item.dueAmount)} strong />
          <KV label="Classes Attended" value={item.attendanceCount} />
          <KV label="Status" value={item.paymentStatus} />
          <KV label="Center" value={item.centerName} />
        </View>
      )}
    />
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    summary: {
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "space-between",
      gap: 12,
    },
    summaryTxt: { fontSize: 12, color: colors.textSecondary, fontWeight: "700" },
    summaryStrong: { fontSize: 13, color: colors.primary, fontWeight: "800" },
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
