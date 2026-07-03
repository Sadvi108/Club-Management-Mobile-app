import { useMemo } from "react";
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Ionicons } from "@expo/vector-icons";
import { useRouter } from "expo-router";
import { radius, spacing, font, useTheme } from "../src/theme";
import { safeBack } from "../src/ui/dialogs";

// Full feature catalog — a SUPERSET of the home Quick Access grid plus every other
// student screen, grouped by section. Icons/colors match the home grid (src/mockData.ts).
type Option = { id: string; label: string; icon: string; color: string; route: string };
const SECTIONS: { title: string; items: Option[] }[] = [
  {
    title: "Training",
    items: [
      { id: "training", label: "Training", icon: "barbell", color: "#4F46E5", route: "/(tabs)/training" },
      { id: "classes", label: "Today's Classes", icon: "flash", color: "#F59E0B", route: "/(tabs)/schedule" },
      { id: "timetable", label: "Timetable", icon: "calendar", color: "#0EA5E9", route: "/(tabs)/schedule" },
      { id: "trainer", label: "My Trainer", icon: "person-circle", color: "#8B5CF6", route: "/(tabs)/training" },
      { id: "attendance", label: "Attendance", icon: "checkmark-done-circle", color: "#10B981", route: "/attendance" },
      { id: "book", label: "Book a Class", icon: "add-circle", color: "#14B8A6", route: "/book-class" },
      { id: "scan", label: "Scan QR", icon: "qr-code", color: "#0EA5E9", route: "/qr-scan" },
    ],
  },
  {
    title: "Payments",
    items: [
      { id: "feesdue", label: "Fees Due", icon: "wallet", color: "#EF4444", route: "/(tabs)/payments" },
      { id: "payments", label: "Payment History", icon: "receipt", color: "#14B8A6", route: "/(tabs)/payments" },
      { id: "prepay", label: "Advance Payment", icon: "card", color: "#8B5CF6", route: "/(tabs)/payments" },
      { id: "purchase", label: "Purchase Request", icon: "bag-handle", color: "#F59E0B", route: "/purchase-request" },
      { id: "purchases", label: "My Purchases", icon: "bag-check", color: "#F97316", route: "/purchases" },
    ],
  },
  {
    title: "Progress",
    items: [
      { id: "progress", label: "Progress Report", icon: "trending-up", color: "#6366F1", route: "/progress" },
      { id: "belt", label: "Belt / Rank", icon: "ribbon", color: "#EAB308", route: "/progress" },
      { id: "grading", label: "Grading", icon: "school", color: "#DB2777", route: "/progress" },
    ],
  },
  {
    title: "Club",
    items: [
      { id: "events", label: "Events", icon: "trophy", color: "#F97316", route: "/events" },
      { id: "competition", label: "Competition", icon: "medal", color: "#DB2777", route: "/events" },
      { id: "offers", label: "Offers", icon: "pricetags", color: "#10B981", route: "/events" },
      { id: "chat", label: "Chat Academy", icon: "chatbubbles", color: "#22C55E", route: "/chat" },
      { id: "helpdesk", label: "Help Desk", icon: "headset", color: "#0EA5E9", route: "/helpdesk" },
      { id: "notifications", label: "Notifications", icon: "notifications", color: "#F59E0B", route: "/notifications" },
    ],
  },
  {
    title: "Account",
    items: [
      { id: "profile", label: "Profile", icon: "person-circle", color: "#64748B", route: "/(tabs)/profile" },
      { id: "details", label: "Student Details", icon: "id-card", color: "#4F46E5", route: "/student-details" },
      { id: "editprofile", label: "Edit Profile", icon: "create", color: "#8B5CF6", route: "/edit-profile" },
    ],
  },
];

export default function More() {
  const router = useRouter();
  const { colors, shadow, mode } = useTheme();
  const styles = useMemo(() => createStyles(colors, shadow, mode), [colors, shadow, mode]);

  return (
    <View style={styles.root}>
      <SafeAreaView edges={["top"]} style={{ backgroundColor: colors.background }}>
        <View style={styles.header}>
          <TouchableOpacity style={styles.backBtn} onPress={() => safeBack(router)} testID="more-back" hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
            <Ionicons name="chevron-back" size={22} color={colors.textPrimary} />
          </TouchableOpacity>
          <Text style={styles.title}>All Features</Text>
          <View style={styles.backBtn} />
        </View>
      </SafeAreaView>

      <ScrollView contentContainerStyle={{ padding: spacing.xl, paddingBottom: 60 }} showsVerticalScrollIndicator={false}>
        <Text style={styles.sub}>Quick access to everything</Text>
        {SECTIONS.map((s) => (
          <View key={s.title}>
            <Text style={styles.sectionTitle}>{s.title.toUpperCase()}</Text>
            <View style={styles.grid}>
              {s.items.map((o) => (
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
              {/* keep the last row left-aligned when items % 3 !== 0 */}
              {s.items.length % 3 !== 0 &&
                Array.from({ length: 3 - (s.items.length % 3) }).map((_, i) => (
                  <View key={`pad-${i}`} style={[styles.card, { opacity: 0 }]} pointerEvents="none" />
                ))}
            </View>
          </View>
        ))}
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
    sectionTitle: { fontSize: 11, fontWeight: "800", letterSpacing: 1, color: colors.textMuted, marginBottom: 10, marginTop: 6 },
    grid: { flexDirection: "row", flexWrap: "wrap", justifyContent: "space-between" },
    card: { width: "30.5%", backgroundColor: colors.surface, borderRadius: radius.lg, paddingVertical: 18, paddingHorizontal: 8, alignItems: "center", marginBottom: 14, ...shadow.soft, borderWidth: mode === "dark" ? 1 : 0, borderColor: colors.border },
    iconWrap: { width: 50, height: 50, borderRadius: 25, alignItems: "center", justifyContent: "center", marginBottom: 8 },
    cardLbl: { fontSize: 11, color: colors.textPrimary, fontWeight: "600", textAlign: "center", lineHeight: 14 },
  });
}
