import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";

// Full quick-access menu — every section of the app in one place.
const ALL_OPTIONS: { id: string; label: string; icon: string; color: string; route: string }[] = [
  { id: "attendance", label: "Attendance", icon: "checkmark-done-circle", color: "#10B981", route: "/attendance" },
  { id: "schedule", label: "Schedule", icon: "calendar", color: "#0EA5E9", route: "/(tabs)/schedule" },
  { id: "training", label: "Training", icon: "barbell", color: "#4F46E5", route: "/(tabs)/training" },
  { id: "progress", label: "Progress", icon: "trending-up", color: "#6366F1", route: "/progress" },
  { id: "belt", label: "Belt / Rank", icon: "ribbon", color: "#EAB308", route: "/progress" },
  { id: "feesdue", label: "Fees Due", icon: "wallet", color: "#EF4444", route: "/(tabs)/payments" },
  { id: "receipt", label: "Receipts", icon: "receipt", color: "#14B8A6", route: "/(tabs)/payments" },
  { id: "outstanding", label: "Outstanding", icon: "document-text", color: "#F97316", route: "/(tabs)/payments" },
  { id: "prepay", label: "Prepay", icon: "card", color: "#8B5CF6", route: "/(tabs)/payments" },
  { id: "grading", label: "Grading", icon: "school", color: "#DB2777", route: "/progress" },
  { id: "events", label: "Events", icon: "trophy", color: "#F59E0B", route: "/events" },
  { id: "tournaments", label: "Tournaments", icon: "medal", color: "#DB2777", route: "/events" },
  { id: "scan", label: "Scan QR", icon: "qr-code", color: "#0EA5E9", route: "/qr-scan" },
  { id: "profile", label: "Profile", icon: "person-circle", color: "#64748B", route: "/(tabs)/profile" },
];

export default function More() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => router.back()} testID="more-back" hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>All Features</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }} showsVerticalScrollIndicator={false}>
        <Text style={styles.sub}>Quick access to everything</Text>
        <View style={styles.grid}>
          {ALL_OPTIONS.map((o) => (
            <TouchableOpacity
              key={o.id}
              style={styles.card}
              activeOpacity={0.8}
              testID={`more-${o.id}`}
              onPress={() => router.push(o.route as any)}
            >
              <View style={[styles.iconWrap, { backgroundColor: o.color + (mode === "dark" ? "33" : "18") }]}>
                <Ionicons name={o.icon as any} size={24} color={o.color} />
              </View>
              <Text style={styles.cardLbl} numberOfLines={2}>{o.label}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

function createStyles(colors: any, shadow: any, mode: "light" | "dark") {
  return StyleSheet.create({
    root: { flex: 1, backgroundColor: colors.background },
    header: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: spacing.xl, paddingVertical: 10 },
    backBtn: { width: 42, height: 42, borderRadius: 21, backgroundColor: colors.surfaceAlt, alignItems: "center", justifyContent: "center" },
    title: { ...font.h3, color: colors.textPrimary },
    sub: { color: colors.textSecondary, fontSize: 13, marginBottom: 16 },
    grid: { flexDirection: "row", flexWrap: "wrap", justifyContent: "space-between" },
    card: { width: "30.5%", backgroundColor: colors.surface, borderRadius: radius.lg, paddingVertical: 18, paddingHorizontal: 8, alignItems: "center", marginBottom: 14, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    iconWrap: { width: 50, height: 50, borderRadius: 25, alignItems: "center", justifyContent: "center", marginBottom: 8 },
    cardLbl: { fontSize: 11, color: colors.textPrimary, fontWeight: "600", textAlign: "center", lineHeight: 14 },
  });
}
