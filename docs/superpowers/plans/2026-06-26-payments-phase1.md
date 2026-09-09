# Payments (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Payments tab into a working flow where the student sees outstanding invoices (own + siblings), downloads real invoice/receipt PDFs, prepays upcoming months, and pays via the live Billplz gateway with a 2-minute countdown.

**Architecture:** Extend the existing `src/api/` layer (new endpoint functions + a cross-platform PDF download helper), then rebuild `app/(tabs)/payments.tsx` as a 3-segment screen (Pay / Prepay / History) with an account switcher and a selection cart. Payment opens the Billplz bill URL in the system browser and confirms via `Payment/Completed`. Data verified with node probes through the local CORS proxy; UI verified in the localhost web preview.

**Tech Stack:** Expo Router, React Native, react-native-web, `expo-web-browser` (installed), `expo-file-system` + `expo-sharing` (new, native PDF download). Live API `apimac.zyncbook.com` via `src/api/http.ts`.

---

## Verification environment (read once)

- **Proxy + web server** are launched by the preview MCP config `expo-web` (runs `start-web.js` → CORS proxy on :8082 + Expo web on :8081). If not running, start it; otherwise reuse.
- **Node probes** run from the scratchpad and hit the proxy (`http://localhost:8082`) or the API directly. Auth helper used throughout:

```js
// probe-auth.js (scratchpad) — returns a fresh bearer + user for the student test account
const BASE = process.env.PROXY ? "http://localhost:8082" : "http://apimac.zyncbook.com";
async function login(u = TEST_USER, p = TEST_PASSWORD) {
  const r = await fetch(BASE + "/Account/Authenticate", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ userType: 3, username: u, password: p, accessMethod: 0, branchId: 0 }),
  });
  const d = (await r.json()).data;
  return { BASE, token: d.accessToken, user: d };
}
module.exports = { login };
```

- Test accounts: the student test account (11 invoices, RM 900 due), `Aunty1`/the test password (siblings: TTT id 34655, KHAIRUL SHAMIN id 46908).
- Repo is **not** git-initialized yet — Task 0 fixes that so commit steps work.

---

## File Structure

- `Club-Management-Mobile-app-main/frontend/src/api/types.ts` — add `TermPayment`, `PayInvoicesResult` types (modify).
- `Club-Management-Mobile-app-main/frontend/src/api/endpoints.ts` — add `fetchTermPayments`, `payInvoices`, `paymentCompleted`, `receiptPdfUrl` (modify).
- `Club-Management-Mobile-app-main/frontend/src/api/download.ts` — new cross-platform authed PDF download helper (create).
- `Club-Management-Mobile-app-main/frontend/src/payments/usePaymentCart.ts` — new cart hook (create).
- `Club-Management-Mobile-app-main/frontend/app/(tabs)/payments.tsx` — rebuilt 3-segment screen (modify).

---

## Task 0: Project setup (git + native deps)

**Files:**
- Create: `Club-Management-Mobile-app-main/.gitignore` already exists; init repo at repo root.

- [ ] **Step 1: Initialize git at the project root so commits work**

Run from `D:/Club-Management-Mobile-app-main (1)/Club-Management-Mobile-app-main`:
```bash
git init
git add -A
git commit -m "chore: snapshot before payments phase 1"
```
Expected: a root commit is created. (If `git` reports identity missing, set `user.email`/`user.name` first.)

- [ ] **Step 2: Add native PDF-download deps via expo (pins compatible versions)**

Run from `frontend/`:
```bash
node node_modules/expo/bin/cli install expo-file-system expo-sharing
```
Expected: both added to `package.json` dependencies. (`expo-web-browser` is already present.)

- [ ] **Step 3: Commit**

```bash
git add frontend/package.json frontend/package-lock.json
git commit -m "chore: add expo-file-system + expo-sharing for native pdf download"
```

---

## Task 1: API endpoints for prepay, pay, confirm, receipt PDF

**Files:**
- Modify: `frontend/src/api/types.ts`
- Modify: `frontend/src/api/endpoints.ts`
- Test: `scratchpad/probe-pay.js`

- [ ] **Step 1: Add types**

Append to `frontend/src/api/types.ts`:
```ts
// POST /Outstanding/FetchTermPayments
export type TermPayment = {
  studentId: number;
  studentName?: string;
  year: number;
  month: number;
  period?: string;
  amount: number;
  invoiceType?: string;
};

// POST /Outstanding/PayInvoices → returns a Billplz bill URL (string) or { url }
export type PayInvoicesResult = { url?: string } | string;
```

