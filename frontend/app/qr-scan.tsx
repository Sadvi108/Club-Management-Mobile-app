import { useEffect, useMemo, useRef, useState } from "react";
import { View, Text, StyleSheet, TouchableOpacity, Animated, Easing } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { radius, spacing, useTheme } from "../src/theme";

export default function QRScan() {
  const router = useRouter();
  const { colors } = useTheme();
  const styles = useMemo(() => createStyles(colors), [colors]);
  const [scanned, setScanned] = useState(false);
  const scan = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(scan, { toValue: 1, duration: 1400, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
        Animated.timing(scan, { toValue: 0, duration: 1400, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
      ])
    ).start();
    const t = setTimeout(() => setScanned(true), 2800);
    return () => clearTimeout(t);
  }, []);

  const translateY = scan.interpolate({ inputRange: [0, 1], outputRange: [0, 220] });

  return (
    <View style={styles.root}>
      <LinearGradient colors={["#000000", "#0A0A0B", "#1F1610"]} style={StyleSheet.absoluteFillObject} />

      <View style={styles.topBar}>
        <TouchableOpacity style={styles.close} onPress={() => router.back()} testID="qr-close">
          <Ionicons name="close" size={22} color="#fff" />
        </TouchableOpacity>
        <Text style={styles.title}>Scan to Check-in</Text>
        <View style={styles.close} />
      </View>

      <View style={styles.center}>
        <Text style={styles.instruction}>
          {scanned ? "Check-in Successful!" : "Align the QR within the frame"}
        </Text>

        <View style={styles.frame}>
          <View style={[styles.corner, styles.tl, { borderColor: colors.primary }]} />
          <View style={[styles.corner, styles.tr, { borderColor: colors.primary }]} />
          <View style={[styles.corner, styles.bl, { borderColor: colors.primary }]} />
          <View style={[styles.corner, styles.br, { borderColor: colors.primary }]} />

          {!scanned && (
            <Animated.View style={[styles.laser, { transform: [{ translateY }] }]}>
              <LinearGradient colors={["rgba(249,115,22,0)", colors.primary, "rgba(249,115,22,0)"]} style={{ width: "100%", height: 3 }} />
            </Animated.View>
          )}

          {scanned && (
            <View style={styles.successBubble}>
              <Ionicons name="checkmark-circle" size={70} color={colors.success} />
              <Text style={styles.successTxt}>Class: Karate Drills</Text>
              <Text style={styles.successMeta}>24 Feb · 06:00 AM</Text>
            </View>
          )}
        </View>

        <Text style={styles.hint}>
          {scanned ? "Attendance marked for today" : "Make sure camera has good lighting"}
        </Text>

        {scanned && (
          <TouchableOpacity onPress={() => router.back()} activeOpacity={0.9} style={styles.doneBtnWrap} testID="qr-done">
            <LinearGradient colors={colors.gradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 0 }} style={styles.doneBtn}>
              <Text style={styles.doneTxt}>Done</Text>
            </LinearGradient>
          </TouchableOpacity>
        )}
      </View>

      <View style={styles.footer}>
        <Ionicons name="shield-checkmark" size={14} color="rgba(255,255,255,0.6)" />
        <Text style={styles.footerTxt}>Secure · End-to-end encrypted</Text>
      </View>
    </View>
  );
}

function createStyles(colors: any) {
  return StyleSheet.create({
    root: { flex: 1 },
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
    successBubble: { alignItems: "center" },
    successTxt: { color: "#fff", fontSize: 16, fontWeight: "800", marginTop: 12 },
    successMeta: { color: "rgba(255,255,255,0.7)", fontSize: 12, marginTop: 4 },
    hint: { color: "rgba(255,255,255,0.6)", fontSize: 12, marginTop: 26, textAlign: "center" },
    doneBtnWrap: { marginTop: 28 },
    doneBtn: { paddingHorizontal: 44, paddingVertical: 14, borderRadius: radius.md },
    doneTxt: { color: "#fff", fontWeight: "800", fontSize: 15 },
    footer: { flexDirection: "row", gap: 6, alignItems: "center", justifyContent: "center", paddingBottom: 40 },
    footerTxt: { color: "rgba(255,255,255,0.6)", fontSize: 11, fontWeight: "500" },
  });
}
