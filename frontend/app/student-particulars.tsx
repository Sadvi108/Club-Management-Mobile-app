import { useCallback, useEffect, useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from "react-native";
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter, useLocalSearchParams } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack, confirmDialog, notify } from "../src/ui/dialogs";
import { SkeletonList } from "../src/ui/skeleton";
import { api } from "../src/api/endpoints";
import { ApiError } from "../src/api/http";
import type { OnlineSubmissionDetail } from "../src/api/types";

function fmt(v: any) {
  return v == null || v === "" ? "—" : String(v);
}

// Required (*) fields the web form enforces before Approve is allowed.
const REQUIRED: { key: keyof OnlineSubmissionDetail; label: string }[] = [
  { key: "trainingCentre", label: "Training Centre" },
  { key: "studentCentre", label: "Student Centre" },
  { key: "presentGrade", label: "Present Grade" },
  { key: "feeType", label: "Fee Type" },
];

export default function StudentParticulars() {
  const router = useRouter();
  const { id, name } = useLocalSearchParams<{ id?: string; name?: string }>();
  const subId = Number(id);
  const { colors, shadow, mode } = useTheme();
  const insets = useSafeAreaInsets();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  const [data, setData] = useState<OnlineSubmissionDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notReady, setNotReady] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    if (!subId) {
      setError("Missing submission id.");
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    setNotReady(false);
    try {
      const d = await api.onlineSubmissionDetail(subId);
      setData(d ?? null);
    } catch (e: any) {
      if (e instanceof ApiError && e.status === 404) setNotReady(true);
      else setError(e?.message || "Could not load student particulars.");
    } finally {
      setLoading(false);
    }
  }, [subId]);

  useEffect(() => {
    void load();
  }, [load]);

  const missing = data ? REQUIRED.filter((r) => !String(data[r.key] ?? "").trim()) : [];
  const canApprove = !!data && missing.length === 0;

  async function onApprove() {
    if (!data) return;
    if (!canApprove) {
      notify("Missing required fields", `Set these first (in the club system): ${missing.map((m) => m.label).join(", ")}.`);
      return;
    }
    const ok = await confirmDialog("Approve registration", `Approve ${data.studentName}? An auto WhatsApp with the login is sent to the parent.`, { confirmLabel: "Approve" });
    if (!ok) return;
    setBusy(true);
    try {
      await api.approveSubmission({
        id: subId,
        trainingCentreId: data.trainingCentreId ?? null,
        studentCentreId: data.studentCentreId ?? null,
        examCentreId: data.examCentreId ?? null,
        presentGradeId: data.presentGradeId ?? null,
        feeTypeId: data.feeTypeId ?? null,
      });
      notify("Approved", `${data.studentName} has been approved.`);
      safeBack(router);
    } catch (e: any) {
      notify("Approve failed", e?.message || "Could not approve.");
    } finally {
      setBusy(false);
    }
  }

  async function onReject() {
    if (!data) return;
    const ok = await confirmDialog("Reject registration", `Reject ${data.studentName}'s submission?`, { confirmLabel: "Reject", destructive: true });
    if (!ok) return;
    setBusy(true);
    try {
      await api.rejectSubmission(subId);
      notify("Rejected", `${data.studentName}'s submission was rejected.`);
      safeBack(router);
    } catch (e: any) {
      notify("Reject failed", e?.message || "Could not reject.");
    } finally {
      setBusy(false);
    }
  }

  const headerName = (name || data?.studentName || "Student").trim();

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.primary }}>
        <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.header}>
          <TouchableOpacity style={styles.backBtn} hitSlop={8} onPress={() => safeBack(router)} testID="sp-back">
            <Ionicons name="chevron-back" size={22} color="#fff" />
          </TouchableOpacity>
          <View style={{ flex: 1 }}>
            <Text style={styles.hLabel}>STUDENT PARTICULARS</Text>
            <Text style={styles.hName} numberOfLines={2} testID="sp-name">{headerName}</Text>
            {!!data?.regNo && <Text style={styles.hReg}>{data.regNo}</Text>}
          </View>
        </LinearGradient>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 120 }} showsVerticalScrollIndicator={false}>
        {loading && <SkeletonList rows={5} lines={2} style={{ padding: 0 }} />}

        {!loading && notReady && (
          <View style={styles.stateBox}>
            <View style={styles.stateIcon}><Ionicons name="cloud-offline-outline" size={28} color={colors.primary} /></View>
            <Text style={styles.stateTitle}>Awaiting backend</Text>
            <Text style={styles.stateSub}>Student particulars load here once the club API exposes the submission-details endpoint.</Text>
          </View>
        )}
        {!loading && !notReady && error && (
          <View style={styles.stateBox}>
            <Ionicons name="alert-circle-outline" size={32} color={colors.danger} />
            <Text style={styles.stateSub}>{error}</Text>
          </View>
        )}

        {!loading && data && (
          <>
            {missing.length > 0 && (
              <View style={styles.warnCard}>
                <Ionicons name="warning-outline" size={18} color={colors.warning} />
                <Text style={styles.warnTxt}>
                  Required before approval: <Text style={{ fontWeight: "800" }}>{missing.map((m) => m.label).join(", ")}</Text>. Set them in the club system, then refresh.
                </Text>
              </View>
            )}

            <Section title="Registration" colors={colors} styles={styles}>
              <KV label="Reg. No" value={data.regNo} styles={styles} />
              <KV label="QR Code" value={data.qrCode} styles={styles} />
              <KV label="Present Grade" value={data.presentGrade} req styles={styles} />
              <KV label="IC / Passport" value={data.icNo} styles={styles} />
              <KV label="Gender" value={data.gender} styles={styles} />
              <KV label="Date of Birth" value={data.dateOfBirth} styles={styles} />
              <KV label="Old Student" value={data.isOldStudent == null ? "" : data.isOldStudent ? "Yes" : "No"} styles={styles} />
            </Section>

            <Section title="Training" colors={colors} styles={styles}>
              <KV label="Training Centre" value={data.trainingCentre} req styles={styles} />
              <KV label="Student Centre" value={data.studentCentre} req styles={styles} />
              <KV label="School / Workplace" value={data.schoolWorkplace || data.schoolName} styles={styles} />
              <KV label="Exam Centre" value={data.examCentre} styles={styles} />
              <KV label="Training Day" value={data.trainingDay} styles={styles} />
              <KV label="Training Time" value={data.trainingTime} styles={styles} />
              <KV label="Commencement" value={data.classCommencementDate} styles={styles} />
            </Section>

            <Section title="Guardian & Contact" colors={colors} styles={styles}>
              <KV label="Parent / Guardian" value={data.guardianName} styles={styles} />
              <KV label="Occupation" value={data.guardianOccupation} styles={styles} />
              <KV label="Contact / WhatsApp" value={data.contactNo} styles={styles} />
              <KV label="Email" value={data.emailAddress} styles={styles} />
              <KV label="Address" value={[data.addressLine1, data.addressLine2, data.city, data.state, data.postcode].filter(Boolean).join(", ")} styles={styles} />
            </Section>

            <Section title="Fees & Membership" colors={colors} styles={styles}>
              <KV label="Fee Type" value={data.feeType} req styles={styles} />
              <KV label="Package / Session" value={data.packageSession} styles={styles} />
              <KV label="Registration Year" value={data.registrationYear} styles={styles} />
              <KV label="Material (Uniform)" value={data.material} styles={styles} />
              <KV label="Uniform Requested" value={data.uniformRequested == null ? "" : data.uniformRequested ? "Yes" : "No"} styles={styles} />
              <KV label="Outstanding" value={data.outstandingAmount != null ? `RM ${Number(data.outstandingAmount).toFixed(2)}` : ""} styles={styles} />
              <KV label="Health Remarks" value={data.healthRemarks} styles={styles} />
            </Section>
          </>
        )}
      </ScrollView>

      {/* Approve / Reject bar */}
      {!loading && data && (
        <View style={[styles.bar, { paddingBottom: Math.max(insets.bottom + 12, 20) }]}>
          <TouchableOpacity style={styles.barReject} disabled={busy} onPress={onReject} activeOpacity={0.85} testID="sp-reject">
            <Ionicons name="close" size={18} color={colors.danger} />
            <Text style={styles.barRejectTxt}>Reject</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.barApproveWrap, !canApprove && { opacity: 0.5 }]} disabled={busy} onPress={onApprove} activeOpacity={0.9} testID="sp-approve">
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.barApprove}>
              <Ionicons name="checkmark" size={18} color="#fff" />
              <Text style={styles.barApproveTxt}>{canApprove ? "Approve" : "Complete fields to approve"}</Text>
            </LinearGradient>
          </TouchableOpacity>
        </View>
      )}
    </View>
  );
}

