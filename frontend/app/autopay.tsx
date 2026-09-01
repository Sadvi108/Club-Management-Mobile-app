import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { confirmDialog, notify, safeBack } from "../src/ui/dialogs";
import {
  PLACEHOLDER_HISTORY,
  PLACEHOLDER_PLAN,
  PLACEHOLDER_UPCOMING,
  FREQUENCY_LABEL,
  fmtDate,
  fmtMoney,
  type AutopayCharge,
  type AutopayStatus,
  type ChargeStatus,
} from "../src/payments/autopay";

// Auto Pay — recurring payment overview. UI SHELL: renders placeholder data and
// every action is a no-op that says so. See src/payments/autopay.ts for the
// wiring checklist and the routes this screen expects.

const STATUS_META: Record<
  ChargeStatus,
  { icon: keyof typeof Ionicons.glyphMap; tone: "success" | "danger" | "warning" | "muted"; label: string }
> = {
  paid: { icon: "checkmark-circle", tone: "success", label: "Paid" },
  scheduled: { icon: "time-outline", tone: "muted", label: "Scheduled" },
  failed: { icon: "alert-circle", tone: "danger", label: "Failed" },
  skipped: { icon: "remove-circle-outline", tone: "warning", label: "Skipped" },
};

export default function Autopay() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  // TODO(autopay): replace with useApi(() => api.autopayPlan(), []) — null when never enrolled.
  const plan = PLACEHOLDER_PLAN;
  // Local only so the shell can demo the pause/resume affordance. The real screen
  // must take status from the server response after POST /Autopay/SetStatus, never
  // from local state — a mandate can be revoked at the gateway without the app knowing.
  const [status, setStatus] = useState<AutopayStatus>(plan.status);

  // TODO(autopay): replace with api.autopaySchedule() / api.autopayCharges().
  const upcoming = PLACEHOLDER_UPCOMING;
  const history = PLACEHOLDER_HISTORY;

  const active = status === "active";
  const enrolled = status !== "none";

  const toneColor = (tone: "success" | "danger" | "warning" | "muted") =>
    tone === "success" ? colors.success : tone === "danger" ? colors.danger : tone === "warning" ? colors.warning : colors.textMuted;

  async function onToggleStatus() {
    if (active) {
      const ok = await confirmDialog(
        "Pause auto pay?",
        "Scheduled charges won't be taken until you resume. You'll need to pay those months yourself."
      );
      if (!ok) return;
      setStatus("paused");
    } else {
      setStatus("active");
    }
    // TODO(autopay): await api.autopaySetStatus({ planId: plan.id, status }) and
    // re-read the plan from the response instead of trusting this local flip.
    notify("Not connected yet", "Auto pay isn't wired to the payment API yet, so this change isn't saved.");
  }

  async function onCancel() {
    const ok = await confirmDialog(
      "Cancel auto pay?",
      "This removes the standing instruction with your bank or e-wallet. You can set it up again at any time.",
      { confirmLabel: "Cancel auto pay", cancelLabel: "Keep it", destructive: true }
    );
    if (!ok) return;
    // TODO(autopay): await api.autopayCancel({ planId: plan.id }), then refetch.
    notify("Not connected yet", "Auto pay isn't wired to the payment API yet, so nothing was cancelled.");
  }

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => safeBack(router, "/(tabs)/payments")} testID="autopay-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Auto Pay</Text>
          <TouchableOpacity
            style={styles.backBtn}
            onPress={() =>
              notify(
                "About auto pay",
                "Auto pay settles your monthly fee automatically on the day you choose, so you never miss a due date. You can pause or cancel it at any time."
              )
            }
            testID="autopay-help"
          >
            <Ionicons name="help-circle-outline" size={20} color={colors.primary} />
          </TouchableOpacity>
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        {/* Shell notice + state switcher — remove BOTH once the routes exist. The switcher
            exists so the not-yet-enrolled state is reviewable without editing code; with a
            real API the state comes from whether the plan fetch returns a plan or null. */}
        <View style={styles.preview}>
          <View style={styles.previewHead}>
            <Ionicons name="construct-outline" size={16} color={colors.warning} />
            <Text style={styles.previewTxt}>
              Preview only — auto pay isn&apos;t connected to the payment API yet. The figures below are sample data.
            </Text>
          </View>
          <View style={styles.previewSwitch}>
            {(["active", "paused", "none"] as AutopayStatus[]).map((s) => (
              <TouchableOpacity
                key={s}
                style={[styles.previewOpt, status === s && styles.previewOptOn]}
                onPress={() => setStatus(s)}
                testID={`autopay-preview-${s}`}
              >
                <Text style={[styles.previewOptTxt, status === s && styles.previewOptTxtOn]}>
                  {s === "none" ? "Not set up" : s === "active" ? "Active" : "Paused"}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {enrolled ? (
          <LinearGradient
            colors={active ? colors.gradient : ([colors.textMuted, colors.textSecondary] as unknown as readonly [string, string])}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={[styles.heroCard, shadow.strong]}
          >
            <View style={styles.heroTop}>
              <View style={styles.statusPill}>
                <View style={[styles.dot, { backgroundColor: active ? "#BBF7D0" : "#FDE68A" }]} />
                <Text style={styles.statusTxt}>{active ? "Active" : "Paused"}</Text>
              </View>
              <Text style={styles.heroFreq}>{FREQUENCY_LABEL[plan.frequency]}</Text>
            </View>

            <Text style={styles.heroAmount}>{fmtMoney(plan.amount)}</Text>
            <Text style={styles.heroFor} numberOfLines={1}>
              for {plan.studentName.trim()}
            </Text>

            <View style={styles.heroMetaRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.heroMetaLbl}>{active ? "Next charge" : "Paused since"}</Text>
                <Text style={styles.heroMetaVal} numberOfLines={1}>
                  {active ? fmtDate(plan.nextChargeDate) : "—"}
                </Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.heroMetaLbl}>Method</Text>
                <Text style={styles.heroMetaVal} numberOfLines={1}>
                  {plan.methodLabel}
                </Text>
              </View>
            </View>

            <View style={styles.heroBtns}>
              <TouchableOpacity style={styles.heroBtn} onPress={onToggleStatus} testID="autopay-toggle">
                <Ionicons name={active ? "pause" : "play"} size={16} color="#fff" />
                <Text style={styles.heroBtnTxt}>{active ? "Pause" : "Resume"}</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.heroBtn}
                onPress={() => router.push("/autopay-setup")}
                testID="autopay-manage"
              >
                <Ionicons name="create-outline" size={16} color="#fff" />
                <Text style={styles.heroBtnTxt}>Manage</Text>
              </TouchableOpacity>
            </View>
          </LinearGradient>
        ) : (
          <View style={[styles.emptyCard, shadow.card]}>
            <View style={styles.emptyIcon}>
              <Ionicons name="sync-circle-outline" size={30} color={colors.primary} />
            </View>
            <Text style={styles.emptyTitle}>Never miss a payment</Text>
            <Text style={styles.emptySub}>
              Set up auto pay and your monthly fee is settled automatically on the day you choose.
            </Text>
            <TouchableOpacity onPress={() => router.push("/autopay-setup")} testID="autopay-enable">
              <LinearGradient
                colors={colors.gradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={[styles.cta, shadow.strong]}
              >
                <Ionicons name="add-circle-outline" size={18} color="#fff" />
                <Text style={styles.ctaTxt}>Set up auto pay</Text>
              </LinearGradient>
            </TouchableOpacity>
          </View>
        )}

        {enrolled && (
          <>
            <Text style={styles.section}>Scheduled</Text>
            {!active && (
              <Text style={styles.pausedNote}>
                Auto pay is paused, so these charges won&apos;t be taken. Resume to put them back on schedule.
              </Text>
            )}
            {upcoming.length === 0 ? (
              <Text style={styles.emptyTxt}>No scheduled charges.</Text>
            ) : (
              upcoming.map((c) => (
                <ChargeRow
                  key={c.id}
                  charge={c}
                  styles={styles}
                  dim={!active}
                  toneColor={toneColor}
                  fallbackMeta={plan.methodLabel}
                />
              ))
            )}

            <Text style={styles.section}>Recent charges</Text>
            {history.length === 0 ? (
              <Text style={styles.emptyTxt}>No charges yet.</Text>
            ) : (
              history.map((c) => <ChargeRow key={c.id} charge={c} styles={styles} toneColor={toneColor} />)
            )}

            <TouchableOpacity style={styles.cancelBtn} onPress={onCancel} testID="autopay-cancel">
              <Ionicons name="close-circle-outline" size={18} color={colors.danger} />
              <Text style={styles.cancelTxt}>Cancel auto pay</Text>
            </TouchableOpacity>
          </>
        )}
      </ScrollView>
    </View>
  );
}

