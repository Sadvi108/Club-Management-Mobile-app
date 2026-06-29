import { useMemo } from "react";
import { View, StyleSheet } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { radius, spacing, useTheme } from "../src/theme";
import { ReportScaffold, KV } from "../src/ui/reportkit";
import { useAuth } from "../src/api/auth";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import type { ReportRow } from "../src/api/types";

const fmtAmount = (n: any) =>
  "RM " + Number(n || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const fmtDate = (d: any) => {
  if (!d) return null;
  const t = new Date(d);
  return isNaN(+t) ? String(d) : t.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
};

export default function CollectionList() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token } = useAuth();
  const params = useLocalSearchParams<{ typeId?: string; label?: string }>();
  const typeId = Number(params.typeId ?? 1);
  const label = params.label ?? "Collections";

  const list = useApi<ReportRow[]>(
    () => (token ? api.collectionCountList(typeId) : Promise.resolve([])),
    [token, typeId]
  );

  return (
    <ReportScaffold<ReportRow>
      title={label}
      subtitle="Live collection records"
      loading={list.loading}
      error={list.error}
      data={list.data}
      emptyText="No collections recorded yet."
      keyExtractor={(r, i) => String(r.id ?? r.receiptNo ?? r.invoiceId ?? i)}
      renderItem={(r) => {
        const title = r.studentName || r.name || r.icNo || r.receiptNo || "Collection";
        return (
          <View style={styles.card}>
            <View style={styles.titleRow}>
              <View style={styles.dot} />
              <View style={{ flex: 1 }}>
                <KV label="" value={title} strong />
              </View>
            </View>
            {(r.icNo != null) && <KV label="IC No" value={r.icNo} />}
            {(r.transactionType || r.type) && <KV label="Type" value={r.transactionType || r.type} />}
            {(r.period) && <KV label="Period" value={r.period} />}
            {(r.amount != null || r.receiptAmount != null || r.paidAmount != null) && (
              <KV label="Amount" value={fmtAmount(r.amount ?? r.receiptAmount ?? r.paidAmount)} strong />
            )}
            {(r.receiptNo != null) && <KV label="Receipt No" value={r.receiptNo} />}
            {(r.receiptDate || r.date || r.paymentDate) && (
              <KV label="Date" value={fmtDate(r.receiptDate || r.date || r.paymentDate)} />
            )}
            {(r.status) && <KV label="Status" value={r.status} />}
            {(r.centerName || r.tcName) && <KV label="Center" value={r.centerName || r.tcName} />}
          </View>
        );
      }}
    />
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    card: {
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      padding: 14,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    titleRow: { flexDirection: "row", alignItems: "center", gap: 10, marginBottom: 2 },
    dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: colors.primary },
  });
}