- [ ] **Step 2: Add endpoint functions**

In `frontend/src/api/endpoints.ts`, add inside the `api` object (after `outstanding`):
```ts
  fetchTermPayments: (body: { studentIds: number[]; year: number; months: number[] }) =>
    http.post<import("./types").TermPayment[]>("/Outstanding/FetchTermPayments", body),

  // body = array of selected invoices (objects from Outstanding/Fetch). Query flags per swagger.
  payInvoices: (invoices: any[], opts?: { payTermPayments?: boolean }) =>
    http.post<import("./types").PayInvoicesResult>(
      `/Outstanding/PayInvoices?PayTermPayments=${opts?.payTermPayments ? "true" : "false"}`,
      invoices
    ),

  paymentCompleted: (status: string) =>
    http.get<any>(`/Payment/Completed/${encodeURIComponent(status)}`),

  // Authed PDF URL. paymentId for paid receipt, or 0 with invoiceId for an unpaid invoice.
  receiptPdfUrl: (clubId: number, paymentId: number, invoiceId: number) =>
    `${require("./config").API_BASE_URL}/Utilities/ReceiptAsPDF/${clubId}/${paymentId}/${invoiceId}`,
```

- [ ] **Step 3: Write the probe that drives the PayInvoices body shape**

Create `scratchpad/probe-pay.js`:
```js
const { login } = require("./probe-auth");
(async () => {
  process.env.PROXY = "1";
  const { BASE, token, user } = await login();
  const auth = { Authorization: "bearer " + token, "Content-Type": "application/json", accept: "*/*" };
  const range = { fromDate: "2024-01-01T00:00:00Z", toDate: "2026-12-31T00:00:00Z" };

  // 1) outstanding invoices
  const inv = await (await fetch(BASE + "/Outstanding/Fetch", { method: "POST", headers: auth,
    body: JSON.stringify({ studentId: user.id, startDate: range.fromDate, endDate: range.toDate }) })).json();
  const invoices = inv.data || [];
  console.log("invoices:", invoices.length, "first:", JSON.stringify(invoices[0]));

  // 2) PayInvoices with the FIRST invoice object as the body array — inspect what comes back.
  const r = await fetch(BASE + "/Outstanding/PayInvoices?PayTermPayments=false",
    { method: "POST", headers: auth, body: JSON.stringify([invoices[0]]) });
  const txt = await r.text();
  console.log("PayInvoices status:", r.status, "body:", txt.slice(0, 600));
})();
```

- [ ] **Step 4: Run the probe and record the real contract**

Run from `scratchpad/`: `node probe-pay.js`
Expected: prints invoices then a `PayInvoices` response. **Read the response**:
- If it returns a URL / `{ url }` / a bill id → that is the gateway URL; keep `payInvoices` as written (adjust the unwrap in Task 6 to match `string` vs `{url}`).
- If it returns `400 Invalid Request` → the body needs different keys. Try a minimal `[{ invoiceId, dueAmount }]` and then `{ invoices: [...] }`; update `payInvoices`'s body to whatever yields a URL. Record the working shape as a comment above `payInvoices`.

> This step intentionally resolves the one unknown contract by observation. Do not proceed to Task 6 until `PayInvoices` returns a usable URL and the body shape is recorded in code.

- [ ] **Step 5: Verify prepay + receipt-PDF endpoints**

Append to `probe-pay.js` and re-run:
```js
  const tp = await fetch(BASE + "/Outstanding/FetchTermPayments", { method: "POST", headers: auth,
    body: JSON.stringify({ studentIds: [user.id], year: 2026, months: [7,8,9,10,11,12] }) });
  console.log("TermPayments:", (await tp.json()).data?.length, "items");
  const pdf = await fetch(BASE + `/Utilities/ReceiptAsPDF/${user.clubId}/0/${invoices[0].invoiceId}`, { headers: { Authorization: "bearer " + token } });
  console.log("invoice PDF:", pdf.status, pdf.headers.get("content-type"));
```
Expected: TermPayments count printed (may be 0 for this student — fine), invoice PDF `200 Application/pdf`.

- [ ] **Step 6: Typecheck + commit**

Run from `frontend/`: `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json`
Expected: exit 0.
```bash
git add frontend/src/api/types.ts frontend/src/api/endpoints.ts
git commit -m "feat(api): add prepay, payInvoices, paymentCompleted, receiptPdfUrl"
```

