import { useEffect, useMemo, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  Modal,
  Image,
  Platform,
} from "react-native";
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import * as WebBrowser from "expo-web-browser";
import * as ImagePicker from "expo-image-picker";
import { useBottomTabBarHeight } from "@react-navigation/bottom-tabs";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../../src/theme";
import { notify } from "../../src/ui/dialogs";
import { SkeletonList } from "../../src/ui/skeleton";
import { useAuth } from "../../src/api/auth";
import { api, defaultRange } from "../../src/api/endpoints";
import { useApi } from "../../src/api/useApi";
import { downloadPdf } from "../../src/api/download";
import { usePaymentCart, type CartItem } from "../../src/payments/usePaymentCart";

type Seg = "pay" | "prepay" | "history";

// Advance-payment selection carried into the pay sheet. studentIds/year/months are what
// /Bcpg/PayInvoices wants for `payTermPayments` (the legacy route took a query flag that
// the backend never honoured). `ids` are the months that already have an invoice; on a
// Boost server the term model bills the rest of `months` too, which is the whole point of
// the route — see `estimated`.
type TermPayContext = {
  ids: number[];
  total: number;
  studentIds: number[];
  year: number;
  months: number[];
  /** true when the selection includes months the academy hasn't invoiced yet. */
  estimated: boolean;
};

