import { useEffect, useMemo, useRef, useState } from "react";
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Animated,
  Easing,
  Platform,
  Linking,
  TextInput,
  ActivityIndicator,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { BlurView } from "expo-blur";
import { useRouter } from "expo-router";
import { CameraView, useCameraPermissions } from "expo-camera";
import { radius, spacing, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";
import { api, ATTENDANCE_RESULT, ATTENDANCE_TYPE, parseCenterQr } from "../src/api/endpoints";
import { useApi } from "../src/api/useApi";
import { useAuth } from "../src/api/auth";
import type { IdValueText } from "../src/api/types";

// QR payloads that are obviously NOT a club check-in code — rejected before hitting the API
// for instant feedback. The backend (/Attendance/Add → status -1) is the real D-CLIX validator.
const FOREIGN_PREFIXES = ["WIFI:", "BEGIN:VCARD", "BEGIN:VEVENT", "MATMSG:", "MAILTO:", "TEL:", "SMSTO:", "BTC:"];
function looksForeign(v: string) {
  const t = v.trim().toUpperCase();
  return FOREIGN_PREFIXES.some((p) => t.startsWith(p));
}

type Result = { ok: boolean; title: string; sub: string };
// Set when the server answers "Select your training class time" — the same QR is resent
// once the user picks a slot.
type ClassPick = { qrCode: string; centerId: number | null };

export default function QRScan() {
  const router = useRouter();
  const { colors } = useTheme();
  const insets = useSafeAreaInsets();
  const styles = useMemo(() => createStyles(colors), [colors]);
  const { token } = useAuth();
  const info = useApi(() => (token ? api.myInfo() : Promise.resolve(null)), [token]);
  const [permission, requestPermission] = useCameraPermissions();
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<Result | null>(null);
  const [manual, setManual] = useState("");
  const [classPick, setClassPick] = useState<ClassPick | null>(null);
  const [slots, setSlots] = useState<IdValueText[]>([]);
  const lockRef = useRef(false); // CameraView fires onBarcodeScanned continuously — gate to one in-flight check
  const scan = useRef(new Animated.Value(0)).current;
  const isWeb = Platform.OS === "web";
  const canScan = !isWeb && !!permission?.granted;

  // Stamped at the moment of the check-in, not at render. This was a useMemo keyed on
  // [result] — which submitCode never reads — so the success card showed the time the
  // scanner screen was opened, which could be many minutes before the actual scan.
  const stampNow = () =>
    new Date().toLocaleString("en-GB", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(scan, { toValue: 1, duration: 1400, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
        Animated.timing(scan, { toValue: 0, duration: 1400, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => loop.stop();
  }, []);

  const translateY = scan.interpolate({ inputRange: [0, 1], outputRange: [0, 220] });

  // One check-in attempt. `tTimeId` is only sent on the retry after the server asked which
  // class this is for. attendanceType 1 = student self check-in (0 is rejected by the API —
  // that was the bug: every scan came back "Invalid QR Code").
  async function submitCode(raw: string, tTimeId?: number) {
    const value = (raw || "").trim();
    if (!value || busy || (lockRef.current && tTimeId === undefined)) return;
    lockRef.current = true;
    if (looksForeign(value)) {
      setResult({ ok: false, title: "Not a D-CLIX QR", sub: "Scan the QR poster at your training center." });
      return;
    }
    setBusy(true);
    try {
      const res = await api.addAttendance({
        qrCode: value,
        attendanceType: ATTENDANCE_TYPE.selfCheckIn,
        tTimeId: tTimeId ?? null,
      });

      if (res?.status === ATTENDANCE_RESULT.checkedIn) {
        const center =
          info.data?.tCenterName || (res.tTimeSession?.[0] as any)?.centerName || "Training Center";
        setClassPick(null);
        setResult({ ok: true, title: "Check-in Successful!", sub: `${center} · ${stampNow()}` });
        return;
      }

      // The centre QR was understood, but the server can't tell which session this is —
      // ask, then resend the same code with the chosen tTimeId.
      if (res?.status === ATTENDANCE_RESULT.needsClassTime) {
        const centerId = parseCenterQr(value);
        setClassPick({ qrCode: value, centerId });
        setSlots([]);
        if (centerId) {
          try {
            setSlots(await api.trainingTimeByTcId(centerId));
          } catch {
            /* the picker falls back to a plain message when the list can't be loaded */
          }
        }
        setResult(null);
        return;
      }

      setResult({
        ok: false,
        title: "Invalid QR Code",
        sub: res?.message && res.message !== "Invalid QR Code"
          ? res.message
          : "Scan the D-CLIX centre poster (its code looks like TC-00001945). Your own student QR won't check you in.",
      });
    } catch (e: any) {
      setResult({ ok: false, title: "Check-in failed", sub: e?.message || "Please try again." });
    } finally {
      setBusy(false);
    }
  }

  function rescan() {
    lockRef.current = false;
    setResult(null);
    setClassPick(null);
    setSlots([]);
    setManual("");
  }

  return (
    <View style={styles.root}>
      {/* Live camera on native (with permission); dark gradient elsewhere */}
      {canScan ? (
        <CameraView
          style={StyleSheet.absoluteFillObject}
          facing="back"
          barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
          onBarcodeScanned={busy || result || lockRef.current ? undefined : ({ data }) => submitCode(data)}
        />
      ) : (
        <LinearGradient colors={["#000000", "#0A0A0B", "#1F1610"]} style={StyleSheet.absoluteFillObject} />
      )}
      {/* Scrim for overlay contrast over the camera feed */}
      <View style={[StyleSheet.absoluteFillObject, { backgroundColor: "rgba(0,0,0,0.35)" }]} pointerEvents="none" />

      <BlurView intensity={30} tint="dark" style={[styles.topBar, { paddingTop: Math.max(insets.top + 8, 56) }]}>
        <TouchableOpacity
          style={styles.close}
          hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          onPress={() => safeBack(router)}
          testID="qr-close"
        >
          <Ionicons name="close" size={22} color="#fff" />
        </TouchableOpacity>
        <Text style={styles.title} numberOfLines={1}>Scan to Check-in</Text>
        <View style={styles.close} />
      </BlurView>

      <View style={styles.center}>
        <Text style={styles.instruction}>
          {result
            ? result.title
            : classPick
              ? "Select your training class time"
              : busy
                ? "Checking in…"
                : "Align the QR within the frame"}
        </Text>

        {/* Server answered "Select your training class time" — pick a slot and resend the code */}
        {classPick && !result ? (
          <View style={styles.pickWrap}>
            {busy ? (
              <ActivityIndicator color={colors.primary} size="large" />
            ) : slots.length ? (
              slots.map((s) => (
                <TouchableOpacity
                  key={s.id}
                  style={styles.pickRow}
                  activeOpacity={0.8}
                  onPress={() => submitCode(classPick.qrCode, s.id)}
                  testID={`qr-slot-${s.id}`}
                >
                  <Ionicons name="time-outline" size={18} color={colors.primary} />
                  <Text style={styles.pickTxt} numberOfLines={1}>{s.text || s.value}</Text>
                  <Ionicons name="chevron-forward" size={18} color="rgba(255,255,255,0.6)" />
                </TouchableOpacity>
              ))
            ) : (
              <Text style={styles.pickEmpty}>
                No class times are listed for this centre. Ask your academy to add the training time,
                then scan again.
              </Text>
            )}
          </View>
        ) : (
        <View style={styles.frame}>
          <View style={[styles.corner, styles.tl, { borderColor: result?.ok === false ? colors.danger : colors.primary }]} />
          <View style={[styles.corner, styles.tr, { borderColor: result?.ok === false ? colors.danger : colors.primary }]} />
          <View style={[styles.corner, styles.bl, { borderColor: result?.ok === false ? colors.danger : colors.primary }]} />
          <View style={[styles.corner, styles.br, { borderColor: result?.ok === false ? colors.danger : colors.primary }]} />

          {!result && !busy && (
            <Animated.View style={[styles.laser, { transform: [{ translateY }] }]}>
              <LinearGradient
                colors={["rgba(249,115,22,0)", colors.primary, "rgba(249,115,22,0)"]}
                style={{ width: "100%", height: 3 }}
              />
            </Animated.View>
          )}

          {busy && <ActivityIndicator color={colors.primary} size="large" />}

          {result && (
            <View style={styles.successBubble}>
              <Ionicons
                name={result.ok ? "checkmark-circle" : "close-circle"}
                size={70}
                color={result.ok ? colors.success : colors.danger}
              />
              <Text style={styles.successTxt} numberOfLines={2}>{result.title}</Text>
              <Text style={styles.successMeta} numberOfLines={2}>{result.sub}</Text>
            </View>
          )}
        </View>
        )}

        <Text style={styles.hint}>
          {result
            ? result.ok
              ? "Attendance marked for today"
              : "Make sure you scan the D-CLIX center QR"
            : classPick
              ? "Your academy needs to know which class this check-in is for"
              : "Make sure the camera has good lighting"}
        </Text>

        {/* Cancel out of the class-time picker back to scanning */}
        {classPick && !result && !busy && (
          <TouchableOpacity onPress={rescan} activeOpacity={0.9} style={styles.doneBtnWrap} testID="qr-pick-cancel">
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.doneBtn}>
              <Text style={styles.doneTxt}>Scan Again</Text>
            </LinearGradient>
          </TouchableOpacity>
        )}

        {/* Native, no permission yet → ask */}
        {!isWeb && permission && !permission.granted && !result && !classPick && (
          <TouchableOpacity
            onPress={() => (permission.canAskAgain ? requestPermission() : Linking.openSettings())}
            activeOpacity={0.9}
            style={styles.doneBtnWrap}
            testID="qr-permission"
          >
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.doneBtn}>
              <Ionicons name="camera" size={16} color="#fff" />
              <Text style={styles.doneTxt}>{permission.canAskAgain ? "  Enable Camera" : "  Open Settings"}</Text>
            </LinearGradient>
          </TouchableOpacity>
        )}

        {/* Web preview has no camera → manual code entry so check-in is still testable */}
        {(isWeb || !permission?.granted) && !result && !classPick && (
          <View style={styles.manualWrap}>
            <Text style={styles.manualNote}>
              {isWeb
                ? "Live camera scanning runs in the D-CLIX mobile app."
                : "Camera unavailable — enter the centre code shown at reception."}
            </Text>
            <View style={styles.manualRow}>
              <TextInput
                style={styles.manualInput}
                placeholder="Centre code, e.g. TC-00001945"
                placeholderTextColor="rgba(255,255,255,0.45)"
                value={manual}
                onChangeText={setManual}
                autoCapitalize="none"
                editable={!busy}
                testID="qr-manual-input"
              />
              <TouchableOpacity onPress={() => submitCode(manual)} disabled={busy || !manual.trim()} testID="qr-manual-submit">
                <LinearGradient
                  colors={colors.gradient}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 0 }}
                  style={[styles.manualBtn, (busy || !manual.trim()) && { opacity: 0.5 }]}
                >
                  <Ionicons name="arrow-forward" size={18} color="#fff" />
                </LinearGradient>
              </TouchableOpacity>
            </View>
          </View>
        )}

        {result && (
          <TouchableOpacity
            onPress={result.ok ? () => safeBack(router) : rescan}
            activeOpacity={0.9}
            style={styles.doneBtnWrap}
            testID={result.ok ? "qr-done" : "qr-rescan"}
          >
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.doneBtn}>
              <Text style={styles.doneTxt}>{result.ok ? "Done" : "Scan Again"}</Text>
            </LinearGradient>
          </TouchableOpacity>
        )}
      </View>

      <View style={[styles.footer, { paddingBottom: Math.max(insets.bottom + 20, 40) }]}>
        <Ionicons name="shield-checkmark" size={14} color="rgba(255,255,255,0.6)" />
        <Text style={styles.footerTxt}>Secure · Verified at the academy</Text>
      </View>
    </View>
  );
}