---

## Task 2: Cross-platform authed PDF download helper

**Files:**
- Create: `frontend/src/api/download.ts`

- [ ] **Step 1: Implement the helper**

Create `frontend/src/api/download.ts`:
```ts
import { Platform } from "react-native";
import { getAuthToken } from "./http";

// Downloads an authed PDF. Web: fetch→blob→open in a new tab (works through the CORS proxy).
// Native: expo-file-system writes the file with the bearer header, then expo-sharing opens it.
export async function downloadPdf(url: string, filename: string): Promise<void> {
  const token = getAuthToken();
  const headers: Record<string, string> = { accept: "application/pdf" };
  if (token) headers["Authorization"] = "bearer " + token;

  if (Platform.OS === "web") {
    const res = await fetch(url, { headers });
    if (!res.ok) throw new Error(`Download failed (${res.status})`);
    const blob = await res.blob();
    const objectUrl = URL.createObjectURL(blob);
    if (typeof window !== "undefined") {
      const a = document.createElement("a");
      a.href = objectUrl;
      a.target = "_blank";
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
    }
    setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    return;
  }

  // Native
  const FileSystem = require("expo-file-system");
  const Sharing = require("expo-sharing");
  const dest = FileSystem.cacheDirectory + filename;
  const { uri, status } = await FileSystem.downloadAsync(url, dest, { headers });
  if (status !== 200) throw new Error(`Download failed (${status})`);
  if (await Sharing.isAvailableAsync()) await Sharing.shareAsync(uri, { mimeType: "application/pdf" });
}
```

- [ ] **Step 2: Typecheck**

Run from `frontend/`: `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json`
Expected: exit 0. (If TS complains about `require("expo-file-system")` types, that's fine — these are native-only requires; no type stubs needed since they aren't imported at top level.)

- [ ] **Step 3: Commit**

```bash
git add frontend/src/api/download.ts
git commit -m "feat(api): cross-platform authed PDF download helper"
```

---

## Task 3: Selection cart hook

**Files:**
- Create: `frontend/src/payments/usePaymentCart.ts`

- [ ] **Step 1: Implement the cart**

Create `frontend/src/payments/usePaymentCart.ts`:
```ts
import { useCallback, useMemo, useState } from "react";
import type { Invoice } from "../api/types";

// A cart item is a real invoice plus the account it belongs to and whether it is a prepay term.
export type CartItem = {
  key: string;            // unique: `${studentId}:${invoiceId}` or `term:${studentId}:${year}-${month}`
  studentId: number;
  studentName: string;
  invoice: Invoice;       // for prepay terms, a synthesized Invoice-shaped object
  isTerm: boolean;
};

export function usePaymentCart() {
  const [items, setItems] = useState<Record<string, CartItem>>({});

  const has = useCallback((key: string) => key in items, [items]);

  const toggle = useCallback((item: CartItem) => {
    setItems((prev) => {
      const next = { ...prev };
      if (next[item.key]) delete next[item.key];
      else next[item.key] = item;
      return next;
    });
  }, []);

  const clear = useCallback(() => setItems({}), []);

  const list = useMemo(() => Object.values(items), [items]);
  const total = useMemo(() => list.reduce((s, i) => s + (i.invoice.dueAmount || 0), 0), [list]);
  const hasTerm = useMemo(() => list.some((i) => i.isTerm), [list]);

  return { items: list, total, hasTerm, has, toggle, clear };
}
```

- [ ] **Step 2: Typecheck + commit**

Run from `frontend/`: `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json`
Expected: exit 0.
```bash
git add frontend/src/payments/usePaymentCart.ts
git commit -m "feat(payments): selection cart hook"
```

---

## Task 4: Payments screen — Pay segment (invoices + per-invoice PDF download)

**Files:**
- Modify: `frontend/app/(tabs)/payments.tsx` (full rewrite; keep existing imports/style patterns)

- [ ] **Step 1: Rewrite payments.tsx with segments + Pay list + per-invoice download**