function fmtDate(iso?: string) {
  if (!iso) return "";
  const d = new Date(iso);
  return isNaN(d.getTime()) ? iso : d.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export default function Payments() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user, apiEnv } = useAuth();
  // Only the Boost server exposes /Bcpg. It is also the gateway the legacy online route
  // proxies to there, so on such a server "Online" and "Boost" are the same payment —
  // the sheet offers one online method, resolved here.
  const boostServer = apiEnv.hasBoostGateway;
  const tabBarHeight = useBottomTabBarHeight(); // offset fixed Pay bar above the tab bar
  const insets = useSafeAreaInsets();
  const cart = usePaymentCart();
  const [seg, setSeg] = useState<Seg>("pay");
  const [busyPdf, setBusyPdf] = useState<string | null>(null);
  // Inactive accounts don't get invoice/receipt PDF downloads
  const isActive = (user?.status || "").trim().toLowerCase() !== "inactive";

  // Account switcher state
  const siblings = useApi(() => api.mySiblings(), []);
  const [activeAccount, setActiveAccount] = useState<{ id: number; name: string } | null>(null);
  const accountId = activeAccount?.id ?? user?.id ?? null;

  // Default the active account to the logged-in student. This has to be an effect: a useMemo
  // that calls setState is a side effect during render, and React is free to drop or re-run a
  // memo, so the default could be re-applied over a chip the user had just tapped.
  useEffect(() => {
    if (user && !activeAccount) setActiveAccount({ id: user.id, name: user.name });
  }, [user, activeAccount]);

  const range = useMemo(() => defaultRange(), []);

  // dues uses accountId so it reloads when the account chip changes
  const dues = useApi(
    () => api.outstanding({ studentId: accountId, startDate: range.fromDate, endDate: range.toDate }),
    [accountId]
  );
  const history = useApi(() => api.receipts({ fromDate: range.fromDate, toDate: range.toDate }), []);

  const invoices = dues.data ?? [];

  // Pay sheet state
  const [sheet, setSheet] = useState(false);
  // "online" = the server's payment gateway (Boost via /Bcpg where available, otherwise the
  // legacy FPX/card gateway), "bankin" = payment-slip upload.
  const [method, setMethod] = useState<"online" | "bankin">("online");
  const [slip, setSlip] = useState<ImagePicker.ImagePickerAsset | null>(null);
  const [paying, setPaying] = useState(false);
  // Advance (term) payment context — when set, the sheet pays these ids with PayTermPayments=true
  // instead of the cart. Bumping prepayRefresh makes PrepaySegment refetch after a payment.
  const [termPay, setTermPay] = useState<TermPayContext | null>(null);
  const [prepayRefresh, setPrepayRefresh] = useState(0);

  const invoiceIds = useMemo(
    () => cart.items.map((i) => i.invoice.invoiceId).filter((id) => id > 0),
    [cart.items]
  );
  // Distinct accounts represented in the cart — the cart is deliberately cross-account
  // (each row carries its own studentName), so a payment can span several siblings.
  const payingAccountIds = useMemo(
    () => Array.from(new Set(cart.items.map((i) => i.studentId).filter((id) => id > 0))),
    [cart.items]
  );

  // What the sheet is actually paying (cart flow vs advance-payment flow)
  const payingIds = termPay ? termPay.ids : invoiceIds;
  const payingTotal = termPay ? termPay.total : cart.total;

  function openSheet() {
    setTermPay(null);
    setMethod("online");
    setSlip(null);
    setSheet(true);
  }

  function openTermSheet(ctx: TermPayContext) {
    setTermPay(ctx);
    setMethod("online");
    setSlip(null);
    setSheet(true);
  }

  async function openPdf(label: string, url: string, filename: string) {
    setBusyPdf(label);
    try {
      await downloadPdf(url, filename);
    } catch (e: any) {
      notify("Download failed", e?.message || "Could not open the PDF.");
    } finally {
      setBusyPdf(null);
    }
  }

  // Build a FormData-appendable file from a picked asset (web → File/Blob, native → {uri,name,type}).
  async function toUploadFile(asset: ImagePicker.ImagePickerAsset): Promise<any> {
    const name = asset.fileName || `slip_${Date.now()}.jpg`;
    const type = asset.mimeType || "image/jpeg";
    if (Platform.OS === "web") {
      const blob = await (await fetch(asset.uri)).blob();
      return new File([blob], name, { type: blob.type || type });
    }
    return { uri: asset.uri, name, type };
  }

  async function pickSlip(from: "camera" | "gallery") {
    try {
      const perm =
        from === "camera"
          ? await ImagePicker.requestCameraPermissionsAsync()
          : await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) {
        notify("Permission needed", `Allow ${from} access to attach a payment slip.`);
        return;
      }
      const res =
        from === "camera"
          ? await ImagePicker.launchCameraAsync({ quality: 0.6 })
          : await ImagePicker.launchImageLibraryAsync({ quality: 0.6, mediaTypes: ImagePicker.MediaTypeOptions.Images });
      if (!res.canceled && res.assets?.[0]) setSlip(res.assets[0]);
    } catch (e: any) {
      notify("Could not pick image", e?.message || "Try again.");
    }
  }

  // Shared post-payment cleanup for both the cart and advance-payment flows.
  function afterPaid() {
    setSheet(false);
    if (termPay) {
      setTermPay(null);
      setPrepayRefresh((n) => n + 1); // make PrepaySegment refetch its term rows
    } else {
      cart.clear();
    }
    dues.reload();
    history.reload();
  }

  async function proceedToPay() {
    // An advance selection can be term-only (months with no invoice yet), which the Boost
    // route bills from the term model — so ids may legitimately be empty there.
    const hasTermSelection = !!termPay && termPay.months.length > 0;
    if (payingIds.length === 0 && !hasTermSelection) {
      notify("Select invoices", "Choose at least one invoice to pay.");
      return;
    }
    setPaying(true);
    try {
      if (method !== "bankin") {
        // One gateway session for whatever is selected: issued invoices, and — on a Boost
        // server — the advance months that have no invoice yet. startPayment picks /Bcpg
        // where it exists and falls back to the legacy gateway where it doesn't.
        const res = await api.startPayment({
          invoiceIds: payingIds,
          term: termPay ? { studentIds: termPay.studentIds, year: termPay.year, months: termPay.months } : null,
        });
        await WebBrowser.openBrowserAsync(res.url); // hosted gateway page
        setPaying(false);

        // Back from the gateway. The browser result never says whether the payment went
        // through, so ask the server: verify by reference, then reconcile the invoice list.
        // Reconcile against every account in this payment, not just the chip that happens to
        // be active — the cart can hold a sibling's invoices, and those live under their own
        // studentId in Outstanding/Fetch.
        const verdict = await api.confirmPayment({
          referenceId: res.referenceId,
          invoiceIds: payingIds,
          studentId: accountId,
          studentIds: termPay ? termPay.studentIds : payingAccountIds,
        });
        afterPaid();
        notify(verdict.outcome === "paid" ? "Payment received" : "Payment", verdict.message);
      } else {
        if (!slip) {
          setPaying(false);
          notify("Payment slip required", "Attach your bank-in slip first.");
          return;
        }
        // Bank-in goes through the legacy multipart route, which bills invoice ids only —
        // months without an invoice can't be settled this way.
        if (payingIds.length === 0) {
          setPaying(false);
          notify(
            "Not available for these months",
            "A bank-in slip can only be submitted against issued invoices. Pay online to settle months your academy hasn't invoiced yet."
          );
          return;
        }
        const file = await toUploadFile(slip);
        await api.payInvoicesBankIn(payingIds, file, !!termPay);
        setPaying(false);
        afterPaid();
        notify("Submitted", "Your payment slip has been submitted for verification.");
      }
    } catch (e: any) {
      setPaying(false);
      notify("Payment failed", e?.message || "Could not complete the payment.");
    }
  }

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <Text style={styles.title}>Fees & Payments</Text>
          <TouchableOpacity
            style={styles.iconBtn}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
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
              <Text style={[styles.segTxt, seg === s && styles.segTxtActive]} numberOfLines={1}>
                {s === "pay" ? "Pay" : s === "prepay" ? "Advance Payment" : "History"}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </SafeAreaView>

      <ScrollView
        contentContainerStyle={{ padding: spacing.xl, paddingBottom: tabBarHeight + 140 }}
        showsVerticalScrollIndicator={false}
      >
        {/* Account switcher chips — Pay segment (Prepay has its own siblings checklist) */}
        {seg === "pay" && (
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
        )}

        {/* Auto Pay entry point. UI shell — see src/payments/autopay.ts. */}
        {seg === "pay" && (
          <TouchableOpacity style={styles.autopayRow} onPress={() => router.push("/autopay")} testID="pay-autopay">
            <View style={styles.autopayIcon}>
              <Ionicons name="sync-circle-outline" size={20} color={colors.primary} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.autopayTitle} numberOfLines={1}>Auto Pay</Text>
              <Text style={styles.autopaySub} numberOfLines={1}>Settle your fees automatically each month</Text>
            </View>
            <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
          </TouchableOpacity>
        )}

        {seg === "pay" && (
          <>
            {dues.loading && <SkeletonList rows={4} lines={2} style={{ paddingHorizontal: 0, paddingTop: 4 }} />}
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
                        <Text style={styles.invType} numberOfLines={1}>{inv.transactionType}</Text>
                      </View>
                      <Text style={styles.invDesc} numberOfLines={1}>
                        {inv.invoiceDescription || inv.period}
                      </Text>
                      <Text style={styles.invMeta}>
                        {inv.period} · {fmtDate(inv.invoiceDate)} · {inv.paymentStatus}
                      </Text>
                    </View>
                    <Text style={styles.invAmt} numberOfLines={1}>RM {(inv.dueAmount || 0).toLocaleString()}</Text>
                  </TouchableOpacity>
                  {/* No per-invoice PDF link here by request — an unpaid invoice is something to
                      pay, not to download. The PDF affordance lives on History, where a receipt
                      is the document a member actually needs to keep. */}
                </View>
              );
            })}
          </>
        )}

        {seg === "prepay" && (
          <PrepaySegment
            user={user!}
            siblings={siblings.data ?? []}
            styles={styles}
            colors={colors}
            onPay={openTermSheet}
            refreshKey={prepayRefresh}
            boostServer={boostServer}
          />
        )}

        {seg === "history" && (
          <>
            {history.loading && <SkeletonList rows={4} lines={2} style={{ paddingHorizontal: 0, paddingTop: 4 }} />}
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
                    <Text style={styles.invAmt} numberOfLines={1}>RM {(p.receiptAmount || 0).toLocaleString()}</Text>
                  </View>
                  {isActive && <TouchableOpacity
                    style={styles.invDownload}
                    testID={`receipt-pdf-${p.id}`}
                    disabled={busyPdf === k}
                    onPress={() =>
                      openPdf(
                        k,
                        // p.id is an invoiceId (Reports/Receipts = one row per invoice line).
                        // ReceiptAsPDF renders the full receipt via the invoiceId slot, not paymentId.
                        api.receiptPdfUrl(user!.clubId, 0, p.id),
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
                  </TouchableOpacity>}
                </View>
              );
            })}
          </>
        )}
      </ScrollView>

      {/* Bottom Pay bar — shown when cart has items */}
      {seg === "pay" && cart.items.length > 0 && (
        <View style={[styles.payBar, { bottom: tabBarHeight }]}>
          <View style={{ flex: 1 }}>
            <Text style={styles.payBarLbl}>{cart.items.length} selected</Text>
            <Text style={styles.payBarTotal}>RM {cart.total.toLocaleString()}</Text>
          </View>
          <TouchableOpacity
            style={styles.payBarBtnWrap}
            testID="pay-open-sheet"
            onPress={openSheet}
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

      {/* Make Payment sheet — Online (Billplz) or Direct Bank-In (slip upload) */}
      <Modal visible={sheet} transparent animationType="slide" onRequestClose={() => !paying && setSheet(false)}>
        <View style={styles.modalOverlay}>
          <View style={[styles.modalCard, { paddingBottom: 24 + insets.bottom }]}>
            <View style={styles.modalHandle} />
            <View style={styles.mpHead}>
              <Text style={styles.modalTitle}>Make Payment</Text>
              <TouchableOpacity onPress={() => !paying && setSheet(false)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} style={styles.mpClose} testID="pay-close">
                <Ionicons name="close" size={20} color={colors.textPrimary} />
              </TouchableOpacity>
            </View>

            <View style={styles.mpSummaryRow}>
              <Text style={styles.mpSummary}>
                {termPay ? "Paying Month(s) : " : "Paying Invoice(s) : "}
                <Text style={styles.mpStrong}>{termPay ? termPay.months.length : payingIds.length}</Text>
              </Text>
              <Text style={styles.mpSummary}>
                {termPay?.estimated ? "Est. Amt : " : "Paying Amt : "}
                <Text style={styles.mpStrong}>{payingTotal.toFixed(2)}</Text>
              </Text>
            </View>
            {termPay && (
              <View style={styles.mpHintRow}>
                <Ionicons name="calendar-outline" size={16} color={colors.primary} />
                <Text style={styles.mpHint}>
                  {termPay.estimated
                    ? "Advance payment — some of these months aren't invoiced yet, so the payment page confirms the final amount."
                    : "Advance payment — settling upcoming months ahead of time."}
                </Text>
              </View>
            )}

            {/* Method toggles. The online method is whichever gateway this server runs. */}
            <View style={styles.mpMethods}>
              {([
                {
                  id: "online",
                  label: boostServer ? "Boost (online payment)" : "Online (FPX / Card)",
                  icon: boostServer ? "wallet-outline" : "globe-outline",
                },
                { id: "bankin", label: "Direct Bank-In", icon: "receipt-outline" },
              ] as { id: "online" | "bankin"; label: string; icon: string }[]).map((m) => {
                const on = method === m.id;
                return (
                  <TouchableOpacity key={m.id} disabled={paying} onPress={() => setMethod(m.id)} style={[styles.mpMethod, on && styles.mpMethodOn]} testID={`pay-method-${m.id}`} activeOpacity={0.7}>
                    <Ionicons name={m.icon as any} size={18} color={on ? colors.primary : colors.textMuted} />
                    <Text style={styles.mpMethodLbl} numberOfLines={1}>{m.label}</Text>
                    <Ionicons name={on ? "checkmark-circle" : "ellipse-outline"} size={22} color={on ? colors.success : colors.textMuted} />
                  </TouchableOpacity>
                );
              })}
            </View>

            {/* Online/Boost hint or Bank-In slip picker */}
            {method !== "bankin" ? (
              <View style={styles.mpHintRow}>
                <Ionicons name={boostServer ? "wallet-outline" : "globe-outline"} size={18} color={colors.textSecondary} />
                <Text style={styles.mpHint}>
                  {boostServer
                    ? "You'll be taken to the secure Boost payment gateway to complete this payment."
                    : "You will be redirected to the secure payment gateway to finalize your payment (FPX, card & e-wallets)."}
                </Text>
              </View>
            ) : (
              <>
                <Text style={styles.mpLabel}>Select Paymentslip</Text>
                {slip ? (
                  <View style={styles.slipPreviewWrap}>
                    <Image source={{ uri: slip.uri }} style={styles.slipPreview} resizeMode="cover" />
                    <TouchableOpacity style={styles.slipRemove} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} onPress={() => setSlip(null)} testID="slip-remove">
                      <Ionicons name="close-circle" size={24} color={colors.danger} />
                    </TouchableOpacity>
                  </View>
                ) : (
                  <View style={styles.slipBox}>
                    <Ionicons name="camera" size={36} color={colors.textMuted} />
                    <View style={styles.slipBtnRow}>
                      <TouchableOpacity style={styles.slipBtn} onPress={() => pickSlip("gallery")} testID="slip-gallery">
                        <Ionicons name="images" size={18} color={colors.primary} />
                        <Text style={styles.slipBtnTxt}>Gallery</Text>
                      </TouchableOpacity>
                      <TouchableOpacity style={styles.slipBtn} onPress={() => pickSlip("camera")} testID="slip-camera">
                        <Ionicons name="camera" size={18} color={colors.primary} />
                        <Text style={styles.slipBtnTxt}>Camera</Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                )}
              </>
            )}

            <TouchableOpacity onPress={proceedToPay} disabled={paying} activeOpacity={0.9} testID="pay-proceed">
              <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.confirmBtn, shadow.strong]}>
                {paying ? <ActivityIndicator color="#fff" /> : (
                  <>
                    <Ionicons name="lock-closed" size={14} color="#fff" />
                    <Text style={styles.confirmTxt}>{method !== "bankin" ? "Proceed to pay" : "Submit Slip"}</Text>
                  </>
                )}
              </LinearGradient>
            </TouchableOpacity>
            <Text style={styles.mpPowered}>
              {method === "bankin" ? "VERIFIED BY YOUR ACADEMY" : boostServer ? "SECURED BY BOOST" : "SECURE PAYMENT GATEWAY"}
            </Text>
          </View>
        </View>
      </Modal>
    </View>
  );
}

