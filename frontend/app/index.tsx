import { useEffect, useMemo, useRef } from "react";
import { View, Text, StyleSheet, Image, Animated, Easing } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { LOGO_URL, useTheme, font } from "../src/theme";

export default function Splash() {
  const router = useRouter();
  const { colors, mode } = useTheme();
  const fade = useRef(new Animated.Value(0)).current;
  const scale = useRef(new Animated.Value(0.85)).current;
  const ring = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(fade, { toValue: 1, duration: 700, useNativeDriver: true }),
      Animated.spring(scale, { toValue: 1, tension: 40, friction: 6, useNativeDriver: true }),
      Animated.loop(
        Animated.timing(ring, { toValue: 1, duration: 1800, easing: Easing.linear, useNativeDriver: true })
      ),
    ]).start();
    const t = setTimeout(() => router.replace("/login"), 2400);
    return () => clearTimeout(t);
  }, []);

  const rotate = ring.interpolate({ inputRange: [0, 1], outputRange: ["0deg", "360deg"] });

  const bgColors = mode === "dark"
    ? (["#000000", "#0A0A0B", "#1F1F23"] as const)
    : (["#FFFFFF", "#FFF7ED", "#FFEDD5"] as const);

  return (
    <View style={[styles.container, { backgroundColor: mode === "dark" ? "#000" : "#fff" }]} testID="splash-screen">
      <LinearGradient colors={bgColors} style={StyleSheet.absoluteFillObject} />

      {/* decorative glow */}
      <View style={[styles.glow, { backgroundColor: colors.primary, opacity: mode === "dark" ? 0.18 : 0.12 }]} />

      <Animated.View style={[styles.center, { opacity: fade, transform: [{ scale }] }]}>
        <View style={styles.logoWrap}>
          <Animated.View style={[styles.ring, { transform: [{ rotate }], borderTopColor: colors.primary }]} />
          <View style={[styles.logoCircle, { backgroundColor: mode === "dark" ? "#17171A" : "#FFFFFF", borderColor: colors.primary }]}>
            <Image source={{ uri: LOGO_URL }} style={styles.logoImg} />
          </View>
        </View>
        <Text style={[styles.brand, { color: colors.textPrimary }]}>D-CLIX</Text>
        <Text style={[styles.tagline, { color: colors.primary }]}>SPORTS TECHNOLOGY PLATFORM</Text>
      </Animated.View>

      <Animated.View style={[styles.footer, { opacity: fade }]}>
        <View style={styles.dotRow}>
          <View style={[styles.dot, { backgroundColor: colors.primary }]} />
          <View style={[styles.dot, { backgroundColor: colors.primary, opacity: 0.5 }]} />
          <View style={[styles.dot, { backgroundColor: colors.primary, opacity: 0.25 }]} />
        </View>
        <Text style={[styles.loader, { color: colors.textSecondary }]}>Preparing your dojo…</Text>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: "center", alignItems: "center" },
  glow: { position: "absolute", width: 420, height: 420, borderRadius: 210, top: "20%" },
  center: { alignItems: "center" },
  logoWrap: { width: 170, height: 170, alignItems: "center", justifyContent: "center", marginBottom: 28 },
  ring: {
    position: "absolute",
    width: 170,
    height: 170,
    borderRadius: 85,
    borderWidth: 2,
    borderColor: "rgba(249,115,22,0.18)",
  },
  logoCircle: {
    width: 130,
    height: 130,
    borderRadius: 65,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 3,
    shadowColor: "#F97316",
    shadowOpacity: 0.35,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 10 },
    overflow: "hidden",
  },
  logoImg: { width: 120, height: 120, borderRadius: 60 },
  brand: { ...font.h1, fontSize: 34, letterSpacing: 6, fontWeight: "900" },
  tagline: { marginTop: 10, fontSize: 10, letterSpacing: 3, fontWeight: "700" },
  footer: { position: "absolute", bottom: 56, alignItems: "center" },
  dotRow: { flexDirection: "row", gap: 6, marginBottom: 12 },
  dot: { width: 8, height: 8, borderRadius: 4 },
  loader: { fontSize: 11, letterSpacing: 1 },
});