Replace the whole file with the version below. (Account switcher, prepay, and pay-sheet land in Tasks 5-6; this step establishes the segmented shell, the Pay list with checkboxes, and invoice PDF download.)
```tsx
import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Alert } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
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
  const cart = usePaymentCart();
  const [seg, setSeg] = useState<Seg>("pay");
  const [busyPdf, setBusyPdf] = useState<string | null>(null);

  const range = useMemo(() => defaultRange(), []);
  const dues = useApi(
    () => api.outstanding({ studentId: user?.id ?? null, startDate: range.fromDate, endDate: range.toDate }),
    [user?.id]
  );
  const history = useApi(() => api.receipts({ fromDate: range.fromDate, toDate: range.toDate }), []);

  const invoices = dues.data ?? [];

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

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <Text style={styles.title}>Fees & Payments</Text>
          <TouchableOpacity style={styles.iconBtn} onPress={() => { dues.reload(); history.reload(); }}>
            <Ionicons name="refresh-outline" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
        <View style={styles.segRow}>
          {(["pay", "prepay", "history"] as Seg[]).map((s) => (
            <TouchableOpacity key={s} style={[styles.seg, seg === s && styles.segActive]} onPress={() => setSeg(s)} testID={`pay-seg-${s}`}>
              <Text style={[styles.segTxt, seg === s && styles.segTxtActive]}>{s === "pay" ? "Pay" : s === "prepay" ? "Prepay" : "History"}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 160 }} showsVerticalScrollIndicator={false}>
        {seg === "pay" && (
          <>
            {dues.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />}
            {!dues.loading && invoices.length === 0 && <Text style={styles.emptyTxt}>No outstanding invoices.</Text>}
            {invoices.map((inv, idx) => {
              const key = `${user?.id}:${inv.invoiceId}`;
              const selected = cart.has(key);
              const item: CartItem = { key, studentId: user!.id, studentName: inv.studentName, invoice: inv, isTerm: false };
              return (
                <View key={inv.invoiceId ?? idx} style={[styles.invCard, selected && styles.invCardSel]} testID={`invoice-${inv.invoiceId}`}>
                  <TouchableOpacity style={styles.invMain} onPress={() => cart.toggle(item)} activeOpacity={0.8}>
                    <Ionicons name={selected ? "checkbox" : "square-outline"} size={22} color={selected ? colors.primary : colors.textMuted} />
                    <View style={{ flex: 1, marginLeft: 10 }}>
                      <View style={styles.invTopRow}>
                        <Text style={styles.invNo}>#{inv.invoiceId}</Text>
                        <Text style={styles.invType}>{inv.transactionType}</Text>
                      </View>
                      <Text style={styles.invDesc} numberOfLines={1}>{inv.invoiceDescription || inv.period}</Text>
                      <Text style={styles.invMeta}>{inv.period} · {fmtDate(inv.invoiceDate)} · {inv.paymentStatus}</Text>
                    </View>
                    <Text style={styles.invAmt}>RM {(inv.dueAmount || 0).toLocaleString()}</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.invDownload}
                    testID={`invoice-pdf-${inv.invoiceId}`}
                    disabled={busyPdf === key}
                    onPress={() => openPdf(key, api.receiptPdfUrl(user!.clubId, 0, inv.invoiceId), `INVOICE_${inv.invoiceId}.pdf`)}
                  >
                    {busyPdf === key ? <ActivityIndicator size="small" color={colors.primary} /> : (
                      <><Ionicons name="document-text-outline" size={14} color={colors.primary} /><Text style={styles.invDownloadTxt}>Invoice PDF</Text></>
                    )}
                  </TouchableOpacity>
                </View>
              );
            })}
          </>
        )}

        {seg === "history" && (
          <>
            {history.loading && <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />}
            {!history.loading && (history.data?.length ?? 0) === 0 && <Text style={styles.emptyTxt}>No receipts found.</Text>}
            {(history.data ?? []).map((p, idx) => {
              const k = `rec-${p.id}-${idx}`;
              return (
                <View key={k} style={styles.invCard} testID={`payment-${p.id}`}>
                  <View style={styles.invMain}>
                    <View style={[styles.recIcon]}><Ionicons name="checkmark" size={16} color={colors.success} /></View>
                    <View style={{ flex: 1, marginLeft: 10 }}>
                      <Text style={styles.invDesc} numberOfLines={1}>{p.paymentMethod}</Text>
                      <Text style={styles.invMeta}>{fmtDate(p.receiptDate)} · {p.tcName} · #{p.receiptNo}</Text>
                    </View>
                    <Text style={styles.invAmt}>RM {(p.receiptAmount || 0).toLocaleString()}</Text>
                  </View>
                  <TouchableOpacity
                    style={styles.invDownload}
                    testID={`receipt-pdf-${p.id}`}
                    disabled={busyPdf === k}
                    onPress={() => openPdf(k, api.receiptPdfUrl(user!.clubId, p.id, 0), `RECEIPT_${p.receiptNo}.pdf`)}
                  >
                    {busyPdf === k ? <ActivityIndicator size="small" color={colors.primary} /> : (
                      <><Ionicons name="download-outline" size={14} color={colors.primary} /><Text style={styles.invDownloadTxt}>Receipt PDF</Text></>
                    )}
                  </TouchableOpacity>
                </View>
              );
            })}
          </>
        )}

        {seg === "prepay" && <Text style={styles.emptyTxt}>Prepay — added in Task 5.</Text>}
      </ScrollView>

      {cart.items.length > 0 && (
        <View style={styles.payBar}>
          <View style={{ flex: 1 }}>
            <Text style={styles.payBarLbl}>{cart.items.length} selected</Text>
            <Text style={styles.payBarTotal}>RM {cart.total.toLocaleString()}</Text>
          </View>
          <TouchableOpacity style={styles.payBarBtnWrap} testID="pay-open-sheet" onPress={() => Alert.alert("Pay", "Pay sheet — added in Task 6.")}>
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.payBarBtn}>
              <Text style={styles.payBarBtnTxt}>Pay</Text>
              <Ionicons name="arrow-forward" size={16} color="#fff" />
            </LinearGradient>
          </TouchableOpacity>
        </View>
      )}
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingHorizontal: spacing.xl, paddingVertical: 14 },
    title: { ...font.h1, color: colors.textPrimary, fontSize: 26 },
    iconBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    segRow: { flexDirection: "row", gap: 8, paddingHorizontal: spacing.xl, paddingBottom: 12 },
    seg: { flex: 1, paddingVertical: 9, borderRadius: radius.md, backgroundColor: colors.surfaceAlt, alignItems: "center" },
    segActive: { backgroundColor: colors.primary },
    segTxt: { fontSize: 13, fontWeight: "700", color: colors.textSecondary },
    segTxtActive: { color: "#fff" },
    emptyTxt: { color: colors.textSecondary, fontSize: 13, textAlign: "center", marginVertical: 30 },

    invCard: { backgroundColor: colors.surface, borderRadius: radius.lg, marginBottom: 10, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border, overflow: "hidden" },
    invCardSel: { borderWidth: 1.5, borderColor: colors.primary },
    invMain: { flexDirection: "row", alignItems: "center", padding: 14 },
    invTopRow: { flexDirection: "row", justifyContent: "space-between" },
    invNo: { fontSize: 11, color: colors.textSecondary, fontWeight: "700" },
    invType: { fontSize: 11, color: colors.primary, fontWeight: "700" },
    invDesc: { fontSize: 14, color: colors.textPrimary, fontWeight: "700", marginTop: 2 },
    invMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
    invAmt: { fontSize: 15, color: colors.textPrimary, fontWeight: "800", marginLeft: 8 },
    invDownload: { flexDirection: "row", gap: 5, alignItems: "center", justifyContent: "center", paddingVertical: 9, borderTopWidth: 1, borderTopColor: colors.border },
    invDownloadTxt: { color: colors.primary, fontSize: 12, fontWeight: "700" },
    recIcon: { width: 30, height: 30, borderRadius: 15, backgroundColor: mode === "dark" ? "#064E3B" : "#D1FAE5", alignItems: "center", justifyContent: "center" },

    payBar: { position: "absolute", left: 0, right: 0, bottom: 0, flexDirection: "row", alignItems: "center", gap: 12, paddingHorizontal: spacing.xl, paddingTop: 12, paddingBottom: 28, backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border },
    payBarLbl: { fontSize: 11, color: colors.textSecondary, fontWeight: "600" },
    payBarTotal: { fontSize: 20, color: colors.textPrimary, fontWeight: "800" },
    payBarBtnWrap: { borderRadius: radius.md, overflow: "hidden" },
    payBarBtn: { flexDirection: "row", gap: 8, alignItems: "center", paddingHorizontal: 28, paddingVertical: 14 },
    payBarBtnTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },
  });
}
```

