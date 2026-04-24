import { useEffect, useRef } from "react";
import { View, Text, StyleSheet, Image, Animated, Easing } from "react-native";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { colors, font } from "../src/theme";

export default function Splash() {
  const router = useRouter();
  const fade = useRef(new Animated.Value(0)).current;
  const scale = useRef(new Animated.Value(0.85)).current;
  const ring = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(fade, { toValue: 1, duration: 700, useNativeDriver: true }),
      Animated.spring(scale, { toValue: 1, tension: 40, friction: 6, useNativeDriver: true }),
      Animated.loop(
        Animated.timing(ring, { toValue: 1, duration: 1600, easing: Easing.linear, useNativeDriver: true })
      ),
    ]).start();
    const t = setTimeout(() => router.replace("/login"), 2200);
    return () => clearTimeout(t);
  }, []);

  const rotate = ring.interpolate({ inputRange: [0, 1], outputRange: ["0deg", "360deg"] });

  return (
    <View style={styles.container} testID="splash-screen">
      <Image
        source={{ uri: "https://images.pexels.com/photos/6005457/pexels-photo-6005457.jpeg?auto=compress&cs=tinysrgb&w=1200" }}
        style={StyleSheet.absoluteFillObject}
        blurRadius={3}
      />
      <LinearGradient
        colors={["rgba(79,70,229,0.85)", "rgba(124,58,237,0.9)", "rgba(147,51,234,0.95)"]}
        style={StyleSheet.absoluteFillObject}
      />

      <Animated.View style={[styles.center, { opacity: fade, transform: [{ scale }] }]}>
        <View style={styles.logoWrap}>
          <Animated.View style={[styles.ring, { transform: [{ rotate }] }]} />
          <View style={styles.logoCircle}>
            <Ionicons name="flash" size={46} color={colors.primary} />
          </View>
        </View>
        <Text style={styles.brand}>APEX ACADEMY</Text>
        <Text style={styles.tagline}>Train Hard. Rise Higher.</Text>
      </Animated.View>

      <Animated.View style={[styles.footer, { opacity: fade }]}>
        <View style={styles.dotRow}>
          <View style={[styles.dot, { backgroundColor: "#fff" }]} />
          <View style={[styles.dot, { opacity: 0.6 }]} />
          <View style={[styles.dot, { opacity: 0.3 }]} />
        </View>
        <Text style={styles.loader}>Preparing your dojo…</Text>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.primary, justifyContent: "center", alignItems: "center" },
  center: { alignItems: "center" },
  logoWrap: { width: 150, height: 150, alignItems: "center", justifyContent: "center", marginBottom: 28 },
  ring: {
    position: "absolute",
    width: 150,
    height: 150,
    borderRadius: 75,
    borderWidth: 2,
    borderColor: "rgba(255,255,255,0.25)",
    borderTopColor: "#fff",
  },
  logoCircle: {
    width: 110,
    height: 110,
    borderRadius: 55,
    backgroundColor: "#fff",
    alignItems: "center",
    justifyContent: "center",
    shadowColor: "#000",
    shadowOpacity: 0.25,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 10 },
  },
  brand: { ...font.h1, color: "#fff", fontSize: 32, letterSpacing: 3, fontWeight: "800" },
  tagline: { color: "rgba(255,255,255,0.85)", marginTop: 10, fontSize: 14, letterSpacing: 2, fontWeight: "500" },
  footer: { position: "absolute", bottom: 56, alignItems: "center" },
  dotRow: { flexDirection: "row", gap: 6, marginBottom: 12 },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: "#fff" },
  loader: { color: "rgba(255,255,255,0.8)", fontSize: 12, letterSpacing: 1 },
});