function Section({ title, children, colors, styles }: any) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title.toUpperCase()}</Text>
      <View>{children}</View>
    </View>
  );
}

function KV({ label, value, req, styles }: { label: string; value: any; req?: boolean; styles: any }) {
  const empty = value == null || String(value).trim() === "";
  return (
    <View style={styles.kv}>
      <Text style={styles.kvLabel}>{label}{req ? " *" : ""}</Text>
      <Text style={[styles.kvValue, req && empty && styles.kvMissing]} numberOfLines={3}>{fmt(value)}</Text>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "flex-start", gap: 10, paddingHorizontal: spacing.lg, paddingBottom: 18, paddingTop: 6 },
    backBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: "rgba(255,255,255,0.2)", alignItems: "center", justifyContent: "center" },
    hLabel: { color: "rgba(255,255,255,0.8)", fontSize: 10, fontWeight: "800", letterSpacing: 1, marginTop: 4 },
    hName: { color: "#fff", fontSize: 19, fontWeight: "800", marginTop: 2 },
    hReg: { color: "rgba(255,255,255,0.9)", fontSize: 12, fontWeight: "600", marginTop: 2 },

    stateBox: { alignItems: "center", gap: 8, paddingVertical: 50, paddingHorizontal: 20 },
    stateIcon: { width: 56, height: 56, borderRadius: 28, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center", marginBottom: 4 },
    stateTitle: { ...font.h4, color: colors.textPrimary },
    stateSub: { fontSize: 13, color: colors.textSecondary, textAlign: "center", lineHeight: 19 },

    warnCard: { flexDirection: "row", gap: 10, alignItems: "flex-start", backgroundColor: colors.warning + "1A", borderRadius: radius.md, padding: 12, marginBottom: 14, borderWidth: 1, borderColor: colors.warning + "44" },
    warnTxt: { flex: 1, fontSize: 12.5, color: colors.textPrimary, lineHeight: 18 },

    section: { backgroundColor: colors.surface, borderRadius: radius.xl, padding: 16, marginBottom: 12, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    sectionTitle: { fontSize: 10.5, fontWeight: "800", letterSpacing: 1, color: colors.primary, marginBottom: 8 },
    kv: { flexDirection: "row", justifyContent: "space-between", gap: 14, paddingVertical: 7, borderBottomWidth: 1, borderBottomColor: colors.border },
    kvLabel: { fontSize: 12.5, color: colors.textSecondary, fontWeight: "600", flex: 1 },
    kvValue: { fontSize: 13, color: colors.textPrimary, fontWeight: "700", flex: 1.3, textAlign: "right" },
    kvMissing: { color: colors.danger },

    bar: { position: "absolute", left: 0, right: 0, bottom: 0, flexDirection: "row", gap: 10, paddingHorizontal: spacing.xl, paddingTop: 12, backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border, ...shadow.card },
    barReject: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6, paddingHorizontal: 20, paddingVertical: 14, borderRadius: radius.md, backgroundColor: colors.danger + "14" },
    barRejectTxt: { color: colors.danger, fontWeight: "800", fontSize: 14 },
    barApproveWrap: { flex: 1, borderRadius: radius.md, overflow: "hidden" },
    barApprove: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 6, paddingVertical: 14 },
    barApproveTxt: { color: "#fff", fontWeight: "800", fontSize: 14 },
  });
}