- [ ] **Step 2: Typecheck**

Run from `frontend/`: `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json`
Expected: exit 0.

- [ ] **Step 3: Verify in the web preview**

Ensure the `expo-web` preview is running (proxy + web). In the preview (mobile viewport), log in as the student test account, open Payments. Screenshot.
Expected: "Pay / Prepay / History" segments; Pay shows the 11 invoices with checkboxes + "Invoice PDF" buttons; selecting invoices shows the bottom Pay bar with a running total. Click an "Invoice PDF" button → a PDF opens/downloads in a new browser tab (real `%PDF`). Click "History" → receipts with "Receipt PDF" buttons that also open real PDFs.

- [ ] **Step 4: Commit**

```bash
git add frontend/app/(tabs)/payments.tsx
git commit -m "feat(payments): segmented screen, invoice list, invoice/receipt PDF download"
```

---

## Task 5: Prepay segment + account switcher (siblings)

**Files:**
- Modify: `frontend/app/(tabs)/payments.tsx`

- [ ] **Step 1: Add the account switcher state + data**

Add near the other hooks in `Payments()`:
```tsx
  const siblings = useApi(() => api.mySiblings(), []);
  const [activeAccount, setActiveAccount] = useState<{ id: number; name: string } | null>(null);
  const accountId = activeAccount?.id ?? user?.id ?? null;
```
Change the `dues` hook to use `accountId` and depend on it:
```tsx
  const dues = useApi(
    () => api.outstanding({ studentId: accountId, startDate: range.fromDate, endDate: range.toDate }),
    [accountId]
  );
```
Set the initial account once the user is known (add an effect):
```tsx
  // default the active account to the logged-in student
  useMemo(() => { if (user && !activeAccount) setActiveAccount({ id: user.id, name: user.name }); }, [user]);
```

