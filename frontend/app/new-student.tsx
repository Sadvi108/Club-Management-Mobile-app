import { useCallback, useEffect, useMemo, useState } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, RefreshControl } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { ScreenHeader } from "../src/ui/reportkit";
import { SkeletonList } from "../src/ui/skeleton";
import { confirmDialog, notify } from "../src/ui/dialogs";
import { api } from "../src/api/endpoints";
import { ApiError } from "../src/api/http";
import type { OnlineSubmissionRow } from "../src/api/types";

function fmtWhen(iso?: string) {
  if (!iso) return "—";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  return d.toLocaleString("en-GB", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

export default function NewStudent() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  // Load pending submissions directly so we can distinguish "backend not ready yet" (404) from a
  // real error — and never render fabricated rows.
  const [rows, setRows] = useState<OnlineSubmissionRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notReady, setNotReady] = useState(false);
  const [busyId, setBusyId] = useState<number | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    setNotReady(false);
    try {
      const data = await api.onlineSubmissions();
      setRows(Array.isArray(data) ? data : []);
    } catch (e: any) {
      if (e instanceof ApiError && e.status === 404) setNotReady(true);
      else setError(e?.message || "Could not load submissions.");
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const openParticulars = (r: OnlineSubmissionRow) =>
    router.push(`/student-particulars?id=${r.id}&name=${encodeURIComponent(r.studentName)}` as any);

  async function onApprove(r: OnlineSubmissionRow) {
    const ok = await confirmDialog(
      "Approve registration",
      `Approve ${r.studentName}? Make sure Training Centre, Student Centre, Present Grade and Fee Type are set (open the student to review). An auto WhatsApp with the login is sent to the parent.`,
      { confirmLabel: "Approve" }
    );
    if (!ok) return;
    setBusyId(r.id);
    try {
      await api.approveSubmission({ id: r.id });
      notify("Approved", `${r.studentName} has been approved.`);
      void load();
    } catch (e: any) {
      notify("Approve failed", e?.message || "Could not approve. Review the required fields first.");
    } finally {
      setBusyId(null);
    }
  }

  async function onReject(r: OnlineSubmissionRow) {
    const ok = await confirmDialog("Reject registration", `Reject and remove ${r.studentName}'s submission?`, {
      confirmLabel: "Reject",
      destructive: true,
    });
    if (!ok) return;
    setBusyId(r.id);
    try {
      await api.rejectSubmission(r.id);
      notify("Rejected", `${r.studentName}'s submission was rejected.`);
      void load();
    } catch (e: any) {
      notify("Reject failed", e?.message || "Could not reject the submission.");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <View style={styles.root}>
      <ScreenHeader title="New Student" subtitle="Online submission approvals" />

      <ScrollView
        contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }}
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={loading} onRefresh={load} tintColor={colors.primary} colors={[colors.primary]} />}
      >
        {/* How-to card (mirrors the web portal steps) */}
        <View style={styles.infoCard}>
          <View style={styles.infoIcon}><Ionicons name="information-circle" size={20} color={colors.primary} /></View>
          <View style={{ flex: 1 }}>
            <Text style={styles.infoTitle}>Approving a new student</Text>
            <Text style={styles.infoStep}>1. Open a submission and confirm Training Centre, Student Centre, Present Grade and Fee Type.</Text>
            <Text style={styles.infoStep}>2. Tap Approve — an auto WhatsApp with the user ID + password is sent to the parent.</Text>
          </View>
        </View>

        {loading && <SkeletonList rows={4} lines={3} style={{ padding: 0, paddingTop: 6 }} />}

        {/* Backend not shipped yet — honest state, no fake rows */}
        {!loading && notReady && (
          <View style={styles.stateBox}>
            <View style={styles.stateIcon}><Ionicons name="cloud-offline-outline" size={30} color={colors.primary} /></View>
            <Text style={styles.stateTitle}>Awaiting backend</Text>
            <Text style={styles.stateSub}>
              Online submission approvals aren&apos;t available on the app server yet. This screen goes live
              automatically once the club API exposes the submissions endpoint — no update needed.
            </Text>
            <TouchableOpacity style={styles.retryBtn} onPress={load} testID="ns-retry">
              <Ionicons name="refresh" size={15} color={colors.primary} />
              <Text style={styles.retryTxt}>Check again</Text>
            </TouchableOpacity>
          </View>
        )}

        {!loading && !notReady && error && (
          <View style={styles.stateBox}>
            <Ionicons name="alert-circle-outline" size={34} color={colors.danger} />
            <Text style={styles.stateSub}>{error}</Text>
            <TouchableOpacity style={styles.retryBtn} onPress={load}>
              <Ionicons name="refresh" size={15} color={colors.primary} />
              <Text style={styles.retryTxt}>Retry</Text>
            </TouchableOpacity>
          </View>
        )}

        {!loading && !notReady && !error && rows.length === 0 && (
          <View style={styles.stateBox}>
            <Ionicons name="checkmark-done-circle-outline" size={34} color={colors.success} />
            <Text style={styles.stateTitle}>All caught up</Text>
            <Text style={styles.stateSub}>No pending online submissions right now.</Text>
          </View>
        )}

        {!loading && rows.map((r) => (
          <View key={r.id} style={styles.card} testID={`ns-${r.id}`}>
            <TouchableOpacity style={styles.cardHead} activeOpacity={0.8} onPress={() => openParticulars(r)} testID={`ns-view-${r.id}`}>
              <View style={styles.avatar}><Text style={styles.avatarTxt}>{(r.studentName || "?").trim().charAt(0).toUpperCase()}</Text></View>
              <View style={{ flex: 1 }}>
                <Text style={styles.name} numberOfLines={2}>{r.studentName}</Text>
                <Text style={styles.sub} numberOfLines={1}>{[r.gender, r.presentGrade].filter(Boolean).join(" · ") || "—"}</Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
            </TouchableOpacity>

            <View style={styles.kvWrap}>
              <Row label="School" value={r.schoolName} colors={colors} />
              <Row label="Training centre" value={r.trainingCentre} colors={colors} />
              <Row label="Guardian" value={r.guardianName} colors={colors} />
              <Row label="Contact" value={r.contactNo} colors={colors} />
              <Row label="Submitted" value={fmtWhen(r.submissionDate)} colors={colors} />
            </View>

            <View style={styles.tagRow}>
              {r.isOldStudent != null && <Tag on={!!r.isOldStudent} onLabel="Old student" offLabel="New student" colors={colors} />}
              {r.uniformRequested != null && r.uniformRequested && <Tag on onLabel="Uniform requested" offLabel="" colors={colors} />}
            </View>

            <View style={styles.actions}>
              <TouchableOpacity style={[styles.actBtn, styles.viewBtn]} onPress={() => openParticulars(r)} activeOpacity={0.85} testID={`ns-particulars-${r.id}`}>
                <Ionicons name="document-text-outline" size={16} color={colors.primary} />
                <Text style={styles.viewTxt}>Particulars</Text>
              </TouchableOpacity>
              <TouchableOpacity style={[styles.actBtn, styles.rejectBtn]} disabled={busyId === r.id} onPress={() => onReject(r)} activeOpacity={0.85} testID={`ns-reject-${r.id}`}>
                <Ionicons name="close" size={16} color={colors.danger} />
                <Text style={styles.rejectTxt}>Reject</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.approveWrap} disabled={busyId === r.id} onPress={() => onApprove(r)} activeOpacity={0.9} testID={`ns-approve-${r.id}`}>
                <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.approveBtn}>
                  <Ionicons name="checkmark" size={16} color="#fff" />
                  <Text style={styles.approveTxt}>Approve</Text>
                </LinearGradient>
              </TouchableOpacity>
            </View>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

function Row({ label, value, colors }: { label: string; value?: string; colors: any }) {
  return (
    <View style={{ flexDirection: "row", justifyContent: "space-between", gap: 12, marginTop: 5 }}>
      <Text style={{ fontSize: 12, color: colors.textSecondary, fontWeight: "600" }}>{label}</Text>
      <Text style={{ fontSize: 12.5, color: colors.textPrimary, fontWeight: "700", flexShrink: 1, textAlign: "right" }} numberOfLines={1}>
        {value?.trim() || "—"}
      </Text>
    </View>
  );
}

function Tag({ on, onLabel, offLabel, colors }: { on: boolean; onLabel: string; offLabel: string; colors: any }) {
  const label = on ? onLabel : offLabel;
  if (!label) return null;
  return (
    <View style={{ flexDirection: "row", alignItems: "center", gap: 4, backgroundColor: colors.surfaceAlt, borderRadius: 8, paddingHorizontal: 8, paddingVertical: 4 }}>
      <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: on ? colors.primary : colors.textMuted }} />
      <Text style={{ fontSize: 10.5, fontWeight: "700", color: colors.textSecondary }}>{label}</Text>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },

    infoCard: { flexDirection: "row", gap: 12, backgroundColor: colors.surfaceAlt, borderRadius: radius.lg, padding: 14, marginBottom: 16, borderWidth: 1, borderColor: colors.primary + "22" },
    infoIcon: { width: 34, height: 34, borderRadius: 17, backgroundColor: colors.surface, alignItems: "center", justifyContent: "center" },
    infoTitle: { fontSize: 13, fontWeight: "800", color: colors.textPrimary, marginBottom: 4 },
    infoStep: { fontSize: 12, color: colors.textSecondary, lineHeight: 17, marginTop: 2 },

    stateBox: { alignItems: "center", gap: 8, paddingVertical: 44, paddingHorizontal: 20 },
    stateIcon: { width: 60, height: 60, borderRadius: 30, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center", marginBottom: 4 },
    stateTitle: { ...font.h4, color: colors.textPrimary },
    stateSub: { fontSize: 13, color: colors.textSecondary, textAlign: "center", lineHeight: 19 },
    retryBtn: { flexDirection: "row", alignItems: "center", gap: 6, marginTop: 10, paddingHorizontal: 16, paddingVertical: 10, borderRadius: radius.md, borderWidth: 1.5, borderColor: colors.primary + "55" },
    retryTxt: { color: colors.primary, fontWeight: "800", fontSize: 13 },

    card: { backgroundColor: colors.surface, borderRadius: radius.xl, padding: 14, marginBottom: 12, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    cardHead: { flexDirection: "row", alignItems: "center", gap: 12 },
    avatar: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center" },
    avatarTxt: { color: "#fff", fontWeight: "800", fontSize: 17 },
    name: { fontSize: 14.5, fontWeight: "800", color: colors.textPrimary },
    sub: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },

    kvWrap: { marginTop: 12, borderTopWidth: 1, borderTopColor: colors.border, paddingTop: 8 },
    tagRow: { flexDirection: "row", flexWrap: "wrap", gap: 6, marginTop: 10 },

    actions: { flexDirection: "row", gap: 8, marginTop: 14 },
    actBtn: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 5, paddingVertical: 10, borderRadius: radius.md, flex: 1 },
    viewBtn: { backgroundColor: colors.surfaceAlt },
    viewTxt: { color: colors.primary, fontWeight: "700", fontSize: 12.5 },
    rejectBtn: { backgroundColor: colors.danger + "14" },
    rejectTxt: { color: colors.danger, fontWeight: "700", fontSize: 12.5 },
    approveWrap: { flex: 1.2, borderRadius: radius.md, overflow: "hidden" },
    approveBtn: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 5, paddingVertical: 10 },
    approveTxt: { color: "#fff", fontWeight: "800", fontSize: 12.5 },
  });
}
