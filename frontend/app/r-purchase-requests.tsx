import { useMemo, useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { radius, useTheme } from "../src/theme";
import { ReportScaffold, SelectField, KV, Option } from "../src/ui/reportkit";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { IdValueText, ReportRow } from "../src/api/types";

const STATUS_OPTIONS: Option[] = [
  { id: "Pending", text: "Pending" },
  { id: "Approved", text: "Approved" },
  { id: "Rejected", text: "Rejected" },
];

export default function RPurchaseRequests() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const [centerId, setCenterId] = useState<number | string | null>(null);
  const [status, setStatus] = useState<number | string>("Pending");

  const [rows, setRows] = useState<ReportRow[] | null>(null);
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
      .purchaseRequests({
        tCenterId: centerId != null ? Number(centerId) : null,
        reportType: String(status),
        fromDate: null,
        toDate: null,
      })
      .then((d: ReportRow[]) => setRows(d ?? []))
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
        testID="rpr-center"
      />
      <SelectField
        label="Status"
        placeholder="Select"
        value={status}
        options={STATUS_OPTIONS}
        onChange={(id) => setStatus(id)}
        compact
        testID="rpr-status"
      />
    </View>
  );

  return (
    <View style={styles.root} testID="rep-purchase-requests">
      <ReportScaffold<ReportRow>
        title="Purchase Requests"
        filters={filters}
        onSearch={onSearch}
        loading={loading}
        error={error}
        data={rows}
        emptyText="No purchase requests."
        renderItem={(item) => {
          const itemName = item.item || item.productName;
          const centerName = item.centerName || item.tcName;
          return (
            <View style={styles.card}>
              <Text style={styles.cardTitle} numberOfLines={2}>
                {item.studentName || item.name || item.item || "Request"}
              </Text>
              {itemName ? <KV label="Item" value={itemName} /> : null}
              {item.qty != null ? <KV label="Qty" value={item.qty} /> : null}
              {item.status ? <KV label="Status" value={item.status} /> : null}
              {centerName ? <KV label="Center" value={centerName} /> : null}
            </View>
          );
        }}
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