- [ ] **Step 2: Render account chips above the Pay list**

Inside the `seg === "pay"` block, before the invoices map:
```tsx
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
              {[{ id: user!.id, name: user!.name }, ...((siblings.data ?? []).map((s) => ({ id: s.id, name: s.text })))]
                .filter((a, i, arr) => arr.findIndex((x) => x.id === a.id) === i)
                .map((a) => {
                  const on = accountId === a.id;
                  return (
                    <TouchableOpacity key={a.id} style={[styles.chip, on && styles.chipOn]} onPress={() => setActiveAccount(a)} testID={`acct-${a.id}`}>
                      <Ionicons name="person-circle-outline" size={16} color={on ? "#fff" : colors.primary} />
                      <Text style={[styles.chipTxt, on && { color: "#fff" }]} numberOfLines={1}>{a.name.trim()}</Text>
                    </TouchableOpacity>
                  );
                })}
            </ScrollView>
```
Update the cart item built in the invoice map to use the active account:
```tsx
                const item: CartItem = { key, studentId: accountId!, studentName: inv.studentName, invoice: inv, isTerm: false };
```
and change `key` to `const key = `${accountId}:${inv.invoiceId}`;`

- [ ] **Step 3: Implement the Prepay segment**

Replace the `seg === "prepay"` placeholder with:
```tsx
        {seg === "prepay" && <PrepaySegment accountId={accountId!} accountName={activeAccount?.name || user!.name} cart={cart} styles={styles} colors={colors} />}
```
Add the `PrepaySegment` component below `Payments()`:
```tsx
function PrepaySegment({ accountId, accountName, cart, styles, colors }: any) {
  const year = new Date().getFullYear();
  const months = [...Array(12)].map((_, i) => i + 1);
  const terms = useApi(() => api.fetchTermPayments({ studentIds: [accountId], year, months }), [accountId]);
  const data = terms.data ?? [];
  if (terms.loading) return <ActivityIndicator color={colors.primary} style={{ marginVertical: 24 }} />;
  if (data.length === 0) return <Text style={styles.emptyTxt}>No upcoming months available to prepay for this account.</Text>;
  return (
    <>
      {data.map((t: any, i: number) => {
        const key = `term:${accountId}:${t.year}-${t.month}`;
        const selected = cart.has(key);
        const invoiceShim = { invoiceId: -1 * (t.month + t.year), dueAmount: t.amount, studentName: accountName,
          invoiceDescription: t.period || `${t.invoiceType || "Fee"} ${t.month}/${t.year}`, period: t.period || `${t.month}/${t.year}`,
          transactionType: t.invoiceType || "Prepay", invoiceDate: `${t.year}-${String(t.month).padStart(2,"0")}-01`, paymentStatus: "Advance" };
        const item = { key, studentId: accountId, studentName: accountName, invoice: invoiceShim, isTerm: true };
        return (
          <TouchableOpacity key={key} style={[styles.invCard, selected && styles.invCardSel, { padding: 14, flexDirection: "row", alignItems: "center" }]} onPress={() => cart.toggle(item)} testID={`term-${key}`}>
            <Ionicons name={selected ? "checkbox" : "square-outline"} size={22} color={selected ? colors.primary : colors.textMuted} />
            <View style={{ flex: 1, marginLeft: 10 }}>
              <Text style={styles.invDesc}>{invoiceShim.invoiceDescription}</Text>
              <Text style={styles.invMeta}>{invoiceShim.period} · Advance</Text>
            </View>
            <Text style={styles.invAmt}>RM {(t.amount || 0).toLocaleString()}</Text>
          </TouchableOpacity>
        );
      })}
    </>
  );
}
```
Add `mySiblings` to `endpoints.ts` only if missing (it already exists as `api.mySiblings`). Add chip styles to `createStyles`:
```tsx
    chipRow: { gap: 8, paddingBottom: 12 },
    chip: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 12, paddingVertical: 8, borderRadius: radius.full, backgroundColor: colors.surfaceAlt, borderWidth: 1, borderColor: colors.border, maxWidth: 160 },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipTxt: { fontSize: 12, fontWeight: "700", color: colors.textPrimary },
```

