import { useMemo, useState } from "react";
import {
  View, Text, StyleSheet, TouchableOpacity, FlatList, ActivityIndicator, RefreshControl, Modal, Image, Pressable,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { radius, spacing, useTheme } from "../src/theme";
import { ScreenHeader, SelectField, Option } from "../src/ui/reportkit";
import { ErrorState } from "../src/ui/errorstate";
import { notify } from "../src/ui/dialogs";
import { useAuth } from "../src/api/auth";
import { api, centerQrContent } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { downloadPdf } from "../src/api/download";
import type { IdValueText } from "../src/api/types";

/**
 * Class check-in for instructors: pick a training centre + time, see the class list, and show
 * the centre's QR for the students to scan.
 *
 * WHY THERE IS NO "MARK PRESENT" BUTTON, AND NO REGISTER OF WHO HAS ARRIVED.
 * The whole attendance subsystem on this API is scoped to the caller, in both directions
 * (probed live on prod 2026-08-12 with instructor RICK1 and student POOBALAN123):
 *
 *  - WRITE. `/Attendance/Add` is the only attendance write, and its `qrCode` is only ever parsed
 *    as a CENTRE code — it says WHERE, never WHO, which is why the schema has no studentId.
 *    Under an instructor token, `attendanceType: 2` with a student's `ST-` code, bare id and
 *    registration code each answered `-1 "Invalid QR Code"` — notably NOT the "Invalid Instructor
 *    details" a student token gets, so the instructor check passed and the QR was the problem.
 *  - READ. `/Reports/Attendance` returns 0 rows for an instructor token even with NO filters,
 *    while student 89623 — who is in this instructor's own roster for centre 1639 — sees their
 *    two "Present" rows at that very centre through their own token.
 *
 * So an instructor can neither record another person's attendance nor see anyone's but their own.
 * A register board would have shown a permanent, confident "0 of 18 checked in" while students
 * were checking in fine. Both need a new backend route — see the tech-debt audit. What is left is
 * genuinely useful and fully proven: the class list, and the QR that students check in with.
 */

export default function ClassCheckIn() {
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);
  const insets = useSafeAreaInsets();
  const { token, user } = useAuth();

  const [centerId, setCenterId] = useState<number | string>("");
  const [timeId, setTimeId] = useState<number | string>("");
  const [qrOpen, setQrOpen] = useState(false);
  const [poster, setPoster] = useState(false);

  const centers = useApi<IdValueText[]>(() => (token ? api.dropdownListByType(3) : Promise.resolve([])), [token]);
  const times = useApi<IdValueText[]>(
    () => (token && centerId ? api.trainingTimeByTcId(Number(centerId)) : Promise.resolve([])),
    [token, centerId]
  );
  // The roster is CENTRE-scoped — there is no roster-by-training-time endpoint, so the training
  // time names the session being run rather than narrowing the list.
  const roster = useApi<IdValueText[]>(
    () => (token && centerId ? api.studentListByTcId(Number(centerId)) : Promise.resolve([])),
    [token, centerId]
  );

  const roster_ = Array.isArray(roster.data) ? roster.data : [];
  const centerOptions: Option[] = (centers.data ?? []).map((o) => ({ id: o.id, text: o.text }));
  const timeOptions: Option[] = (times.data ?? []).map((o) => ({ id: o.id, text: o.text }));
  const centerName = centerOptions.find((o) => String(o.id) === String(centerId))?.text || "";
  const timeName = timeOptions.find((o) => String(o.id) === String(timeId))?.text || "";

  // useApi keeps the previous data on error, so an unrendered error would show the PREVIOUS
  // centre's class list as if it were this one.
  const firstError = centers.error || times.error || roster.error || null;

  const openPoster = async () => {
    if (!user?.clubId || !centerId) return;
    setPoster(true);
    try {
      await downloadPdf(
        api.trainingCenterQRCodeUrl(user.clubId, Number(centerId)),
        `CENTRE_QR_${centerQrContent(centerId)}.pdf`
      );
    } catch (e: any) {
      notify("Couldn't open the poster", e?.message || "Try again.");
    } finally {
      setPoster(false);
    }
  };

  return (
    <View style={styles.root} testID="update-attendance">
      <ScreenHeader
        title="Class Check-In"
        subtitle={centerId ? `${roster_.length} student${roster_.length === 1 ? "" : "s"} at this centre` : undefined}
      />

      <FlatList
        data={roster_}
        keyExtractor={(item, i) => `${item.id}-${i}`}
        contentContainerStyle={{ paddingBottom: 40 + insets.bottom }}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={roster.loading && !!centerId}
            onRefresh={() => { roster.reload(); times.reload(); }}
            tintColor={colors.primary}
            colors={[colors.primary]}
          />
        }
        ListHeaderComponent={
          <View>
            <View style={styles.filterCard}>
              <SelectField
                label="Training Centre"
                placeholder="Select centre"
                value={centerId}
                options={centerOptions}
                loading={centers.loading}
                onChange={(id) => { setCenterId(id); setTimeId(""); }}
                testID="ua-centre"
              />
              <SelectField
                label="Training Time"
                placeholder={centerId ? "Select time" : "Select centre first"}
                value={timeId}
                options={timeOptions}
                loading={times.loading}
                disabled={!centerId}
                onChange={(id) => setTimeId(id)}
                testID="ua-time"
              />
            </View>

            {!!firstError && (
              <View style={{ marginHorizontal: spacing.xl, marginTop: 12 }}>
                <ErrorState
                  message={firstError}
                  onRetry={() => { centers.reload(); times.reload(); roster.reload(); }}
                  testID="ua-error"
                />
              </View>
            )}

            <TouchableOpacity
              style={styles.scanBtnWrap}
              onPress={() =>
                centerId
                  ? setQrOpen(true)
                  : notify("Select a centre", "Choose a training centre to show its check-in QR.")
              }
              activeOpacity={0.9}
              testID="ua-show-qr"
            >
              <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={[styles.scanBtn, shadow.strong]}>
                <Ionicons name="qr-code" size={20} color="#fff" />
                <Text style={styles.scanTxt}>Show Centre QR</Text>
              </LinearGradient>
            </TouchableOpacity>

            {/* Say plainly why there is no tick-and-save here, rather than showing a register
                that this API can never populate for an instructor. */}
            <View style={styles.noteCard}>
              <Ionicons name="information-circle-outline" size={17} color={colors.textSecondary} />
              <Text style={styles.noteTxt}>
                Students check in by scanning this QR with their own D-CLIX app, and it appears in
                their attendance straight away. Instructor accounts can&apos;t record or view
                check-ins on the current API — marking the register from here needs a backend update.
              </Text>
            </View>

            <View style={styles.listHead}>
              <Text style={styles.listTitle}>Class List</Text>
              {roster.loading && !!centerId ? (
                <ActivityIndicator color={colors.primary} />
              ) : (
                !!centerId && <Text style={styles.countChip}>{roster_.length}</Text>
              )}
            </View>
            {!!timeName && <Text style={styles.sessionTxt}>{centerName} · {timeName}</Text>}
          </View>
        }
        renderItem={({ item, index }) => (
          <View style={styles.card}>
            <Text style={styles.sno}>{index + 1}</Text>
            <View style={styles.avatar}>
              <Ionicons name="person" size={18} color={colors.primary} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.name} numberOfLines={1}>{item.text || "—"}</Text>
              {!!item.value && <Text style={styles.meta} numberOfLines={1}>{item.value}</Text>}
            </View>
          </View>
        )}
        ListEmptyComponent={
          roster.loading ? (
            <View style={styles.center}><ActivityIndicator color={colors.primary} size="large" /></View>
          ) : (
            <View style={styles.center}>
              <Ionicons name="people-outline" size={44} color={colors.textMuted} />
              <Text style={styles.emptyTxt}>
                {!centerId ? "Select a training centre to load the class list." : "No students at this centre."}
              </Text>
            </View>
          )
        }
      />

      {/* Full-screen centre QR — held up for the class to scan. */}
      <Modal visible={qrOpen} animationType="fade" onRequestClose={() => setQrOpen(false)}>
        <View style={styles.qrRoot}>
          <Pressable style={styles.qrClose} onPress={() => setQrOpen(false)} testID="ua-qr-close" hitSlop={10}>
            <Ionicons name="close" size={26} color={colors.textPrimary} />
          </Pressable>
          <Text style={styles.qrCentre} numberOfLines={2}>{centerName || "Training Centre"}</Text>
          <Text style={styles.qrSub}>Scan with the D-CLIX app to check in</Text>
          <View style={styles.qrBox}>
            {!!centerId && (
              <Image
                source={{ uri: api.qrCodeUrl(centerQrContent(centerId), 600) }}
                style={styles.qrImg}
                resizeMode="contain"
                testID="ua-qr-image"
              />
            )}
          </View>
          <Text style={styles.qrCode}>{centerId ? centerQrContent(centerId) : ""}</Text>
          <Text style={styles.qrTypeHint}>
            Can&apos;t scan? Students can type this code on their check-in screen.
          </Text>
          <TouchableOpacity style={styles.posterBtn} onPress={openPoster} disabled={poster} testID="ua-poster">
            {poster ? (
              <ActivityIndicator color={colors.primary} />
            ) : (
              <>
                <Ionicons name="print-outline" size={16} color={colors.primary} />
                <Text style={styles.posterTxt}>Open printable poster</Text>
              </>
            )}
          </TouchableOpacity>
        </View>
      </Modal>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    filterCard: { backgroundColor: colors.surfaceAlt, marginHorizontal: spacing.xl, marginTop: 4, borderRadius: radius.xl, padding: 14, gap: 10 },

    scanBtnWrap: { marginHorizontal: spacing.xl, marginTop: 16 },
    scanBtn: { flexDirection: "row", gap: 10, alignItems: "center", justifyContent: "center", paddingVertical: 15, borderRadius: radius.full },
    scanTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },

    noteCard: {
      flexDirection: "row", gap: 10, alignItems: "flex-start",
      backgroundColor: colors.surfaceAlt, borderRadius: radius.lg, padding: 13,
      marginHorizontal: spacing.xl, marginTop: 14,
    },
    noteTxt: { flex: 1, fontSize: 11.5, color: colors.textSecondary, lineHeight: 17 },

    listHead: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginHorizontal: spacing.xl, marginTop: 24, marginBottom: 4 },
    listTitle: { fontSize: 16, fontWeight: "800", color: colors.textPrimary },
    countChip: { fontSize: 12, fontWeight: "800", color: colors.primary, backgroundColor: colors.primary + "1A", paddingHorizontal: 10, paddingVertical: 4, borderRadius: 12, overflow: "hidden" },
    sessionTxt: { marginHorizontal: spacing.xl, marginBottom: 10, fontSize: 11.5, color: colors.textSecondary, fontWeight: "600" },

    card: { flexDirection: "row", alignItems: "center", gap: 10, backgroundColor: colors.surface, borderRadius: radius.lg, padding: 12, marginHorizontal: spacing.xl, marginBottom: 8, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    sno: { width: 20, fontSize: 12, fontWeight: "700", color: colors.textMuted, textAlign: "center" },
    avatar: { width: 40, height: 40, borderRadius: 20, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    name: { fontSize: 14, fontWeight: "700", color: colors.textPrimary },
    meta: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },

    center: { alignItems: "center", justifyContent: "center", padding: 40, gap: 10 },
    emptyTxt: { color: colors.textSecondary, fontSize: 14, textAlign: "center" },

    qrRoot: { flex: 1, backgroundColor: colors.background, alignItems: "center", justifyContent: "center", padding: spacing.xl },
    qrClose: { position: "absolute", top: 54, right: 20, width: 44, height: 44, borderRadius: 22, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    qrCentre: { fontSize: 22, fontWeight: "800", color: colors.textPrimary, textAlign: "center" },
    qrSub: { fontSize: 13, color: colors.textSecondary, marginTop: 6, marginBottom: 24 },
    qrBox: { backgroundColor: "#fff", padding: 16, borderRadius: radius.xl, ...shadow.card },
    qrImg: { width: 260, height: 260 },
    qrCode: { fontSize: 17, fontWeight: "800", color: colors.textPrimary, letterSpacing: 2, marginTop: 20 },
    qrTypeHint: { fontSize: 12, color: colors.textSecondary, marginTop: 6, textAlign: "center" },
    posterBtn: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 8, marginTop: 26, paddingVertical: 12, paddingHorizontal: 20, borderRadius: radius.full, borderWidth: 1.5, borderColor: colors.primary + "55", backgroundColor: colors.primary + "12", minHeight: 46 },
    posterTxt: { color: colors.primary, fontWeight: "800", fontSize: 13.5 },
  });
}