// PrepaySegment: a yearly calendar (months only). Tap available months to prepay in advance.
const MONTH_ABBR = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function termMonth(t: any): number {
  const d = new Date(t.invoiceDate);
  const m = d.getMonth();
  if (!isNaN(m)) return m + 1;
  const idx = MONTH_ABBR.findIndex((mm) =>
    String(t.period || "").toLowerCase().startsWith(mm.toLowerCase())
  );
  return idx >= 0 ? idx + 1 : 0;
}

function PrepaySegment({
  user,
  siblings,
  styles,
  colors,
  onPay,
  refreshKey,
  boostServer,
}: {
  user: { id: number; name: string };
  siblings: { id: number; value: string; text: string }[];
  styles: ReturnType<typeof createStyles>;
  colors: any;
  onPay: (ctx: TermPayContext) => void;
  refreshKey: number;
  /** Server exposes /Bcpg, whose term model can bill months with no invoice yet. */
  boostServer: boolean;
}) {
  const thisYear = new Date().getFullYear();
  const [year, setYear] = useState(thisYear);

  const accounts = useMemo(
    () =>
      [{ id: user.id, name: user.name }, ...siblings.map((s) => ({ id: s.id, name: s.text }))].filter(
        (a, i, arr) => arr.findIndex((x) => x.id === a.id) === i
      ),
    // user.name belongs here too — without it the sibling checklist kept showing the old name
    // after an Edit Profile rename, since user.id never changes.
    [user.id, user.name, siblings]
  );
  const [selAccts, setSelAccts] = useState<Set<number>>(new Set([user.id]));
  const [selMonths, setSelMonths] = useState<Set<number>>(new Set());

  const acctKey = [...selAccts].sort((a, b) => a - b).join(",");
  const terms = useApi(
    () =>
      selAccts.size
        ? api.fetchTermPayments({ studentIds: [...selAccts], year, months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] })
        : Promise.resolve([] as any[]),
    [year, acctKey, refreshKey]
  );
  // Month numbers mean different invoices in a different year, and different amounts for a
  // different set of siblings — carrying a selection across either change means the Pay button
  // bills months the user picked while looking at something else. Drop it on both.
  useEffect(() => {
    setSelMonths(new Set());
  }, [year, acctKey]);

  const rows = useMemo(() => (Array.isArray(terms.data) ? terms.data : []), [terms.data]);
  // Rows with a real invoiceId are billable by any gateway. Rows with invoiceId 0 are months
  // the academy hasn't invoiced yet: the legacy route can never charge them (probed live —
  // no PayTermPayments query binding makes the backend create those invoices), but /Bcpg
  // takes the term model in the body and bills them, so they are selectable on a Boost server.
  const invoicedRows = useMemo(() => rows.filter((r) => (r.invoiceId ?? 0) > 0), [rows]);
  const uninvoicedRows = useMemo(() => rows.filter((r) => !((r.invoiceId ?? 0) > 0)), [rows]);
  const uninvoicedMonths = useMemo(() => new Set(uninvoicedRows.map((r) => termMonth(r))), [uninvoicedRows]);
  const payableRows = boostServer ? rows : invoicedRows;
  const availMonths = useMemo(() => new Set(payableRows.map((r) => termMonth(r))), [payableRows]);
  // Months shown with a clock: known but not payable on this server.
  const upcomingMonths = useMemo(
    () => (boostServer ? new Set<number>() : uninvoicedMonths),
    [boostServer, uninvoicedMonths]
  );
  const chosen = payableRows.filter((r) => selMonths.has(termMonth(r)));
  const totalInvoices = chosen.length;
  const dueAmount = chosen.reduce((s, r) => s + (r.dueAmount || 0), 0);
  // Any chosen month without an invoice → the total is the academy's projected fee and the
  // gateway page shows the amount the backend actually bills.
  const estimated = chosen.some((r) => !((r.invoiceId ?? 0) > 0));

  const toggleMonth = (m: number) => {
    if (!availMonths.has(m)) {
      // Legacy servers charge only months whose invoice exists (verified live — the bill
      // always contained just the real invoiceIds).
      if (upcomingMonths.has(m)) {
        notify(
          `${MONTH_ABBR[m - 1]} ${year} — not billed yet`,
          "Your academy hasn't issued this month's invoice yet, so this server can't charge it. It becomes payable here automatically the moment the invoice is issued."
        );
      }
      return;
    }
    setSelMonths((prev) => {
      const n = new Set(prev);
      n.has(m) ? n.delete(m) : n.add(m);
      return n;
    });
  };
  const toggleAcct = (id: number) =>
    setSelAccts((prev) => {
      const n = new Set(prev);
      n.has(id) ? n.delete(id) : n.add(id);
      return n;
    });

  return (
    <View>
      <Text style={styles.tpTitle}>Advance Payment</Text>

      {/* Year selector */}
      <View style={styles.tpYearRow}>
        <TouchableOpacity disabled={year <= thisYear} onPress={() => setYear((y) => y - 1)} hitSlop={{ top: 6, bottom: 6, left: 6, right: 6 }} style={styles.calNav} testID="prepay-year-prev">
          <Ionicons name="chevron-back" size={18} color={year <= thisYear ? colors.textMuted : colors.primary} />
        </TouchableOpacity>
        <Text style={styles.tpYear}>{year}</Text>
        <TouchableOpacity onPress={() => setYear((y) => y + 1)} hitSlop={{ top: 6, bottom: 6, left: 6, right: 6 }} style={styles.calNav} testID="prepay-year-next">
          <Ionicons name="chevron-forward" size={18} color={colors.primary} />
        </TouchableOpacity>
      </View>

      <Text style={styles.tpLabel}>Select Month(s) to PAY</Text>
      {terms.loading ? (
        <ActivityIndicator color={colors.primary} style={{ marginVertical: 20 }} />
      ) : (
        <>
          <View style={styles.tpMonthGrid}>
            {MONTH_ABBR.map((abbr, i) => {
              const m = i + 1;
              const available = availMonths.has(m);
              const upcoming = !available && upcomingMonths.has(m);
              const selected = available && selMonths.has(m);
              // Payable, but the invoice doesn't exist yet — the amount is the academy's
              // projection until the gateway prices it.
              const projected = available && uninvoicedMonths.has(m);
              return (
                <TouchableOpacity
                  key={abbr}
                  // upcoming months stay tappable so the tap explains why they can't be paid yet
                  disabled={!available && !upcoming}
                  onPress={() => toggleMonth(m)}
                  style={styles.tpMonth}
                  testID={`prepay-month-${m}`}
                  activeOpacity={0.7}
                >
                  <Ionicons
                    name={selected ? "radio-button-on" : upcoming ? "time-outline" : "radio-button-off"}
                    size={20}
                    color={!available ? (upcoming ? colors.textMuted : colors.border) : selected ? colors.primary : colors.textMuted}
                  />
                  <Text style={[styles.tpMonthTxt, { color: available ? colors.textPrimary : colors.textMuted, fontWeight: available ? "700" : "500" }]}>
                    {abbr}
                    {projected ? "*" : ""}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
          {upcomingMonths.size > 0 && (
            <View style={styles.mpHintRow}>
              <Ionicons name="time-outline" size={15} color={colors.textSecondary} />
              <Text style={styles.mpHint}>
                Months with a clock haven&apos;t been billed by your academy yet — they become payable once the invoice is issued.
              </Text>
            </View>
          )}
          {boostServer && uninvoicedMonths.size > 0 && (
            <View style={styles.mpHintRow}>
              <Ionicons name="information-circle-outline" size={15} color={colors.textSecondary} />
              <Text style={styles.mpHint}>
                Months marked * haven&apos;t been invoiced yet. You can still pay them in advance — the amount shown is your academy&apos;s standard fee, and the payment page confirms the final amount before you pay.
              </Text>
            </View>
          )}
        </>
      )}

      <Text style={[styles.tpLabel, { marginTop: 20 }]}>Select Siblings to PAY</Text>
      {accounts.map((a) => {
        const on = selAccts.has(a.id);
        return (
          <TouchableOpacity key={a.id} onPress={() => toggleAcct(a.id)} style={styles.tpSibRow} testID={`prepay-acct-${a.id}`} activeOpacity={0.7}>
            <Ionicons name={on ? "checkmark-circle" : "ellipse-outline"} size={24} color={on ? colors.success : colors.textMuted} />
            <Text style={styles.tpSibName} numberOfLines={1}>{a.name.trim()}</Text>
          </TouchableOpacity>
        );
      })}

      <View style={styles.tpSummary}>
        <Text style={styles.tpSummaryTxt}>Total Month(s) : {totalInvoices}</Text>
        <Text style={styles.tpSummaryTxt}>
          {estimated ? "Est. Amt : " : "Due Amt : "}
          {dueAmount.toFixed(2)}
        </Text>
      </View>

      {totalInvoices > 0 ? (
        <TouchableOpacity
          testID="prepay-paynow"
          activeOpacity={0.9}
          onPress={() =>
            onPay({
              // Only real invoice ids go in `invoiceIds`; every selected month goes in the
              // term model, which is what bills the not-yet-invoiced ones on /Bcpg.
              ids: chosen.map((c) => c.invoiceId).filter((id) => (id ?? 0) > 0),
              total: dueAmount,
              studentIds: [...selAccts],
              year,
              months: [...new Set(chosen.map((c) => termMonth(c)))].filter((m) => m > 0),
              estimated,
            })
          }
        >
          <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.tpPayBtnActive}>
            <Ionicons name="lock-closed" size={14} color="#fff" />
            <Text style={styles.tpPayTxtActive}>
              Pay Now · {estimated ? "~" : ""}RM {dueAmount.toFixed(2)}
            </Text>
          </LinearGradient>
        </TouchableOpacity>
      ) : (
        <View style={styles.tpPayBtn} testID="prepay-paynow">
          <Text style={styles.tpPayTxt}>Select month(s) to pay</Text>
        </View>
      )}
    </View>
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
      paddingHorizontal: 4,
      borderRadius: radius.md,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
    },
    segActive: { backgroundColor: colors.primary },
    segTxt: { fontSize: 11, fontWeight: "700", color: colors.textSecondary },
    segTxtActive: { color: "#fff" },
    emptyTxt: { color: colors.textSecondary, fontSize: 13, textAlign: "center", marginVertical: 30 },

    // Account switcher chips (Task 5)
    autopayRow: {
      flexDirection: "row",
      alignItems: "center",
      gap: 12,
      backgroundColor: colors.surface,
      padding: 13,
      borderRadius: radius.md,
      marginBottom: 14,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    autopayIcon: {
      width: 36,
      height: 36,
      borderRadius: 18,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
      justifyContent: "center",
    },
    autopayTitle: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
    autopaySub: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },

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

    // Term Payment (prepay)
    calNav: { width: 40, height: 40, borderRadius: 20, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    tpTitle: { ...font.h3, color: colors.textPrimary, marginTop: 4, marginBottom: 14 },
    tpYearRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", backgroundColor: colors.surface, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, paddingHorizontal: 10, paddingVertical: 8, marginBottom: 18 },
    tpYear: { fontSize: 18, fontWeight: "800", color: colors.textPrimary },
    tpLabel: { fontSize: 15, fontWeight: "800", color: colors.textPrimary, marginBottom: 12 },
    tpMonthGrid: { flexDirection: "row", flexWrap: "wrap" },
    tpMonth: { width: "25%", flexDirection: "row", alignItems: "center", gap: 6, paddingVertical: 10 },
    tpMonthTxt: { fontSize: 14 },
    tpSibRow: { flexDirection: "row", alignItems: "center", gap: 12, paddingVertical: 10 },
    tpSibName: { fontSize: 15, fontWeight: "600", color: colors.textPrimary, flex: 1 },
    tpSummary: { flexDirection: "row", justifyContent: "space-between", marginTop: 18, marginBottom: 16 },
    tpSummaryTxt: { fontSize: 15, fontWeight: "800", color: colors.textPrimary },
    tpPayBtn: { backgroundColor: colors.surfaceAlt, borderRadius: radius.md, paddingVertical: 16, alignItems: "center", opacity: 0.7 },
    tpPayTxt: { fontSize: 15, fontWeight: "700", color: colors.textMuted },
    tpPayBtnActive: { flexDirection: "row", gap: 8, borderRadius: radius.md, paddingVertical: 16, alignItems: "center", justifyContent: "center" },
    tpPayTxtActive: { fontSize: 15, fontWeight: "800", color: "#fff" },

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
    mpHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
    mpClose: { width: 36, height: 36, borderRadius: 18, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    mpSummaryRow: { flexDirection: "row", justifyContent: "space-between", marginTop: 16, marginBottom: 18 },
    mpSummary: { fontSize: 14, color: colors.textSecondary, fontWeight: "600" },
    mpStrong: { color: colors.primary, fontWeight: "800" },
    // Stacked full-width option rows — a horizontal row of three labels overflows a 375px screen.
    mpMethods: { gap: 10, marginBottom: 18 },
    mpMethod: { flexDirection: "row", alignItems: "center", gap: 10, backgroundColor: colors.surfaceAlt, borderRadius: radius.md, paddingHorizontal: 14, paddingVertical: 13, borderWidth: 1.5, borderColor: "transparent" },
    mpMethodOn: { borderColor: colors.primary, backgroundColor: colors.primary + (mode === "dark" ? "26" : "12") },
    mpMethodLbl: { flex: 1, fontSize: 14.5, fontWeight: "700", color: colors.textPrimary },
    mpHintRow: { flexDirection: "row", gap: 10, alignItems: "center", backgroundColor: colors.surfaceAlt, borderRadius: radius.md, padding: 14, marginBottom: 16 },
    mpHint: { flex: 1, fontSize: 13, color: colors.textSecondary, lineHeight: 18 },
    mpLabel: { fontSize: 15, fontWeight: "800", color: colors.textPrimary, marginBottom: 12 },
    slipBox: { borderWidth: 1.5, borderStyle: "dashed", borderColor: colors.border, borderRadius: radius.lg, paddingVertical: 24, alignItems: "center", gap: 16, marginBottom: 16 },
    slipBtnRow: { flexDirection: "row", gap: 12 },
    slipBtn: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 18, paddingVertical: 10, borderRadius: radius.md, backgroundColor: colors.surfaceAlt, borderWidth: 1, borderColor: colors.border },
    slipBtnTxt: { color: colors.primary, fontWeight: "700", fontSize: 14 },
    slipPreviewWrap: { marginBottom: 16, borderRadius: radius.lg, overflow: "hidden", position: "relative" },
    slipPreview: { width: "100%", height: 180, borderRadius: radius.lg },
    slipRemove: { position: "absolute", top: 8, right: 8, backgroundColor: "#fff", borderRadius: 12 },
    mpPowered: { textAlign: "center", color: colors.textMuted, fontSize: 11, fontWeight: "700", letterSpacing: 1, marginTop: 14 },
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