- [ ] **Step 4: Typecheck**

Run from `frontend/`: `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json`
Expected: exit 0.

- [ ] **Step 5: Verify in preview**

Log in as `Aunty1`/the test password (has siblings). Payments → Pay: account chips show ROY + TTT + KHAIRUL SHAMIN; tapping a sibling reloads that account's invoices; selecting invoices from two accounts both appear in the bottom total. Prepay tab lists advance months (or the empty message). Screenshot each.
Expected: account switching works; cart total spans accounts; prepay lists items or the empty state.

- [ ] **Step 6: Commit**

```bash
git add frontend/app/(tabs)/payments.tsx
git commit -m "feat(payments): sibling account switcher + prepay segment"
```

---

## Task 6: Pay sheet, 2-minute countdown, gateway handoff, confirm

**Files:**
- Modify: `frontend/app/(tabs)/payments.tsx`

- [ ] **Step 1: Add pay-sheet + countdown state and the pay routine**

Add imports at top: `import { Modal } from "react-native";` and `import * as WebBrowser from "expo-web-browser";`.
Add state in `Payments()`:
```tsx
  const [sheet, setSheet] = useState(false);
  const [method, setMethod] = useState("card");
  const [paying, setPaying] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(120);
```
Add the countdown effect + pay routine:
```tsx
  // 2-minute countdown while the pay sheet is processing a bill
  useEffect(() => {
    if (!paying) return;
    if (secondsLeft <= 0) { setPaying(false); setSheet(false); Alert.alert("Session expired", "Payment session timed out. Please try again."); return; }
    const t = setTimeout(() => setSecondsLeft((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [paying, secondsLeft]);

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
      Alert.alert("Payment", result?.type === "cancel" ? "Returned from gateway. Refreshing your invoices." : "Thank you. Refreshing your invoices.");
    } catch (e: any) {
      setPaying(false);
      Alert.alert("Payment failed", e?.message || "Could not start the payment.");
    }
  }
```
Also add `import { useEffect } from "react";` to the React import.

- [ ] **Step 2: Wire the Pay bar button to open the sheet**

Change the pay-bar button `onPress` from the Task-4 placeholder to:
```tsx
          <TouchableOpacity style={styles.payBarBtnWrap} testID="pay-open-sheet" onPress={() => { setSecondsLeft(120); setSheet(true); }}>
```

- [ ] **Step 3: Add the pay sheet modal before the closing `</View>` of root**

