import { useEffect, useMemo, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  Modal,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import * as WebBrowser from "expo-web-browser";
import { useBottomTabBarHeight } from "@react-navigation/bottom-tabs";
import { radius, spacing, font, useTheme } from "../../src/theme";
import { useAuth } from "../../src/api/auth";
import { api, defaultRange } from "../../src/api/endpoints";
import { useApi } from "../../src/api/useApi";
import { downloadPdf } from "../../src/api/download";
import { usePaymentCart, type CartItem } from "../../src/payments/usePaymentCart";

type Seg = "pay" | "prepay" | "history";

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export default function Payments() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user } = useAuth();
  const tabBarHeight = useBottomTabBarHeight(); // offset fixed Pay bar above the tab bar
  const cart = usePaymentCart();
  const [seg, setSeg] = useState<Seg>("pay");
  const [busyPdf, setBusyPdf] = useState<string | null>(null);

  // Account switcher state
  const siblings = useApi(() => api.mySiblings(), []);
  const [activeAccount, setActiveAccount] = useState<{ id: number; name: string } | null>(null);
  const accountId = activeAccount?.id ?? user?.id ?? null;

  // Default the active account to the logged-in student
  useMemo(() => { if (user && !activeAccount) setActiveAccount({ id: user.id, name: user.name }); }, [user]);

  const range = useMemo(() => defaultRange(), []);

  // dues uses accountId so it reloads when the account chip changes
  const dues = useApi(
    () => api.outstanding({ studentId: accountId, startDate: range.fromDate, endDate: range.toDate }),
    [accountId]
  );
  const history = useApi(() => api.receipts({ fromDate: range.fromDate, toDate: range.toDate }), []);

  const invoices = dues.data ?? [];

  // Pay sheet state (Task 6)
  const [sheet, setSheet] = useState(false);
  const [method, setMethod] = useState("card");
  const [paying, setPaying] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(120);

  // 2-minute countdown while the pay sheet is processing a bill
  useEffect(() => {
    if (!paying) return;
    if (secondsLeft <= 0) {
      setPaying(false);
      setSheet(false);
      Alert.alert("Session expired", "Payment session timed out. Please try again.");
      return;
    }
    const t = setTimeout(() => setSecondsLeft((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [paying, secondsLeft]);

  async function openPdf(label: string, url: string, filename: string) {
    setBusyPdf(label);
    try {
      await downloadPdf(url, filename);
    } catch (e: any) {
      Alert.alert("Download failed", e?.message || "Could not open the PDF.");
    } finally {
      setBusyPdf(null);
    }
  }

  async function confirmPay() {
    setPaying(true);
    setSecondsLeft(120);
    try {
      const body = cart.items.map((i) => i.invoice); // shape confirmed in Task 1, Step 4
      const res: any = await api.payInvoices(body, { payTermPayments: cart.hasTerm });
      const billUrl = typeof res === "string" ? res : res?.url;
      if (!billUrl) throw new Error("Gateway did not return a payment URL.");
      const result = await WebBrowser.openBrowserAsync(billUrl);
      // After the browser closes, confirm status (best-effort) and refresh.
      try { await api.paymentCompleted("paid"); } catch {}
      setPaying(false);
      setSheet(false);
      cart.clear();
      dues.reload();
      history.reload();
      Alert.alert(
        "Payment",
        result?.type === "cancel"
          ? "Returned from gateway. Refreshing your invoices."
          : "Thank you. Refreshing your invoices."
      );
    } catch (e: any) {
      setPaying(false);
      Alert.alert("Payment failed", e?.message || "Could not start the payment.");
    }
  }

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <Text style={styles.title}>Fees & Payments</Text>
          <TouchableOpacity
            style={styles.iconBtn}
            onPress={() => { dues.reload(); history.reload(); }}
          >
            <Ionicons name="refresh-outline" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
        <View style={styles.segRow}>
          {(["pay", "prepay", "history"] as Seg[]).map((s) => (
            <TouchableOpacity
              key={s}
              style={[styles.seg, seg === s && styles.segActive]}
              onPress={() => setSeg(s)}
              testID={`pay-seg-${s}`}
            >
              <Text style={[styles.segTxt, seg === s && styles.segTxtActive]}>
                {s === "pay" ? "Pay" : s === "prepay" ? "Prepay" : "History"}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </SafeAreaView>

      <ScrollView
        contentContainerStyle={{ padding: spacing.xl, paddingBottom: tabBarHeight + 140 }}
        showsVerticalScrollIndicator={false}
      >
        {seg === "pay" && (
          <>
            {/* Account switcher chips */}
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.chipRow}
            >
              {[
                { id: user!.id, name: user!.name },
                ...((siblings.data ?? []).map((s) => ({ id: s.id, name: s.text }))),
              ]
                .filter((a, i, arr) => arr.findIndex((x) => x.id === a.id) === i)
                .map((a) => {
                  const on = accountId === a.id;
                  return (
                    <TouchableOpacity
                      key={a.id}
                      style={[styles.chip, on && styles.chipOn]}
                      onPress={() => setActiveAccount(a)}
                      testID={`acct-${a.id}`}
                    >
                      <Ionicons
                        name="person-circle-outline"
                        size={16}
                        color={on ? "#fff" : colors.primary}
                      />
                      <Text style={[styles.chipTxt, on && { color: "#fff" }]} numberOfLines={1}>
                        {a.name.trim()}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
            </ScrollView>

            {dues.loading && (
              <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />
            )}
            {!dues.loading && invoices.length === 0 && (
              <Text style={styles.emptyTxt}>No outstanding invoices.</Text>
            )}
            {invoices.map((inv, idx) => {
              const key = `${accountId}:${inv.invoiceId}`;
              const selected = cart.has(key);
              const item: CartItem = {
                key,
                studentId: accountId!,
                studentName: inv.studentName,
                invoice: inv,
                isTerm: false,
              };
              return (
                <View
                  key={inv.invoiceId ?? idx}
                  style={[styles.invCard, selected && styles.invCardSel]}
                  testID={`invoice-${inv.invoiceId}`}
                >
                  <TouchableOpacity
                    style={styles.invMain}
                    onPress={() => cart.toggle(item)}
                    activeOpacity={0.8}
                  >
                    <Ionicons
                      name={selected ? "checkbox" : "square-outline"}
                      size={22}
                      color={selected ? colors.primary : colors.textMuted}
                    />
                    <View style={{ flex: 1, marginLeft: 10 }}>
                      <View style={styles.invTopRow}>
                        <Text style={styles.invNo}>#{inv.invoiceId}</Text>
                        <Text style={styles.invType}>{inv.transactionType}</Text>
                      </View>
                      <Text style={styles.invDesc} numberOfLines={1}>
                        {inv.invoiceDescription || inv.period}
                      </Text>
                      <Text style={styles.invMeta}>
                        {inv.period} · {fmtDate(inv.invoiceDate)} · {inv.paymentStatus}
                      </Text>
                    </View>
                    <Text style={styles.invAmt}>RM {(inv.dueAmount || 0).toLocaleString()}</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.invDownload}
                    testID={`invoice-pdf-${inv.invoiceId}`}
                    disabled={busyPdf === key}
                    onPress={() =>
                      openPdf(
                        key,
                        api.receiptPdfUrl(user!.clubId, 0, inv.invoiceId),
                        `INVOICE_${inv.invoiceId}.pdf`
                      )
                    }
                  >
                    {busyPdf === key ? (
                      <ActivityIndicator size="small" color={colors.primary} />
                    ) : (
                      <>
                        <Ionicons name="document-text-outline" size={14} color={colors.primary} />
                        <Text style={styles.invDownloadTxt}>Invoice PDF</Text>
                      </>
                    )}
                  </TouchableOpacity>
                </View>
              );
            })}
          </>
        )}

        {seg === "prepay" && (
          <PrepaySegment
            accountId={accountId!}
            accountName={activeAccount?.name || user!.name}
            cart={cart}
            styles={styles}
            colors={colors}
          />
        )}

        {seg === "history" && (
          <>
            {history.loading && (
              <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />
            )}
            {!history.loading && (history.data?.length ?? 0) === 0 && (
              <Text style={styles.emptyTxt}>No receipts found.</Text>
            )}
            {(history.data ?? []).map((p, idx) => {
              const k = `rec-${p.id}-${idx}`;
              return (
                <View key={k} style={styles.invCard} testID={`payment-${p.id}`}>
                  <View style={styles.invMain}>
                    <View style={styles.recIcon}>
                      <Ionicons name="checkmark" size={16} color={colors.success} />
                    </View>
                    <View style={{ flex: 1, marginLeft: 10 }}>
                      <Text style={styles.invDesc} numberOfLines={1}>
                        {p.paymentMethod}
                      </Text>
                      <Text style={styles.invMeta}>
                        {fmtDate(p.receiptDate)} · {p.tcName} · #{p.receiptNo}
                      </Text>
                    </View>
                    <Text style={styles.invAmt}>RM {(p.receiptAmount || 0).toLocaleString()}</Text>
                  </View>
                  <TouchableOpacity
                    style={styles.invDownload}
                    testID={`receipt-pdf-${p.id}`}
                    disabled={busyPdf === k}
                    onPress={() =>
                      openPdf(
                        k,
                        api.receiptPdfUrl(user!.clubId, p.id, 0),
                        `RECEIPT_${p.receiptNo}.pdf`
                      )
                    }
                  >
                    {busyPdf === k ? (
                      <ActivityIndicator size="small" color={colors.primary} />
                    ) : (
                      <>
                        <Ionicons name="download-outline" size={14} color={colors.primary} />
                        <Text style={styles.invDownloadTxt}>Receipt PDF</Text>
                      </>
                    )}
                  </TouchableOpacity>
                </View>
              );
            })}
          </>
        )}
      </ScrollView>

      {/* Bottom Pay bar — shown when cart has items */}
      {cart.items.length > 0 && (
        <View style={[styles.payBar, { bottom: tabBarHeight }]}>
          <View style={{ flex: 1 }}>
            <Text style={styles.payBarLbl}>{cart.items.length} selected</Text>
            <Text style={styles.payBarTotal}>RM {cart.total.toLocaleString()}</Text>
          </View>
          <TouchableOpacity
            style={styles.payBarBtnWrap}
            testID="pay-open-sheet"
            onPress={() => { setSecondsLeft(120); setSheet(true); }}
          >
            <LinearGradient
              colors={colors.gradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 0 }}
              style={styles.payBarBtn}
            >
              <Text style={styles.payBarBtnTxt}>Pay</Text>
              <Ionicons name="arrow-forward" size={16} color="#fff" />
            </LinearGradient>
          </TouchableOpacity>
        </View>
      )}

      {/* Pay sheet modal (Task 6) */}
      <Modal
        visible={sheet}
        transparent
        animationType="slide"
        onRequestClose={() => !paying && setSheet(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalCard}>
            <View style={styles.modalHandle} />
            <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
              <Text style={styles.modalTitle}>Complete Payment</Text>
              {paying && (
                <Text style={styles.countdown}>
                  {String(Math.floor(secondsLeft / 60)).padStart(1, "0")}:
                  {String(secondsLeft % 60).padStart(2, "0")}
                </Text>
              )}
            </View>
            <Text style={styles.modalAmt}>RM {cart.total.toLocaleString()}</Text>
            {[
              { id: "card", label: "Credit / Debit Card", icon: "card" },
              { id: "fpx", label: "FPX / eWallet", icon: "phone-portrait" },
              { id: "bank", label: "Bank Transfer", icon: "business" },
            ].map((m) => (
              <TouchableOpacity
                key={m.id}
                disabled={paying}
                onPress={() => setMethod(m.id)}
                style={[styles.methodRow, method === m.id && styles.methodRowActive]}
                testID={`pay-method-${m.id}`}
              >
                <View
                  style={[styles.methodIcon, method === m.id && { backgroundColor: colors.primary }]}
                >
                  <Ionicons
                    name={m.icon as any}
                    size={18}
                    color={method === m.id ? "#fff" : colors.primary}
                  />
                </View>
                <Text style={styles.methodLbl}>{m.label}</Text>
                <Ionicons
                  name={method === m.id ? "radio-button-on" : "radio-button-off"}
                  size={20}
                  color={method === m.id ? colors.primary : colors.textMuted}
                />
              </TouchableOpacity>
            ))}
            <TouchableOpacity
              onPress={confirmPay}
              disabled={paying}
              activeOpacity={0.9}
              testID="pay-confirm-btn"
            >
              <LinearGradient
                colors={colors.gradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={[styles.confirmBtn, shadow.strong]}
              >
                {paying ? (
                  <ActivityIndicator color="#fff" />
                ) : (
                  <>
                    <Ionicons name="lock-closed" size={14} color="#fff" />
                    <Text style={styles.confirmTxt}>Confirm & Pay Securely</Text>
                  </>
                )}
              </LinearGradient>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => !paying && setSheet(false)}
              style={{ marginTop: 10, alignSelf: "center" }}
            >
              <Text style={{ color: colors.textSecondary, fontSize: 13 }}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

// PrepaySegment lives in the same file (plan Task 5)
function PrepaySegment({
  accountId,
  accountName,
  cart,
  styles,
  colors,
}: {
  accountId: number;
  accountName: string;
  cart: ReturnType<typeof usePaymentCart>;
  styles: ReturnType<typeof createStyles>;
  colors: any;
}) {
  const year = new Date().getFullYear();
  const months = [...Array(12)].map((_, i) => i + 1);
  const terms = useApi(
    () => api.fetchTermPayments({ studentIds: [accountId], year, months }),
    [accountId]
  );
  const data = terms.data ?? [];

  if (terms.loading) {
    return <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />;
  }
  if (data.length === 0) {
    return (
      <Text style={styles.emptyTxt}>
        No upcoming months available to prepay for this account.
      </Text>
    );
  }
  return (
    <>
      {data.map((t: any) => {
        // FetchTermPayments returns full invoice-shaped rows (real invoiceId + dueAmount).
        const key = `term:${accountId}:${t.invoiceId}`;
        const selected = cart.has(key);
        const item: CartItem = {
          key,
          studentId: accountId,
          studentName: accountName,
          invoice: { ...t, studentId: accountId, studentName: accountName },
          isTerm: true,
        };
        return (
          <TouchableOpacity
            key={key}
            style={[
              styles.invCard,
              selected && styles.invCardSel,
              { padding: 14, flexDirection: "row", alignItems: "center" },
            ]}
            onPress={() => cart.toggle(item)}
            testID={`term-${key}`}
          >
            <Ionicons
              name={selected ? "checkbox" : "square-outline"}
              size={22}
              color={selected ? colors.primary : colors.textMuted}
            />
            <View style={{ flex: 1, marginLeft: 10 }}>
              <Text style={styles.invDesc}>{t.invoiceDescription || t.period}</Text>
              <Text style={styles.invMeta}>{t.period} · Advance</Text>
            </View>
            <Text style={styles.invAmt}>RM {(t.dueAmount || 0).toLocaleString()}</Text>
          </TouchableOpacity>
        );
      })}
    </>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: {
      flexDirection: "row",
      justifyContent: "space-between",
      alignItems: "center",
      paddingHorizontal: spacing.xl,
      paddingVertical: 14,
    },
    title: { ...font.h1, color: colors.textPrimary, fontSize: 26 },
    iconBtn: {
      width: 42,
      height: 42,
      borderRadius: 21,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
      justifyContent: "center",
    },

    // Segment tabs
    segRow: { flexDirection: "row", gap: 8, paddingHorizontal: spacing.xl, paddingBottom: 12 },
    seg: {
      flex: 1,
      paddingVertical: 9,
      borderRadius: radius.md,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
    },
    segActive: { backgroundColor: colors.primary },
    segTxt: { fontSize: 13, fontWeight: "700", color: colors.textSecondary },
    segTxtActive: { color: "#fff" },
    emptyTxt: { color: colors.textSecondary, fontSize: 13, textAlign: "center", marginVertical: 30 },

    // Account switcher chips (Task 5)
    chipRow: { gap: 8, paddingBottom: 12 },
    chip: {
      flexDirection: "row",
      alignItems: "center",
      gap: 6,
      paddingHorizontal: 12,
      paddingVertical: 8,
      borderRadius: radius.full,
      backgroundColor: colors.surfaceAlt,
      borderWidth: 1,
      borderColor: colors.border,
      maxWidth: 160,
    },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipTxt: { fontSize: 12, fontWeight: "700", color: colors.textPrimary },

    // Invoice / receipt cards
    invCard: {
      backgroundColor: colors.surface,
      borderRadius: radius.lg,
      marginBottom: 10,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
      overflow: "hidden",
    },
    invCardSel: { borderWidth: 1.5, borderColor: colors.primary },
    invMain: { flexDirection: "row", alignItems: "center", padding: 14 },
    invTopRow: { flexDirection: "row", justifyContent: "space-between" },
    invNo: { fontSize: 11, color: colors.textSecondary, fontWeight: "700" },
    invType: { fontSize: 11, color: colors.primary, fontWeight: "700" },
    invDesc: { fontSize: 14, color: colors.textPrimary, fontWeight: "700", marginTop: 2 },
    invMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
    invAmt: { fontSize: 15, color: colors.textPrimary, fontWeight: "800", marginLeft: 8 },
    invDownload: {
      flexDirection: "row",
      gap: 5,
      alignItems: "center",
      justifyContent: "center",
      paddingVertical: 9,
      borderTopWidth: 1,
      borderTopColor: colors.border,
    },
    invDownloadTxt: { color: colors.primary, fontSize: 12, fontWeight: "700" },
    recIcon: {
      width: 30,
      height: 30,
      borderRadius: 15,
      backgroundColor: mode === "dark" ? "#064E3B" : "#D1FAE5",
      alignItems: "center",
      justifyContent: "center",
    },

    // Bottom pay bar
    payBar: {
      position: "absolute",
      left: 0,
      right: 0,
      // `bottom` is set inline to the tab-bar height so the bar floats just above it
      flexDirection: "row",
      alignItems: "center",
      gap: 12,
      paddingHorizontal: spacing.xl,
      paddingTop: 14,
      paddingBottom: 14,
      backgroundColor: colors.surface,
      borderTopWidth: 1,
      borderTopColor: colors.border,
      ...shadow.card,
    },
    payBarLbl: { fontSize: 11, color: colors.textSecondary, fontWeight: "600" },
    payBarTotal: { fontSize: 20, color: colors.textPrimary, fontWeight: "800" },
    payBarBtnWrap: { borderRadius: radius.md, overflow: "hidden" },
    payBarBtn: {
      flexDirection: "row",
      gap: 8,
      alignItems: "center",
      paddingHorizontal: 28,
      paddingVertical: 14,
    },
    payBarBtnTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },

    // Pay sheet modal (Task 6)
    modalOverlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: "flex-end" },
    modalCard: {
      backgroundColor: colors.surface,
      borderTopLeftRadius: 28,
      borderTopRightRadius: 28,
      padding: 22,
      paddingBottom: 36,
    },
    modalHandle: {
      width: 40,
      height: 4,
      backgroundColor: colors.border,
      borderRadius: 2,
      alignSelf: "center",
      marginBottom: 18,
    },
    modalTitle: { ...font.h2, color: colors.textPrimary },
    countdown: { fontSize: 18, fontWeight: "800", color: colors.primary },
    modalAmt: { ...font.h1, color: colors.primary, fontSize: 32, marginTop: 12, marginBottom: 10 },
    methodRow: {
      flexDirection: "row",
      gap: 12,
      alignItems: "center",
      padding: 14,
      borderRadius: radius.md,
      borderWidth: 1,
      borderColor: colors.border,
      marginBottom: 10,
    },
    methodRowActive: { borderColor: colors.primary, backgroundColor: colors.surfaceAlt },
    methodIcon: {
      width: 36,
      height: 36,
      borderRadius: 18,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
      justifyContent: "center",
    },
    methodLbl: { flex: 1, fontSize: 14, color: colors.textPrimary, fontWeight: "600" },
    confirmBtn: {
      flexDirection: "row",
      gap: 8,
      paddingVertical: 16,
      borderRadius: radius.md,
      alignItems: "center",
      justifyContent: "center",
      marginTop: 10,
      minHeight: 52,
    },
    confirmTxt: { color: "#fff", fontWeight: "800", fontSize: 14 },
  });
}