function createStyles(colors: any) {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: "#000" },
    topBar: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.xl, paddingTop: 56, paddingBottom: 14 },
    close: { width: 42, height: 42, borderRadius: 21, backgroundColor: "rgba(255,255,255,0.12)", alignItems: "center", justifyContent: "center" },
    title: { color: "#fff", fontSize: 16, fontWeight: "700" },
    center: { flex: 1, alignItems: "center", justifyContent: "center", paddingHorizontal: spacing.xl },
    instruction: { color: "rgba(255,255,255,0.9)", fontSize: 14, marginBottom: 28, fontWeight: "500" },
    frame: { width: 240, height: 240, justifyContent: "center", alignItems: "center" },
    corner: { position: "absolute", width: 40, height: 40 },
    tl: { top: 0, left: 0, borderTopWidth: 4, borderLeftWidth: 4, borderTopLeftRadius: 12 },
    tr: { top: 0, right: 0, borderTopWidth: 4, borderRightWidth: 4, borderTopRightRadius: 12 },
    bl: { bottom: 0, left: 0, borderBottomWidth: 4, borderLeftWidth: 4, borderBottomLeftRadius: 12 },
    br: { bottom: 0, right: 0, borderBottomWidth: 4, borderRightWidth: 4, borderBottomRightRadius: 12 },
    laser: { position: "absolute", top: 10, width: 220 },
    successBubble: { alignItems: "center", paddingHorizontal: 8 },
    successTxt: { color: "#fff", fontSize: 16, fontWeight: "800", marginTop: 12, maxWidth: 220, textAlign: "center" },
    successMeta: { color: "rgba(255,255,255,0.75)", fontSize: 12, marginTop: 4, textAlign: "center", maxWidth: 220 },
    hint: { color: "rgba(255,255,255,0.6)", fontSize: 12, marginTop: 26, textAlign: "center" },
    doneBtnWrap: { marginTop: 28 },
    doneBtn: { flexDirection: "row", alignItems: "center", justifyContent: "center", paddingHorizontal: 44, paddingVertical: 14, borderRadius: radius.md },
    doneTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },
    pickWrap: { width: "100%", maxWidth: 340, gap: 10, paddingVertical: 8, minHeight: 120, justifyContent: "center" },
    pickRow: {
      flexDirection: "row", alignItems: "center", gap: 10,
      backgroundColor: "rgba(255,255,255,0.12)", borderRadius: radius.md,
      paddingHorizontal: 14, paddingVertical: 14,
    },
    pickTxt: { flex: 1, color: "#fff", fontSize: 14, fontWeight: "700" },
    pickEmpty: { color: "rgba(255,255,255,0.75)", fontSize: 13, textAlign: "center", lineHeight: 19 },
    manualWrap: { marginTop: 28, width: "100%", maxWidth: 320 },
    manualNote: { color: "rgba(255,255,255,0.65)", fontSize: 12, textAlign: "center", marginBottom: 12 },
    manualRow: { flexDirection: "row", alignItems: "center", gap: 10 },
    manualInput: { flex: 1, backgroundColor: "rgba(255,255,255,0.12)", borderRadius: radius.md, paddingHorizontal: 14, paddingVertical: 12, color: "#fff", fontSize: 14 },
    manualBtn: { width: 46, height: 46, borderRadius: radius.md, alignItems: "center", justifyContent: "center" },
    footer: { flexDirection: "row", gap: 6, alignItems: "center", justifyContent: "center", paddingBottom: 40 },
    footerTxt: { color: "rgba(255,255,255,0.6)", fontSize: 11, fontWeight: "500" },
  });
}