```tsx
      <Modal visible={sheet} transparent animationType="slide" onRequestClose={() => !paying && setSheet(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalCard}>
            <View style={styles.modalHandle} />
            <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
              <Text style={styles.modalTitle}>Complete Payment</Text>
              {paying && <Text style={styles.countdown}>{String(Math.floor(secondsLeft / 60)).padStart(1, "0")}:{String(secondsLeft % 60).padStart(2, "0")}</Text>}
            </View>
            <Text style={styles.modalAmt}>RM {cart.total.toLocaleString()}</Text>
            {[{ id: "card", label: "Credit / Debit Card", icon: "card" }, { id: "fpx", label: "FPX / eWallet", icon: "phone-portrait" }, { id: "bank", label: "Bank Transfer", icon: "business" }].map((m) => (
              <TouchableOpacity key={m.id} disabled={paying} onPress={() => setMethod(m.id)} style={[styles.methodRow, method === m.id && styles.methodRowActive]} testID={`pay-method-${m.id}`}>
                <View style={[styles.methodIcon, method === m.id && { backgroundColor: colors.primary }]}><Ionicons name={m.icon as any} size={18} color={method === m.id ? "#fff" : colors.primary} /></View>
                <Text style={styles.methodLbl}>{m.label}</Text>
                <Ionicons name={method === m.id ? "radio-button-on" : "radio-button-off"} size={20} color={method === m.id ? colors.primary : colors.textMuted} />
              </TouchableOpacity>
            ))}
            <TouchableOpacity onPress={confirmPay} disabled={paying} activeOpacity={0.9} testID="pay-confirm-btn">
              <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.confirmBtn, shadow.strong]}>
                {paying ? <ActivityIndicator color="#fff" /> : (<><Ionicons name="lock-closed" size={14} color="#fff" /><Text style={styles.confirmTxt}>Confirm & Pay Securely</Text></>)}
              </LinearGradient>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => !paying && setSheet(false)} style={{ marginTop: 10, alignSelf: "center" }}><Text style={{ color: colors.textSecondary, fontSize: 13 }}>Cancel</Text></TouchableOpacity>
          </View>
        </View>
      </Modal>
```

- [ ] **Step 4: Add the modal styles to `createStyles`**

```tsx
    modalOverlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: "flex-end" },
    modalCard: { backgroundColor: colors.surface, borderTopLeftRadius: 28, borderTopRightRadius: 28, padding: 22, paddingBottom: 36 },
    modalHandle: { width: 40, height: 4, backgroundColor: colors.border, borderRadius: 2, alignSelf: "center", marginBottom: 18 },
    modalTitle: { ...font.h2, color: colors.textPrimary },
    countdown: { fontSize: 18, fontWeight: "800", color: colors.primary },
    modalAmt: { ...font.h1, color: colors.primary, fontSize: 32, marginTop: 12, marginBottom: 10 },
    methodRow: { flexDirection: "row", gap: 12, alignItems: "center", padding: 14, borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, marginBottom: 10 },
    methodRowActive: { borderColor: colors.primary, backgroundColor: colors.surfaceAlt },
    methodIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    methodLbl: { flex: 1, fontSize: 14, color: colors.textPrimary, fontWeight: "600" },
    confirmBtn: { flexDirection: "row", gap: 8, paddingVertical: 16, borderRadius: radius.md, alignItems: "center", justifyContent: "center", marginTop: 10, minHeight: 52 },
    confirmTxt: { color: "#fff", fontWeight: "800", fontSize: 14 },
```

- [ ] **Step 5: Typecheck**

Run from `frontend/`: `node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json`
Expected: exit 0.

- [ ] **Step 6: Verify**

Web preview: select invoices → Pay → sheet opens with method options + RM total. Tapping Confirm starts the countdown (shows `2:00` ticking down) and calls `PayInvoices`. On web the gateway opens in a new tab (or logs the URL). Screenshot the sheet with the running countdown.
Native/logs: confirm `WebBrowser.openBrowserAsync` opens the Billplz page and returning to the app refreshes invoices.
Expected: countdown visible and decrementing; `PayInvoices` returns a URL (verified in Task 1); no crash; cart clears on return.

- [ ] **Step 7: Commit**

```bash
git add frontend/app/(tabs)/payments.tsx
git commit -m "feat(payments): pay sheet, 2-min countdown, Billplz gateway handoff + confirm"
```

---

## Self-review notes (already applied)

- **Spec coverage:** invoices shown (T4) ✓, invoice PDF download (T4) ✓, receipt PDF download (T4) ✓, prepay (T5) ✓, sibling accounts (T5) ✓, select-invoice-then-pay (T4+T6) ✓, 2-min countdown (T6) ✓, real gateway via external browser (T6) ✓.
- **Open contract:** `PayInvoices` body is resolved by observation in T1S4 before T6 depends on it.
- **Type consistency:** `CartItem`, `api.receiptPdfUrl(clubId,paymentId,invoiceId)`, `downloadPdf(url,filename)`, `api.payInvoices(invoices,opts)` used consistently across tasks.
- **No-test-framework note:** verification uses node probes + preview screenshots (the established pattern this session), not jest.

## Out of scope (own plans later)

Home phase (notifications + Quick Access grid + health stats) and Settings phase (edit profile + photo) — separate plans after Payments lands.
