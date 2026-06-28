import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { api, defaultRange } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export default function Purchases() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const range = useMemo(() => defaultRange(), []);
  const data = useApi(() => api.purchaseRequests({ fromDate: range.fromDate, toDate: range.toDate }), []);
  const rows = data.data ?? [];

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => safeBack(router)} testID="pr-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>My Purchases</Text>
          <TouchableOpacity style={styles.backBtn} onPress={() => data.reload()}>
            <Ionicons name="refresh-outline" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>
      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }} showsVerticalScrollIndicator={false}>
        {data.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 30 }} />}
        {data.error && <Text style={styles.errTxt}>{data.error}</Text>}
        {!data.loading && rows.length === 0 && (
          <View style={styles.empty}>
            <Ionicons name="bag-handle-outline" size={44} color={colors.textMuted} />
            <Text style={styles.emptyTxt}>No purchase requests</Text>
            <Text style={styles.emptySub}>Your purchase history will appear here</Text>
          </View>
        )}
        {rows.map((p: any, i: number) => (
          <View key={i} style={styles.card}>
            <View style={styles.cardIcon}><Ionicons name="bag-handle" size={18} color={colors.primary} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.cardTitle} numberOfLines={1}>{p.itemName || p.productName || p.name || p.description || p.invoiceDescription || "Purchase"}</Text>
              <Text style={styles.cardMeta} numberOfLines={1}>{fmtDate(p.requestDate || p.date || p.invoiceDate)} {p.status || p.paymentStatus ? `· ${p.status || p.paymentStatus}` : ""}</Text>
            </View>
            {(p.amount != null || p.dueAmount != null || p.totalAmount != null) && (
              <Text style={styles.cardAmt} numberOfLines={1}>RM {(p.amount ?? p.totalAmount ?? p.dueAmount ?? 0).toLocaleString()}</Text>
            )}
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.lg, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },
    errTxt: { color: colors.danger, fontSize: 13, marginBottom: 10 },
    empty: { alignItems: "center", paddingVertical: 60, gap: 6 },
    emptyTxt: { ...font.h4, color: colors.textPrimary, marginTop: 10 },
    emptySub: { fontSize: 13, color: colors.textSecondary },
    card: { flexDirection: "row", gap: spacing.md, alignItems: "center", backgroundColor: colors.surface, borderRadius: radius.lg, padding: spacing.md, marginBottom: spacing.sm, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    cardIcon: { width: 38, height: 38, borderRadius: 19, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    cardTitle: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },
    cardMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
    cardAmt: { fontSize: 14, fontWeight: "800", color: colors.textPrimary, marginLeft: spacing.sm, flexShrink: 0 },
  });
}
