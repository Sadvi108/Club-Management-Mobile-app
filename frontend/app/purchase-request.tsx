import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, ActivityIndicator } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import * as WebBrowser from "expo-web-browser";
import { radius, spacing, font, useTheme } from "../src/theme";
import { ScreenHeader } from "../src/ui/reportkit";
import { notify } from "../src/ui/dialogs";
import { api, defaultRange } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { PurchaseProduct } from "../src/api/types";

const fmtRM = (x: number) => "RM " + Number(x || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export default function PurchaseRequest() {
  const { colors, shadow, mode } = useTheme();
  const insets = useSafeAreaInsets();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { token, apiEnv } = useAuth();
  const products = useApi<PurchaseProduct[]>(() => (token ? api.purchaseProducts() : Promise.resolve([])), [token]);
  const rows = products.data ?? [];
  // A purchase is raised by paying for it: /Bcpg/PayInvoices carries the lines in
  // `purchaseItems`. There is no other create-purchase route in the mobile API, so on a
  // server without the Boost gateway this screen can only browse the catalogue.
  const canPurchase = apiEnv.hasBoostGateway;

  // productId -> quantity string
  const [qty, setQty] = useState<Record<number, string>>({});
  const setQ = (id: number, v: string) => setQty((m) => ({ ...m, [id]: v.replace(/[^0-9]/g, "") }));
  const [paying, setPaying] = useState(false);

  const proceed = async () => {
    const selected = rows
      .map((p) => ({ p, n: parseInt(qty[p.productId] || "0", 10) || 0 }))
      .filter((x) => x.n > 0);
    if (selected.length === 0) {
      notify("Nothing selected", "Enter a quantity for at least one item.");
      return;
    }
    const total = selected.reduce((sum, x) => sum + x.n * Number(x.p.price || 0), 0);
    if (!canPurchase) {
      // Almost always means the app is signed in to Production, where /Bcpg doesn't exist.
      // Name the server so it's obvious, and say exactly how to move.
      notify(
        "Purchases aren't available yet",
        `Purchases are raised by paying for them, and the payment gateway that does it is not ` +
          `deployed on ${apiEnv.label} (${apiEnv.baseUrl.replace(/^https?:\/\//, "")}) yet. ` +
          `You can browse the catalogue here; ordering turns on by itself once the gateway is live ` +
          `on this server — there is nothing to change in the app.`
      );
      return;
    }
    setPaying(true);
    try {
      // Row count before paying, so the return leg can tell whether the request was raised.
      const range = defaultRange();
      const baseline = await api
        .purchaseRequests({ fromDate: range.fromDate, toDate: range.toDate })
        .then((r) => r?.length ?? 0)
        .catch(() => null);
      const res = await api.startPayment({
        purchaseItems: selected.map((x) => api.purchaseLine(x.p, x.n)),
      });
      await WebBrowser.openBrowserAsync(res.url);
      const verdict = await api.confirmPayment({ referenceId: res.referenceId, purchaseBaseline: baseline });
      notify(
        verdict.outcome === "paid" ? "Purchase confirmed" : "Purchase",
        verdict.outcome === "paid"
          ? `${selected.length} item(s) · ${fmtRM(total)}. Your academy will process the order.`
          : verdict.message
      );
      if (verdict.outcome === "paid") setQty({});
    } catch (e: any) {
      notify("Purchase failed", e?.message || "Could not start the payment.");
    } finally {
      setPaying(false);
    }
  };

  return (
    <View style={styles.root} testID="purchase-request">
      <ScreenHeader title="New Purchase Request" />

      {products.loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={colors.primary} size="large" />
        </View>
      ) : products.error ? (
        <View style={styles.center}>
          <Ionicons name="alert-circle-outline" size={40} color={colors.danger} />
          <Text style={styles.errTxt}>{products.error}</Text>
        </View>
      ) : rows.length === 0 ? (
        <View style={styles.center}>
          <Ionicons name="cart-outline" size={44} color={colors.textMuted} />
          <Text style={styles.emptyTxt}>No products available.</Text>
        </View>
      ) : (
        <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 140 + insets.bottom }} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
          {rows.map((p) => {
            const n = parseInt(qty[p.productId] || "0", 10) || 0;
            const lineTotal = n * Number(p.price || 0);
            return (
              <View key={p.productId} style={styles.card}>
                <View style={styles.topRow}>
                  <Text style={styles.metaLabel} numberOfLines={1}>Type: <Text style={styles.metaStrong}>{p.category || "—"}</Text></Text>
                  <Text style={styles.price} numberOfLines={1}>Price: {fmtRM(Number(p.price || 0))}</Text>
                </View>
                <Text style={styles.itemName} numberOfLines={2}>Item: {p.name || "—"}</Text>

                <View style={styles.inputRow}>
                  <View style={styles.qtyWrap}>
                    <Text style={styles.fieldLabel}>Qty</Text>
                    <TextInput
                      style={styles.qtyInput}
                      value={qty[p.productId] ?? ""}
                      onChangeText={(v) => setQ(p.productId, v)}
                      keyboardType="numeric"
                      placeholder="0"
                      placeholderTextColor={colors.textMuted}
                      testID={`pr-qty-${p.productId}`}
                    />
                  </View>
                  <View style={styles.totalWrap}>
                    <Text style={styles.fieldLabel}>Total</Text>
                    <View style={styles.totalField}>
                      <Text style={styles.totalTxt} numberOfLines={1}>{fmtRM(lineTotal)}</Text>
                    </View>
                  </View>
                </View>
              </View>
            );
          })}
        </ScrollView>
      )}

      <View style={[styles.footer, { backgroundColor: colors.background, borderTopColor: colors.border, paddingBottom: Math.max(insets.bottom + 12, 28) }]}>
        <TouchableOpacity onPress={proceed} disabled={paying} activeOpacity={0.9} testID="pr-proceed">
          <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.proceedBtn, shadow.strong]}>
            {paying ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <>
                <Ionicons name="bag-check" size={20} color="#fff" />
                <Text style={styles.proceedTxt}>{canPurchase ? "Proceed to pay" : "Proceed"}</Text>
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
    center: { flex: 1, alignItems: "center", justifyContent: "center", padding: 40, gap: 10 },
    errTxt: { color: colors.danger, fontSize: 14, textAlign: "center" },
    emptyTxt: { color: colors.textSecondary, fontSize: 14, textAlign: "center" },

    card: {
      backgroundColor: colors.surface, borderRadius: radius.lg, padding: 14, marginBottom: 12,
      ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border,
    },
    topRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", gap: 12 },
    metaLabel: { fontSize: 12, color: colors.textSecondary, fontWeight: "600", flexShrink: 1 },
    metaStrong: { color: colors.textPrimary, fontWeight: "800" },
    price: { fontSize: 13, color: colors.primary, fontWeight: "800", flexShrink: 0 },
    itemName: { fontSize: 15, fontWeight: "800", color: colors.textPrimary, marginTop: 8 },

    inputRow: { flexDirection: "row", alignItems: "flex-end", gap: 14, marginTop: 12 },
    qtyWrap: { width: 120 },
    totalWrap: { flex: 1 },
    fieldLabel: { ...font.tiny, color: colors.textSecondary, marginBottom: 6, textTransform: "uppercase" },
    qtyInput: {
      backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, borderRadius: radius.full,
      paddingHorizontal: 16, paddingVertical: 10, minHeight: 46, fontSize: 14, fontWeight: "700", color: colors.textPrimary,
    },
    totalField: {
      backgroundColor: colors.surfaceAlt, borderWidth: 1, borderColor: colors.border, borderRadius: radius.full,
      paddingHorizontal: 16, justifyContent: "center", minHeight: 46,
    },
    totalTxt: { fontSize: 14, fontWeight: "800", color: colors.textPrimary },

    footer: { position: "absolute", left: 0, right: 0, bottom: 0, paddingHorizontal: spacing.xl, paddingTop: 12, paddingBottom: 28, borderTopWidth: 1 },
    proceedBtn: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8, borderRadius: radius.full, paddingVertical: 15, minHeight: 52 },
    proceedTxt: { color: "#fff", fontWeight: "800", fontSize: 16 },
  });
}
