import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, spacing, useTheme } from "../src/theme";
import { ReportScaffold, SelectField, DateField, KV, toISODate, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { Receipt } from "../src/api/types";

const PAYMENT_MODES: Option[] = [
  { id: "", text: "All" },
  { id: "Cash", text: "Cash" },
  { id: "Online", text: "Online" },
  { id: "Bank-In", text: "Bank-In" },
];

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

function fmtAmount(x: any) {
  return "RM " + Number(x || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export default function ReceiptReport() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const [from, setFrom] = useState<Date>(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [to, setTo] = useState<Date>(new Date());
  const [paymentMode, setPaymentMode] = useState<string>("");
  const [centerId, setCenterId] = useState<number | string | null>(null);
  const [params, setParams] = useState<{ tCenterId: number | string | null; reportType: string | null; fromDate: string; toDate: string } | null>(null);

  const centers = useApi(() => (token ? api.dropdownListByType(3) : Promise.resolve([])), [token]);
  const centerOptions: Option[] = (centers.data ?? []).map((o) => ({ id: o.id, text: o.text }));

  const report = useApi<Receipt[]>(
    () =>
      token && params
        ? api.receipts({
            tCenterId: params.tCenterId == null ? null : Number(params.tCenterId),
            reportType: params.reportType,
            fromDate: params.fromDate,
            toDate: params.toDate,
          })
        : Promise.resolve([]),
    [token, params]
  );

  const onSearch = () =>
    setParams({
      tCenterId: centerId,
      reportType: paymentMode || null,
      fromDate: toISODate(from),
      toDate: toISODate(to),
    });

  return (
    <View style={styles.root} testID="rep-receipts">
      <ReportScaffold<Receipt>
        title="Receipt Report"
        loading={report.loading && !!params}
        error={report.error}
        data={params ? report.data : []}
        onSearch={onSearch}
        emptyText="No receipts found."
        filters={
          <>
            <View style={styles.dateRow}>
              <DateField label="From" value={from} onChange={setFrom} testID="rep-from" />
              <DateField label="To" value={to} onChange={setTo} testID="rep-to" />
            </View>
            <SelectField
              label="Payment Mode"
              placeholder="All"
              value={paymentMode}
              options={PAYMENT_MODES}
              onChange={(id) => setPaymentMode(String(id))}
              testID="rep-mode"
            />
            <SelectField
              label="Training Center"
              placeholder="Select center"
              value={centerId}
              options={centerOptions}
              onChange={(id) => setCenterId(id)}
              loading={centers.loading}
              testID="rep-center"
            />
          </>
        }
        renderItem={(item) => (
          <View style={styles.card}>
            <Text style={styles.cardTitle} numberOfLines={1}>{item.name}</Text>
            <KV label="IC No" value={item.icNo} />
            <KV label="Receipt No" value={item.receiptNo} />
            <KV label="Date" value={fmtDate(item.receiptDate)} />
            <KV label="Amount" value={fmtAmount(item.receiptAmount)} strong />
            <KV label="Method" value={item.paymentMethod} />
            <KV label="Center" value={item.tcName} />
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
