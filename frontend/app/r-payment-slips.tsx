import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, SelectField, KV, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { IdValueText, ReportRow } from "../src/api/types";

type PaymentSlipRow = {
  id: number;
  tcName: string;
  receiptNo: string;
  receiptDate: string;
  receiptAmount: number;
  status: string;
  attachment: string;
  icNo: string;
  name: string;
};

const STATUS_OPTIONS: Option[] = [
  { id: "Pending", text: "Pending" },
  { id: "Approved", text: "Approved" },
  { id: "Rejected", text: "Rejected" },
];

const fmtDate = (x?: string) => {
  if (!x) return "";
  const d = new Date(x);
  return isNaN(d.getTime())
    ? x
    : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
};

const fmtAmount = (x: any) =>
  "RM " + Number(x || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export default function RPaymentSlips() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const [centerId, setCenterId] = useState<number | string | null>(null);
  const [status, setStatus] = useState<number | string>("Pending");

  const [rows, setRows] = useState<PaymentSlipRow[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const centers = useApi<IdValueText[]>(
    () => (token ? api.dropdownListByType(3) : Promise.resolve([])),
    [token]
  );
  const centerOptions: Option[] = (centers.data ?? []).map((o) => ({ id: o.id, text: o.text }));

  const onSearch = () => {
    if (!token) return;
    setLoading(true);
    setError(null);
    api
      .paymentSlips({
        tCenterId: centerId != null ? Number(centerId) : null,
        reportType: String(status),
        fromDate: null,
        toDate: null,
      })
      .then((d: ReportRow[]) => setRows((d ?? []) as PaymentSlipRow[]))
      .catch((e) => {
        setError(e?.message || "Failed to load");
        setRows([]);
      })
      .finally(() => setLoading(false));
  };

  const filters = (
    <View style={styles.filterRow}>
      <SelectField
        label="Training Center"
        placeholder="Select"
        value={centerId}
        options={centerOptions}
        onChange={(id) => setCenterId(id)}
        loading={centers.loading}
        compact
        testID="rps-center"
      />
      <SelectField
        label="Status"
        placeholder="Select"
        value={status}
        options={STATUS_OPTIONS}
        onChange={(id) => setStatus(id)}
        compact
        testID="rps-status"
      />
    </View>
  );

  return (
    <View style={styles.root} testID="rep-payment-slips">
      <ReportScaffold<PaymentSlipRow>
        title="Payment Slips"
        filters={filters}
        onSearch={onSearch}
        loading={loading}
        error={error}
        data={rows}
        emptyText="No payment slips."
        renderItem={(item) => (
          <View style={styles.card}>
            <Text style={styles.cardTitle} numberOfLines={2}>{item.name}</Text>
            <KV label="IC No" value={item.icNo} />
            <KV label="Receipt No" value={item.receiptNo} />
            <KV label="Date" value={fmtDate(item.receiptDate)} />
            <KV label="Amount" value={fmtAmount(item.receiptAmount)} strong />
            <KV label="Status" value={item.status} />
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
    filterRow: { flexDirection: "row", gap: 10 },
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
