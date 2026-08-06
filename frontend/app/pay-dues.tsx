import { useMemo, useState } from "react";
import { View, Text, StyleSheet, TouchableOpacity, FlatList, ActivityIndicator } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import * as WebBrowser from "expo-web-browser";
import { radius, spacing, useTheme } from "../src/theme";
import { ScreenHeader, SelectField, KV, type Option } from "../src/ui/reportkit";
import { notify } from "../src/ui/dialogs";
import { api } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { Invoice } from "../src/api/types";

const money = (x: any) =>
  "RM " + Number(x || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export default function PayDues() {
  const { token } = useAuth();
  const { colors, shadow, mode } = useTheme();
  const insets = useSafeAreaInsets();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const [type, setType] = useState<string>("");
  const [pendingOnly, setPendingOnly] = useState(true);
  const [selected, setSelected] = useState<number[]>([]);
  const [paying, setPaying] = useState(false);

  const types = useApi(() => (token ? api.invoiceTypes() : Promise.resolve([])), [token]);
  const typeOptions: Option[] = useMemo(
    () => [{ id: "", text: "All" }, ...(types.data ?? []).map((t) => ({ id: t.id, text: t.text }))],
    [types.data]
  );

  const inv = useApi(
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

  const rows = inv.data ?? [];
  const filtered = useMemo(
    () => (pendingOnly ? rows.filter((r) => r.paymentStatus === "Pending") : rows),
    [rows, pendingOnly]
  );

  const dueTotal = useMemo(() => filtered.reduce((s, r) => s + Number(r.dueAmount || 0), 0), [filtered]);
  const selectedDue = useMemo(
    () => filtered.filter((r) => selected.includes(r.invoiceId)).reduce((s, r) => s + Number(r.dueAmount || 0), 0),
    [filtered, selected]
  );

  const toggle = (id: number) =>
    setSelected((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));

  const payNow = async () => {
    if (selected.length === 0) {
      notify("Select invoices", "Choose at least one invoice to pay.");
      return;
    }
    setPaying(true);
    try {
      // Boost gateway (/Bcpg/PayInvoices) where the server has it, legacy gateway otherwise.
      const res = await api.startPayment({ invoiceIds: selected });
      await WebBrowser.openBrowserAsync(res.url);
      // The browser never reports the result — verify by reference, then reconcile the list.
      const verdict = await api.confirmPayment({ referenceId: res.referenceId, invoiceIds: selected });
      inv.reload();
      setSelected([]);
      notify(verdict.outcome === "paid" ? "Payment received" : "Payment", verdict.message);
    } catch (e: any) {
      notify("Payment failed", e?.message);
    } finally {
      setPaying(false);
    }
  };

  const renderItem = ({ item }: { item: Invoice }) => {
    const on = selected.includes(item.invoiceId);
    return (
      <TouchableOpacity style={styles.card} activeOpacity={0.85} onPress={() => toggle(item.invoiceId)}>
        <View style={styles.checkCol}>
          <Ionicons name={on ? "checkbox" : "square-outline"} size={22} color={colors.primary} />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={styles.cardTitle} numberOfLines={1}>{item.studentName || "—"}</Text>
          <KV label="Type" value={item.transactionType} />
          <KV label="Period" value={item.period} />
          <KV label="Due Amt" value={money(item.dueAmount)} strong />
          <KV label="Status" value={item.paymentStatus} />
          {item.invoiceDescription ? (
            <Text style={styles.desc} numberOfLines={2}>{item.invoiceDescription}</Text>
          ) : null}
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.root} testID="pay-dues">
      <ScreenHeader title="Pay Your Dues" />

      <View style={styles.filterCard}>
        <SelectField
          label="Filter By Transaction Type"
          placeholder="All"
          value={type}
          options={typeOptions}
          onChange={(id) => { setType(String(id)); setSelected([]); }}
          loading={types.loading}
        />

        <TouchableOpacity
          style={styles.toggleRow}
          activeOpacity={0.7}
          onPress={() => setPendingOnly((v) => !v)}
          testID="paydues-pending-toggle"
        >
          <Ionicons name={pendingOnly ? "checkbox" : "checkbox-outline"} size={20} color={colors.primary} />
          <Text style={styles.toggleTxt}>Show only Pending</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.summaryCard}>
        <KV label="Total Invoice(s)" value={String(filtered.length)} />
        <KV label="Due Amt" value={money(dueTotal)} strong />
      </View>

      {inv.error ? (
        <View style={styles.center}>
          <Ionicons name="alert-circle-outline" size={40} color={colors.danger} />
          <Text style={styles.errTxt}>{inv.error}</Text>
        </View>
      ) : inv.loading ? (
        <View style={styles.center}><ActivityIndicator color={colors.primary} size="large" /></View>
      ) : filtered.length === 0 ? (
        <View style={styles.center}>
          <Ionicons name="file-tray-outline" size={44} color={colors.textMuted} />
          <Text style={styles.emptyTxt}>No outstanding invoices</Text>
        </View>
      ) : (
        <FlatList
          data={filtered}
          keyExtractor={(it) => String(it.invoiceId)}
          renderItem={renderItem}
          contentContainerStyle={{ padding: spacing.xl, paddingBottom: 160 }}
          showsVerticalScrollIndicator={false}
          ItemSeparatorComponent={() => <View style={{ height: 10 }} />}
          initialNumToRender={12}
          removeClippedSubviews
        />
      )}

      <View style={[styles.payBar, { paddingBottom: Math.max(insets.bottom + 12, 28) }]}>
        <TouchableOpacity activeOpacity={0.9} onPress={payNow} disabled={paying} testID="paydues-pay">
          <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.payBtn, shadow.strong]}>
            {paying ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <>
                <Ionicons name="lock-closed" size={14} color="#fff" />
                <Text style={styles.payTxt} numberOfLines={1}>
                  Pay Now ({selected.length} selected) · {money(selectedDue)}
                </Text>
              </>
            )}
          </LinearGradient>
        </TouchableOpacity>
      </View>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    filterCard: {
      backgroundColor: colors.surfaceAlt, marginHorizontal: spacing.xl, marginTop: 4, marginBottom: 6,
      borderRadius: radius.xl, padding: 14, gap: 10,
    },
    toggleRow: { flexDirection: "row", alignItems: "center", gap: 10, paddingVertical: 4 },
    toggleTxt: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },
    summaryCard: {
      backgroundColor: colors.surface, marginHorizontal: spacing.xl, marginBottom: 6,
      borderRadius: radius.lg, padding: 14, ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border,
    },
    card: {
      flexDirection: "row", gap: spacing.md, alignItems: "flex-start",
      backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border,
    },
    checkCol: { paddingTop: 1 },
    cardTitle: { fontSize: 15, fontWeight: "800", color: colors.textPrimary },
    desc: { fontSize: 12, color: colors.textSecondary, marginTop: 6 },
    center: { flex: 1, alignItems: "center", justifyContent: "center", padding: 40, gap: 10 },
    emptyTxt: { color: colors.textSecondary, fontSize: 14, textAlign: "center" },
    errTxt: { color: colors.danger, fontSize: 14, textAlign: "center" },
    payBar: {
      position: "absolute", left: 0, right: 0, bottom: 0,
      padding: spacing.xl, paddingBottom: 28,
      borderTopWidth: 1, borderColor: colors.border, backgroundColor: colors.background,
    },
    payBtn: {
      flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8,
      borderRadius: radius.full, paddingVertical: 15, minHeight: 50, paddingHorizontal: 16,
    },
    payTxt: { color: "#fff", fontWeight: "800", fontSize: 15, flexShrink: 1 },
  });
}