function ChargeRow({
  charge,
  styles,
  dim,
  toneColor,
  fallbackMeta,
}: {
  charge: AutopayCharge;
  styles: ReturnType<typeof createStyles>;
  dim?: boolean;
  toneColor: (t: "success" | "danger" | "warning" | "muted") => string;
  /** Subtitle for a charge with nothing else to say — the status is already shown on the right. */
  fallbackMeta?: string;
}) {
  const meta = STATUS_META[charge.status];
  const color = toneColor(meta.tone);
  return (
    <View style={[styles.row, dim && { opacity: 0.55 }]}>
      <View style={[styles.rowIcon, { backgroundColor: color + "1A" }]}>
        <Ionicons name={meta.icon} size={19} color={color} />
      </View>
      <View style={{ flex: 1 }}>
        <Text style={styles.rowTitle} numberOfLines={1}>
          {fmtDate(charge.dueDate)}
        </Text>
        <Text style={styles.rowMeta} numberOfLines={1}>
          {charge.failureReason
            ? charge.failureReason
            : charge.receiptNo
              ? `Receipt ${charge.receiptNo}`
              : fallbackMeta || meta.label}
        </Text>
      </View>
      <View style={{ alignItems: "flex-end" }}>
        <Text style={styles.rowAmt} numberOfLines={1}>
          {fmtMoney(charge.amount)}
        </Text>
        <Text style={[styles.rowStatus, { color }]} numberOfLines={1}>
          {meta.label}
        </Text>
      </View>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: {
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "space-between",
      paddingHorizontal: spacing.xl,
      paddingVertical: 10,
    },
    backBtn: {
      width: 42,
      height: 42,
      borderRadius: 21,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
      justifyContent: "center",
    },
    title: { ...font.h3, color: colors.textPrimary },

    preview: {
      backgroundColor: mode === "dark" ? "#3A2F12" : "#FEF3C7",
      borderRadius: radius.md,
      padding: 12,
      marginBottom: 16,
    },
    previewHead: { flexDirection: "row", gap: 8, alignItems: "flex-start" },
    previewTxt: { flex: 1, fontSize: 11, lineHeight: 16, color: mode === "dark" ? "#FDE68A" : "#92400E" },
    previewSwitch: { flexDirection: "row", gap: 6, marginTop: 10 },
    previewOpt: {
      flex: 1,
      paddingVertical: 6,
      borderRadius: radius.sm,
      alignItems: "center",
      borderWidth: 1,
      borderColor: mode === "dark" ? "#6B5A22" : "#FCD34D",
    },
    previewOptOn: { backgroundColor: mode === "dark" ? "#6B5A22" : "#FCD34D" },
    previewOptTxt: { fontSize: 10, fontWeight: "700", color: mode === "dark" ? "#FDE68A" : "#92400E" },
    previewOptTxtOn: { color: mode === "dark" ? "#FFFBEB" : "#78350F" },

    heroCard: { borderRadius: radius.xxl, padding: 18 },
    heroTop: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
    statusPill: {
      flexDirection: "row",
      alignItems: "center",
      gap: 6,
      backgroundColor: "rgba(255,255,255,0.22)",
      paddingHorizontal: 10,
      paddingVertical: 4,
      borderRadius: radius.full,
    },
    dot: { width: 7, height: 7, borderRadius: 4 },
    statusTxt: { color: "#fff", fontSize: 11, fontWeight: "800" },
    heroFreq: { color: "rgba(255,255,255,0.9)", fontSize: 11, fontWeight: "700" },
    heroAmount: { color: "#fff", fontSize: 32, fontWeight: "800", marginTop: 14, letterSpacing: -0.5 },
    heroFor: { color: "rgba(255,255,255,0.9)", fontSize: 12, marginTop: 2 },
    heroMetaRow: { flexDirection: "row", gap: 12, marginTop: 16 },
    heroMetaLbl: { color: "rgba(255,255,255,0.75)", fontSize: 10, fontWeight: "700", letterSpacing: 0.4 },
    heroMetaVal: { color: "#fff", fontSize: 13, fontWeight: "700", marginTop: 3 },
    heroBtns: { flexDirection: "row", gap: 10, marginTop: 18 },
    heroBtn: {
      flex: 1,
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "center",
      gap: 7,
      backgroundColor: "rgba(255,255,255,0.22)",
      paddingVertical: 11,
      borderRadius: radius.md,
    },
    heroBtnTxt: { color: "#fff", fontSize: 13, fontWeight: "800" },

    emptyCard: {
      backgroundColor: colors.surface,
      borderRadius: radius.xxl,
      padding: 22,
      alignItems: "center",
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    emptyIcon: {
      width: 60,
      height: 60,
      borderRadius: 30,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
      justifyContent: "center",
    },
    emptyTitle: { ...font.h3, color: colors.textPrimary, marginTop: 14 },
    emptySub: { fontSize: 12, color: colors.textSecondary, textAlign: "center", marginTop: 6, lineHeight: 18 },
    cta: {
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "center",
      gap: 8,
      paddingVertical: 13,
      paddingHorizontal: 26,
      borderRadius: radius.xl,
      marginTop: 18,
    },
    ctaTxt: { color: "#fff", fontSize: 14, fontWeight: "800" },

    section: { ...font.h4, color: colors.textPrimary, marginTop: 22, marginBottom: 10 },
    pausedNote: { fontSize: 11, color: colors.textSecondary, marginBottom: 10, lineHeight: 16 },
    emptyTxt: { color: colors.textSecondary, fontSize: 13, marginBottom: 10 },

    row: {
      flexDirection: "row",
      gap: 12,
      alignItems: "center",
      backgroundColor: colors.surface,
      padding: 13,
      borderRadius: radius.md,
      marginBottom: 9,
      ...shadow.soft,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    rowIcon: { width: 36, height: 36, borderRadius: 18, alignItems: "center", justifyContent: "center" },
    rowTitle: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
    rowMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
    rowAmt: { fontSize: 13, fontWeight: "800", color: colors.textPrimary },
    rowStatus: { fontSize: 11, fontWeight: "700", marginTop: 2 },

    cancelBtn: {
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "center",
      gap: 8,
      marginTop: 24,
      paddingVertical: 13,
      borderRadius: radius.md,
      borderWidth: 1,
      borderColor: colors.danger + "55",
    },
    cancelTxt: { color: colors.danger, fontSize: 13, fontWeight: "700" },
  });
}
