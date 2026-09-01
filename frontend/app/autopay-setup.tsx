import { useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, TextInput } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { notify, safeBack } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import {
  FREQUENCY_LABEL,
  PLACEHOLDER_PLAN,
  fmtDate,
  fmtMoney,
  fmtMonthShort,
  previewSchedule,
  startMonthOptions,
  type AutopayFrequency,
} from "../src/payments/autopay";

// Auto Pay setup / manage. UI SHELL: the form is fully interactive and previews
// real dates, but Confirm does not enrol anything — see src/payments/autopay.ts.

const FREQUENCIES: AutopayFrequency[] = ["monthly", "quarterly", "yearly"];
// Days offered for the charge date. Kept to 1-28 so every month has the day and
// nobody has to reason about February; `clampDay` still guards anything else.
const CHARGE_DAYS = [1, 5, 10, 15, 20, 25, 28];

export default function AutopaySetup() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const { user } = useAuth();

  // Prefill from the existing plan when managing. The account name comes from the
  // session (already in context — no fetch).
  // TODO(autopay): when several accounts are payable, add a sibling picker fed by
  // api.mySiblings(), the way (tabs)/payments.tsx builds its account chips.
  const accountName = (user?.name || PLACEHOLDER_PLAN.studentName).trim();

  const [amount, setAmount] = useState(String(PLACEHOLDER_PLAN.amount));
  const [frequency, setFrequency] = useState<AutopayFrequency>(PLACEHOLDER_PLAN.frequency);
  const [chargeDay, setChargeDay] = useState(PLACEHOLDER_PLAN.chargeDay);

  const monthOptions = useMemo(() => startMonthOptions(), []);
  const [startMonth, setStartMonth] = useState(monthOptions[0]);

  const amountValue = Number(amount.replace(/[^0-9.]/g, "")) || 0;
  const amountValid = amountValue > 0;

  // Live preview of what the user is actually agreeing to.
  const schedule = useMemo(
    () => previewSchedule(startMonth, frequency, chargeDay, 3),
    [startMonth, frequency, chargeDay]
  );

  function onConfirm() {
    if (!amountValid) {
      notify("Enter an amount", "Set the amount to charge each cycle before continuing.");
      return;
    }
    // TODO(autopay): POST /Autopay/Enroll with
    //   { studentId, amount: amountValue, frequency, chargeDay, startDate: startMonth }
    // then open the returned mandate/consent URL with WebBrowser.openBrowserAsync()
    // exactly as api.startPayment() does, and only treat the plan as active after the
    // gateway confirms the mandate — never on the app's own say-so.
    notify(
      "Not connected yet",
      "Auto pay isn't wired to the payment API yet, so this plan wasn't saved. The screen is a working preview of the flow."
    );
  }

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => safeBack(router, "/autopay")} testID="autopay-setup-back">
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>Set up Auto Pay</Text>
          <View style={{ width: 42 }} />
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 160 }} showsVerticalScrollIndicator={false}>
        {/* Account */}
        <Text style={styles.label}>Account</Text>
        <View style={styles.acctCard}>
          <View style={styles.acctIcon}>
            <Ionicons name="person-circle-outline" size={22} color={colors.primary} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.acctName} numberOfLines={1}>
              {accountName}
            </Text>
            <Text style={styles.acctMeta} numberOfLines={1}>
              Fees will be charged for this student
            </Text>
          </View>
        </View>

        {/* Amount */}
        <Text style={styles.label}>Amount each cycle</Text>
        <View style={[styles.amountRow, !amountValid && amount.length > 0 && { borderColor: colors.danger }]}>
          <Text style={styles.currency}>RM</Text>
          <TextInput
            style={styles.amountInput}
            value={amount}
            onChangeText={setAmount}
            keyboardType="decimal-pad"
            placeholder="0.00"
            placeholderTextColor={colors.textMuted}
            testID="autopay-amount"
          />
        </View>
        <Text style={styles.hint}>
          Your academy&apos;s monthly fee. If an invoice is issued for a different amount, the invoice wins.
        </Text>

        {/* Frequency */}
        <Text style={styles.label}>How often</Text>
        <View style={styles.optRow}>
          {FREQUENCIES.map((f) => {
            const on = frequency === f;
            return (
              <TouchableOpacity
                key={f}
                style={[styles.opt, on && styles.optOn]}
                onPress={() => setFrequency(f)}
                testID={`autopay-freq-${f}`}
              >
                <Text style={[styles.optTxt, on && styles.optTxtOn]} numberOfLines={1}>
                  {FREQUENCY_LABEL[f]}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>

        {/* Charge day */}
        <Text style={styles.label}>Charge on day</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.dayRow}>
          {CHARGE_DAYS.map((d) => {
            const on = chargeDay === d;
            return (
              <TouchableOpacity
                key={d}
                style={[styles.day, on && styles.dayOn]}
                onPress={() => setChargeDay(d)}
                testID={`autopay-day-${d}`}
              >
                <Text style={[styles.dayTxt, on && styles.dayTxtOn]}>{d}</Text>
              </TouchableOpacity>
            );
          })}
        </ScrollView>

        {/* Start month */}
        <Text style={styles.label}>Starting</Text>
        <View style={styles.optRow}>
          {monthOptions.map((m) => {
            const on = startMonth === m;
            return (
              <TouchableOpacity
                key={m}
                style={[styles.opt, on && styles.optOn]}
                onPress={() => setStartMonth(m)}
                testID={`autopay-start-${m}`}
              >
                <Text style={[styles.optTxt, on && styles.optTxtOn]} numberOfLines={1}>
                  {fmtMonthShort(m)}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>

        {/* Method */}
        <Text style={styles.label}>Payment method</Text>
        <View style={[styles.methodCard, styles.methodOn]}>
          <Ionicons name="card-outline" size={20} color={colors.primary} />
          <View style={{ flex: 1, marginLeft: 12 }}>
            <Text style={styles.methodTitle}>Online (card / e-wallet)</Text>
            <Text style={styles.methodSub} numberOfLines={2}>
              You&apos;ll authorise a standing instruction once. Nothing is charged today.
            </Text>
          </View>
          <Ionicons name="radio-button-on" size={18} color={colors.primary} />
        </View>
        <View style={[styles.methodCard, { opacity: 0.5 }]}>
          <Ionicons name="receipt-outline" size={20} color={colors.textSecondary} />
          <View style={{ flex: 1, marginLeft: 12 }}>
            <Text style={styles.methodTitle}>Direct Bank-In</Text>
            <Text style={styles.methodSub} numberOfLines={2}>
              Not available for auto pay — a slip has to be uploaded by hand each time.
            </Text>
          </View>
        </View>

        {/* Review */}
        <Text style={styles.section}>Your schedule</Text>
        <View style={[styles.reviewCard, shadow.soft]}>
          <View style={styles.reviewHead}>
            <Text style={styles.reviewAmt}>{fmtMoney(amountValue)}</Text>
            <Text style={styles.reviewFreq}>{FREQUENCY_LABEL[frequency]}</Text>
          </View>
          <View style={styles.divider} />
          {schedule.map((d, i) => (
            <View key={d} style={styles.reviewRow}>
              <Ionicons
                name={i === 0 ? "flag-outline" : "time-outline"}
                size={15}
                color={i === 0 ? colors.primary : colors.textMuted}
              />
              <Text style={[styles.reviewDate, i === 0 && { color: colors.textPrimary, fontWeight: "700" }]}>
                {fmtDate(d)}
              </Text>
              <Text style={styles.reviewRowAmt}>{fmtMoney(amountValue)}</Text>
            </View>
          ))}
          <Text style={styles.reviewNote}>
            Then {FREQUENCY_LABEL[frequency].toLowerCase()} until you pause or cancel. You can stop auto pay at any
            time.
          </Text>
        </View>
      </ScrollView>

      {/* Confirm bar */}
      <SafeAreaView edges={["bottom"]} style={styles.barWrap}>
        <TouchableOpacity onPress={onConfirm} disabled={!amountValid} testID="autopay-confirm">
          <LinearGradient
            colors={amountValid ? colors.gradient : ([colors.textMuted, colors.textMuted] as unknown as readonly [string, string])}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 0 }}
            style={[styles.confirm, amountValid && shadow.strong]}
          >
            <Ionicons name="shield-checkmark-outline" size={18} color="#fff" />
            <Text style={styles.confirmTxt}>Confirm auto pay</Text>
          </LinearGradient>
        </TouchableOpacity>
      </SafeAreaView>
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

    label: { ...font.tiny, color: colors.textSecondary, marginTop: 20, marginBottom: 9, textTransform: "uppercase" },
    hint: { fontSize: 11, color: colors.textMuted, marginTop: 7, lineHeight: 16 },
    section: { ...font.h4, color: colors.textPrimary, marginTop: 26, marginBottom: 10 },

    acctCard: {
      flexDirection: "row",
      alignItems: "center",
      gap: 12,
      backgroundColor: colors.surface,
      padding: 13,
      borderRadius: radius.md,
      borderWidth: 1,
      borderColor: colors.border,
    },
    acctIcon: {
      width: 38,
      height: 38,
      borderRadius: 19,
      backgroundColor: colors.surfaceAlt,
      alignItems: "center",
      justifyContent: "center",
    },
    acctName: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
    acctMeta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },

    amountRow: {
      flexDirection: "row",
      alignItems: "center",
      backgroundColor: colors.surface,
      borderRadius: radius.md,
      borderWidth: 1,
      borderColor: colors.border,
      paddingHorizontal: 14,
    },
    currency: { fontSize: 15, fontWeight: "800", color: colors.textSecondary, marginRight: 8 },
    amountInput: { flex: 1, paddingVertical: 14, fontSize: 20, fontWeight: "800", color: colors.textPrimary },

    optRow: { flexDirection: "row", gap: 8 },
    opt: {
      flex: 1,
      paddingVertical: 11,
      paddingHorizontal: 6,
      borderRadius: radius.md,
      backgroundColor: colors.surface,
      borderWidth: 1,
      borderColor: colors.border,
      alignItems: "center",
    },
    optOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    optTxt: { fontSize: 12, fontWeight: "700", color: colors.textSecondary },
    optTxtOn: { color: "#fff" },

    dayRow: { gap: 8, paddingRight: spacing.xl },
    day: {
      width: 44,
      height: 44,
      borderRadius: 22,
      backgroundColor: colors.surface,
      borderWidth: 1,
      borderColor: colors.border,
      alignItems: "center",
      justifyContent: "center",
    },
    dayOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    dayTxt: { fontSize: 13, fontWeight: "700", color: colors.textSecondary },
    dayTxtOn: { color: "#fff" },

    methodCard: {
      flexDirection: "row",
      alignItems: "center",
      backgroundColor: colors.surface,
      padding: 14,
      borderRadius: radius.md,
      borderWidth: 1,
      borderColor: colors.border,
      marginBottom: 9,
    },
    methodOn: { borderColor: colors.primary },
    methodTitle: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
    methodSub: { fontSize: 11, color: colors.textSecondary, marginTop: 2, lineHeight: 16 },

    reviewCard: {
      backgroundColor: colors.surface,
      borderRadius: radius.xl,
      padding: 16,
      borderWidth: mode === "dark" ? 1 : 0,
      borderColor: colors.border,
    },
    reviewHead: { flexDirection: "row", alignItems: "baseline", justifyContent: "space-between" },
    reviewAmt: { fontSize: 24, fontWeight: "800", color: colors.textPrimary, letterSpacing: -0.5 },
    reviewFreq: { fontSize: 12, fontWeight: "700", color: colors.primary },
    divider: { height: 1, backgroundColor: colors.border, marginVertical: 14 },
    reviewRow: { flexDirection: "row", alignItems: "center", gap: 10, paddingVertical: 7 },
    reviewDate: { flex: 1, fontSize: 13, color: colors.textSecondary },
    reviewRowAmt: { fontSize: 13, fontWeight: "700", color: colors.textPrimary },
    reviewNote: { fontSize: 11, color: colors.textMuted, marginTop: 12, lineHeight: 16 },

    barWrap: {
      position: "absolute",
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: colors.background,
      paddingHorizontal: spacing.xl,
      paddingTop: 12,
      borderTopWidth: 1,
      borderTopColor: colors.border,
    },
    confirm: {
      flexDirection: "row",
      alignItems: "center",
      justifyContent: "center",
      gap: 9,
      paddingVertical: 15,
      borderRadius: radius.xl,
      marginBottom: 8,
    },
    confirmTxt: { color: "#fff", fontSize: 15, fontWeight: "800" },
  });
}
